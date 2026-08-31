package markit.tests.unit.plugins.standard.block

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.StandardMarkdownBundle
import markit.core.nodes.TextNode
import markit.plugins.standard.block.fenced_code_block.FencedCodeBlockConfig
import markit.plugins.standard.inline.inline_code.InlineCodeNode
import markit.tests.utils.{AstTestKit, ParseModeResult, ParseModeTestKit}

@Test
class OrderedListTests {
    @TestCase
    func keepsStartNumberAndChineseContent() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "3. 第三项\n4. 第四项\n",
            "<ol start=\"3\"><li>第三项</li><li>第四项</li></ol>"
        )
    }

    @TestCase
    func supportsParenDelimiterLists() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "1) First item\n2) Second item\n3) Third item\n",
            "<ol><li>First item</li><li>Second item</li><li>Third item</li></ol>"
        )
    }

    @TestCase
    func supportsLargeStartNumbersAndUnicodeItems() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            """
100. One hundred
101. One hundred one
999. 中文第九百九十九
""",
            "<ol start=\"100\"><li>One hundred</li><li>One hundred one</li><li>中文第九百九十九</li></ol>"
        )
    }

    @TestCase
    func supportsIndentedOrderedLists() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "  1. Indented first item\n  2. Indented second item\n",
            "<ol><li>Indented first item</li><li>Indented second item</li></ol>"
        )
    }

    @TestCase
    func rendersNestedOrderedListInsideParentItem() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            """
1. 外层
   1. 内层一
   2. 内层二
2. 结束
""",
            "<ol><li>外层<ol><li>内层一</li><li>内层二</li></ol></li><li>结束</li></ol>"
        )
    }

    @TestCase
    func mergesIndentedContinuationIntoSameItemParagraph() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "1. 第一行\n   第二行\n2. 下一项\n",
            "<ol><li>第一行\n第二行</li><li>下一项</li></ol>"
        )
    }

    @TestCase
    func supportsEmptyItems() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "1. \n2. Second item\n3. \n",
            "<ol><li></li><li>Second item</li><li></li></ol>"
        )
    }

    @TestCase
    func parsesInlineCodeInsideTightOrderedListItemsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            { => Markit() },
            "2. 调用 `代码`\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<ol start=\"2\"><li>调用 <code>代码</code></li></ol>")
                @Expect(result.markdown, "2. 调用 `代码`\n\n")
                @Expect(result.typst, "+ 调用 #markit-inline-code(\"代码\")\\u{2060}\n\n")

                AstTestKit.expectRoot(result.root, 1)
                let list = AstTestKit.child(result.root, 0, "OrderedListNode")
                AstTestKit.expectSpan(list, 0, 18, 0, 10)
                let item = AstTestKit.child(list, 0, "OrderedListItemNode")
                AstTestKit.expectSpan(item, 0, 18, 0, 10)
                let paragraph = AstTestKit.child(item, 0, "ParagraphNode")
                AstTestKit.expectSpan(paragraph, 3, 18, 3, 10)
                let text = AstTestKit.child(paragraph, 0, "TextNode")
                if (let textNode: TextNode <- text) {
                    @Expect(textNode.content, "调用 ")
                }
                AstTestKit.expectSpan(text, 3, 10, 3, 6)
                let code = AstTestKit.child(paragraph, 1, "InlineCodeNode")
                if (let codeNode: InlineCodeNode <- code) {
                    @Expect(codeNode.content, "代码")
                    @Expect(codeNode.fenceLength, 1)
                }
                AstTestKit.expectSpan(code, 10, 18, 6, 10)
            }
        )
    }

    @TestCase
    func blankLinesMakeTheListLoose() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "1. First item\n\n2. Second item\n",
            "<ol><li><p>First item</p></li><li>Second item</li></ol>"
        )
    }

    @TestCase
    func supportsFencedCodeBlocksInsideOrderedItems() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit(StandardMarkdownBundle(fencedCodeBlockConfig: FencedCodeBlockConfig(enableCodehl: false))) },
            """
1. 第一项
   ```javascript
   console.log("中文");
   ```
2. 第二项
""",
            "<ol><li>第一项<pre><code class=\"language-javascript\">console.log(&quot;中文&quot;);</code></pre></li><li>第二项</li></ol>"
        )
    }

    @TestCase
    func splitsOrderedListsWhenDelimiterChanges() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "1. dot\n2) paren\n",
            "<ol><li>dot</li></ol><ol start=\"2\"><li>paren</li></ol>"
        )
    }

    @TestCase
    func preservesSpecialCharactersInsideOrderedItems() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            """
1. Item with !@#$%^&*() symbols
2. Item with émojis 🚀
3. Item with 中文
""",
            "<ol><li>Item with !@#$%^&amp;*() symbols</li><li>Item with émojis 🚀</li><li>Item with 中文</li></ol>"
        )
    }
}
