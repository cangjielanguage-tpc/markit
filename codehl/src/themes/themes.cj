package codehl.themes

import std.collection.{ArrayList, HashMap}
import std.fs.*
import std.sync.Mutex
import seajson.*

public class Theme {
    public let name: String
    public let foreground: String
    public let background: String
    public let rules: Array<ThemeRule>

    public init(name!: String = "", foreground!: String = "", background!: String = "", rules!: Array<ThemeRule> = []) {
        this.name = name
        this.foreground = foreground
        this.background = background
        this.rules = rules
    }
}

public class ThemeRule {
    public let scope: String
    public let foreground: String
    public let fontStyle: String
    public let hasFontStyle: Bool

    public init(scope: String, foreground!: String = "", fontStyle!: String = "", hasFontStyle!: Bool = false) {
        this.scope = scope
        this.foreground = foreground
        this.fontStyle = fontStyle
        this.hasFontStyle = hasFontStyle
    }
}

public class ThemeLoader {
    public init() {}

    public func loadFromJson(json: String): Theme {
        return load(parseJson(json))
    }

    public func load(root: JsonValue): Theme {
        let name = jsonFieldString(root, "name") ?? ""
        var foreground = ""
        var background = ""
        match (jsonField(root, "colors")) {
            case Some(colors) =>
                foreground = jsonFieldString(colors, "editor.foreground") ?? ""
                background = jsonFieldString(colors, "editor.background") ?? ""
            case None => ()
        }

        let rules = ArrayList<ThemeRule>()
        match (jsonField(root, "tokenColors")) {
            case Some(JsonArrVal(items)) =>
                for (item in items) {
                    appendRules(rules, item)
                }
            case _ => ()
        }
        return Theme(name: name, foreground: foreground, background: background, rules: rules.toArray())
    }

    private static func appendRules(out: ArrayList<ThemeRule>, item: JsonValue): Unit {
        let settings = jsonField(item, "settings")
        let foreground = match (settings) {
            case Some(s) => jsonFieldString(s, "foreground") ?? ""
            case None => ""
        }
        let hasFontStyle = match (settings) {
            case Some(s) => jsonField(s, "fontStyle").isSome()
            case None => false
        }
        let fontStyle = match (settings) {
            case Some(s) => jsonFieldString(s, "fontStyle") ?? ""
            case None => ""
        }
        if (foreground.isEmpty() && !hasFontStyle) {
            return
        }
        match (jsonField(item, "scope")) {
            case Some(JsonStrVal(scope)) =>
                for (selector in splitSelectors(scope)) {
                    if (!selector.isEmpty()) {
                        out.add(ThemeRule(selector, foreground: foreground, fontStyle: fontStyle, hasFontStyle: hasFontStyle))
                    }
                }
            case Some(JsonArrVal(scopes)) =>
                for (scopeValue in scopes) {
                    match (scopeValue) {
                        case JsonStrVal(scope) =>
                            for (selector in splitSelectors(scope)) {
                                if (!selector.isEmpty()) {
                                    out.add(ThemeRule(selector, foreground: foreground, fontStyle: fontStyle, hasFontStyle: hasFontStyle))
                                }
                            }
                        case _ => ()
                    }
                }
            case _ => ()
        }
    }

    private static func splitSelectors(value: String): Array<String> {
        let out = ArrayList<String>()
        for (part in value.split(",")) {
            let trimmed = part.trimAscii()
            if (!trimmed.isEmpty()) {
                out.add(trimmed)
            }
        }
        return out.toArray()
    }
}

public class ThemeRegistry {
    private let themeDirs: Array<String>
    private let themeCache: HashMap<String, Theme>

    public init(themeDir!: String = "assets/themes", themeDirs!: Array<String> = []) {
        this.themeDirs = if (themeDirs.isEmpty()) { [themeDir] } else { themeDirs }
        this.themeCache = HashMap<String, Theme>()
    }

    public func loadTheme(name: String): ?Theme {
        let normalized = normalizeThemeName(name)
        if (normalized.isEmpty()) {
            return None
        }
        for (fileName in candidateFileNames(normalized)) {
            match (loadThemeFile(fileName)) {
                case Some(theme) => return Some(theme)
                case None => ()
            }
        }
        return None
    }

    public func loadThemeFile(fileName: String): ?Theme {
        match (themeCache.get(fileName)) {
            case Some(theme) => return Some(theme)
            case None => ()
        }
        let path = resolveThemePath(fileName)
        if (path.isEmpty()) {
            return None
        }
        try {
            let json = String.fromUtf8(File.readFrom(Path(path)))
            let theme = ThemeLoader().loadFromJson(json)
            themeCache[fileName] = theme
            return Some(theme)
        } catch (_: Exception) {
            return None
        }
    }

    private func resolveThemePath(fileName: String): String {
        for (themeDir in themeDirs) {
            for (prefix in assetSearchPrefixes()) {
                let base = if (prefix.isEmpty()) { Path(themeDir) } else { Path(prefix).join(themeDir) }
                let candidate = base.join(fileName).normalize().toString()
                if (exists(Path(candidate))) {
                    return candidate
                }
            }
        }
        return ""
    }

    private static func assetSearchPrefixes(): Array<String> {
        return ["", "codehl", "..\\codehl", "..\\..\\codehl", "..\\..\\..\\codehl"]
    }

    private static func candidateFileNames(name: String): Array<String> {
        if (name.endsWith(".json")) {
            return [name]
        }
        return [name + ".json", name + ".tmTheme.json"]
    }

    private static func normalizeThemeName(name: String): String {
        return name.trimAscii().replace("\\", "/")
    }
}

public class ThemeResolver {
    private let theme: Theme
    private let styleCache: HashMap<String, String>
    private let styleCacheMutex: Mutex

