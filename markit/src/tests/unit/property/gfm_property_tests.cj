package markit.tests.unit.property

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.core.nodes.{Node, TextNode}
import markit.plugins.gfm.block.alphabetic_list.{AlphabeticListItemNode, AlphabeticListNode}
import markit.plugins.gfm.block.math_block.{MathBlockConfig, MathBlockNode}
import markit.plugins.gfm.block.table.{TableCellNode, TableConfig, TableNode, TableRowNode}
import markit.plugins.gfm.block.task_list.{TaskListItemNode, TaskListNode}
import markit.plugins.gfm.inline.autolink.AutolinkNode
import markit.plugins.gfm.inline.footnote.{FootnoteDefinitionNode, FootnoteReferenceNode}
import markit.plugins.gfm.inline.inline_math.{InlineMathConfig, InlineMathNode}
import markit.plugins.gfm.inline.strikethrough.StrikethroughNode
import markit.tests.utils.{AstTestKit, ParseModeResult, ParseModeTestKit}

private func gfm(): Markit {
    return Markit(GFMBundle(
        mathBlockConfig: MathBlockConfig(enableHtmlMathtex: false),
        inlineMathConfig: InlineMathConfig(enableHtmlMathtex: false)
    ))
}

private func gfmThreeLineTable(): Markit {
    return Markit(GFMBundle(
        tableConfig: TableConfig(enableThreeLineTable: true),
        mathBlockConfig: MathBlockConfig(enableHtmlMathtex: false),
        inlineMathConfig: InlineMathConfig(enableHtmlMathtex: false)
    ))
}

