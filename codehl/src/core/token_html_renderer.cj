package codehl.core

import std.collection.ArrayList
import std.collection.HashMap
import std.sync.Mutex
import codehl.html.HtmlEscaper
import codehl.languages.{CodeTokenizer, Token, TokenizerState}
import codehl.themes.{Theme, ThemeResolver}

public class TokenHtmlRenderer {
    private static let resolverCache = HashMap<String, ThemeResolver>()
    private static let resolverCacheMutex = Mutex()

    public init() {}

    public func renderBlock(block: CodeBlock): String {
        let out = StringBuilder(estimateBlockHtmlCapacity(block))
        renderBlockTo(out, block)
        return out.toString()
    }

    public func renderBlockTo(out: StringBuilder, block: CodeBlock): Unit {
        var renderedAnyLine = false
        let resolver: ?ThemeResolver = match (block.theme) {
            case Some(t) => Some(cachedResolver(t))
            case None => None<ThemeResolver>
        }

        appendPreOpen(out, block.classPrefix, block.lang)
        for (line in block.lines) {
            if (!line.visible) {
                continue
            }
            if (renderedAnyLine) {
                out.append("\n")
            }
            appendLineOpen(out, block.classPrefix, line.lineNumber, line.highlighted)
            appendCodeSpans(out, line.text, line.spans, block.classPrefix, resolver)
            out.append("</span>")
            renderedAnyLine = true
        }
        out.append("</code></pre>")
    }

    public func render(code: String, tokenizer: CodeTokenizer, options: HighlightOptions, lang: String, prefix: String): String {
        let lines = splitCodeLines(code)
        let out = StringBuilder(code.size * 2 + lines.size * 96)
        var state = TokenizerState()
        var renderedAnyLine = false

        appendPreOpen(out, prefix, lang)
        for (i in 0..lines.size) {
            let lineNumber = i + 1
            let tokenized = tokenizer.tokenizeLine(lines[i], state)
            state = tokenized.state
            if (!shouldRenderLine(lineNumber, options)) {
                continue
            }
            if (renderedAnyLine) {
                out.append("\n")
            }
            appendLineOpen(out, prefix, lineNumber, containsLine(options.highlightLines, lineNumber))
            appendTokenizedLine(out, lines[i], tokenized.tokens, prefix)
            out.append("</span>")
            renderedAnyLine = true
        }
        out.append("</code></pre>")
        return out.toString()
    }

    public func renderPlain(code: String, options: HighlightOptions, lang: String, prefix: String): String {
        let lines = splitCodeLines(code)
        let out = StringBuilder(code.size * 2 + lines.size * 80)
        var renderedAnyLine = false

        appendPreOpen(out, prefix, lang)
        for (i in 0..lines.size) {
            let lineNumber = i + 1
            if (!shouldRenderLine(lineNumber, options)) {
                continue
            }
            if (renderedAnyLine) {
                out.append("\n")
            }
            appendLineOpen(out, prefix, lineNumber, containsLine(options.highlightLines, lineNumber))
            out.append(HtmlEscaper.escapeText(lines[i]))
            out.append("</span>")
            renderedAnyLine = true
        }
        out.append("</code></pre>")
        return out.toString()
    }

    public static func splitCodeLines(code: String): Array<String> {
        let normalized = if (code.contains("\r")) { code.replace("\r\n", "\n").replace("\r", "\n") } else { code }
        let raw = normalized.split("\n")
        if (raw.size > 1 && raw[raw.size - 1].isEmpty()) {
            let trimmed = ArrayList<String>()
            for (i in 0..raw.size - 1) {
                trimmed.add(raw[i])
            }
            return trimmed.toArray()
        }
        return raw
    }

    private static func appendPreOpen(out: StringBuilder, prefix: String, lang: String): Unit {
        out.append("<pre class=\"")
        out.append(prefix)
        out.append(" ")
        out.append(prefix)
        out.append("-lang-")
        out.append(HtmlEscaper.escapeAttribute(lang))
        out.append("\"><code>")
    }

    private static func cachedResolver(theme: Theme): ThemeResolver {
        let key = themeCacheKey(theme)
        synchronized(resolverCacheMutex) {
            match (resolverCache.get(key)) {
                case Some(resolver) => return resolver
                case None =>
                    let resolver = ThemeResolver(theme)
                    resolverCache[key] = resolver
                    return resolver
            }
        }
    }

