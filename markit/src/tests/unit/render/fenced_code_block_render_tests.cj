package markit.tests.unit.render

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.core.nodes.Node
import markit.plugins.standard.block.fenced_code_block.{FencedCodeBlockConfig, FencedCodeBlockPlugin}
import markit.plugins.standard.block.fenced_code_block.FencedCodeBlockNode
import markit.tests.utils.{AstTestKit, ParseModeTestKit}

@Test
@Tag[Render, FencedCodeBlock]
class FencedCodeBlockRenderTests {
    @TestCase
    func groupedFenceRenderTargetsStayStableAcrossModes() {
        let fixture = """
```typescript {3..=4,8} [2..=4:zh,6..=8:en]
///// 基础.ts
const a = 1;
///// second.js [javascript]
const b = 2;
```"""
        let results = ParseModeTestKit.collect(
            {
                => Markit.empty().use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableGroup: true)))
            },
            fixture
        )
        let baseline = results[0]

        @Expect(
            baseline.markdown,
            "```typescript\n///// 基础.ts\nconst a = 1;\n///// second.js [javascript]\nconst b = 2;\n```\n\n"
        )
        @Expect(
            baseline.typst,
            "``````typescript\nconst a = 1;\n``````\n\n``````javascript\nconst b = 2;\n``````\n\n"
        )
        expectGroupedFenceAst(baseline.root)
        @Expect(baseline.json, baseline.root.toJson())
        @Expect(baseline.tree, baseline.root.toString())

        for (result in results) {
            @Expect(result.markdown, baseline.markdown)
            @Expect(result.typst, baseline.typst)
            @Expect(result.json, baseline.json)
            @Expect(result.tree, baseline.tree)
        }
    }

    @TestCase
    func fencedCodeRendererWritesCodehlDualThemeMetaAsInlineHtml() {
        let result = Markit.empty().use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableCodehl: false))).parse("```cj\nlet x = 1\n```\n")
        let codeNode = AstTestKit.child(result.root(), 0, "FencedCodeBlockNode")
        if (let code: FencedCodeBlockNode <- codeNode) {
            code.setString("codehl.html.light", "<pre class=\"codehl light\"><code>light</code></pre>")
            code.setString("codehl.html.dark", "<pre class=\"codehl dark\"><code>dark</code></pre>")
        }

        @Expect(
            result.root().toHtml(),
            "<div class=\"codehl-dual-theme\" data-codehl=\"native\" data-codehl-theme=\"dual\"><div class=\"codehl-theme codehl-theme-light\"><pre class=\"codehl light\"><code>light</code></pre></div><div class=\"codehl-theme codehl-theme-dark\"><pre class=\"codehl dark\"><code>dark</code></pre></div></div>"
        )
        @Expect(result.toMarkdown(), "```cj\nlet x = 1\n```\n\n")
        @Expect(result.toTypst(), "``````cj\nlet x = 1\n``````\n\n")
    }

    @TestCase
    func fencedCodeRendererCanDisableCodehlMetaGeneration() {
        let result = Markit.empty().use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableCodehl: false))).parse("```cj {1}\nlet x = 1\n```\n")

        @Expect(
            result.root().toHtml(),
            "<pre><code class=\"language-cj\" data-highlight-lines=\"1\">let x = 1</code></pre>"
        )
    }

    @TestCase
    func fencedCodeRendererWritesGeneratedCodehlDualThemeInlineHtml() {
        let result = Markit.empty().use(FencedCodeBlockPlugin()).parse("```json\nfalse\n```\n")

        @Expect(
            result.root().toHtml(),
            "<div class=\"codehl-dual-theme\" data-codehl=\"native\" data-codehl-theme=\"dual\"><div class=\"codehl-theme codehl-theme-light\"><pre class=\"codehl codehl-lang-json\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-constant-language-json\" style=\"color:#0000ff;\">false</span></span></code></pre></div><div class=\"codehl-theme codehl-theme-dark\"><pre class=\"codehl codehl-lang-json\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-constant-language-json\" style=\"color:#569cd6;\">false</span></span></code></pre></div></div>"
        )
    }

    @TestCase
    func fencedCodeRendererHighlightsCangjiePlainChineseText() {
        let result = Markit.empty().use(FencedCodeBlockPlugin()).parse("```cangjie\n仓颉\n```\n")

        @Expect(
            result.root().toHtml(),
            "<div class=\"codehl-dual-theme\" data-codehl=\"native\" data-codehl-theme=\"dual\"><div class=\"codehl-theme codehl-theme-light\"><pre class=\"codehl codehl-lang-cangjie\"><code><span class=\"codehl-line\" data-line=\"1\">仓颉</span></code></pre></div><div class=\"codehl-theme codehl-theme-dark\"><pre class=\"codehl codehl-lang-cangjie\"><code><span class=\"codehl-line\" data-line=\"1\">仓颉</span></code></pre></div></div>"
        )
    }

    @TestCase
    func fencedCodeRendererHighlightsCangjieBilingualNewlineCommentExample() {
        let result = Markit.empty().use(FencedCodeBlockPlugin()).parse(
            "```cangjie [..=6:en,7..8:NA,8..:zh]\nlet width1: Int32 = 32 // The newline character is treated as a terminator.\nlet length1: Int32 = 1024 // The newline character is treated as a terminator.\nlet width2: Int32 = 32; let length2: Int32 = 1024 // The newline character is treated as a terminator.\nvar x = 100 + // The newline character is treated as a connector.\n200 * 300 - // The newline character is treated as a connector.\n50 // The newline character is treated as a terminator.\n\nlet width1: Int32 = 32 // 换行符被视为结束符\nlet length1: Int32 = 1024 // 换行符被视为结束符\nlet width2: Int32 = 32; let length2: Int32 = 1024 // 换行符被视为结束符\nvar x = 100 + // 换行符被视为分隔符\n200 * 300 - // 换行符被视为分隔符\n50 // 换行符被视为结束符\n```\n"
        )
        let codeNode = AstTestKit.child(result.root(), 0, "FencedCodeBlockNode")
        if (let code: FencedCodeBlockNode <- codeNode) {
            @Expect(code.language, "cangjie")
            @Expect(code.i18nLines, "..=6:en,7..8:NA,8..:zh")
            @Expect(code.content().split("\n").size, 13)
            @Expect(code.content().split("\n")[7], "let width1: Int32 = 32 // 换行符被视为结束符")
        }
    }

    @TestCase
    func generatedCodehlHtmlAppliesFencedCodeI18nRules() {
        let result = Markit.empty()
            .use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(targetLanguage: "zh")))
            .parse("```cangjie [1:en,2:zh]\nlet en = 1\nlet zh = 2\n```\n")

        @Expect(
            result.root().toHtml(),
            "<div class=\"codehl-dual-theme\" data-codehl=\"native\" data-codehl-theme=\"dual\"><div class=\"codehl-theme codehl-theme-light\"><pre class=\"codehl codehl-lang-cangjie\"><code><span class=\"codehl-line\" data-line=\"2\"><span class=\"codehl-token codehl-keyword-control-Cangjie\" style=\"color:#AF00DB;\">let</span> <span class=\"codehl-token codehl-support-variable-Cangjie\" style=\"color:#001080;\">zh</span> = <span class=\"codehl-token codehl-constant-numeric-decimal-integer-Cangjie\" style=\"color:#098658;\">2</span></span></code></pre></div><div class=\"codehl-theme codehl-theme-dark\"><pre class=\"codehl codehl-lang-cangjie\"><code><span class=\"codehl-line\" data-line=\"2\"><span class=\"codehl-token codehl-keyword-control-Cangjie\" style=\"color:#C586C0;\">let</span> <span class=\"codehl-token codehl-support-variable-Cangjie\" style=\"color:#9CDCFE;\">zh</span> = <span class=\"codehl-token codehl-constant-numeric-decimal-integer-Cangjie\" style=\"color:#b5cea8;\">2</span></span></code></pre></div></div>"
        )
    }

    @TestCase
    func fencedCodeRendererFiltersMarkdownAndTypstForTargetLanguage() {
        let result = Markit.empty()
            .use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableCodehl: false, targetLanguage: "en")))
            .parse("```cangjie [1:zh,2:en,3:zh]\nlet zh = 1\nlet en = 2\nlet zhAgain = 3\n```\n")

        @Expect(result.toMarkdown(), "```cangjie\nlet en = 2\n```\n\n")
        @Expect(result.toTypst(), "``````cangjie\nlet en = 2\n``````\n\n")
    }

    @TestCase
    func groupedFencedCodePanelsWriteGeneratedCodehlInlineHtml() {
        let result = Markit.empty()
            .use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableGroup: true)))
            .parse(
                """
```json
///// light.json
false
///// dark.json
true
```"""
            )

        @Expect(
            result.root().toHtml(),
            "<div class=\"code-block-group\"><div class=\"code-tabs\"><button class=\"code-tab active\" data-tab=\"0\"><span class=\"file-icon icon-json\"></span><span class=\"file-name\">light.json</span></button><button class=\"code-tab\" data-tab=\"1\"><span class=\"file-icon icon-json\"></span><span class=\"file-name\">dark.json</span></button></div><div class=\"code-panels\"><div class=\"code-panel active\" data-panel=\"0\"><div class=\"codehl-dual-theme\" data-codehl=\"native\" data-codehl-theme=\"dual\"><div class=\"codehl-theme codehl-theme-light\"><pre class=\"codehl codehl-lang-json\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-constant-language-json\" style=\"color:#0000ff;\">false</span></span></code></pre></div><div class=\"codehl-theme codehl-theme-dark\"><pre class=\"codehl codehl-lang-json\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-constant-language-json\" style=\"color:#569cd6;\">false</span></span></code></pre></div></div></div><div class=\"code-panel\" data-panel=\"1\"><div class=\"codehl-dual-theme\" data-codehl=\"native\" data-codehl-theme=\"dual\"><div class=\"codehl-theme codehl-theme-light\"><pre class=\"codehl codehl-lang-json\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-constant-language-json\" style=\"color:#0000ff;\">true</span></span></code></pre></div><div class=\"codehl-theme codehl-theme-dark\"><pre class=\"codehl codehl-lang-json\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-constant-language-json\" style=\"color:#569cd6;\">true</span></span></code></pre></div></div></div></div></div>"
        )
    }

    private func expectGroupedFenceAst(root: Node): Unit {
        AstTestKit.expectRoot(root, 1)
        let codeNode = AstTestKit.child(root, 0, "FencedCodeBlockNode")
        if (let code: FencedCodeBlockNode <- codeNode) {
            @Expect(code.language, "typescript")
            @Expect(String.fromUtf8([code.fenceMarker]), "`")
            @Expect(code.fenceLength, 3)
            @Expect(code.highlightLines, "3..=4,8")
            @Expect(code.i18nLines, "2..=4:zh,6..=8:en")
            @Expect(code.fileGroups.size, 2)

            @Expect(code.fileGroups[0].filename, "基础.ts")
            @Expect(code.fileGroups[0].language, "typescript")
            @Expect(code.fileGroups[0].content, "const a = 1;")

            @Expect(code.fileGroups[1].filename, "second.js")
            @Expect(code.fileGroups[1].language, "javascript")
            @Expect(code.fileGroups[1].content, "const b = 2;")
        }
    }
}
