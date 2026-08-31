package markit.tests.unit.plugins.anchor

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.{CommonMarkBundle, GFMBundle, StandardMarkdownBundle}
import markit.plugins.commonmark.block.html_block.HtmlBlockConfig
import markit.plugins.gfm.block.math_block.MathBlockConfig
import markit.plugins.gfm.block.table.TableConfig
import markit.plugins.standard.block.fenced_code_block.FencedCodeBlockConfig
import markit.plugins.standard.block.heading.HeadingNumberingConfig
import markit.plugins.standard.block.list.ListConfig
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

private func standardAnchors(): Markit {
    return Markit(StandardMarkdownBundle(
        fencedCodeBlockConfig: FencedCodeBlockConfig(enableCodehl: false, autoAnchor: true),
        listConfig: ListConfig(autoAnchor: true)
    ))
}

private func standardBlockAnchors(): Markit {
    return Markit(StandardMarkdownBundle(
        fencedCodeBlockConfig: FencedCodeBlockConfig(enableCodehl: false, autoAnchor: true),
        listConfig: ListConfig(autoAnchor: true),
        blockAutoAnchor: true
    ))
}

private func standardBlockAnchorsWithHeadingState(): Markit {
    return Markit(StandardMarkdownBundle(
        headingNumberingConfig: HeadingNumberingConfig(
            enabled: true,
            initialCounters: Some([5, 1, 0, 0, 0, 0])
        ),
        fencedCodeBlockConfig: FencedCodeBlockConfig(enableCodehl: false, autoAnchor: true),
        listConfig: ListConfig(autoAnchor: true),
        blockAutoAnchor: true
    ))
}

private func commonMarkBlockAnchors(): Markit {
    return Markit(CommonMarkBundle(
        fencedCodeBlockConfig: FencedCodeBlockConfig(enableCodehl: false, autoAnchor: true),
        listConfig: ListConfig(autoAnchor: true),
        htmlBlockConfig: HtmlBlockConfig(enableInlineMarkdownParsing: true),
        blockAutoAnchor: true
    ))
}

private func gfmAnchors(): Markit {
    return Markit(GFMBundle(
        fencedCodeBlockConfig: FencedCodeBlockConfig(enableCodehl: false, autoAnchor: true),
        listConfig: ListConfig(autoAnchor: true),
        mathBlockConfig: MathBlockConfig(enableHtmlMathtex: false, enableTypstMathtex: false, autoAnchor: true),
        tableConfig: TableConfig(autoAnchor: true)
    ))
}

