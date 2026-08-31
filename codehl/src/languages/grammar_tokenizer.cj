package codehl.languages

import std.collection.{ArrayList, HashMap}
import std.regex.*
import std.sync.Mutex
import codehl.grammar.{Grammar, GrammarCapture, GrammarPattern}

public class GrammarTokenizer <: CodeTokenizer {
    private static let diagnostics = TokenizerDiagnostics()
    private let grammar: Grammar
    private let ids: Array<String>
    private let externalGrammars: HashMap<String, Grammar>
    private let expandedPatternCache: HashMap<String, Array<ExpandedPattern>>
    private let ruleScannerCache: HashMap<String, RuleScanner>
    private var rootRuleScanner: ?RuleScanner
    private let scopeClassCache: HashMap<String, String>
    private let scopeStackCache: HashMap<String, Array<String>>

    public init(grammar: Grammar, languageIds: Array<String>) {
        this.grammar = grammar
        this.ids = languageIds
        this.externalGrammars = HashMap<String, Grammar>()
        this.expandedPatternCache = HashMap<String, Array<ExpandedPattern>>()
        this.ruleScannerCache = HashMap<String, RuleScanner>()
        this.rootRuleScanner = None<RuleScanner>
        this.scopeClassCache = HashMap<String, String>()
        this.scopeStackCache = HashMap<String, Array<String>>()
    }

    public init(grammar: Grammar, languageIds: Array<String>, externalGrammars: HashMap<String, Grammar>) {
        this.grammar = grammar
        this.ids = languageIds
        this.externalGrammars = externalGrammars
        this.expandedPatternCache = HashMap<String, Array<ExpandedPattern>>()
        this.ruleScannerCache = HashMap<String, RuleScanner>()
        this.rootRuleScanner = None<RuleScanner>
        this.scopeClassCache = HashMap<String, String>()
        this.scopeStackCache = HashMap<String, Array<String>>()
    }

    public prop name: String {
        get() {
            return grammar.name
        }
    }

    public prop languageIds: Array<String> {
        get() {
            return ids
        }
    }

    public static func enableDiagnostics(): Unit {
        diagnostics.enabled = true
        diagnostics.reset()
    }

    public static func disableDiagnostics(): TokenizerDiagnosticSnapshot {
        diagnostics.enabled = false
        return diagnostics.snapshot()
    }

    public func tokenizeLine(line: String, state: TokenizerState): LineTokens {
        let tokens = ArrayList<Token>()
        let stack = ArrayList<TokenizerContext>()
        for (context in state.contexts) {
            stack.add(context)
        }
        var cursor: Int64 = 0
        var scannerStackSize: Int64 = -1
        var scanner: ?RuleScanner = None
        var zeroWidthBeginCursor: Int64 = -1
        let zeroWidthBeginKeys = ArrayList<String>()

        while (cursor < line.size) {
            if (cursor != zeroWidthBeginCursor) {
                zeroWidthBeginCursor = cursor
                zeroWidthBeginKeys.clear()
            }
            match (tryCloseContext(line, cursor, tokens, stack)) {
                case Some(nextCursor) =>
                    cursor = nextCursor
                    continue
                case None => ()
            }

            if (scannerStackSize != stack.size) {
                scanner = Some(currentRuleScanner(stack))
                scannerStackSize = stack.size
            }
            let ruleMatch = match (scanner) {
                case Some(value) => findNextRule(line, cursor, value)
                case None => None<RuleMatch>
            }
            match (findNonContentContextEnd(line, cursor, stack)) {
                case Some(endRange) =>
                    match (ruleMatch) {
                        case Some(found) =>
                            if (endRange.start <= found.start) {
                                cursor = closeTopContext(line, endRange, tokens, stack, cursor)
                                continue
                            }
                        case None =>
                            cursor = closeTopContext(line, endRange, tokens, stack, cursor)
                            continue
                    }
                case None => ()
            }
            match (ruleMatch) {
                case Some(found) =>
                    if (found.start > cursor) {
                        cursor = found.start
                    }
                    if (found.isBegin && found.end <= found.start) {
                        let key = zeroWidthBeginKey(found, cursor)
                        if (containsString(zeroWidthBeginKeys, key)) {
                            cursor += 1
                            continue
                        }
                        zeroWidthBeginKeys.add(key)
                    }
                    let next = applyRule(line, found, tokens, stack)
                    cursor = if (next > cursor || found.isBegin) { next } else { cursor + 1 }
                case None =>
                    break
            }
        }

        return LineTokens(tokens.toArray(), TokenizerState(contexts: cleanupLineLocalContexts(stack).toArray()))
    }

    private static func zeroWidthBeginKey(found: RuleMatch, cursor: Int64): String {
        return "${cursor}|${found.grammar.scopeName}|${found.rule.name}|${found.rule.contentName}|${found.rule.begin}|${found.rule.end}"
    }

    private static func containsString(values: ArrayList<String>, target: String): Bool {
        for (value in values) {
            if (value == target) {
                return true
            }
        }
        return false
    }

    private static func cleanupLineLocalContexts(stack: ArrayList<TokenizerContext>): ArrayList<TokenizerContext> {
        let cleaned = ArrayList<TokenizerContext>()
        for (context in stack) {
            if (!context.canCarryAcrossLines) {
                continue
            }
            let activeScope = contextActiveScope(context)
            if (activeScope.isEmpty() && isLineLocalStructuralContext(context)) {
                continue
            }
            if (activeScope.startsWith("comment.line.") || context.endPattern.contains("\\n") || context.whilePattern.contains("\\n")) {
                continue
            }
            cleaned.add(context)
        }
        return cleaned
    }

    private static func isLineLocalStructuralContext(context: TokenizerContext): Bool {
        if (contextActiveScope(context).isEmpty() && looksLikeTagEndPattern(context.endPattern)) {
            return false
        }
        return context.endPattern.isEmpty() ||
            hasLiteral(context.endPattern, "\\G") ||
            hasLiteral(context.endPattern, "\\n") ||
            hasLiteral(context.endPattern, "$") ||
            hasLiteral(context.whilePattern, "\\n")
    }

    private func currentPatterns(stack: ArrayList<TokenizerContext>): PatternSet {
        if (stack.isEmpty()) {
            return PatternSet(grammar, rootPatterns(grammar))
        }
        let context = stack[stack.size - 1]
        return PatternSet(grammarForScope(context.grammarScope), context.patterns)
    }

    private func currentRuleScanner(stack: ArrayList<TokenizerContext>): RuleScanner {
        if (stack.isEmpty()) {
            match (rootRuleScanner) {
                case Some(scanner) => return scanner
                case None =>
                    let scanner = ruleScannerFor(rootPatterns(grammar), grammar)
                    rootRuleScanner = Some(scanner)
                    return scanner
            }
        }
        let patterns = currentPatterns(stack)
        return ruleScannerFor(patterns.patterns, patterns.grammar)
    }

    private func ruleScannerFor(patterns: Array<GrammarPattern>, activeGrammar: Grammar): RuleScanner {
        let key = ruleScannerKey(patterns, activeGrammar)
        match (ruleScannerCache.get(key)) {
            case Some(scanner) => return scanner
            case None =>
                let candidates = ArrayList<RuleCandidate>()
                for (pattern in patterns) {
                    for (entry in expandPattern(pattern, activeGrammar, 0)) {
                        match (entry.matchRegex) {
                            case Some(compiled) => candidates.add(RuleCandidate(entry.pattern, entry.grammar, compiled, false, entry.needsMatchCaptures, entry.matchMaxCaptureIndex))
                            case None =>
                                match (entry.beginRegex) {
                                    case Some(compiled) => candidates.add(RuleCandidate(entry.pattern, entry.grammar, compiled, true, entry.needsBeginCaptures, entry.beginMaxCaptureIndex))
                                    case None => ()
                                }
                        }
                    }
                }
                let scanner = RuleScanner(candidates.toArray())
                ruleScannerCache[key] = scanner
                return scanner
        }
    }

    private static func ruleScannerKey(patterns: Array<GrammarPattern>, activeGrammar: Grammar): String {
        let out = StringBuilder(activeGrammar.scopeName.size + patterns.size * 24 + 24)
        out.append(activeGrammar.scopeName)
        out.append("|")
        out.append(patterns.size.toString())
        for (pattern in patterns) {
            out.append("|")
            out.append(pattern.include)
            out.append(":")
            out.append(pattern.matchPattern)
            out.append(":")
            out.append(pattern.begin)
            out.append(":")
            out.append(pattern.name)
            out.append(":")
            out.append(pattern.contentName)
            out.append(":")
            out.append(pattern.patterns.size.toString())
        }
        return out.toString()
    }

