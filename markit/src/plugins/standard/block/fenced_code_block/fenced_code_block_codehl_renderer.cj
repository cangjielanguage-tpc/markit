package markit.plugins.standard.block.fenced_code_block

import std.collection.HashMap
import std.sync.Mutex
import codehl.{DualThemeHtml, DualThemeOptions, Highlighter, HighlightOptions, LanguageAlias, LanguageRegistration, LineOptionsParser, Theme}

class FencedCodeBlockCodehlRenderer {
    private static let highlighterCache = HashMap<String, Highlighter>()
    private static let highlighterCacheMutex = Mutex()

    static func renderInto(node: FencedCodeBlockNode, config: FencedCodeBlockConfig): Unit {
        if (!config.enableCodehl) {
            return
        }
        if (!node.fileGroups.isEmpty()) {
            return
        }
        if (!isHighlightableLanguage(node.language)) {
            return
        }
        renderWithConfig(node, config)
    }

    static func renderContentWithConfig(
        content: String,
        language: String,
        highlightLines: String,
        i18nLines: String,
        config: FencedCodeBlockConfig
    ): DualThemeHtml {
        try {
            let lineCount = countLines(content)
            return highlighter(config).highlightDualThemeFragments(
                content,
                options: DualThemeOptions(
                    lightTheme: effectiveLightTheme(config),
                    darkTheme: effectiveDarkTheme(config),
                    base: HighlightOptions(
                        lang: language,
                        highlightLines: LineOptionsParser.parseHighlightLines(highlightLines, lineCount),
                        i18nLines: FencedCodeBlockLineRuleUtils.collectI18nLineNumbers(i18nLines, config.targetLanguage, lineCount).toArray(),
                        targetLang: config.targetLanguage
                    )
                )
            )
        } catch (e: Exception) {
            throw IllegalArgumentException("codehl render failed for fenced code language='${language}', snippet='${snippet(content)}': ${e.toString()}")
        }
    }

    static func renderContentWithThemeNames(
        content: String,
        language: String,
        highlightLines: String,
        lightTheme: String,
        darkTheme: String
    ): DualThemeHtml {
        let lineCount = countLines(content)
        return highlighter().highlightDualThemeFragments(
            content,
            options: DualThemeOptions(
                lightTheme: lightTheme,
                darkTheme: darkTheme,
                base: HighlightOptions(
                    lang: language,
                    highlightLines: LineOptionsParser.parseHighlightLines(highlightLines, lineCount)
                )
            )
        )
    }

    static func renderWithConfig(node: FencedCodeBlockNode, config: FencedCodeBlockConfig): Unit {
        let fragments = try {
            let lineCount = countLines(node.literal)
            highlighter(config).highlightDualThemeFragments(
                node.literal,
                options: DualThemeOptions(
                    lightTheme: effectiveLightTheme(config),
                    darkTheme: effectiveDarkTheme(config),
                    base: HighlightOptions(
                        lang: node.language,
                        highlightLines: LineOptionsParser.parseHighlightLines(node.highlightLines, lineCount),
                        i18nLines: FencedCodeBlockLineRuleUtils.collectI18nLineNumbers(node.i18nLines, config.targetLanguage, lineCount).toArray(),
                        targetLang: config.targetLanguage
                    )
                )
            )
        } catch (e: Exception) {
            throw IllegalArgumentException("codehl render failed for fenced code node=${node.id}, language='${node.language}', snippet='${snippet(node.literal)}': ${e.toString()}")
        }
        node.setString("codehl.html.light", fragments.lightHtml)
        node.setString("codehl.html.dark", fragments.darkHtml)
    }

    static func renderWithThemeNames(node: FencedCodeBlockNode, lightTheme: String, darkTheme: String): Unit {
        let lineCount = countLines(node.literal)
        let fragments = highlighter(
            grammarDirs: [],
            themeDirs: [],
            languages: [],
            aliases: []
        ).highlightDualThemeFragments(
            node.literal,
            options: DualThemeOptions(
                lightTheme: lightTheme,
                darkTheme: darkTheme,
                base: HighlightOptions(
                    lang: node.language,
                    highlightLines: LineOptionsParser.parseHighlightLines(node.highlightLines, lineCount)
                )
            )
        )
        node.setString("codehl.html.light", fragments.lightHtml)
        node.setString("codehl.html.dark", fragments.darkHtml)
    }

