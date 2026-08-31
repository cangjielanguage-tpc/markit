package codehl.tests

import std.unittest.*
import std.unittest.testmacro.*
import codehl.{DualThemeOptions, Highlighter, HighlightOptions}

@Test
@Tag[CoreHighlighter]
class HighlighterTests {
    @TestCase
    func plainFallbackEscapesHtmlAndKeepsLines() {
        let highlighter = Highlighter()
        let html = highlighter.highlightPlain(
            "let x = 1 < 2 && name == \"cj\"\nprintln(x)\n",
            options: HighlightOptions(lang: "cj")
        )

        @Expect(
            html,
            "<pre class=\"codehl codehl-lang-cangjie\"><code><span class=\"codehl-line\" data-line=\"1\">let x = 1 &lt; 2 &amp;&amp; name == \"cj\"</span>\n<span class=\"codehl-line\" data-line=\"2\">println(x)</span></code></pre>"
        )
    }

    @TestCase
    func highlightLinesAddsStableClass() {
        let highlighter = Highlighter()
        let html = highlighter.highlightPlain(
            "a\nb\nc",
            options: HighlightOptions(highlightLines: [2])
        )

        @Expect(
            html,
            "<pre class=\"codehl codehl-lang-plain\"><code><span class=\"codehl-line\" data-line=\"1\">a</span>\n<span class=\"codehl-line highlighted\" data-line=\"2\">b</span>\n<span class=\"codehl-line\" data-line=\"3\">c</span></code></pre>"
        )
    }

    @TestCase
    func i18nLinesFilterWhenTargetLanguageIsSet() {
        let highlighter = Highlighter()
        let html = highlighter.highlightPlain(
            "zh line\nen line\nshared",
            options: HighlightOptions(i18nLines: [1, 3], targetLang: "zh")
        )

        @Expect(
            html,
            "<pre class=\"codehl codehl-lang-plain\"><code><span class=\"codehl-line\" data-line=\"1\">zh line</span>\n<span class=\"codehl-line\" data-line=\"3\">shared</span></code></pre>"
        )
    }

    @TestCase
    func dualThemeWrapsBothPlainOutputs() {
        let highlighter = Highlighter()
        let html = highlighter.highlightDualTheme(
            "x",
            options: DualThemeOptions(
                lightTheme: "light-plus",
                darkTheme: "dark-plus",
                base: HighlightOptions(lang: "text")
            )
        )

        @Expect(
            html,
            "<div class=\"codehl-dual-theme\"><div class=\"codehl-theme codehl-theme-light\" data-theme=\"light-plus\"><pre class=\"codehl codehl-lang-plain\"><code><span class=\"codehl-line\" data-line=\"1\">x</span></code></pre></div><div class=\"codehl-theme codehl-theme-dark\" data-theme=\"dark-plus\"><pre class=\"codehl codehl-lang-plain\"><code><span class=\"codehl-line\" data-line=\"1\">x</span></code></pre></div></div>"
        )
    }

    @TestCase
    func emptyClassPrefixFallsBackToDefault() {
        let highlighter = Highlighter()
        let html = highlighter.highlightPlain(
            "x",
            options: HighlightOptions(classPrefix: "")
        )

        @Expect(
            html,
            "<pre class=\"codehl codehl-lang-plain\"><code><span class=\"codehl-line\" data-line=\"1\">x</span></code></pre>"
        )
    }

    @TestCase
    func attributeValuesAreEscapedExactly() {
        let highlighter = Highlighter()
        let html = highlighter.highlightDualTheme(
            "x",
            options: DualThemeOptions(
                lightTheme: "light&\"'",
                darkTheme: "dark<>",
                base: HighlightOptions(lang: "cj&\"'")
            )
        )

        @Expect(
            html,
            "<div class=\"codehl-dual-theme\"><div class=\"codehl-theme codehl-theme-light\" data-theme=\"light&amp;&quot;&#39;\"><pre class=\"codehl codehl-lang-cj&amp;&quot;&#39;\"><code><span class=\"codehl-line\" data-line=\"1\">x</span></code></pre></div><div class=\"codehl-theme codehl-theme-dark\" data-theme=\"dark&lt;&gt;\"><pre class=\"codehl codehl-lang-cj&amp;&quot;&#39;\"><code><span class=\"codehl-line\" data-line=\"1\">x</span></code></pre></div></div>"
        )
    }