    private func rootPatterns(activeGrammar: Grammar): Array<GrammarPattern> {
        if (activeGrammar.injections.isEmpty()) {
            return activeGrammar.patterns
        }
        let out = ArrayList<GrammarPattern>()
        for (pattern in activeGrammar.patterns) {
            out.add(pattern)
        }
        for (pattern in activeGrammar.injections) {
            out.add(pattern)
        }
        return out.toArray()
    }

    private func tryCloseContext(line: String, cursor: Int64, tokens: ArrayList<Token>, stack: ArrayList<TokenizerContext>): ?Int64 {
        if (stack.isEmpty()) {
            return None
        }
        let context = stack[stack.size - 1]
        if (context.endPattern.isEmpty() && context.whilePattern.isEmpty()) {
            return None
        }
        if (!context.whilePattern.isEmpty() && cursor == 0) {
            match (RegexAdapter.findAt(context.whilePattern, line, cursor)) {
                case Some(range) =>
                    if (range.end > range.start) {
                        if (!addCapturedTokens(line, tokens, range, context.whileCaptures, activeGrammar: grammarForScope(context.grammarScope)) && !context.scope.isEmpty() && shouldTokenizeContextBoundary(context.scope)) {
                            tokens.add(scopedToken(range.start, range.end, context.scope, stack))
                        }
                        return Some(range.end)
                    }
                case None =>
                    stack.remove(at: stack.size - 1)
                    return None
            }
        }
        if (context.endPattern.isEmpty()) {
            return None
        }
        if (!contextConsumesContent(context)) {
            match (RegexAdapter.findContextEndAt(context.endPattern, line, cursor)) {
                case Some(range) =>
                    let boundaryScope = context.scope
                    if (!addCapturedTokens(line, tokens, range, context.endCaptures, activeGrammar: grammarForScope(context.grammarScope)) && !boundaryScope.isEmpty() && shouldTokenizeContextBoundary(boundaryScope)) {
                        tokens.add(scopedToken(range.start, range.end, boundaryScope, stack))
                    }
                    stack.remove(at: stack.size - 1)
                    return Some(if (range.end > range.start) { range.end } else { cursor })
                case None => return None
            }
        }

        match (RegexAdapter.findContextEnd(context.endPattern, line, cursor)) {
            case Some(range) =>
                let contentScope = contextActiveScope(context)
                if (range.start > cursor && !contentScope.isEmpty() && shouldTokenizeContextBoundary(contentScope)) {
                    tokens.add(scopedToken(cursor, range.start, contentScope, stack))
                }
                if (!addCapturedTokens(line, tokens, range, context.endCaptures, activeGrammar: grammarForScope(context.grammarScope)) && !context.scope.isEmpty() && shouldTokenizeContextBoundary(context.scope)) {
                    tokens.add(scopedToken(range.start, range.end, context.scope, stack))
                }
                stack.remove(at: stack.size - 1)
                return Some(if (range.end > range.start) { range.end } else { cursor })
            case None =>
                let contentScope = contextActiveScope(context)
                if (!contentScope.isEmpty() && shouldTokenizeContextBoundary(contentScope)) {
                    tokens.add(scopedToken(cursor, line.size, contentScope, stack))
                }
                if (contentScope.startsWith("comment.line.")) {
                    stack.remove(at: stack.size - 1)
                }
                return Some(line.size)
        }
    }

    private func findNonContentContextEnd(line: String, cursor: Int64, stack: ArrayList<TokenizerContext>): ?MatchRange {
        if (stack.isEmpty()) {
            return None
        }
        let context = stack[stack.size - 1]
        if (context.endPattern.isEmpty() || context.applyEndPatternLast || contextConsumesContent(context)) {
            return None
        }
        return RegexAdapter.findContextEnd(context.endPattern, line, cursor)
    }

    private func closeTopContext(line: String, range: MatchRange, tokens: ArrayList<Token>, stack: ArrayList<TokenizerContext>, cursor: Int64): Int64 {
        let context = stack[stack.size - 1]
        if (!addCapturedTokens(line, tokens, range, context.endCaptures, activeGrammar: grammarForScope(context.grammarScope)) && !context.scope.isEmpty() && shouldTokenizeContextBoundary(context.scope)) {
            tokens.add(scopedToken(range.start, range.end, context.scope, stack))
        }
        stack.remove(at: stack.size - 1)
        return if (range.end > cursor) { range.end } else { cursor }
    }

    private static func contextConsumesContent(context: TokenizerContext): Bool {
        let scope = contextActiveScope(context)
        return scope.startsWith("comment.") || scope.startsWith("string.")
    }

    private static func contextActiveScope(context: TokenizerContext): String {
        return if (context.contentScope.isEmpty()) { context.scope } else { context.contentScope }
    }

    private func findNextRule(line: String, cursor: Int64, scanner: RuleScanner): ?RuleMatch {
        var best: ?RuleMatch = None
        let input = if (cursor == 0) {
            line
        } else {
            try {
                recordNonZeroCursorSubstring(line.size - cursor)
                line[cursor..line.size]
            } catch (_: Exception) {
                return None
            }
        }
        var bestStart = line.size + 1
        for (candidate in scanner.candidates) {
            recordRuleCandidateScan()
            best = betterMatch(
                best,
                candidate.pattern,
                candidate.grammar,
                RegexAdapter.findCompiledBefore(candidate.regex, input, cursor, candidate.needsCaptures, candidate.maxCaptureIndex, bestStart),
                candidate.isBegin,
                cursor
            )
            match (best) {
                case Some(found) =>
                    bestStart = found.start
                    if (found.start == cursor) {
                        return best
                    }
                case None => ()
            }
        }
        return best
    }

    private func betterMatch(best: ?RuleMatch, rule: GrammarPattern, activeGrammar: Grammar, range: ?MatchRange, isBegin: Bool, searchCursor: Int64): ?RuleMatch {
        match (range) {
            case Some(r) =>
                if (!isBegin && r.end <= r.start) {
                    return best
                }
                match (best) {
                    case Some(existing) =>
                        if (r.start < existing.start) {
                            return Some(RuleMatch(rule, activeGrammar, r, isBegin, searchCursor: searchCursor))
                        }
                        return best
                    case None => return Some(RuleMatch(rule, activeGrammar, r, isBegin, searchCursor: searchCursor))
                }
            case None => return best
        }
    }

    private func expandPattern(pattern: GrammarPattern, activeGrammar: Grammar, depth: Int64): Array<ExpandedPattern> {
        if (depth > 32) {
            return []
        }
        if (shouldCacheExpandedPattern(pattern)) {
            let key = expandedPatternKey(pattern, activeGrammar, depth)
            match (expandedPatternCache.get(key)) {
                case Some(cached) => return cached
                case None =>
                    let expanded = expandPatternUncached(pattern, activeGrammar, depth)
                    expandedPatternCache[key] = expanded
                    return expanded
            }
        }
        return expandPatternUncached(pattern, activeGrammar, depth)
    }

    private func expandPatternUncached(pattern: GrammarPattern, activeGrammar: Grammar, depth: Int64): Array<ExpandedPattern> {
        if (!pattern.include.isEmpty()) {
            if (pattern.include.startsWith("#")) {
                let key = pattern.include[1..pattern.include.size]
                match (activeGrammar.repository.get(key)) {
                    case Some(repoPattern) =>
                        return expandRepositoryPattern(repoPattern, activeGrammar, depth + 1)
                    case None => return []
                }
            }
            if (pattern.include == "$self" || pattern.include == "$base") {
                return expandPatternList(rootPatterns(activeGrammar), activeGrammar, depth + 1)
            }
            match (resolveExternalInclude(pattern.include)) {
                case Some(external) =>
                    match (externalRepositoryKey(pattern.include)) {
                        case Some(key) =>
                            match (external.repository.get(key)) {
                                case Some(repoPattern) => return expandRepositoryPattern(repoPattern, external, depth + 1)
                                case None => return []
                            }
                        case None => return expandPatternList(external.patterns, external, depth + 1)
                    }
                case None => ()
            }
            return []
        }
        return [ExpandedPattern(pattern, activeGrammar)]
    }

    private static func shouldCacheExpandedPattern(pattern: GrammarPattern): Bool {
        return !pattern.include.isEmpty() ||
            (pattern.matchPattern.isEmpty() && pattern.begin.isEmpty() && !pattern.patterns.isEmpty())
    }

