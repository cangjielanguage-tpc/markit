package markit.tests.unit.property

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.{GFMBundle, StandardMarkdownBundle}
import markit.core.nodes.Node
import markit.plugins.i18n.I18nPlugin
import markit.plugins.i18n.config.I18nConfig
import markit.plugins.standard.block.list.{OrderedListNode, UnorderedListNode}
import markit.tests.utils.{AstTestKit, ParseModeResult, ParseModeTestKit}

private func standardNesting(): Markit {
    return Markit(StandardMarkdownBundle())
}

private func gfmNesting(): Markit {
    return Markit(GFMBundle())
}

private func i18nNestingEn(): Markit {
    return Markit(GFMBundle()).use(I18nPlugin(
        config: I18nConfig(defaultLanguage: "zh", targetLanguage: "en")
    ))
}

@Test
class UniversalEscapeNestingPropertyTests {
    @TestCase
    func escapedBlockStartersStayParagraphTextAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            standardNesting,
            "\\# not heading\n\\- not list\n\\> not quote\n\\``` not fence\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p># not heading\n- not list\n&gt; not quote\n``` not fence</p>")
                AstTestKit.expectRoot(result.root, 1)
                AstTestKit.expectNoNode(result.root, "Heading1Node")
                AstTestKit.expectNoNode(result.root, "UnorderedListNode")
                AstTestKit.expectNoNode(result.root, "BlockquoteNode")
                AstTestKit.expectNoNode(result.root, "FencedCodeBlockNode")
                AstTestKit.expectSpan(AstTestKit.child(result.root, 0, "ParagraphNode"), 0, 54, 0, 54)
            }
        )
    }

    @TestCase
    func deepMixedListAndBlockquoteNestingKeepsParentSpansAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            standardNesting,
            """
- outer
  1. ordered
     > quote
     > - inner
- tail
""",
            { result: ParseModeResult =>
                @Expect(result.html, "<ul><li>outer<ol><li>ordered<blockquote><p>quote</p><ul><li>inner</li></ul></blockquote></li></ol></li><li>tail</li></ul>")
                let outer = AstTestKit.child(result.root, 0, "UnorderedListNode")
                if (let list: UnorderedListNode <- outer) {
                    @Expect(list.children.size, 2)
                    let first = AstTestKit.child(list, 0, "UnorderedListItemNode")
                    let orderedNode = AstTestKit.child(first, 1, "OrderedListNode")
                    if (let ordered: OrderedListNode <- orderedNode) {
                        @Expect(ordered.children.size, 1)
                    }
                    let quoteNode = AstTestKit.child(AstTestKit.child(orderedNode, 0, "OrderedListItemNode"), 1, "BlockquoteNode")
                    AstTestKit.child(quoteNode, 0, "ParagraphNode")
                    AstTestKit.child(quoteNode, 1, "UnorderedListNode")
                }
                validateParentLinksAndDocumentRanges(result.root, result.root.sourceSpan.endByte)
            }
        )
    }

    @TestCase
    func i18nTableAndTaskListNestingStayStableAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            i18nNestingEn,
            """
:::en
- [x] done

| A | B |
| - | - |
| 中 | `code` |
:::
""",
            { result: ParseModeResult =>
                @Expect(result.html, "<ul class=\"task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" checked=\"checked\" /> done</li></ul><table><thead><tr><th>A</th><th>B</th></tr></thead><tbody><tr><td>中</td><td><code>code</code></td></tr></tbody></table>")
                let block = AstTestKit.child(result.root, 0, "I18nBlockNode")
                AstTestKit.child(block, 0, "TaskListNode")
                AstTestKit.child(block, 1, "TableNode")
                AstTestKit.expectSpan(block, 0, 58, 0, 56)
            }
        )
    }

    private func validateParentLinksAndDocumentRanges(node: Node, maxByte: Int64): Unit {
        for (child in node.children) {
            if (let Some(parent) <- child.parent) {
                @Expect(parent.name, node.name)
                @Expect(child.sourceSpan.startByte >= 0, true)
                @Expect(child.sourceSpan.endByte <= maxByte, true)
                @Expect(child.sourceSpan.endByte >= child.sourceSpan.startByte, true)
            } else {
                throw IllegalArgumentException("${child.name} has no parent")
            }
            validateParentLinksAndDocumentRanges(child, maxByte)
        }
    }
}