    private static func themeCacheKey(theme: Theme): String {
        if (!theme.name.isEmpty()) {
            return theme.name
        }
        return "${theme.foreground}|${theme.background}|${theme.rules.size}"
    }

    private static func appendLineOpen(out: StringBuilder, prefix: String, lineNumber: Int64, highlighted: Bool): Unit {
        out.append("<span class=\"")
        out.append(prefix)
        out.append("-line")
        if (highlighted) {
            out.append(" highlighted")
        }
        out.append("\" data-line=\"")
        out.append(lineNumber.toString())
        out.append("\">")
    }

    private static func appendTokenizedLine(out: StringBuilder, line: String, tokens: Array<Token>, prefix: String): Unit {
        var cursor: Int64 = 0
        for (token in tokens) {
            if (token.startByte < cursor || token.endByte <= token.startByte || token.endByte > line.size) {
                continue
            }
            let start = nextUtf8Boundary(line, token.startByte)
            let end = nextUtf8Boundary(line, token.endByte)
            if (cursor < start) {
                appendEscapedSlice(out, line, cursor, start)
            }
            out.append("<span class=\"")
            out.append(prefix)
            out.append("-token ")
            out.append(prefix)
            out.append("-")
            out.append(HtmlEscaper.escapeAttribute(token.scope))
            out.append("\">")
            appendEscapedSlice(out, line, start, end)
            out.append("</span>")
            cursor = end
        }
        if (cursor < line.size) {
            appendEscapedSlice(out, line, cursor, line.size)
        }
    }

    private static func appendCodeSpans(out: StringBuilder, line: String, spans: Array<CodeSpan>, prefix: String, resolver: ?ThemeResolver): Unit {
        var cursor: Int64 = 0
        for (span in spans) {
            if (span.startByte < cursor || span.endByte <= span.startByte || span.endByte > line.size) {
                continue
            }
            let start = nextUtf8Boundary(line, span.startByte)
            let end = nextUtf8Boundary(line, span.endByte)
            if (end <= start) {
                continue
            }
            if (cursor < start) {
                appendEscapedSlice(out, line, cursor, start)
            }
            out.append("<span class=\"")
            out.append(prefix)
            out.append("-token ")
            out.append(prefix)
            out.append("-")
            out.append(HtmlEscaper.escapeAttribute(span.scope))
            out.append("\"")
            match (resolver) {
                case Some(r) =>
                    let style = r.styleForScopeStack(span.scopes)
                    if (!style.isEmpty()) {
                        out.append(" style=\"")
                        out.append(HtmlEscaper.escapeAttribute(style))
                        out.append("\"")
                    }
                case None => ()
            }
            out.append(">")
            appendEscapedSlice(out, line, start, end)
            out.append("</span>")
            cursor = end
        }
        if (cursor < line.size) {
            appendEscapedSlice(out, line, cursor, line.size)
        }
    }

    private static func appendEscapedSlice(out: StringBuilder, line: String, start: Int64, end: Int64): Unit {
        if (start >= end) {
            return
        }
        out.append(HtmlEscaper.escapeText(line[start..end]))
    }

    private static func nextUtf8Boundary(line: String, index: Int64): Int64 {
        var cursor = index
        while (cursor < line.size && isUtf8ContinuationByte(line[cursor])) {
            cursor += 1
        }
        return cursor
    }

    private static func isUtf8ContinuationByte(byte: Byte): Bool {
        return (byte & 0xC0) == 0x80
    }

    private static func estimateBlockHtmlCapacity(block: CodeBlock): Int64 {
        var size: Int64 = 128
        for (line in block.lines) {
            size += line.text.size * 2 + line.spans.size * 96 + 80
        }
        return size
    }

    private static func shouldRenderLine(lineNumber: Int64, options: HighlightOptions): Bool {
        if (options.i18nLines.isEmpty()) {
            return true
        }
        if (options.targetLang.trimAscii().isEmpty()) {
            return true
        }
        return containsLine(options.i18nLines, lineNumber)
    }

    private static func containsLine(lines: Array<Int64>, lineNumber: Int64): Bool {
        for (line in lines) {
            if (line == lineNumber) {
                return true
            }
        }
        return false
    }
}