    private static func expandedPatternKey(pattern: GrammarPattern, activeGrammar: Grammar, depth: Int64): String {
        let out = StringBuilder(
            activeGrammar.scopeName.size + pattern.include.size + pattern.matchPattern.size +
            pattern.begin.size + pattern.end.size + pattern.name.size + pattern.contentName.size + 48
        )
        out.append(activeGrammar.scopeName)
        out.append("|")
        out.append(depth.toString())
        out.append("|")
        out.append(pattern.include)
        out.append("|")
        out.append(pattern.matchPattern)
        out.append("|")
        out.append(pattern.begin)
        out.append("|")
        out.append(pattern.end)
        out.append("|")
        out.append(pattern.name)
        out.append("|")
        out.append(pattern.contentName)
        out.append("|")
        out.append(pattern.patterns.size.toString())
        return out.toString()
    }

    private func expandRepositoryPattern(pattern: GrammarPattern, activeGrammar: Grammar, depth: Int64): Array<ExpandedPattern> {
        if (!pattern.matchPattern.isEmpty() || !pattern.begin.isEmpty() || !pattern.include.isEmpty()) {
            return expandPattern(pattern, activeGrammar, depth + 1)
        }
        if (!pattern.patterns.isEmpty()) {
            return expandPatternList(pattern.patterns, activeGrammar, depth + 1)
        }
        return [ExpandedPattern(pattern, activeGrammar)]
    }

    private func expandPatternList(patterns: Array<GrammarPattern>, activeGrammar: Grammar, depth: Int64): Array<ExpandedPattern> {
        let out = ArrayList<ExpandedPattern>()
        for (pattern in patterns) {
            for (expanded in expandPattern(pattern, activeGrammar, depth + 1)) {
                out.add(expanded)
            }
        }
        return out.toArray()
    }

    private func applyRule(line: String, found: RuleMatch, tokens: ArrayList<Token>, stack: ArrayList<TokenizerContext>): Int64 {
        let activeMatch = ruleMatchWithCapturesIfNeeded(line, found)
        let rule = activeMatch.rule
        if (activeMatch.isBegin) {
            if (rule.end.isEmpty() && (rule.whilePattern.isEmpty() || !isSafeWhilePattern(rule.whilePattern))) {
                if (!addCapturedTokens(line, tokens, activeMatch.range, rule.beginCaptures, activeGrammar: activeMatch.grammar) && !rule.name.isEmpty() && shouldTokenizeContextBoundary(rule.name)) {
                    tokens.add(scopedToken(activeMatch.start, activeMatch.end, rule.name, stack, activeGrammar: activeMatch.grammar))
                }
                return if (activeMatch.end > activeMatch.start) { activeMatch.end } else { activeMatch.start + 1 }
            }

            if (shouldSplitBeginEndContent(rule)) {
                if (!addCapturedTokens(line, tokens, activeMatch.range, rule.beginCaptures, activeGrammar: activeMatch.grammar) && !rule.name.isEmpty() && shouldTokenizeContextBoundary(rule.name)) {
                    tokens.add(scopedToken(activeMatch.start, activeMatch.end, rule.name, stack, activeGrammar: activeMatch.grammar))
                }
                match (RegexAdapter.findContextEnd(rule.end, line, activeMatch.end)) {
                    case Some(endRange) =>
                        if (endRange.start > activeMatch.end && !rule.name.isEmpty()) {
                            tokens.add(scopedToken(activeMatch.end, endRange.start, rule.name, stack, activeGrammar: activeMatch.grammar))
                        }
                        if (!addCapturedTokens(line, tokens, endRange, rule.endCaptures, activeGrammar: activeMatch.grammar) && !rule.name.isEmpty() && shouldTokenizeContextBoundary(rule.name)) {
                            tokens.add(scopedToken(endRange.start, endRange.end, rule.name, stack, activeGrammar: activeMatch.grammar))
                        }
                        return endRange.end
                    case None =>
                        if (activeMatch.end < line.size && !rule.name.isEmpty()) {
                            tokens.add(scopedToken(activeMatch.end, line.size, rule.name, stack, activeGrammar: activeMatch.grammar))
                        }
                        stack.add(newContext(rule, activeMatch.grammar, line, activeMatch.range))
                        return line.size
                }
            }

            if (shouldConsumeWholeBeginEnd(rule)) {
                match (RegexAdapter.findContextEnd(rule.end, line, activeMatch.end)) {
                    case Some(endRange) =>
                        tokens.add(scopedToken(activeMatch.start, endRange.end, rule.name, stack, activeGrammar: activeMatch.grammar))
                        return endRange.end
                    case None =>
                        tokens.add(scopedToken(activeMatch.start, line.size, rule.name, stack, activeGrammar: activeMatch.grammar))
                        stack.add(newContext(rule, activeMatch.grammar, line, activeMatch.range))
                        return line.size
                }
            }

            if (!addCapturedTokens(line, tokens, activeMatch.range, rule.beginCaptures, activeGrammar: activeMatch.grammar) && !rule.name.isEmpty() && shouldTokenizeContextBoundary(rule.name)) {
                tokens.add(scopedToken(activeMatch.start, activeMatch.end, rule.name, stack, activeGrammar: activeMatch.grammar))
            }
            stack.add(newContext(rule, activeMatch.grammar, line, activeMatch.range))
            return activeMatch.end
        }

        if (!addCapturedTokensForMatch(line, tokens, activeMatch.range, rule.captures, rule.name, activeMatch.grammar) && !rule.name.isEmpty()) {
            tokens.add(scopedToken(activeMatch.start, activeMatch.end, rule.name, stack, activeGrammar: activeMatch.grammar))
        }
        return activeMatch.end
    }

    private func ruleMatchWithCapturesIfNeeded(line: String, found: RuleMatch): RuleMatch {
        if (!ruleNeedsCaptures(found.rule, found.isBegin)) {
            return found
        }
        if (!found.range.captures.isEmpty()) {
            return found
        }
        let pattern = if (found.isBegin) { found.rule.begin } else { found.rule.matchPattern }
        match (RegexAdapter.findWithCaptures(pattern, line, found.searchCursor, maxCaptureIndex: ruleMaxCaptureIndex(found.rule, found.isBegin))) {
            case Some(range) =>
                if (range.start == found.start && range.end == found.end) {
                    return RuleMatch(found.rule, found.grammar, range, found.isBegin)
                }
            case None => ()
        }
        return found
    }

    static func ruleNeedsCaptures(rule: GrammarPattern, isBegin: Bool): Bool {
        if (isBegin) {
            return !rule.beginCaptures.isEmpty() ||
                patternUsesBackReference(rule.end) ||
                patternUsesBackReference(rule.whilePattern)
        }
        return !rule.captures.isEmpty()
    }

    static func ruleMaxCaptureIndex(rule: GrammarPattern, isBegin: Bool): Int64 {
        if (isBegin) {
            var maxIndex = maxCaptureIndex(rule.beginCaptures)
            let endMax = maxBackReferenceIndex(rule.end)
            if (endMax > maxIndex) {
                maxIndex = endMax
            }
            let whileMax = maxBackReferenceIndex(rule.whilePattern)
            if (whileMax > maxIndex) {
                maxIndex = whileMax
            }
            return maxIndex
        }
        return maxCaptureIndex(rule.captures)
    }

    private static func maxCaptureIndex(captures: HashMap<Int64, GrammarCapture>): Int64 {
        var maxIndex: Int64 = 0
        for ((index, _) in captures) {
            if (index > maxIndex) {
                maxIndex = index
            }
        }
        return maxIndex
    }

    private static func maxBackReferenceIndex(pattern: String): Int64 {
        var maxIndex: Int64 = 0
        var escaped = false
        for (b in pattern.toArray()) {
            if (escaped) {
                if (b >= b'1' && b <= b'9') {
                    let index = Int64(b - b'0')
                    if (index > maxIndex) {
                        maxIndex = index
                    }
                }
                escaped = false
                continue
            }
            if (b == b'\\') {
                escaped = true
            }
        }
        return maxIndex
    }

    private static func patternUsesBackReference(pattern: String): Bool {
        var escaped = false
        for (b in pattern.toArray()) {
            if (escaped) {
                if (b >= b'1' && b <= b'9') {
                    return true
                }
                escaped = false
                continue
            }
            if (b == b'\\') {
                escaped = true
            }
        }
        return false
    }