    @TestCase
    func supportedLanguagesFollowCurrentJsAliases() {
        let highlighter = Highlighter()

        @Expect(highlighter.supportsLanguage("json"), true)
        @Expect(highlighter.supportsLanguage("cj"), true)
        @Expect(highlighter.supportsLanguage("cangjie"), true)
        @Expect(highlighter.supportsLanguage("text"), true)
        @Expect(highlighter.supportsLanguage("unknown-lang"), false)
    }

    @TestCase
    func vscodeBuiltInGrammarWhitelistLoadsCommonLanguages() {
        let highlighter = Highlighter()

        @Expect(highlighter.supportsLanguage("bash"), true)
        @Expect(highlighter.supportsLanguage("python"), true)
        @Expect(highlighter.supportsLanguage("py"), true)
        @Expect(highlighter.supportsLanguage("javascript"), true)
        @Expect(highlighter.supportsLanguage("js"), true)
        @Expect(highlighter.supportsLanguage("typescript"), true)
        @Expect(highlighter.supportsLanguage("ts"), true)
        @Expect(highlighter.supportsLanguage("yaml"), true)
        @Expect(highlighter.supportsLanguage("yml"), true)
        @Expect(highlighter.supportsLanguage("cpp"), true)
        @Expect(highlighter.supportsLanguage("csharp"), true)
        @Expect(highlighter.supportsLanguage("powershell"), true)
    }

    @TestCase
    func codeToTokensReturnsRenderableCodeBlock() {
        let highlighter = Highlighter()
        let block = highlighter.codeToTokens("{\"ok\": false}", options: HighlightOptions(lang: "json"))

        @Expect(block.lang, "json")
        @Expect(block.lines.size, 1)
        @Expect(block.lines[0].lineNumber, 1)
        @Expect(block.lines[0].text, "{\"ok\": false}")
        @Expect(block.lines[0].spans.size, 5)
        @Expect(block.lines[0].spans[0].scope, "punctuation-definition-dictionary-begin-json")
        @Expect(block.toHtml(), highlighter.highlight("{\"ok\": false}", options: HighlightOptions(lang: "json")))
    }

    @TestCase
    func codeBlockCanAppendHtmlToExistingWriterBuffer() {
        let highlighter = Highlighter()
        let block = highlighter.codeToTokens("{\"ok\": true}", options: HighlightOptions(lang: "json"))
        let out = StringBuilder(256)

        block.writeHtmlTo(out)

        @Expect(out.toString(), block.toHtml())
    }

    @TestCase
    func codeToTokensCanResumeFromFinalStateForIncrementalParsing() {
        let highlighter = Highlighter()
        let first = highlighter.codeToTokens("/* open", options: HighlightOptions(lang: "jsonc"))
        let second = highlighter.codeToTokens("still */", options: HighlightOptions(lang: "jsonc"), initialState: first.finalState)

        @Expect(first.finalState.isInitial(), false)
        @Expect(second.finalState.isInitial(), true)
        @Expect(first.lines[0].spans.size, 1)
        @Expect(first.lines[0].spans[0].scope, "comment-block-json-comments")
        @Expect(second.lines[0].spans.size, 2)
        @Expect(second.lines[0].spans[0].scope, "comment-block-json-comments")
        @Expect(second.lines[0].spans[1].scope, "punctuation-definition-comment-json-comments")
    }

    @TestCase
    func highlighterUsesGrammarFileForCangjie() {
        let highlighter = Highlighter()
        let html = highlighter.highlight(
            "let day = \"Day\"",
            options: HighlightOptions(lang: "cj")
        )

        @Expect(
            html,
            "<pre class=\"codehl codehl-lang-cangjie\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-keyword-control-Cangjie\">let</span> <span class=\"codehl-token codehl-support-variable-Cangjie\">day</span> = <span class=\"codehl-token codehl-string-quoted-double-Cangjie\">\"Day\"</span></span></code></pre>"
        )
    }

