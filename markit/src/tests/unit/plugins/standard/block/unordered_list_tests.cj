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
class UnorderedListTests {
    @TestCase
    func keepsMixedBulletMarkersInSameList() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "- dash\n* star\n+ plus\n",
            "<ul><li>dash</li><li>star</li><li>plus</li></ul>"
        )
    }

    @TestCase
    func supportsIndentedUnorderedLists() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "  - Indented first item\n  - Indented second item\n",
            "<ul><li>Indented first item</li><li>Indented second item</li></ul>"
        )
    }

    @TestCase
    func rendersNestedUnorderedListInsideParentItem() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            """
- 外层
  - 内层一
  - 内层二
- 结束
""",
            "<ul><li>外层<ul><li>内层一</li><li>内层二</li></ul></li><li>结束</li></ul>"
        )
    }

    @TestCase
    func rendersFencedCodeBlockInsideListItem() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit(StandardMarkdownBundle(fencedCodeBlockConfig: FencedCodeBlockConfig(enableCodehl: false))) },
            """
- 第一项
  ```javascript
  console.log("中文");
  ```
- 第二项
""",
            "<ul><li>第一项<pre><code class=\"language-javascript\">console.log(&quot;中文&quot;);</code></pre></li><li>第二项</li></ul>"
        )
    }

    @TestCase
    func supportsEmptyItems() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "- \n- Second item\n- \n",
            "<ul><li></li><li>Second item</li><li></li></ul>"
        )
    }

    @TestCase
    func parsesInlineCodeInsideTightUnorderedListItemsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            { => Markit() },
            "- 调用 `代码`\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<ul><li>调用 <code>代码</code></li></ul>")
                @Expect(result.markdown, "- 调用 `代码`\n\n")
                @Expect(result.typst, "- 调用 #markit-inline-code(\"代码\")\\u{2060}\n\n")

                AstTestKit.expectRoot(result.root, 1)
                let list = AstTestKit.child(result.root, 0, "UnorderedListNode")
                AstTestKit.expectSpan(list, 0, 17, 0, 9)
                let item = AstTestKit.child(list, 0, "UnorderedListItemNode")
                AstTestKit.expectSpan(item, 0, 17, 0, 9)
                let paragraph = AstTestKit.child(item, 0, "ParagraphNode")
                AstTestKit.expectSpan(paragraph, 2, 17, 2, 9)
                let text = AstTestKit.child(paragraph, 0, "TextNode")
                if (let textNode: TextNode <- text) {
                    @Expect(textNode.content, "调用 ")
                }
                AstTestKit.expectSpan(text, 2, 9, 2, 5)
                let code = AstTestKit.child(paragraph, 1, "InlineCodeNode")
                if (let codeNode: InlineCodeNode <- code) {
                    @Expect(codeNode.content, "代码")
                    @Expect(codeNode.fenceLength, 1)
                }
                AstTestKit.expectSpan(code, 9, 17, 5, 9)
            }
        )
    }

    @TestCase
    func looseListWrapsParagraphsInsideItems() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "- 第一段\n\n  第二段\n- 第二项\n",
            "<ul><li><p>第一段</p><p>第二段</p></li><li>第二项</li></ul>"
        )
    }

    @TestCase
    func preservesDeepChineseNesting() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            """
- 一级
  - 二级
    - 三级
      - 四级
""",
            "<ul><li>一级<ul><li>二级<ul><li>三级<ul><li>四级</li></ul></li></ul></li></ul></li></ul>"
        )
    }
}