    private func newContext(rule: GrammarPattern, activeGrammar: Grammar, line: String, range: MatchRange): TokenizerContext {
        let childGrammar = effectiveChildGrammar(rule, activeGrammar)
        let whilePattern = if (isSafeWhilePattern(rule.whilePattern)) { resolveBackReferences(rule.whilePattern, line, range) } else { "" }
        return TokenizerContext(
            rule.name,
            rule.contentName,
            resolveBackReferences(rule.end, line, range),
            whilePattern,
            rule.applyEndPatternLast,
            effectiveChildPatterns(rule, childGrammar),
            rule.endCaptures,
            whileCaptures: rule.whileCaptures,
            grammarScope: childGrammar.scopeName,
            canCarryAcrossLines: canCarryAcrossLines(rule)
        )
    }

    private static func canCarryAcrossLines(rule: GrammarPattern): Bool {
        if (!rule.whilePattern.isEmpty()) {
            return true
        }
        if (hasLiteral(rule.end, "\\n") || rule.name.startsWith("comment.line.")) {
            return false
        }
        if (rule.end == "(?!\\G)") {
            return false
        }
        if (!rule.contentName.isEmpty()) {
            return true
        }
        if (looksLikeTagEndPattern(rule.end) || hasLiteral(rule.end, "^")) {
            return true
        }
        if (rule.name.startsWith("string.") || rule.name.startsWith("comment.block.")) {
            return true
        }
        if (rule.name.isEmpty() && hasLiteral(rule.end, "$")) {
            return false
        }
        return !rule.name.isEmpty()
    }

    private static func looksLikeTagEndPattern(pattern: String): Bool {
        return hasLiteral(pattern, "</") || hasLiteral(pattern, "(<")
    }

    private static func hasLiteral(value: String, literal: String): Bool {
        if (literal.isEmpty()) {
            return true
        }
        if (literal.size > value.size) {
            return false
        }
        let source = value.toArray()
        let target = literal.toArray()
        var i: Int64 = 0
        while (i <= source.size - target.size) {
            var j: Int64 = 0
            var matched = true
            while (j < target.size) {
                if (source[i + j] != target[j]) {
                    matched = false
                    break
                }
                j += 1
            }
            if (matched) {
                return true
            }
            i += 1
        }
        return false
    }

    private static func isSafeWhilePattern(pattern: String): Bool {
        if (pattern.isEmpty()) {
            return false
        }
        return !(pattern.contains("(?") || pattern.contains("\\g<") || pattern.contains("\\k<") || pattern.contains("*+") || pattern.contains("++"))
    }

    private func effectiveChildGrammar(rule: GrammarPattern, activeGrammar: Grammar): Grammar {
        if (!rule.contentName.isEmpty()) {
            match (resolveExternalInclude(rule.contentName)) {
                case Some(external) => return external
                case None => ()
            }
        }
        return activeGrammar
    }

    private func effectiveChildPatterns(rule: GrammarPattern, activeGrammar: Grammar): Array<GrammarPattern> {
        if (!rule.patterns.isEmpty()) {
            return rule.patterns
        }
        if (!rule.contentName.isEmpty()) {
            match (resolveExternalInclude(rule.contentName)) {
                case Some(external) => return external.patterns
                case None => ()
            }
        }
        return []
    }

    private func resolveExternalInclude(include: String): ?Grammar {
        let normalized = stripIncludeSelector(include)
        if (normalized.isEmpty() || normalized.startsWith("#") || normalized == "$self" || normalized == "$base") {
            return None
        }
        let scope = if (normalized.contains("#")) {
            let parts = normalized.split("#")
            parts[0]
        } else {
            normalized
        }
        return externalGrammars.get(scope)
    }

    private static func stripIncludeSelector(include: String): String {
        var value = include.trimAscii()
        while (value.size > 2 && ((value[0] == b'L' || value[0] == b'R') && value[1] == b':')) {
            value = value[2..value.size].trimAscii()
        }
        return value
    }

    private static func externalRepositoryKey(include: String): ?String {
        let normalized = stripIncludeSelector(include)
        if (!normalized.contains("#")) {
            return None
        }
        let parts = normalized.split("#")
        if (parts.size < 2 || parts[1].isEmpty()) {
            return None
        }
        return Some(parts[1])
    }

    private func grammarForScope(scopeName: String): Grammar {
        if (scopeName.isEmpty() || scopeName == grammar.scopeName) {
            return grammar
        }
        match (externalGrammars.get(scopeName)) {
            case Some(external) => return external
            case None => return grammar
        }
    }

    private func addCapturedTokensForMatch(line: String, tokens: ArrayList<Token>, range: MatchRange, captures: HashMap<Int64, GrammarCapture>, baseScope: String, activeGrammar: Grammar): Bool {
        if (shouldFillCaptureGapsForMatch(baseScope)) {
            return addCapturedTokensWithBase(line, tokens, range, captures, baseScope, activeGrammar)
        }
        return addCapturedTokens(line, tokens, range, captures, activeGrammar: activeGrammar)
    }

    private static func shouldFillCaptureGapsForMatch(baseScope: String): Bool {
        return baseScope.startsWith("string.") && (baseScope.endsWith(".sql") || baseScope.endsWith(".toml"))
    }

    private func addCapturedTokensWithBase(line: String, tokens: ArrayList<Token>, range: MatchRange, captures: HashMap<Int64, GrammarCapture>, baseScope: String, activeGrammar: Grammar): Bool {
        if (captures.isEmpty()) {
            return false
        }
        let captured = ArrayList<Token>()
        if (!addCapturedTokens(line, captured, range, captures, activeGrammar: activeGrammar)) {
            return false
        }
        let shouldFillBase = !baseScope.isEmpty() && shouldTokenizeContextBoundary(baseScope)
        var cursor = range.start
        for (token in captured) {
            if (shouldFillBase && cursor < token.startByte) {
                tokens.add(scopedTokenWithoutContext(cursor, token.startByte, baseScope, activeGrammar))
            }
            tokens.add(token)
            cursor = token.endByte
        }
        if (shouldFillBase && cursor < range.end) {
            tokens.add(scopedTokenWithoutContext(cursor, range.end, baseScope, activeGrammar))
        }
        return true
    }

    private func addCapturedTokens(line: String, tokens: ArrayList<Token>, range: MatchRange, captures: HashMap<Int64, GrammarCapture>, activeGrammar!: Grammar = grammar, depth!: Int64 = 0): Bool {
        if (captures.isEmpty()) {
            return false
        }
        if (range.captures.isEmpty()) {
            match (captures.get(0)) {
                case Some(capture) =>
                    return addSingleCaptureToken(line, tokens, range.start, range.end, capture, activeGrammar, depth)
                case None => ()
            }
        }
        var added = false
        for (captureRange in range.captures) {
            match (captures.get(captureRange.index)) {
                case Some(capture) =>
                    if (captureRange.end <= captureRange.start) {
                        continue
                    }
                    if (addSingleCaptureToken(line, tokens, captureRange.start, captureRange.end, capture, activeGrammar, depth)) {
                        added = true
                    }
                case None => ()
            }
        }
        return added
    }

    private func addSingleCaptureToken(line: String, tokens: ArrayList<Token>, start: Int64, end: Int64, capture: GrammarCapture, activeGrammar: Grammar, depth: Int64): Bool {
        if (end <= start) {
            return false
        }
        if (!capture.patterns.isEmpty()) {
            let nested = ArrayList<Token>()
            if (tokenizeCapturePatterns(line, nested, start, end, capture.patterns, activeGrammar, depth + 1) &&
                (capture.name.isEmpty() || coversRange(nested, start, end))) {
                for (token in nested) {
                    tokens.add(token)
                }
                return true
            }
        }
        if (!capture.name.isEmpty()) {
            tokens.add(scopedTokenWithoutContext(start, end, capture.name, activeGrammar))
            return true
        }
        return false
    }

    private static func coversRange(tokens: ArrayList<Token>, start: Int64, end: Int64): Bool {
        if (tokens.isEmpty()) {
            return false
        }
        var cursor = start
        for (token in tokens) {
            if (token.startByte != cursor || token.endByte <= token.startByte) {
                return false
            }
            cursor = token.endByte
        }
        return cursor == end
    }

    private func tokenizeCapturePatterns(line: String, tokens: ArrayList<Token>, start: Int64, end: Int64, patterns: Array<GrammarPattern>, activeGrammar: Grammar, depth: Int64): Bool {
        if (depth > 16) {
            return false
        }
        let segment = line[start..end]
        recordCaptureSegmentSubstring(end - start)
        let before = tokens.size
        let stack = ArrayList<TokenizerContext>()
        var cursor = start
        while (cursor < end) {
            match (findNextRuleInRange(segment, start, cursor, end, patterns, activeGrammar)) {
                case Some(found) =>
                    let next = applyRule(line, found, tokens, stack)
                    cursor = if (next > cursor) { next } else { cursor + 1 }
                case None =>
                    break
            }
        }
        return tokens.size > before
    }

