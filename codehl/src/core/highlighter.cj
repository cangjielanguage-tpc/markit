package codehl.core

import std.collection.ArrayList
import codehl.html.HtmlEscaper
import codehl.languages.{LanguageAlias, LanguageRegistration, LanguageRegistry, TokenizerState}
import codehl.themes.{Theme, ThemeRegistry}

public class Highlighter {
    private let languages: LanguageRegistry
    private let renderer: TokenHtmlRenderer
    private let defaultTheme: ?Theme
    private let themes: ThemeRegistry

    public init(
        theme!: ?Theme = None,
        grammarDir!: String = "assets/grammars",
        themeDir!: String = "assets/themes",
        grammarDirs!: Array<String> = [],
        themeDirs!: Array<String> = [],
        languages!: Array<LanguageRegistration> = [],
        aliases!: Array<LanguageAlias> = []
    ) {
        this.languages = LanguageRegistry(
            grammarDir: grammarDir,
            grammarDirs: grammarDirs,
            languages: languages,
            aliases: aliases
        )
        this.renderer = TokenHtmlRenderer()
        this.defaultTheme = theme
        this.themes = ThemeRegistry(themeDir: themeDir, themeDirs: themeDirs)
    }

    public func supportsLanguage(lang: String): Bool {
        let normalized = languages.normalizeConfiguredLanguage(lang)
        return normalized == "plain" || languages.findTokenizer(normalized).isSome()
    }

    public func supportsTheme(theme: String): Bool {
        return themes.loadTheme(theme).isSome()
    }

    public func highlight(code: String, options!: HighlightOptions = HighlightOptions()): String {
        return codeToTokens(code, options: options).toHtml()
    }

    public func highlightPlain(code: String, options!: HighlightOptions = HighlightOptions()): String {
        return codeToTokens(code, options: options, forcePlain: true).toHtml()
    }

    public func highlightBlock(code: String, options!: HighlightOptions = HighlightOptions()): CodeBlock {
        return codeToTokens(code, options: options)
    }

    public func codeToTokens(
        code: String,
        options!: HighlightOptions = HighlightOptions(),
        initialState!: TokenizerState = TokenizerState(),
        forcePlain!: Bool = false
    ): CodeBlock {
        let lang = languages.normalizeConfiguredLanguage(options.lang)
        let prefix = normalizeClassPrefix(options.classPrefix)
        let lines = TokenHtmlRenderer.splitCodeLines(code)
        let outLines = ArrayList<CodeLine>()
        var state = initialState

        if (!forcePlain) {
            if (let Some(tokenizer) <- languages.findTokenizer(lang)) {
                for (i in 0..lines.size) {
                    let lineNumber = i + 1
                    let tokenized = tokenizer.tokenizeLine(lines[i], state)
                    state = tokenized.state
                    outLines.add(CodeLine(
                        lineNumber,
                        lines[i],
                        tokenized.tokens,
                        containsLine(options.highlightLines, lineNumber),
                        shouldRenderLine(lineNumber, options)
                    ))
                }
                return CodeBlock(lang, prefix, outLines.toArray(), state, theme: effectiveTheme(options))
            }
        }

        for (i in 0..lines.size) {
            let lineNumber = i + 1
            outLines.add(CodeLine(
                lineNumber,
                lines[i],
                [],
                containsLine(options.highlightLines, lineNumber),
                shouldRenderLine(lineNumber, options)
            ))
        }
        return CodeBlock(lang, prefix, outLines.toArray(), state, theme: effectiveTheme(options))
    }

    public func highlightDualTheme(code: String, options!: DualThemeOptions = DualThemeOptions()): String {
        let prefix = normalizeClassPrefix(options.base.classPrefix)
        let fragments = highlightDualThemeFragments(code, options: options)
        let light = wrapThemeFragment(fragments.lightHtml, prefix, options.lightTheme, "light")
        let dark = wrapThemeFragment(fragments.darkHtml, prefix, options.darkTheme, "dark")
        let out = StringBuilder(light.size + dark.size + prefix.size + 32)
        out.append("<div class=\"")
        out.append(prefix)
        out.append("-dual-theme\">")
        out.append(light)
        out.append(dark)
        out.append("</div>")
        return out.toString()
    }

    public func highlightDualThemeFragments(code: String, options!: DualThemeOptions = DualThemeOptions()): DualThemeHtml {
        let tokenOptions = HighlightOptions(
            lang: options.base.lang,
            classPrefix: options.base.classPrefix,
            highlightLines: options.base.highlightLines,
            i18nLines: options.base.i18nLines,
            targetLang: options.base.targetLang,
            themeName: "",
            theme: None
        )
        let block = codeToTokens(code, options: tokenOptions)
        return DualThemeHtml(
            block.withTheme(effectiveDualTheme(options.lightThemeModel, options.lightTheme)).toHtml(),
            block.withTheme(effectiveDualTheme(options.darkThemeModel, options.darkTheme)).toHtml()
        )
    }

    private func effectiveDualTheme(theme: ?Theme, themeName: String): ?Theme {
        match (theme) {
            case Some(t) => return Some(t)
            case None =>
                if (!themeName.trimAscii().isEmpty()) {
                    match (themes.loadTheme(themeName)) {
                        case Some(loaded) => return Some(loaded)
                        case None => ()
                    }
                }
                return defaultTheme
        }
    }

    private static func wrapThemeFragment(inner: String, prefix: String, theme: String, mode: String): String {
        let escapedMode = HtmlEscaper.escapeAttribute(mode)
        let escapedTheme = HtmlEscaper.escapeAttribute(theme)
        let out = StringBuilder(inner.size + prefix.size * 2 + escapedMode.size + escapedTheme.size + 64)
        out.append("<div class=\"")
        out.append(prefix)
        out.append("-theme ")
        out.append(prefix)
        out.append("-theme-")
        out.append(escapedMode)
        out.append("\" data-theme=\"")
        out.append(escapedTheme)
        out.append("\">")
        out.append(inner)
        out.append("</div>")
        return out.toString()
    }

    private static func normalizeClassPrefix(prefix: String): String {
        let value = prefix.trimAscii()
        return if (value.isEmpty()) { "codehl" } else { value }
    }

    private func effectiveTheme(options: HighlightOptions): ?Theme {
        match (options.theme) {
            case Some(theme) => return Some(theme)
            case None =>
                if (!options.themeName.trimAscii().isEmpty()) {
                    match (themes.loadTheme(options.themeName)) {
                        case Some(theme) => return Some(theme)
                        case None => ()
                    }
                }
                return defaultTheme
        }
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