    static func renderWithThemes(node: FencedCodeBlockNode, lightTheme: ?Theme, darkTheme: ?Theme): Unit {
        let lineCount = countLines(node.literal)
        let fragments = highlighter(
            grammarDirs: [],
            themeDirs: [],
            languages: [],
            aliases: []
        ).highlightDualThemeFragments(
            node.literal,
            options: DualThemeOptions(
                lightThemeModel: lightTheme,
                darkThemeModel: darkTheme,
                base: HighlightOptions(
                    lang: node.language,
                    highlightLines: LineOptionsParser.parseHighlightLines(node.highlightLines, lineCount)
                )
            )
        )
        node.setString("codehl.html.light", fragments.lightHtml)
        node.setString("codehl.html.dark", fragments.darkHtml)
    }

    private static func effectiveLightTheme(config: FencedCodeBlockConfig): String {
        if (!config.theme.isEmpty()) {
            return config.theme
        }
        return config.lightTheme
    }

    private static func effectiveDarkTheme(config: FencedCodeBlockConfig): String {
        if (!config.theme.isEmpty()) {
            return config.theme
        }
        return config.darkTheme
    }

    private static func highlighter(config: FencedCodeBlockConfig): Highlighter {
        return highlighter(
            grammarDirs: config.codehlGrammarDirs,
            themeDirs: config.codehlThemeDirs,
            languages: config.codehlLanguages,
            aliases: config.codehlAliases
        )
    }

    private static func highlighter(
        grammarDirs!: Array<String> = [],
        themeDirs!: Array<String> = [],
        languages!: Array<LanguageRegistration> = [],
        aliases!: Array<LanguageAlias> = []
    ): Highlighter {
        let key = highlighterCacheKey(grammarDirs, themeDirs, languages, aliases)
        synchronized(highlighterCacheMutex) {
            match (highlighterCache.get(key)) {
                case Some(cached) => return cached
                case None =>
                    let created = Highlighter(
                        grammarDirs: grammarDirs,
                        themeDirs: themeDirs,
                        languages: languages,
                        aliases: aliases
                    )
                    highlighterCache[key] = created
                    return created
            }
        }
    }

    private static func highlighterCacheKey(
        grammarDirs: Array<String>,
        themeDirs: Array<String>,
        languages: Array<LanguageRegistration>,
        aliases: Array<LanguageAlias>
    ): String {
        let out = StringBuilder(128)
        out.append("g:")
        appendStringArrayKey(out, grammarDirs)
        out.append("|t:")
        appendStringArrayKey(out, themeDirs)
        out.append("|l:")
        for (language in languages) {
            out.append(language.language)
            out.append("=")
            out.append(language.grammar)
            out.append("(")
            appendStringArrayKey(out, language.aliases)
            out.append(");")
        }
        out.append("|a:")
        for (alias in aliases) {
            out.append(alias.alias)
            out.append("=")
            out.append(alias.language)
            out.append(";")
        }
        return out.toString()
    }

    private static func isHighlightableLanguage(language: String): Bool {
        if (language.isEmpty()) {
            return false
        }
        let normalized = language.toAsciiLower()
        return normalized != "plain" && normalized != "text"
    }

    private static func appendStringArrayKey(out: StringBuilder, values: Array<String>): Unit {
        out.append(values.size.toString())
        out.append("[")
        for (value in values) {
            out.append(value.size.toString())
            out.append(":")
            out.append(value)
            out.append(";")
        }
        out.append("]")
    }

    private static func countLines(value: String): Int64 {
        if (value.isEmpty()) {
            return 1
        }
        var count: Int64 = 1
        for (b in value) {
            if (b == b'\n') {
                count += 1
            }
        }
        if (value.endsWith("\n") && count > 1) {
            count -= 1
        }
        return count
    }

    private static func snippet(value: String): String {
        let out = StringBuilder(80)
        var count: Int64 = 0
        for (rune in value.runes()) {
            if (count >= 20) {
                out.append("...")
                break
            }
            if (rune == r'\n') {
                out.append("\\n")
            } else if (rune == r'\r') {
                out.append("\\r")
            } else if (rune == r'\t') {
                out.append("\\t")
            } else {
                out.append(String([rune]))
            }
            count += 1
        }
        return out.toString()
    }
}