    private func findNextRuleInRange(segment: String, offset: Int64, cursor: Int64, end: Int64, patterns: Array<GrammarPattern>, activeGrammar: Grammar): ?RuleMatch {
        var best: ?RuleMatch = None
        let localCursor = cursor - offset
        var input = ""
        try {
            input = segment[localCursor..segment.size]
        } catch (_: Exception) {
            return None
        }
        let scanner = ruleScannerFor(patterns, activeGrammar)
        var bestStart = end + 1
        for (candidate in scanner.candidates) {
            best = betterMatch(
                best,
                candidate.pattern,
                candidate.grammar,
                offsetRange(RegexAdapter.findCompiledBefore(candidate.regex, input, localCursor, candidate.needsCaptures, candidate.maxCaptureIndex, bestStart - offset), offset),
                candidate.isBegin,
                cursor
            )
            match (best) {
                case Some(found) => bestStart = found.start
                case None => ()
            }
        }
        match (best) {
            case Some(found) =>
                return if (found.start < end && found.end <= end) { Some(found) } else { None }
            case None => return None
        }
    }

    private static func offsetRange(range: ?MatchRange, offset: Int64): ?MatchRange {
        match (range) {
            case Some(r) =>
                let captures = ArrayList<CaptureRange>()
                for (capture in r.captures) {
                    captures.add(CaptureRange(capture.index, capture.start + offset, capture.end + offset))
                }
                recordCaptureRangeOffsetCopies(captures.size)
                return Some(MatchRange(r.start + offset, r.end + offset, captures: captures.toArray()))
            case None => return None
        }
    }

    private static func shouldConsumeWholeBeginEnd(rule: GrammarPattern): Bool {
        return rule.name.startsWith("string.") || rule.name.startsWith("comment.")
    }

    private static func shouldSplitBeginEndContent(rule: GrammarPattern): Bool {
        return rule.name.startsWith("string.") &&
            (rule.name.endsWith(".sql") || rule.name.endsWith(".toml")) &&
            (!rule.beginCaptures.isEmpty() || !rule.endCaptures.isEmpty())
    }

    private static func shouldTokenizeContextBoundary(scope: String): Bool {
        return !scope.startsWith("meta.")
    }

    private static func resolveBackReferences(pattern: String, line: String, beginRange: MatchRange): String {
        if (pattern.isEmpty()) {
            return pattern
        }
        let out = StringBuilder(pattern.size)
        var i: Int64 = 0
        while (i < pattern.size) {
            if (pattern[i] == b'\\' && i + 1 < pattern.size && pattern[i + 1] >= b'0' && pattern[i + 1] <= b'9') {
                let index = Int64(pattern[i + 1] - b'0')
                match (captureText(beginRange, index, line)) {
                    case Some(text) => out.append(RegexAdapter.escapeLiteral(text))
                    case None =>
                        out.append("\\")
                        out.append(String.fromUtf8([pattern[i + 1]]))
                }
                i += 2
                continue
            }
            i += appendPatternRune(out, pattern, i)
        }
        return out.toString()
    }

    private static func captureText(range: MatchRange, index: Int64, line: String): ?String {
        for (capture in range.captures) {
            if (capture.index == index && capture.end <= line.size) {
                return Some(line[capture.start..capture.end])
            }
        }
        return None
    }

    private func scopedToken(start: Int64, end: Int64, rawScope: String, stack: ArrayList<TokenizerContext>, activeGrammar!: Grammar = grammar): Token {
        return Token(start, end, scopeClassFor(rawScope), scopes: rawScopeStack(rawScope, stack, activeGrammar))
    }

    private func scopedTokenWithoutContext(start: Int64, end: Int64, rawScope: String, activeGrammar: Grammar): Token {
        return Token(start, end, scopeClassFor(rawScope), scopes: rawScopeStackWithoutContext(rawScope, activeGrammar))
    }

    private func scopeClassFor(rawScope: String): String {
        match (scopeClassCache.get(rawScope)) {
            case Some(value) => return value
            case None =>
                let value = ScopeClass.fromScope(rawScope)
                scopeClassCache[rawScope] = value
                return value
        }
    }

    private func rawScopeStack(rawScope: String, stack: ArrayList<TokenizerContext>, activeGrammar: Grammar): Array<String> {
        let key = rawScopeStackKey(rawScope, stack, activeGrammar)
        match (scopeStackCache.get(key)) {
            case Some(cached) =>
                recordScopeStackCacheHit()
                return cached
            case None => recordScopeStackCacheMiss()
        }
        let scopes = ArrayList<String>()
        if (!activeGrammar.scopeName.isEmpty()) {
            scopes.add(activeGrammar.scopeName)
        }
        for (context in stack) {
            if (!context.scope.isEmpty()) {
                scopes.add(context.scope)
            }
            if (!context.contentScope.isEmpty()) {
                scopes.add(context.contentScope)
            }
        }
        if (!rawScope.isEmpty()) {
            scopes.add(rawScope)
        }
        let result = dedupeAdjacentScopes(scopes).toArray()
        scopeStackCache[key] = result
        return result
    }

    private func rawScopeStackWithoutContext(rawScope: String, activeGrammar: Grammar): Array<String> {
        let key = rawScopeStackKey(rawScope, activeGrammar)
        match (scopeStackCache.get(key)) {
            case Some(cached) =>
                recordScopeStackCacheHit()
                return cached
            case None => recordScopeStackCacheMiss()
        }
        let scopes = ArrayList<String>()
        if (!activeGrammar.scopeName.isEmpty()) {
            scopes.add(activeGrammar.scopeName)
        }
        if (!rawScope.isEmpty()) {
            scopes.add(rawScope)
        }
        let result = dedupeAdjacentScopes(scopes).toArray()
        scopeStackCache[key] = result
        return result
    }

    private static func rawScopeStackKey(rawScope: String, activeGrammar: Grammar): String {
        let out = StringBuilder(activeGrammar.scopeName.size + rawScope.size + 8)
        var last = ""
        appendScopeKeyPart(out, activeGrammar.scopeName, last)
        last = activeGrammar.scopeName
        if (!rawScope.isEmpty() && rawScope != last) {
            appendScopeKeySeparator(out)
            out.append(rawScope)
        }
        return out.toString()
    }

    private static func rawScopeStackKey(rawScope: String, stack: ArrayList<TokenizerContext>, activeGrammar: Grammar): String {
        let out = StringBuilder(activeGrammar.scopeName.size + rawScope.size + stack.size * 48 + 24)
        var last = ""
        appendScopeKeyPart(out, activeGrammar.scopeName, last)
        last = activeGrammar.scopeName
        for (context in stack) {
            if (!context.scope.isEmpty() && context.scope != last) {
                appendScopeKeySeparator(out)
                out.append(context.scope)
                last = context.scope
            }
            if (!context.contentScope.isEmpty() && context.contentScope != last) {
                appendScopeKeySeparator(out)
                out.append(context.contentScope)
                last = context.contentScope
            }
        }
        if (!rawScope.isEmpty() && rawScope != last) {
            appendScopeKeySeparator(out)
            out.append(rawScope)
        }
        return out.toString()
    }

    private static func appendScopeKeyPart(out: StringBuilder, scope: String, last: String): Unit {
        if (!scope.isEmpty() && scope != last) {
            appendScopeKeySeparator(out)
            out.append(scope)
        }
    }

    private static func appendScopeKeySeparator(out: StringBuilder): Unit {
        if (out.size > 0) {
            out.append("\u{1F}")
        }
    }

    private static func dedupeAdjacentScopes(scopes: ArrayList<String>): ArrayList<String> {
        let out = ArrayList<String>()
        var last = ""
        for (scope in scopes) {
            if (!scope.isEmpty() && scope != last) {
                out.add(scope)
                last = scope
            }
        }
        return out
    }

    static func recordNonZeroCursorSubstring(byteSize: Int64): Unit {
        if (diagnostics.enabled) {
            diagnostics.nonZeroCursorSubstringCount += 1
            diagnostics.nonZeroCursorSubstringBytes += byteSize
        }
    }

    static func recordCaptureSegmentSubstring(byteSize: Int64): Unit {
        if (diagnostics.enabled) {
            diagnostics.captureSegmentSubstringCount += 1
            diagnostics.captureSegmentSubstringBytes += byteSize
        }
    }