@Test
class GFMPropertyTests {
    @TestCase
    func tableStructureAlignmentAndInlineChildrenStayStableAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "| Left | Center | Right |\n|:-----|:------:|------:|\n| `code` | 中文 | R1 |\n| Cell \\| 2 | C2 | R2 |\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<table><thead><tr><th class=\"text-left\">Left</th><th class=\"text-center\">Center</th><th class=\"text-right\">Right</th></tr></thead><tbody><tr><td class=\"text-left\"><code>code</code></td><td class=\"text-center\">中文</td><td class=\"text-right\">R1</td></tr><tr><td class=\"text-left\">Cell | 2</td><td class=\"text-center\">C2</td><td class=\"text-right\">R2</td></tr></tbody></table>")
                AstTestKit.expectNodeCount(result.root, "TableNode", 1)
                AstTestKit.expectNodeCount(result.root, "InlineCodeNode", 1)

                let tableNode = AstTestKit.child(result.root, 0, "TableNode")
                if (let table: TableNode <- tableNode) {
                    @Expect(table.columnCount, 3)
                    @Expect(table.alignments[0].toString(), "Left")
                    @Expect(table.alignments[1].toString(), "Center")
                    @Expect(table.alignments[2].toString(), "Right")
                    @Expect(table.children.size, 3)
                    expectTableRow(AstTestKit.child(table, 0, "TableRowNode"), true, ["Left", "Center", "Right"])
                    expectTableRow(AstTestKit.child(table, 1, "TableRowNode"), false, ["`code`", "中文", "R1"])
                    expectTableRow(AstTestKit.child(table, 2, "TableRowNode"), false, ["Cell \\| 2", "C2", "R2"])
                }
            }
        )
    }

    @TestCase
    func malformedTableFallsBackToParagraphButThreeLineCanBeEnabledAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "| A | B |\nplain paragraph\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>| A | B |\nplain paragraph</p>")
                AstTestKit.expectNoNode(result.root, "TableNode")
            }
        )

        ParseModeTestKit.assertAcrossModes(
            gfmThreeLineTable,
            "---\n| A | B |\n| --- | --- |\n| 1 | 2 |\n---\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<table class=\"table-three-line\"><thead><tr><th>A</th><th>B</th></tr></thead><tbody><tr><td>1</td><td>2</td></tr></tbody></table>")
                AstTestKit.expectNodeCount(result.root, "TableNode", 1)
                AstTestKit.expectNodeCount(result.root, "DividerNode", 2)
            }
        )
    }

    @TestCase
    func taskListItemsPreserveMarkersCheckedStateAndInlineChildrenAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "- [ ] 中文任务\n* [x] **bold** and `code`\n+ [X] symbols !@#\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<ul class=\"task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" /> 中文任务</li><li class=\"task-list-item\"><input type=\"checkbox\" checked=\"checked\" /> <strong>bold</strong> and <code>code</code></li><li class=\"task-list-item\"><input type=\"checkbox\" checked=\"checked\" /> symbols !@#</li></ul>")
                let listNode = AstTestKit.child(result.root, 0, "TaskListNode")
                if (let list: TaskListNode <- listNode) {
                    @Expect(list.children.size, 3)
                    expectTaskItem(AstTestKit.child(list, 0, "TaskListItemNode"), "-", false, "中文任务")
                    expectTaskItem(AstTestKit.child(list, 1, "TaskListItemNode"), "*", true, "**bold** and `code`")
                    expectTaskItem(AstTestKit.child(list, 2, "TaskListItemNode"), "+", true, "symbols !@#")
                }
                AstTestKit.expectNodeCount(result.root, "BoldNode", 1)
                AstTestKit.expectNodeCount(result.root, "InlineCodeNode", 1)
            }
        )
    }

    @TestCase
    func alphabeticListsPreserveCaseLetterDelimiterAndDiscontinuousSplitsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "A) 中文第一项\nB) émojis 🚀\n\nc. Third\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<ol class=\"alphabetic-list uppercase\"><li>中文第一项</li><li>émojis 🚀</li></ol><ol class=\"alphabetic-list\"><li>Third</li></ol>")
                AstTestKit.expectRoot(result.root, 2)
                expectAlphabeticList(AstTestKit.child(result.root, 0, "AlphabeticListNode"), "A", ")", true, ["中文第一项", "émojis 🚀"], ["A", "B"])
                expectAlphabeticList(AstTestKit.child(result.root, 1, "AlphabeticListNode"), "c", ".", false, ["Third"], ["c"])
            }
        )
    }

    @TestCase
    func mathBlocksPreserveContentAndDoNotParseInlineMarkdownAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "$$\nπ ≈ 3.14159\n**bold** _italic_ `code`\n$$\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<div class=\"math-block\">π ≈ 3.14159\n**bold** _italic_ `code`</div>")
                if (let math: MathBlockNode <- AstTestKit.child(result.root, 0, "MathBlockNode")) {
                    @Expect(math.content, "π ≈ 3.14159\n**bold** _italic_ `code`")
                    @Expect(math.indentLevel, 0)
                }
                AstTestKit.expectNoNode(result.root, "BoldNode")
                AstTestKit.expectNoNode(result.root, "ItalicNode")
                AstTestKit.expectNoNode(result.root, "InlineCodeNode")
            }
        )
    }

    @TestCase
    func inlineMathAndStrikethroughPreserveContentAndBlockMarkdownInsideMathAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "The formula $**bold** _italic_ `code`$ and ~~中文删除线~~.\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>The formula <span class=\"math inline\">**bold** _italic_ `code`</span> and <del>中文删除线</del>.</p>")
                AstTestKit.expectNodeCount(result.root, "InlineMathNode", 1)
                AstTestKit.expectNodeCount(result.root, "StrikethroughNode", 1)
                AstTestKit.expectNoNode(result.root, "BoldNode")
                AstTestKit.expectNoNode(result.root, "InlineCodeNode")

                let paragraph = AstTestKit.child(result.root, 0, "ParagraphNode")
                if (let math: InlineMathNode <- AstTestKit.child(paragraph, 1, "InlineMathNode")) {
                    @Expect(math.content, "**bold** _italic_ `code`")
                }
                if (let strike: StrikethroughNode <- AstTestKit.child(paragraph, 3, "StrikethroughNode")) {
                    @Expect(strike.content, "中文删除线")
                }
            }
        )
    }

    @TestCase
    func bareAutolinksExcludeTrailingPunctuationAndPreserveFieldsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "Visit https://example.com. Email user+tag@example.com!\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>Visit <a href=\"https://example.com\">https://example.com</a>. Email <a href=\"mailto:user+tag@example.com\">user+tag@example.com</a>!</p>")
                expectAutolinks(
                    result.root,
                    ["Url", "Email"],
                    ["https://example.com", "mailto:user+tag@example.com"],
                    ["https://example.com", "user+tag@example.com"]
                )
            }
        )
    }

    @TestCase
    func footnotesResolveForwardRepeatedAndMultilineDefinitionsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "First [^note] and second [^note].\n\n[^note]: First **bold** line\n    Second *italic* line\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>First <a id=\"fnref:note\" href=\"#fn:note\" class=\"footnote-ref\">1</a> and second <a id=\"fnref:note\" href=\"#fn:note\" class=\"footnote-ref\">1</a>.</p><div id=\"fn:note\" class=\"footnote-definition\">First <strong>bold</strong> line\nSecond <em>italic</em> line</div>")
                AstTestKit.expectNodeCount(result.root, "FootnoteReferenceNode", 2)
                AstTestKit.expectNodeCount(result.root, "FootnoteDefinitionNode", 1)
                if (let definition: FootnoteDefinitionNode <- AstTestKit.child(result.root, 1, "FootnoteDefinitionNode")) {
                    @Expect(definition.footnoteId, "note")
                    @Expect(definition.footnoteNumber, 1)
                    @Expect(definition.content, "First **bold** line\nSecond *italic* line")
                }
                expectFootnoteReferences(result.root, "note", 1, 2)
            }
        )
    }

    private func expectTableRow(rowNode: Node, isHeader: Bool, contents: Array<String>): Unit {
        if (let row: TableRowNode <- rowNode) {
            @Expect(row.isHeader, isHeader)
            @Expect(row.children.size, contents.size)
            for (i in 0..contents.size) {
                let cellNode = AstTestKit.child(row, i, "TableCellNode")
                if (let cell: TableCellNode <- cellNode) {
                    @Expect(cell.content, contents[i])
                    @Expect(cell.isHeader, isHeader)
                }
            }
        }
    }

    private func expectTaskItem(node: Node, marker: String, checked: Bool, content: String): Unit {
        if (let item: TaskListItemNode <- node) {
            @Expect(String.fromUtf8([item.marker]), marker)
            @Expect(item.checked, checked)
            @Expect(item.content, content)
        }
    }

    private func expectAlphabeticList(
        node: Node,
        startLetter: String,
        delimiter: String,
        upperCase: Bool,
        contents: Array<String>,
        letters: Array<String>
    ): Unit {
        if (let list: AlphabeticListNode <- node) {
            @Expect(String.fromUtf8([list.startLetter]), startLetter)
            @Expect(String.fromUtf8([list.delimiter]), delimiter)
            @Expect(list.isUpperCase, upperCase)
            @Expect(list.children.size, contents.size)
            @Expect(letters.size, contents.size)
            for (i in 0..contents.size) {
                let itemNode = AstTestKit.child(list, i, "AlphabeticListItemNode")
                if (let item: AlphabeticListItemNode <- itemNode) {
                    @Expect(item.content, contents[i])
                    @Expect(String.fromUtf8([item.letter]), letters[i])
                    @Expect(String.fromUtf8([item.delimiter]), delimiter)
                    expectItemText(item, contents[i])
                }
            }
        }
    }

    private func expectItemText(item: Node, content: String): Unit {
        let firstChild = item.children[0]
        if (let text: TextNode <- firstChild) {
            @Expect(text.content, content)
            return
        }

        let paragraph = AstTestKit.child(item, 0, "ParagraphNode")
        if (let text: TextNode <- AstTestKit.child(paragraph, 0, "TextNode")) {
            @Expect(text.content, content)
        }
    }

    private func expectAutolinks(root: Node, types: Array<String>, urls: Array<String>, displayTexts: Array<String>): Unit {
        @Expect(types.size, urls.size)
        @Expect(types.size, displayTexts.size)
        AstTestKit.expectNodeCount(root, "AutolinkNode", types.size)

        let paragraph = AstTestKit.child(root, 0, "ParagraphNode")
        var index: Int64 = 0
        for (child in paragraph.children) {
            if (let link: AutolinkNode <- child) {
                @Expect(link.autolinkTypeName(), types[index])
                @Expect(link.url, urls[index])
                @Expect(link.displayText, displayTexts[index])
                index += 1
            }
        }
        @Expect(index, types.size)
    }

    private func expectFootnoteReferences(root: Node, footnoteId: String, footnoteNumber: Int64, count: Int64): Unit {
        var found: Int64 = 0
        for (child in root.children) {
            for (grandChild in child.children) {
                if (let reference: FootnoteReferenceNode <- grandChild) {
                    @Expect(reference.footnoteId, footnoteId)
                    @Expect(reference.footnoteNumber, footnoteNumber)
                    found += 1
                }
            }
        }
        @Expect(found, count)
    }
}
