package markit.tests.unit.plugins.gfm.block

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.core.nodes.{Node, TextNode}
import markit.plugins.gfm.block.alphabetic_list.{AlphabeticListItemNode, AlphabeticListNode}
import markit.plugins.standard.block.fenced_code_block.FencedCodeBlockConfig
import markit.tests.utils.{AstTestKit, ParseModeResult, ParseModeTestKit}

private func gfm(): Markit {
    return Markit(GFMBundle(fencedCodeBlockConfig: FencedCodeBlockConfig(enableCodehl: false)))
}

@Test
class AlphabeticListTests {
    @TestCase
    func rendersLowercaseAlphabeticListAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "a. First item\nb. Second item\nc. Third item\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<ol class=\"alphabetic-list\"><li>First item</li><li>Second item</li><li>Third item</li></ol>")
                expectAlphabeticList(result.root, ["First item", "Second item", "Third item"], ["a", "b", "c"], startLetter: "a")
            }
        )
    }

    @TestCase
    func rendersUppercaseParenListAndChineseAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            gfm,
            "A) 中文第一项\nB) émojis 🚀\n",
            "<ol class=\"alphabetic-list uppercase\"><li>中文第一项</li><li>émojis 🚀</li></ol>"
        )
    }

    @TestCase
    func rejectsInvalidDelimiterAndNoSpaceAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "a.NoSpace\nb: invalid delimiter\n",
            { result: ParseModeResult =>
                AstTestKit.expectNoNode(result.root, "AlphabeticListNode")
                @Expect(result.html, "<p>a.NoSpace\nb: invalid delimiter</p>")
            }
        )
    }

    @TestCase
    func stopsWhenLettersAreDiscontinuousAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "a. First item\nc. Third item\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<ol class=\"alphabetic-list\"><li>First item</li></ol><ol class=\"alphabetic-list\"><li>Third item</li></ol>")
                AstTestKit.expectRoot(result.root, 2)
                expectAlphabeticListAt(result.root, 0, ["First item"], ["a"], startLetter: "a")
                expectAlphabeticListAt(result.root, 1, ["Third item"], ["c"], startLetter: "c")
            }
        )
    }

    @TestCase
    func keepsFencedCodeBlockInsideAlphabeticItemAcrossModes() {
        let markdown = """
a. First item
   ```javascript
   console.log("hello");
   ```

b. Second item
"""

        ParseModeTestKit.assertHtmlAcrossModes(
            gfm,
            markdown,
            "<ol class=\"alphabetic-list\"><li>First item<pre><code class=\"language-javascript\">console.log(&quot;hello&quot;);</code></pre></li><li>Second item</li></ol>"
        )
    }

    @TestCase
    func keepsFourSpaceIndentedFencedCodeBlockInsideAlphabeticItemAcrossModes() {
        let markdown = """
a. First item
    ```javascript
    console.log("hello");
    ```

b. Second item
"""

        ParseModeTestKit.assertHtmlAcrossModes(
            gfm,
            markdown,
            "<ol class=\"alphabetic-list\"><li>First item<pre><code class=\"language-javascript\">console.log(&quot;hello&quot;);</code></pre></li><li>Second item</li></ol>"
        )
    }

    private func expectAlphabeticList(root: Node, items: Array<String>, letters: Array<String>, startLetter!: String): Unit {
        AstTestKit.expectRoot(root, 1)
        expectAlphabeticListAt(root, 0, items, letters, startLetter: startLetter)
    }

    private func expectAlphabeticListAt(root: Node, index: Int64, items: Array<String>, letters: Array<String>, startLetter!: String): Unit {
        let listNode = AstTestKit.child(root, index, "AlphabeticListNode")
        if (let list: AlphabeticListNode <- listNode) {
            @Expect(list.tight, true)
            @Expect(String.fromUtf8([list.startLetter]), startLetter)
            @Expect(list.children.size, items.size)
            @Expect(letters.size, items.size)
            for (i in 0..items.size) {
                let itemNode = AstTestKit.child(list, i, "AlphabeticListItemNode")
                if (let item: AlphabeticListItemNode <- itemNode) {
                    @Expect(item.content, items[i])
                    @Expect(item.indentLevel, 0)
                    @Expect(String.fromUtf8([item.letter]), letters[i])
                    @Expect(item.children.size, 1)
                    let textNode = AstTestKit.child(item, 0, "TextNode")
                    if (let text: TextNode <- textNode) {
                        @Expect(text.content, items[i])
                    }
                }
            }
        }
    }
}