    static func recordCaptureRangeOffsetCopies(count: Int64): Unit {
        if (diagnostics.enabled) {
            diagnostics.captureRangeOffsetCopies += count
        }
    }

    static func recordRuleCandidateScan(): Unit {
        if (diagnostics.enabled) {
            diagnostics.ruleCandidateScans += 1
        }
    }

    static func recordRegexFindCall(): Unit {
        if (diagnostics.enabled) {
            diagnostics.regexFindCalls += 1
        }
    }

    static func recordCaptureGroupPositionProbe(): Unit {
        if (diagnostics.enabled) {
            diagnostics.captureGroupPositionProbes += 1
        }
    }

    static func recordScopeStackCacheHit(): Unit {
        if (diagnostics.enabled) {
            diagnostics.scopeStackCacheHits += 1
        }
    }

    static func recordScopeStackCacheMiss(): Unit {
        if (diagnostics.enabled) {
            diagnostics.scopeStackCacheMisses += 1
        }
    }
}

class RuleMatch {
    let rule: GrammarPattern
    let grammar: Grammar
    let start: Int64
    let end: Int64
    let isBegin: Bool
    let range: MatchRange
    let searchCursor: Int64

    init(rule: GrammarPattern, start: Int64, end: Int64, isBegin: Bool) {
        this.rule = rule
        this.grammar = Grammar("", "", [], HashMap<String, GrammarPattern>())
        this.start = start
        this.end = end
        this.isBegin = isBegin
        this.range = MatchRange(start, end)
        this.searchCursor = start
    }

    init(rule: GrammarPattern, grammar: Grammar, range: MatchRange, isBegin: Bool, searchCursor!: Int64 = range.start) {
        this.rule = rule
        this.grammar = grammar
        this.start = range.start
        this.end = range.end
        this.isBegin = isBegin
        this.range = range
        this.searchCursor = searchCursor
    }
}

class PatternSet {
    let grammar: Grammar
    let patterns: Array<GrammarPattern>

    init(grammar: Grammar, patterns: Array<GrammarPattern>) {
        this.grammar = grammar
        this.patterns = patterns
    }
}

class RuleScanner {
    let candidates: Array<RuleCandidate>

    init(candidates: Array<RuleCandidate>) {
        this.candidates = candidates
    }
}

class RuleCandidate {
    let pattern: GrammarPattern
    let grammar: Grammar
    let regex: CompiledRegexPattern
    let isBegin: Bool
    let needsCaptures: Bool
    let maxCaptureIndex: Int64

    init(pattern: GrammarPattern, grammar: Grammar, regex: CompiledRegexPattern, isBegin: Bool, needsCaptures: Bool, maxCaptureIndex: Int64) {
        this.pattern = pattern
        this.grammar = grammar
        this.regex = regex
        this.isBegin = isBegin
        this.needsCaptures = needsCaptures
        this.maxCaptureIndex = maxCaptureIndex
    }

}

public class TokenizerDiagnosticSnapshot {
    public let nonZeroCursorSubstringCount: Int64
    public let nonZeroCursorSubstringBytes: Int64
    public let captureSegmentSubstringCount: Int64
    public let captureSegmentSubstringBytes: Int64
    public let captureRangeOffsetCopies: Int64
    public let ruleCandidateScans: Int64
    public let regexFindCalls: Int64
    public let captureGroupPositionProbes: Int64
    public let scopeStackCacheHits: Int64
    public let scopeStackCacheMisses: Int64

    public init(
        nonZeroCursorSubstringCount: Int64,
        nonZeroCursorSubstringBytes: Int64,
        captureSegmentSubstringCount: Int64,
        captureSegmentSubstringBytes: Int64,
        captureRangeOffsetCopies: Int64,
        ruleCandidateScans: Int64,
        regexFindCalls: Int64,
        captureGroupPositionProbes: Int64,
        scopeStackCacheHits: Int64,
        scopeStackCacheMisses: Int64
    ) {
        this.nonZeroCursorSubstringCount = nonZeroCursorSubstringCount
        this.nonZeroCursorSubstringBytes = nonZeroCursorSubstringBytes
        this.captureSegmentSubstringCount = captureSegmentSubstringCount
        this.captureSegmentSubstringBytes = captureSegmentSubstringBytes
        this.captureRangeOffsetCopies = captureRangeOffsetCopies
        this.ruleCandidateScans = ruleCandidateScans
        this.regexFindCalls = regexFindCalls
        this.captureGroupPositionProbes = captureGroupPositionProbes
        this.scopeStackCacheHits = scopeStackCacheHits
        this.scopeStackCacheMisses = scopeStackCacheMisses
    }
}

class TokenizerDiagnostics {
    public var enabled: Bool = false
    var nonZeroCursorSubstringCount: Int64 = 0
    var nonZeroCursorSubstringBytes: Int64 = 0
    var captureSegmentSubstringCount: Int64 = 0
    var captureSegmentSubstringBytes: Int64 = 0
    var captureRangeOffsetCopies: Int64 = 0
    var ruleCandidateScans: Int64 = 0
    var regexFindCalls: Int64 = 0
    var captureGroupPositionProbes: Int64 = 0
    var scopeStackCacheHits: Int64 = 0
    var scopeStackCacheMisses: Int64 = 0

    func reset(): Unit {
        nonZeroCursorSubstringCount = 0
        nonZeroCursorSubstringBytes = 0
        captureSegmentSubstringCount = 0
        captureSegmentSubstringBytes = 0
        captureRangeOffsetCopies = 0
        ruleCandidateScans = 0
        regexFindCalls = 0
        captureGroupPositionProbes = 0
        scopeStackCacheHits = 0
        scopeStackCacheMisses = 0
    }

    func snapshot(): TokenizerDiagnosticSnapshot {
        return TokenizerDiagnosticSnapshot(
            nonZeroCursorSubstringCount,
            nonZeroCursorSubstringBytes,
            captureSegmentSubstringCount,
            captureSegmentSubstringBytes,
            captureRangeOffsetCopies,
            ruleCandidateScans,
            regexFindCalls,
            captureGroupPositionProbes,
            scopeStackCacheHits,
            scopeStackCacheMisses
        )
    }
}

class ExpandedPattern {
    let pattern: GrammarPattern
    let grammar: Grammar
    let matchRegex: ?CompiledRegexPattern
    let beginRegex: ?CompiledRegexPattern
    let needsMatchCaptures: Bool
    let needsBeginCaptures: Bool
    let matchMaxCaptureIndex: Int64
    let beginMaxCaptureIndex: Int64

    init(pattern: GrammarPattern, grammar: Grammar) {
        this.pattern = pattern
        this.grammar = grammar
        this.matchRegex = if (pattern.matchPattern.isEmpty()) { None<CompiledRegexPattern> } else { RegexAdapter.compile(pattern.matchPattern, false) }
        this.beginRegex = if (!pattern.matchPattern.isEmpty() || pattern.begin.isEmpty()) { None<CompiledRegexPattern> } else { RegexAdapter.compile(pattern.begin, false) }
        this.needsMatchCaptures = GrammarTokenizer.ruleNeedsCaptures(pattern, false)
        this.needsBeginCaptures = GrammarTokenizer.ruleNeedsCaptures(pattern, true)
        this.matchMaxCaptureIndex = GrammarTokenizer.ruleMaxCaptureIndex(pattern, false)
        this.beginMaxCaptureIndex = GrammarTokenizer.ruleMaxCaptureIndex(pattern, true)
    }
}

class MatchRange {
    let start: Int64
    let end: Int64
    let captures: Array<CaptureRange>

    init(start: Int64, end: Int64, captures!: Array<CaptureRange> = []) {
        this.start = start
        this.end = end
        this.captures = captures
    }
}

class CaptureRange {
    let index: Int64
    let start: Int64
    let end: Int64

    init(index: Int64, start: Int64, end: Int64) {
        this.index = index
        this.start = start
        this.end = end
    }
}

class CompiledRegexPattern {
    let original: String
    let sanitized: String
    let tooComplex: Bool
    let originalContainsCursorAnchor: Bool
    let lineStartAnchored: Bool
    let regex: ?Regex

    init(
        original: String,
        sanitized: String,
        tooComplex: Bool,
        originalContainsCursorAnchor: Bool,
        lineStartAnchored: Bool,
        regex: ?Regex
    ) {
        this.original = original
        this.sanitized = sanitized
        this.tooComplex = tooComplex
        this.originalContainsCursorAnchor = originalContainsCursorAnchor
        this.lineStartAnchored = lineStartAnchored
        this.regex = regex
    }
}