    @TestCase
    func cangjieHighlightSupportsChineseCommentsAndStrings() {
        let highlighter = Highlighter()
        let html = highlighter.highlight(
            "// 中文注释\nlet day = \"今天\"",
            options: HighlightOptions(lang: "cj")
        )

        @Expect(
            html,
            "<pre class=\"codehl codehl-lang-cangjie\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-comment-line-Cangjie\">// 中文注释</span></span>\n<span class=\"codehl-line\" data-line=\"2\"><span class=\"codehl-token codehl-keyword-control-Cangjie\">let</span> <span class=\"codehl-token codehl-support-variable-Cangjie\">day</span> = <span class=\"codehl-token codehl-string-quoted-double-Cangjie\">\"今天\"</span></span></code></pre>"
        )
    }

    @TestCase
    func cangjieHighlightSupportsPlainChineseIdentifierText() {
        let highlighter = Highlighter()
        let html = highlighter.highlight(
            "仓颉",
            options: HighlightOptions(lang: "cangjie")
        )

        @Expect(
            html,
            "<pre class=\"codehl codehl-lang-cangjie\"><code><span class=\"codehl-line\" data-line=\"1\">仓颉</span></code></pre>"
        )
    }

    @TestCase
    func cangjieHighlightSupportsChineseLineCommentAfterNumber() {
        let highlighter = Highlighter()
        let html = highlighter.highlight(
            "59 // 换行被视为结束符",
            options: HighlightOptions(lang: "cangjie")
        )

        @Expect(
            html,
            "<pre class=\"codehl codehl-lang-cangjie\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-constant-numeric-decimal-integer-Cangjie\">59</span> <span class=\"codehl-token codehl-comment-line-Cangjie\">// 换行被视为结束符</span></span></code></pre>"
        )
    }

    @TestCase
    func cangjieLineCommentKeepsKeywordsInsideComment() {
        let highlighter = Highlighter()
        let html = highlighter.highlight(
            "let a: Int32 = 1 // is as",
            options: HighlightOptions(lang: "cangjie")
        )

        @Expect(
            html,
            "<pre class=\"codehl codehl-lang-cangjie\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-keyword-control-Cangjie\">let</span> <span class=\"codehl-token codehl-support-variable-Cangjie\">a</span>: <span class=\"codehl-token codehl-keyword-control-Cangjie\">Int32</span> = <span class=\"codehl-token codehl-constant-numeric-decimal-integer-Cangjie\">1</span> <span class=\"codehl-token codehl-comment-line-Cangjie\">// is as</span></span></code></pre>"
        )
    }

    @TestCase
    func cangjieHighlightSupportsBilingualNewlineCommentExample() {
        let highlighter = Highlighter()
        let block = highlighter.codeToTokens(
            "let width1: Int32 = 32 // The newline character is treated as a terminator.\nlet length1: Int32 = 1024 // The newline character is treated as a terminator.\nlet width2: Int32 = 32; let length2: Int32 = 1024 // The newline character is treated as a terminator.\nvar x = 100 + // The newline character is treated as a connector.\n200 * 300 - // The newline character is treated as a connector.\n50 // The newline character is treated as a terminator.\n\nlet width1: Int32 = 32 // 换行符被视为结束符\nlet length1: Int32 = 1024 // 换行符被视为结束符\nlet width2: Int32 = 32; let length2: Int32 = 1024 // 换行符被视为结束符\nvar x = 100 + // 换行符被视为分隔符\n200 * 300 - // 换行符被视为分隔符\n50 // 换行符被视为结束符",
            options: HighlightOptions(lang: "cangjie")
        )

        @Expect(block.lines.size, 13)
        @Expect(block.lines[0].text, "let width1: Int32 = 32 // The newline character is treated as a terminator.")
        @Expect(block.lines[7].text, "let width1: Int32 = 32 // 换行符被视为结束符")
        @Expect(block.lines[12].text, "50 // 换行符被视为结束符")
        @Expect(block.finalState.isInitial(), true)
    }