@Test
@Tag[AutoAnchor]
class AutoAnchorTests {
    @TestCase
    func listItemsUseSectionAndNestedListPathAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            standardAnchors,
            """
# A

1. Parent
   - Child
2. Next
""",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<h1 id=\"a\" data-source-start-byte=\"0\" data-source-end-byte=\"3\">A</h1><ol><li id=\"1-ol-1.1\" data-anchor-id=\"1-ol-1.1\" data-source-start-byte=\"5\" data-source-end-byte=\"25\" class=\"markit-anchor-target\">Parent<ul><li id=\"1-ol-1.1-ul-1.1\" data-anchor-id=\"1-ol-1.1-ul-1.1\" data-source-start-byte=\"15\" data-source-end-byte=\"25\" class=\"markit-anchor-target\">Child</li></ul></li><li id=\"1-ol-1.2\" data-anchor-id=\"1-ol-1.2\" data-source-start-byte=\"26\" data-source-end-byte=\"33\" class=\"markit-anchor-target\">Next</li></ol>"
                )
                @Expect(
                    result.markdown,
                    "# A\n\n1. Parent\n\n   - Child\n2. Next\n\n"
                )
            }
        )
    }

    @TestCase
    func codeMathAndTableUsePerSectionBlockIndexesAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfmAnchors,
            """
# A

```text
x
```

$$
x = y
$$

| Name | Value |
| --- | --- |
| a | b |
""",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<h1 id=\"a\" data-source-start-byte=\"0\" data-source-end-byte=\"3\">A</h1><pre id=\"1-code-1\" data-anchor-id=\"1-code-1\" data-source-start-byte=\"5\" data-source-end-byte=\"18\" class=\"markit-anchor-target\"><code class=\"language-text\">x</code></pre><div id=\"1-math-1\" data-anchor-id=\"1-math-1\" data-source-start-byte=\"20\" data-source-end-byte=\"31\" class=\"math-block markit-anchor-target\">x = y</div><table><thead><tr><th id=\"1-table-1\" data-anchor-id=\"1-table-1\" data-source-start-byte=\"33\" data-source-end-byte=\"73\" class=\"markit-anchor-target\">Name</th><th>Value</th></tr></thead><tbody><tr><td>a</td><td>b</td></tr></tbody></table>"
                )
                @Expect(
                    result.markdown,
                    "# A\n\n```text\nx\n```\n\n$$\nx = y\n$$\n\n| Name | Value |\n| --- | --- |\n| a | b |\n\n"
                )
            }
        )
    }

    @TestCase
    func genericBlocksUseSectionBlockIndexesAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            standardBlockAnchors,
            """
# A

First paragraph

---

Second paragraph
""",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<h1 id=\"a\" data-source-start-byte=\"0\" data-source-end-byte=\"3\">A</h1><p id=\"1-block-1\" data-anchor-id=\"1-block-1\" data-source-start-byte=\"5\" data-source-end-byte=\"20\" class=\"markit-anchor-target\">First paragraph</p><hr id=\"1-block-2\" data-anchor-id=\"1-block-2\" data-source-start-byte=\"22\" data-source-end-byte=\"25\" class=\"markit-anchor-target\" /><p id=\"1-block-3\" data-anchor-id=\"1-block-3\" data-source-start-byte=\"27\" data-source-end-byte=\"43\" class=\"markit-anchor-target\">Second paragraph</p>"
                )
                @Expect(
                    result.markdown,
                    "# A\n\nFirst paragraph\n\n---\n\nSecond paragraph\n\n"
                )
            }
        )
    }

    @TestCase
    func blockAnchorsUseRenderedHeadingNumberAsSectionPrefixAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            standardBlockAnchorsWithHeadingState,
            """
## B

Text
""",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<h2 id=\"b\" data-number=\"5.2\" data-source-start-byte=\"0\" data-source-end-byte=\"4\">5.2 B</h2><p id=\"5.2-block-1\" data-anchor-id=\"5.2-block-1\" data-source-start-byte=\"6\" data-source-end-byte=\"10\" class=\"markit-anchor-target\">Text</p>"
                )
                @Expect(
                    result.markdown,
                    "## 5.2 B\n\nText\n\n"
                )
            }
        )
    }

    @TestCase
    func nestedParagraphsDoNotReceiveGenericBlockAnchorsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            standardBlockAnchors,
            """
# A

- `One`
- Two

> Quote
""",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<h1 id=\"a\" data-source-start-byte=\"0\" data-source-end-byte=\"3\">A</h1><ul><li id=\"1-ul-1.1\" data-anchor-id=\"1-ul-1.1\" data-source-start-byte=\"5\" data-source-end-byte=\"12\" class=\"markit-anchor-target\"><p><code>One</code></p></li><li id=\"1-ul-1.2\" data-anchor-id=\"1-ul-1.2\" data-source-start-byte=\"13\" data-source-end-byte=\"19\" class=\"markit-anchor-target\"><p>Two</p></li></ul><blockquote id=\"1-block-1\" data-anchor-id=\"1-block-1\" class=\"markit-anchor-target\"><p>Quote</p></blockquote>"
                )
                @Expect(
                    result.markdown,
                    "# A\n\n- `One`\n- Two\n\n> Quote\n\n"
                )
            }
        )
    }

    @TestCase
    func listIndexesAreUniqueAcrossContainerScopesInSameSectionAcrossModes() {
        ParseModeTestKit.assertMarkdownAcrossModes(
            standardBlockAnchors,
            """
# A

- Top

> - Quoted
""",
            "# A\n\n- Top\n\n> - Quoted\n\n"
        )
    }

    @TestCase
    func safeHtmlBlocksUseGenericBlockAnchorsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            commonMarkBlockAnchors,
            """
# A

<section class="panel">
Text
</section>
""",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<h1 id=\"a\" data-source-start-byte=\"0\" data-source-end-byte=\"3\">A</h1><section id=\"1-block-1\" data-anchor-id=\"1-block-1\" data-source-start-byte=\"5\" data-source-end-byte=\"44\" class=\"panel markit-anchor-target\"><p>Text</p></section>"
                )
                @Expect(
                    result.markdown,
                    "# A\n\n<section class=\"panel\">\nText\n</section>\n\n"
                )
            }
        )
    }

    @TestCase
    func disabledAutoAnchorsKeepDefaultRenderingAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit(GFMBundle(mathBlockConfig: MathBlockConfig(enableHtmlMathtex: false))) },
            """
# A

1. Item

```text
x
```

$$
x = y
$$

| Name | Value |
| --- | --- |
| a | b |
""",
            "<h1 id=\"a\">A</h1><ol><li><p>Item</p></li></ol><pre><code class=\"language-text\">x</code></pre><div class=\"math-block\">x = y</div><table><thead><tr><th>Name</th><th>Value</th></tr></thead><tbody><tr><td>a</td><td>b</td></tr></tbody></table>"
        )
    }
}