class RegexAdapter {
    private static let regexCache = HashMap<String, Regex>()
    private static let compiledPatternCache = HashMap<String, CompiledRegexPattern>()
    private static let invalidRegexCache = HashMap<String, Bool>()
    private static let regexCacheMutex = Mutex()
    private static let maxCachedRegexCount: Int64 = 4096

    static func find(pattern: String, line: String, cursor: Int64): ?MatchRange {
        try {
            return findSanitized(pattern, inputFromCursor(line, cursor), cursor, false, false)
        } catch (_: Exception) {
            return None
        }
    }

    static func findInInput(pattern: String, input: String, cursor: Int64): ?MatchRange {
        return findSanitized(pattern, input, cursor, false, false)
    }

    static func findCompiled(compiled: CompiledRegexPattern, input: String, cursor: Int64, captureGroups: Bool): ?MatchRange {
        return findCompiledSanitized(compiled, input, cursor, captureGroups, 0, cursor + input.size + 1)
    }

    static func findCompiledBefore(compiled: CompiledRegexPattern, input: String, cursor: Int64, captureGroups: Bool, maxCaptureIndex: Int64, bestStart: Int64): ?MatchRange {
        return findCompiledSanitized(compiled, input, cursor, captureGroups, maxCaptureIndex, bestStart)
    }

    static func findWithCaptures(pattern: String, line: String, cursor: Int64, maxCaptureIndex!: Int64 = 0): ?MatchRange {
        try {
            return findSanitized(pattern, inputFromCursor(line, cursor), cursor, false, true, maxCaptureIndex: maxCaptureIndex)
        } catch (_: Exception) {
            return None
        }
    }

    static func findContextEnd(pattern: String, line: String, cursor: Int64): ?MatchRange {
        try {
            return findSanitized(pattern, inputFromCursor(line, cursor), cursor, true, true)
        } catch (_: Exception) {
            return None
        }
    }

    private static func inputFromCursor(line: String, cursor: Int64): String {
        if (cursor == 0) {
            return line
        }
        GrammarTokenizer.recordNonZeroCursorSubstring(line.size - cursor)
        return line[cursor..line.size]
    }

    private static func findSanitized(pattern: String, input: String, cursor: Int64, disableCursorLineStart: Bool, captureGroups: Bool, maxCaptureIndex!: Int64 = 0): ?MatchRange {
        try {
            let disableAnchors = disableCursorLineStart && cursor > 0
            let compiled = match (compile(pattern, disableAnchors)) {
                case Some(value) => value
                case None => return None
            }
            return findCompiledSanitized(compiled, input, cursor, captureGroups, maxCaptureIndex, cursor + input.size + 1)
        } catch (_: Exception) {
            return None
        }
    }

    static func compile(pattern: String, disableLineAnchors: Bool): ?CompiledRegexPattern {
        let key = if (disableLineAnchors) { pattern + "\u{0}disable-line-anchors" } else { pattern }
        synchronized(regexCacheMutex) {
            match (compiledPatternCache.get(key)) {
                case Some(compiled) => return Some(compiled)
                case None => ()
            }
            let tooComplex = isTooComplexForCurrentAdapter(pattern)
            if (tooComplex) {
                let compiled = CompiledRegexPattern(pattern, "", true, false, false, None<Regex>)
                if (compiledPatternCache.size < maxCachedRegexCount) {
                    compiledPatternCache[key] = compiled
                }
                return Some(compiled)
            }
            var sanitized = sanitize(pattern)
            if (disableLineAnchors) {
                sanitized = disableLineStartAnchors(sanitized)
            }
            let regex = cachedRegexLocked(sanitized)
            let compiled = CompiledRegexPattern(
                pattern,
                sanitized,
                false,
                pattern.contains("\\G"),
                isLineStartAnchored(sanitized),
                regex
            )
            if (compiledPatternCache.size < maxCachedRegexCount) {
                compiledPatternCache[key] = compiled
            }
            return Some(compiled)
        }
    }

    private static func findCompiledSanitized(compiled: CompiledRegexPattern, input: String, cursor: Int64, captureGroups: Bool, maxCaptureIndex: Int64, bestStart: Int64): ?MatchRange {
        try {
            if (compiled.tooComplex) {
                return None
            }
            if (cursor > 0 && !compiled.originalContainsCursorAnchor && compiled.lineStartAnchored) {
                return None
            }
            let regex = match (compiled.regex) {
                case Some(value) => value
                case None => return None
            }
            GrammarTokenizer.recordRegexFindCall()
            match (regex.find(input, group: captureGroups)) {
                case Some(data) =>
                    let pos = data.matchPosition()
                    let start = cursor + pos.start
                    if (start >= bestStart) {
                        return None
                    }
                    let end = cursor + pos.end
                    if (!captureGroups) {
                        return Some(MatchRange(start, end))
                    }
                    let captures = ArrayList<CaptureRange>()
                    captures.add(CaptureRange(0, start, end))
                    let groupLimit = minGroupCount(data.groupCount(), maxCaptureIndex)
                    var i: Int64 = 1
                    while (i <= groupLimit) {
                        try {
                            GrammarTokenizer.recordCaptureGroupPositionProbe()
                            let groupPos = data.matchPosition(i)
                            if (groupPos.end > groupPos.start) {
                                captures.add(CaptureRange(i, cursor + groupPos.start, cursor + groupPos.end))
                            }
                        } catch (_: Exception) {
                            ()
                        }
                        i += 1
                    }
                    return Some(MatchRange(start, end, captures: captures.toArray()))
                case None => return None
            }
        } catch (_: Exception) {
            return None
        }
    }

    private static func minGroupCount(groupCount: Int64, maxCaptureIndex: Int64): Int64 {
        if (maxCaptureIndex <= 0 || groupCount < maxCaptureIndex) {
            return groupCount
        }
        return maxCaptureIndex
    }

    private static func cachedRegex(pattern: String): ?Regex {
        synchronized(regexCacheMutex) {
            return cachedRegexLocked(pattern)
        }
    }

    private static func cachedRegexLocked(pattern: String): ?Regex {
        if (invalidRegexCache.contains(pattern)) {
            return None
        }
        match (regexCache.get(pattern)) {
            case Some(regex) => return Some(regex)
            case None =>
                try {
                    let regex = Regex(pattern)
                    if (regexCache.size < maxCachedRegexCount) {
                        regexCache[pattern] = regex
                    }
                    return Some(regex)
                } catch (_: Exception) {
                    if (invalidRegexCache.size < maxCachedRegexCount) {
                        invalidRegexCache[pattern] = true
                    }
                    return None
                }
        }
    }

    private static func isTooComplexForCurrentAdapter(pattern: String): Bool {
        if (pattern.contains("(?(")) {
            return true
        }
        if (pattern.contains("\\K")) {
            return true
        }
        if (hasVariableLengthLookbehind(pattern)) {
            return true
        }
        return false
    }

    private static func hasVariableLengthLookbehind(pattern: String): Bool {
        var searchStart: Int64 = 0
        while (searchStart < pattern.size) {
            let positive = pattern.indexOf("(?<=", searchStart)
            let negative = pattern.indexOf("(?<!", searchStart)
            let start = match ((positive, negative)) {
                case (Some(p), Some(n)) => if (p < n) { p } else { n }
                case (Some(p), None) => p
                case (None, Some(n)) => n
                case (None, None) => return false
            }
            let contentStart = start + 4
            var index = contentStart
            var escaped = false
            var inClass = false
            while (index < pattern.size) {
                let current = pattern[index]
                if (escaped) {
                    escaped = false
                    index += 1
                    continue
                }
                if (current == b'\\') {
                    escaped = true
                    index += 1
                    continue
                }
                if (current == b'[') {
                    inClass = true
                    index += 1
                    continue
                }
                if (current == b']') {
                    inClass = false
                    index += 1
                    continue
                }
                if (!inClass && current == b')') {
                    let content = pattern[contentStart..index]
                    if (lookbehindContentCanBeVariableLength(content)) {
                        return true
                    }
                    searchStart = index + 1
                    break
                }
                index += 1
            }
            if (index >= pattern.size) {
                return true
            }
        }
        return false
    }