    @TestCase
    func cangjieDualThemeSupportsBilingualNewlineCommentExample() {
        let highlighter = Highlighter()
        let fragments = highlighter.highlightDualThemeFragments(
            "let width1: Int32 = 32 // The newline character is treated as a terminator.\nlet length1: Int32 = 1024 // The newline character is treated as a terminator.\nlet width2: Int32 = 32; let length2: Int32 = 1024 // The newline character is treated as a terminator.\nvar x = 100 + // The newline character is treated as a connector.\n200 * 300 - // The newline character is treated as a connector.\n50 // The newline character is treated as a terminator.\n\nlet width1: Int32 = 32 // 换行符被视为结束符\nlet length1: Int32 = 1024 // 换行符被视为结束符\nlet width2: Int32 = 32; let length2: Int32 = 1024 // 换行符被视为结束符\nvar x = 100 + // 换行符被视为分隔符\n200 * 300 - // 换行符被视为分隔符\n50 // 换行符被视为结束符",
            options: DualThemeOptions(base: HighlightOptions(lang: "cangjie"))
        )

        @Expect(fragments.lightHtml.startsWith("<pre class=\"codehl codehl-lang-cangjie\">"), true)
        @Expect(fragments.darkHtml.startsWith("<pre class=\"codehl codehl-lang-cangjie\">"), true)
    }

    @TestCase
    func cangjieHighlightSupportsCommonChineseTextPositions() {
        let highlighter = Highlighter()
        let block = highlighter.codeToTokens(
            "/* 块注释 */\nfunc main() {\n    let 用户名 = \"张三\"\n    println(用户名)\n}",
            options: HighlightOptions(lang: "cangjie")
        )

        @Expect(block.lines.size, 5)
        @Expect(block.lines[0].text, "/* 块注释 */")
        @Expect(block.lines[0].spans.size, 1)
        @Expect(block.lines[0].spans[0].scope, "comment-block-Cangjie")
        @Expect(block.lines[2].text, "    let 用户名 = \"张三\"")
        @Expect(block.lines[2].spans.size, 2)
        @Expect(block.lines[2].spans[0].scope, "keyword-control-Cangjie")
        @Expect(block.lines[2].spans[1].scope, "string-quoted-double-Cangjie")
        @Expect(block.lines[3].text, "    println(用户名)")
    }

    @TestCase
    func dualThemeUsesTokenizedRendererForSupportedLanguages() {
        let highlighter = Highlighter()
        let html = highlighter.highlightDualTheme(
            "{\"ok\": false}",
            options: DualThemeOptions(base: HighlightOptions(lang: "json"))
        )

        @Expect(
            html,
            "<div class=\"codehl-dual-theme\"><div class=\"codehl-theme codehl-theme-light\" data-theme=\"light-plus\"><pre class=\"codehl codehl-lang-json\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-punctuation-definition-dictionary-begin-json\">{</span><span class=\"codehl-token codehl-string-json-support-type-property-name-json\" style=\"color:#a31515;\">\"ok\"</span><span class=\"codehl-token codehl-punctuation-separator-dictionary-key-value-json\">:</span> <span class=\"codehl-token codehl-constant-language-json\" style=\"color:#0000ff;\">false</span><span class=\"codehl-token codehl-punctuation-definition-dictionary-end-json\">}</span></span></code></pre></div><div class=\"codehl-theme codehl-theme-dark\" data-theme=\"dark-plus\"><pre class=\"codehl codehl-lang-json\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-punctuation-definition-dictionary-begin-json\">{</span><span class=\"codehl-token codehl-string-json-support-type-property-name-json\" style=\"color:#ce9178;\">\"ok\"</span><span class=\"codehl-token codehl-punctuation-separator-dictionary-key-value-json\">:</span> <span class=\"codehl-token codehl-constant-language-json\" style=\"color:#569cd6;\">false</span><span class=\"codehl-token codehl-punctuation-definition-dictionary-end-json\">}</span></span></code></pre></div></div>"
        )
    }
}