    public init(theme: Theme) {
        this.theme = theme
        this.styleCache = HashMap<String, String>()
        this.styleCacheMutex = Mutex()
    }

    public func styleForScope(scope: String): String {
        return styleForScopeStack([scope])
    }

    public func styleForScopeStack(scopes: Array<String>): String {
        synchronized(styleCacheMutex) {
            let cacheKey = scopeStackKey(scopes)
            match (styleCache.get(cacheKey)) {
                case Some(style) => return style
                case None => ()
            }
            var foreground = ""
            var fontStyle: ?String = None
            var matched = false
            var bestForegroundScore: Int64 = -1
            var bestForegroundIndex: Int64 = -1
            var bestFontStyleScore: Int64 = -1
            var bestFontStyleIndex: Int64 = -1
            for (i in 0..theme.rules.size) {
                let rule = theme.rules[i]
                let score = selectorScore(rule.scope, scopes)
                if (score < 0) {
                    continue
                }
                matched = true
                if (!rule.foreground.isEmpty() && (score > bestForegroundScore || (score == bestForegroundScore && i > bestForegroundIndex))) {
                    foreground = rule.foreground
                    bestForegroundScore = score
                    bestForegroundIndex = i
                }
                if (rule.hasFontStyle && (score > bestFontStyleScore || (score == bestFontStyleScore && i > bestFontStyleIndex))) {
                    fontStyle = Some(rule.fontStyle)
                    bestFontStyleScore = score
                    bestFontStyleIndex = i
                }
            }
            if (!matched) {
                styleCache[cacheKey] = ""
                return ""
            }
            let style = styleFromParts(foreground, fontStyle)
            styleCache[cacheKey] = style
            return style
        }
    }

    private static func selectorScore(selector: String, scopes: Array<String>): Int64 {
        let trimmed = selector.trimAscii()
        if (trimmed.isEmpty() || scopes.isEmpty()) {
            return -1
        }
        let parts = splitSelectorParts(trimmed)
        if (parts.isEmpty()) {
            return -1
        }
        let positive = ArrayList<String>()
        let negative = ArrayList<String>()
        var excluding = false
        for (part in parts) {
            if (part == "-") {
                excluding = true
                continue
            }
            if (excluding) {
                negative.add(part)
            } else {
                positive.add(part)
            }
        }
        if (positive.isEmpty()) {
            return -1
        }
        for (deny in negative) {
            if (stackContainsSelector(scopes, deny)) {
                return -1
            }
        }
        return positiveSelectorScore(positive.toArray(), scopes)
    }

    private static func positiveSelectorScore(parts: Array<String>, scopes: Array<String>): Int64 {
        let tokenScope = normalizedScope(scopes[scopes.size - 1])
        let tokenSelector = normalizeSelector(parts[parts.size - 1])
        if (!scopeMatches(tokenScope, tokenSelector)) {
            return -1
        }
        var stackIndex = scopes.size - 2
        var partIndex = parts.size - 2
        var score: Int64 = selectorPartScore(tokenScope, tokenSelector) * 1000000 + parts.size * 1000
        while (partIndex >= 0) {
            let selectorPart = normalizeSelector(parts[partIndex])
            var found = false
            while (stackIndex >= 0) {
                let scope = normalizedScope(scopes[stackIndex])
                if (scopeMatches(scope, selectorPart)) {
                    score += selectorPartScore(scope, selectorPart) * 1000 + stackIndex
                    found = true
                    stackIndex -= 1
                    break
                }
                stackIndex -= 1
            }
            if (!found) {
                return -1
            }
            partIndex -= 1
        }
        return score
    }

    private static func splitSelectorParts(selector: String): Array<String> {
        let out = ArrayList<String>()
        for (part in selector.split(" ", removeEmpty: true)) {
            let trimmed = part.trimAscii()
            if (!trimmed.isEmpty()) {
                out.add(trimmed)
            }
        }
        return out.toArray()
    }

    private static func stackContainsSelector(scopes: Array<String>, selector: String): Bool {
        let normalizedSelector = normalizeSelector(selector)
        for (scope in scopes) {
            if (scopeMatches(normalizedScope(scope), normalizedSelector)) {
                return true
            }
        }
        return false
    }

    private static func scopeMatches(scope: String, selector: String): Bool {
        if (selector.isEmpty()) {
            return false
        }
        return scope == selector || scope.startsWith(selector + "-")
    }

    private static func selectorPartScore(scope: String, selector: String): Int64 {
        return if (scope == selector) { selector.size + 10000 } else { selector.size }
    }

    private static func normalizeSelector(selector: String): String {
        return normalizedScope(selector.trimAscii())
    }

    private static func normalizedScope(scope: String): String {
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

    private static func styleFromRule(rule: ThemeRule): String {
        return styleFromParts(rule.foreground, Some(rule.fontStyle))
    }

    private static func styleFromParts(foreground: String, fontStyle: ?String): String {
        let out = StringBuilder(64)
        if (!foreground.isEmpty()) {
            out.append("color:")
            out.append(foreground)
            out.append(";")
        }
        match (fontStyle) {
            case Some(value) =>
                if (value.contains("italic")) {
                    out.append("font-style:italic;")
                }
                if (value.contains("bold")) {
                    out.append("font-weight:bold;")
                }
                if (value.contains("underline")) {
                    out.append("text-decoration:underline;")
                }
            case None => ()
        }
        return out.toString()
    }

    private static func scopeStackKey(scopes: Array<String>): String {
        let out = StringBuilder(64)
        for (i in 0..scopes.size) {
            if (i > 0) {
                out.append("|")
            }
            out.append(scopes[i])
        }
        return out.toString()
    }
}