    private static func lookbehindContentCanBeVariableLength(content: String): Bool {
        var escaped = false
        var inClass = false
        for (b in content.toArray()) {
            if (escaped) {
                escaped = false
                continue
            }
            if (b == b'\\') {
                escaped = true
                continue
            }
            if (b == b'[') {
                inClass = true
                continue
            }
            if (b == b']') {
                inClass = false
                continue
            }
            if (!inClass && (b == b'*' || b == b'+' || b == b'{')) {
                return true
            }
        }
        return false
    }

    static func findAt(pattern: String, line: String, cursor: Int64): ?MatchRange {
        match (find(pattern, line, cursor)) {
            case Some(range) =>
                return if (range.start == cursor) { Some(range) } else { None }
            case None => return None
        }
    }

    static func findContextEndAt(pattern: String, line: String, cursor: Int64): ?MatchRange {
        match (findContextEnd(pattern, line, cursor)) {
            case Some(range) =>
                return if (range.start == cursor) { Some(range) } else { None }
            case None => return None
        }
    }

    static func escapeLiteral(value: String): String {
        let out = StringBuilder(value.size * 2)
        var i: Int64 = 0
        while (i < value.size) {
            let b = value[i]
            if (b == b'\\' || b == b'.' || b == b'^' || b == b'$' || b == b'|' ||
                b == b'?' || b == b'*' || b == b'+' || b == b'(' || b == b')' ||
                b == b'[' || b == b']' || b == b'{' || b == b'}') {
                out.append("\\")
            }
            i += appendPatternRune(out, value, i)
        }
        return out.toString()
    }

    private static func sanitize(pattern: String): String {
        var value = pattern
            .replace("\\G", "^")
            .replace("\\A", "^")
            .replace("\\z", "$")
            .replace("\\Z", "$")
            .replace("\\R", "\\n")
            .replace("(?=\\s*\\(.*)", "(?=\\s*\\()")
            .replace("(?=\\s*\\<[\\*\\<\\,\\w\\s]*\\>\\s*\\(.*)", "(?=\\s*\\<[\\*\\<\\,\\w\\s]*\\>\\s*\\()")
            .replace("\\h", "[0-9A-Fa-f]")
            .replace("[:ascii:]", "\\x00-\\x7F")
            .replace("[:alnum:]", "A-Za-z0-9")
            .replace("[:alpha:]", "A-Za-z")
            .replace("[:digit:]", "0-9")
            .replace("[:xdigit:]", "A-Fa-f0-9")
            .replace("[:upper:]", "A-Z")
            .replace("[:lower:]", "a-z")
            .replace("[:space:]", "\\s")
            .replace("[:blank:]", " \\t")
            .replace("[:word:]", "A-Za-z0-9_")
        value = downgradeAtomicGroups(value)
        value = downgradePossessiveQuantifiers(value)
        if (value.startsWith("(?x)")) {
            return compactExtendedPattern(value[4..value.size])
        }
        return value
    }

    private static func downgradeAtomicGroups(pattern: String): String {
        if (!pattern.contains("(?>")) {
            return pattern
        }
        let out = StringBuilder(pattern.size)
        var inClass = false
        var escaped = false
        var i: Int64 = 0
        while (i < pattern.size) {
            let b = pattern[i]
            if (escaped) {
                i += appendPatternRune(out, pattern, i)
                escaped = false
                continue
            }
            if (b == b'\\') {
                out.append("\\")
                escaped = true
                i += 1
                continue
            }
            if (b == b'[') {
                inClass = true
                out.append("[")
                i += 1
                continue
            }
            if (b == b']') {
                inClass = false
                out.append("]")
                i += 1
                continue
            }
            if (!inClass && b == b'(' && i + 2 < pattern.size && pattern[i + 1] == b'?' && pattern[i + 2] == b'>') {
                out.append("(?:")
                i += 3
                continue
            }
            i += appendPatternRune(out, pattern, i)
        }
        return out.toString()
    }

    private static func downgradePossessiveQuantifiers(pattern: String): String {
        if (!pattern.contains("*+") && !pattern.contains("++") && !pattern.contains("?+") && !pattern.contains("}+")) {
            return pattern
        }
        let out = StringBuilder(pattern.size)
        var inClass = false
        var escaped = false
        var i: Int64 = 0
        while (i < pattern.size) {
            let b = pattern[i]
            if (escaped) {
                i += appendPatternRune(out, pattern, i)
                escaped = false
                continue
            }
            if (b == b'\\') {
                out.append("\\")
                escaped = true
                i += 1
                continue
            }
            if (b == b'[') {
                inClass = true
                out.append("[")
                i += 1
                continue
            }
            if (b == b']') {
                inClass = false
                out.append("]")
                i += 1
                continue
            }
            if (!inClass && i + 1 < pattern.size && pattern[i + 1] == b'+' && isPossessiveQuantifierTail(pattern, i)) {
                _ = appendPatternRune(out, pattern, i)
                i += 2
                continue
            }
            i += appendPatternRune(out, pattern, i)
        }
        return out.toString()
    }

    private static func isPossessiveQuantifierTail(pattern: String, index: Int64): Bool {
        let b = pattern[index]
        if (b == b'*' || b == b'?' || b == b'}') {
            return true
        }
        if (b != b'+') {
            return false
        }
        if (index == 0) {
            return false
        }
        let previous = pattern[index - 1]
        return previous != b'(' && previous != b'|' && previous != b'[' && previous != b'{'
    }

    private static func disableLineStartAnchors(pattern: String): String {
        let out = StringBuilder(pattern.size)
        var inClass = false
        var escaped = false
        var i: Int64 = 0
        while (i < pattern.size) {
            let b = pattern[i]
            if (escaped) {
                i += appendPatternRune(out, pattern, i)
                escaped = false
                continue
            }
            if (b == b'\\') {
                out.append("\\")
                escaped = true
                i += 1
                continue
            }
            if (b == b'[') {
                inClass = true
                out.append("[")
                i += 1
                continue
            }
            if (b == b']') {
                inClass = false
                out.append("]")
                i += 1
                continue
            }
            if (!inClass && b == b'^') {
                out.append("(?!)")
                i += 1
                continue
            }
            i += appendPatternRune(out, pattern, i)
        }
        return out.toString()
    }

    private static func isLineStartAnchored(pattern: String): Bool {
        return pattern.startsWith("^") || pattern.startsWith("(?=^")
    }

    private static func compactExtendedPattern(pattern: String): String {
        let out = StringBuilder(pattern.size)
        var inClass = false
        var escaped = false
        var inComment = false
        var i: Int64 = 0
        while (i < pattern.size) {
            let b = pattern[i]
            if (inComment) {
                if (b == b'\n' || b == b'\r') {
                    inComment = false
                }
                i += 1
                continue
            }
            if (escaped) {
                i += appendPatternRune(out, pattern, i)
                escaped = false
                continue
            }
            if (b == b'\\') {
                out.append("\\")
                escaped = true
                i += 1
                continue
            }
            if (b == b'[') {
                inClass = true
                out.append("[")
                i += 1
                continue
            }
            if (b == b']') {
                inClass = false
                out.append("]")
                i += 1
                continue
            }
            if (!inClass && b == b'#') {
                inComment = true
                i += 1
                continue
            }
            if (!inClass && (b == b' ' || b == b'\t' || b == b'\n' || b == b'\r')) {
                i += 1
                continue
            }
            i += appendPatternRune(out, pattern, i)
        }
        return out.toString()
    }
}

private func appendPatternRune(out: StringBuilder, text: String, index: Int64): Int64 {
    let b = text[index]
    if (b < 128) {
        out.append(String.fromUtf8([b]))
        return 1
    }
    let width = utf8RuneWidth(b)
    let end = min(index + width, text.size)
    out.append(text[index..end])
    return end - index
}

private func utf8RuneWidth(lead: UInt8): Int64 {
    if ((lead & 0xE0) == 0xC0) {
        return 2
    }
    if ((lead & 0xF0) == 0xE0) {
        return 3
    }
    if ((lead & 0xF8) == 0xF0) {
        return 4
    }
    return 1
}

class ScopeClass {
    static func fromScope(scope: String): String {
        let out = StringBuilder(scope.size)
        for (b in scope.toArray()) {
            if ((b >= b'a' && b <= b'z') || (b >= b'A' && b <= b'Z') || (b >= b'0' && b <= b'9')) {
                out.append(String.fromUtf8([b]))
            } else {
                out.append("-")
            }
        }
        return trimDashes(out.toString())
    }

    private static func trimDashes(value: String): String {
        var start: Int64 = 0
        var end = value.size
        while (start < end && value[start] == b'-') {
            start += 1
        }
        while (end > start && value[end - 1] == b'-') {
            end -= 1
        }
        return value[start..end]
    }
}
