package markit.tests.unit.plugins.gfm.block

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.core.nodes.{Node, TextNode}
import markit.plugins.gfm.block.table.{TableCellNode, TableConfig, TableNode, TableRowNode}
import markit.plugins.i18n.I18nPlugin
import markit.plugins.i18n.config.I18nConfig
import markit.plugins.standard.inline.inline_code.InlineCodeNode
import markit.tests.utils.{AstTestKit, ParseModeResult, ParseModeTestKit}

private func gfm(): Markit {
    return Markit(GFMBundle())
}

private func gfmThreeLine(): Markit {
    return Markit(GFMBundle(tableConfig: TableConfig(enableThreeLineTable: true)))
}

private func gfmThreeLineI18n(targetLanguage: String): Markit {
    return Markit(GFMBundle(tableConfig: TableConfig(enableThreeLineTable: true))).use(I18nPlugin(
        config: I18nConfig(defaultLanguage: "zh", targetLanguage: targetLanguage)
    ))
}

@Test
class TableTests {
    @TestCase
    func rendersBasicTableAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "| Header 1 | Header 2 |\n|----------|----------|\n| Cell 1   | Cell 2   |\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<table><thead><tr><th>Header 1</th><th>Header 2</th></tr></thead><tbody><tr><td>Cell 1</td><td>Cell 2</td></tr></tbody></table>")
                expectBasicTableAst(result.root)
            }
        )
    }

    @TestCase
    func rendersAlignmentClassesAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            gfm,
            "| Left | Center | Right |\n|:-----|:------:|------:|\n| L1   | C1     | R1    |\n",
            "<table><thead><tr><th class=\"text-left\">Left</th><th class=\"text-center\">Center</th><th class=\"text-right\">Right</th></tr></thead><tbody><tr><td class=\"text-left\">L1</td><td class=\"text-center\">C1</td><td class=\"text-right\">R1</td></tr></tbody></table>"
        )
    }

    @TestCase
    func supportsEscapedPipesInlineCodeAndChineseAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "| Syntax | 描述 |\n|--------|------|\n| `\\|` | 中文管道 |\n| Cell \\| 1 | émojis 🚀 |\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<table><thead><tr><th>Syntax</th><th>描述</th></tr></thead><tbody><tr><td><code>|</code></td><td>中文管道</td></tr><tr><td>Cell | 1</td><td>émojis 🚀</td></tr></tbody></table>")
                expectInlineCodeCell(result.root)
            }
        )
    }

    @TestCase
    func preservesSpecialCharacterCellsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "| Header !@# | Header $%^ |\n|------------|------------|\n| Cell &*()  | Cell +=[]  |\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<table><thead><tr><th>Header !@#</th><th>Header $%^</th></tr></thead><tbody><tr><td>Cell &amp;*()</td><td>Cell +=[]</td></tr></tbody></table>")
                @Expect(result.markdown, "| Header !@# | Header $%^ |\n| --- | --- |\n| Cell &*() | Cell +=[] |\n\n")
                let table = expectTableWithSpan(result.root, 2, 2, 0, 83, 0, 83)
                expectRowWithTextSpans(
                    AstTestKit.child(table, 0, "TableRowNode"),
                    true,
                    ["Header !@#", "Header $%^"],
                    0,
                    27,
                    0,
                    27,
                    [2, 15],
                    [12, 25],
                    [2, 15],
                    [12, 25]
                )
                expectRowWithTextSpans(
                    AstTestKit.child(table, 1, "TableRowNode"),
                    false,
                    ["Cell &*()", "Cell +=[]"],
                    56,
                    83,
                    56,
                    83,
                    [58, 71],
                    [67, 80],
                    [58, 71],
                    [67, 80]
                )
            }
        )
    }

    @TestCase
    func preservesUnicodeCellsAndByteRuneOffsetsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "| 中文标题 | English |\n|----------|----------|\n| 内容一   | Content 1 |\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<table><thead><tr><th>中文标题</th><th>English</th></tr></thead><tbody><tr><td>内容一</td><td>Content 1</td></tr></tbody></table>")
                @Expect(result.markdown, "| 中文标题 | English |\n| --- | --- |\n| 内容一 | Content 1 |\n\n")
                let table = expectTableWithSpan(result.root, 2, 2, 0, 78, 0, 64)
                expectRowWithTextSpans(
                    AstTestKit.child(table, 0, "TableRowNode"),
                    true,
                    ["中文标题", "English"],
                    0,
                    26,
                    0,
                    18,
                    [2, 17],
                    [14, 24],
                    [2, 9],
                    [6, 16]
                )
                expectRowWithTextSpans(
                    AstTestKit.child(table, 1, "TableRowNode"),
                    false,
                    ["内容一", "Content 1"],
                    51,
                    78,
                    43,
                    64,
                    [53, 67],
                    [62, 76],
                    [45, 53],
                    [48, 62]
                )
            }
        )
    }

    @TestCase
    func preservesEmptyCellsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "| Header 1 | Header 2 |\n|----------|----------|\n|          | Cell 2   |\n| Cell 3   |          |\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<table><thead><tr><th>Header 1</th><th>Header 2</th></tr></thead><tbody><tr><td></td><td>Cell 2</td></tr><tr><td>Cell 3</td><td></td></tr></tbody></table>")
                @Expect(result.markdown, "| Header 1 | Header 2 |\n| --- | --- |\n|  | Cell 2 |\n| Cell 3 |  |\n\n")
                expectEmptyCellsTableAst(result.root)
            }
        )
    }

    @TestCase
    func rendersMultipleRowsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "| Name | Age | City |\n|------|-----|------|\n| John | 25  | NYC  |\n| Jane | 30  | LA   |\n| Bob  | 35  | SF   |\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<table><thead><tr><th>Name</th><th>Age</th><th>City</th></tr></thead><tbody><tr><td>John</td><td>25</td><td>NYC</td></tr><tr><td>Jane</td><td>30</td><td>LA</td></tr><tr><td>Bob</td><td>35</td><td>SF</td></tr></tbody></table>")
                @Expect(result.markdown, "| Name | Age | City |\n| --- | --- | --- |\n| John | 25 | NYC |\n| Jane | 30 | LA |\n| Bob | 35 | SF |\n\n")
                expectMultipleRowsTableAst(result.root)
            }
        )
    }

    @TestCase
    func typstUsesFractionalColumnsForWrappingAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "| Name | Command |\n| --- | --- |\n| Render | `markit render --input example --output dist-example` |\n",
            { result: ParseModeResult =>
                @Expect(
                    result.typst,
                    "#align(center)[\n  #block(width: 100%)[\n    #table(\n      columns: (1fr, 1fr),\n      align: (auto, auto),\n      inset: (x: 10pt, y: 6pt),\n      fill: (x, y) => if true and y == 0 {\n        luma(245)\n      } else {\n        white\n      },\n      stroke: 0.6pt + luma(180),\n      table.header([*Name*], [*Command*]), [Render], [#markit-inline-code-table(\"markit render --input example --output dist-example\")\\u{2060}]\n    )\n  ]\n]\n\n"
                )
                expectTypstWrappingTableAst(result.root)
            }
        )
    }

    @TestCase
    func tableRequiresAlignmentRowAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "| A | B |\nplain paragraph\n",
            { result: ParseModeResult =>
                AstTestKit.expectNoNode(result.root, "TableNode")
                @Expect(result.html, "<p>| A | B |\nplain paragraph</p>")
            }
        )
    }

    @TestCase
    func rendersThreeLineTableWhenEnabledAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfmThreeLine,
            "---\n| A | B |\n| --- | --- |\n| 1 | 2 |\n---\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<table class=\"table-three-line\"><thead><tr><th>A</th><th>B</th></tr></thead><tbody><tr><td>1</td><td>2</td></tr></tbody></table>")
                @Expect(result.markdown, "---\n| A | B |\n| --- | --- |\n| 1 | 2 |\n---\n\n")
                @Expect(
                    result.typst,
                    "#align(center)[\n  #block(width: 100%, above: 1.45em, below: 1.45em)[\n    #table(\n      columns: (1fr, 1fr),\n      align: (auto, auto),\n      inset: (x: 10pt, y: 6pt),\n      fill: none,\n      stroke: (x, y) => if true and y == 0 {\n        (left: none, right: none, top: 1.4pt + luma(45), bottom: 0.7pt + luma(120))\n      } else if y == 1 {\n        (left: none, right: none, top: none, bottom: 1.4pt + luma(45))\n      } else {\n        none\n      },\n      [*A*], [*B*], [1], [2]\n    )\n  ]\n]\n\n"
                )
            }
        )
    }

    @TestCase
    func supportsPipesInsideInlineCodeSpansAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "| Operator | Description |\n|----------|-------------|\n| `|` | Bitwise OR |\n| `||` | Logic OR |\n| ``|>`` | Pipeline |\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<table><thead><tr><th>Operator</th><th>Description</th></tr></thead><tbody><tr><td><code>|</code></td><td>Bitwise OR</td></tr><tr><td><code>||</code></td><td>Logic OR</td></tr><tr><td><code>|&gt;</code></td><td>Pipeline</td></tr></tbody></table>")
                @Expect(result.markdown, "| Operator | Description |\n| --- | --- |\n| `|` | Bitwise OR |\n| `||` | Logic OR |\n| ``|>`` | Pipeline |\n\n")
                @Expect(result.typst.contains("[#markit-inline-code-table(\"|\")\\u{2060}]"), true)
                @Expect(result.typst.contains("[#markit-inline-code-table(\"||\")\\u{2060}]"), true)
                @Expect(result.typst.contains("[#markit-inline-code-table(\"|>\")\\u{2060}]"), true)
                let table = expectTableWithSpan(result.root, 2, 4, 0, 116, 0, 116)
                expectCellContent(AstTestKit.child(AstTestKit.child(table, 1, "TableRowNode"), 0, "TableCellNode"), "`|`")
                expectCellContent(AstTestKit.child(AstTestKit.child(table, 2, "TableRowNode"), 0, "TableCellNode"), "`||`")
                expectCellContent(AstTestKit.child(AstTestKit.child(table, 3, "TableRowNode"), 0, "TableCellNode"), "``|>``")
            }
        )
    }

    @TestCase
    func i18nKeepsThreeLineTableMarkersAcrossTargets() {
        let markdown = """
---
| :zh{名称}: :en{Name}: | :zh{值}: :en{Value}: |
| --- | --- |
| :zh{中文}: :en{English}: | :{shared}: |
---
"""

        ParseModeTestKit.assertAcrossModes(
            { => gfmThreeLineI18n("zh") },
            markdown,
            { result: ParseModeResult =>
                @Expect(result.html.contains("<table class=\"table-three-line\">"), true)
                @Expect(result.html.contains("名称"), true)
                @Expect(result.html.contains("English"), false)
                @Expect(result.typst.contains("fill: none"), true)
                @Expect(result.typst.contains("left: none, right: none"), true)
            }
        )
        ParseModeTestKit.assertAcrossModes(
            { => gfmThreeLineI18n("en") },
            markdown,
            { result: ParseModeResult =>
                @Expect(result.html.contains("<table class=\"table-three-line\">"), true)
                @Expect(result.html.contains("Name"), true)
                @Expect(result.html.contains("中文"), false)
                @Expect(result.typst.contains("fill: none"), true)
                @Expect(result.typst.contains("left: none, right: none"), true)
            }
        )
    }

    private func expectBasicTableAst(root: Node): Unit {
        AstTestKit.expectRoot(root, 1)
        let tableNode = AstTestKit.child(root, 0, "TableNode")
        if (let table: TableNode <- tableNode) {
            @Expect(table.columnCount, 2)
            @Expect(table.children.size, 2)
            expectRow(AstTestKit.child(table, 0, "TableRowNode"), true, ["Header 1", "Header 2"])
            expectRow(AstTestKit.child(table, 1, "TableRowNode"), false, ["Cell 1", "Cell 2"])
        }
    }

    private func expectInlineCodeCell(root: Node): Unit {
        AstTestKit.expectRoot(root, 1)
        let tableNode = AstTestKit.child(root, 0, "TableNode")
        if (let table: TableNode <- tableNode) {
            @Expect(table.columnCount, 2)
            @Expect(table.children.size, 3)
            AstTestKit.expectSpan(table, 0, 90, 0, 74)
            expectRow(AstTestKit.child(table, 0, "TableRowNode"), true, ["Syntax", "描述"])

            let codeRowNode = AstTestKit.child(table, 1, "TableRowNode")
            if (let codeRow: TableRowNode <- codeRowNode) {
                @Expect(codeRow.isHeader, false)
                @Expect(codeRow.children.size, 2)
                AstTestKit.expectSpan(codeRow, 38, 61, 34, 49)
                let codeCellNode = AstTestKit.child(codeRow, 0, "TableCellNode")
                if (let codeCell: TableCellNode <- codeCellNode) {
                    @Expect(codeCell.content, "`\\|`")
                    @Expect(codeCell.children.size, 1)
                    AstTestKit.expectSpan(codeCell, 38, 61, 34, 49)
                    let inlineCodeNode = AstTestKit.child(codeCell, 0, "InlineCodeNode")
                    if (let inlineCode: InlineCodeNode <- inlineCodeNode) {
                        @Expect(inlineCode.content, "|")
                        @Expect(inlineCode.fenceLength, 1)
                        AstTestKit.expectSpan(inlineCode, 40, 44, 36, 40)
                        AstTestKit.expectLeaf(inlineCode)
                    }
                }
                expectCellTextWithSpan(AstTestKit.child(codeRow, 1, "TableCellNode"), "中文管道", 47, 59, 43, 47)
            }

            let emojiRow = AstTestKit.child(table, 2, "TableRowNode")
            AstTestKit.expectSpan(emojiRow, 62, 90, 50, 74)
            if (let row: TableRowNode <- emojiRow) {
                @Expect(row.isHeader, false)
                @Expect(row.children.size, 2)
                expectCellTextWithSpan(AstTestKit.child(row, 0, "TableCellNode"), "Cell \\| 1", 64, 73, 52, 61)
                expectCellTextWithSpan(AstTestKit.child(row, 1, "TableCellNode"), "émojis 🚀", 76, 88, 64, 72)
            }
        }
    }

    private func expectEmptyCellsTableAst(root: Node): Unit {
        let table = expectTableWithSpan(root, 2, 3, 0, 95, 0, 95)
        expectRow(AstTestKit.child(table, 0, "TableRowNode"), true, ["Header 1", "Header 2"])

        let firstBodyRow = expectTableRowWithSpan(AstTestKit.child(table, 1, "TableRowNode"), false, 2, 48, 71, 48, 71)
        expectEmptyCell(AstTestKit.child(firstBodyRow, 0, "TableCellNode"), 48, 71, 48, 71)
        expectCellTextWithSpan(AstTestKit.child(firstBodyRow, 1, "TableCellNode"), "Cell 2", 61, 67, 61, 67)

        let secondBodyRow = expectTableRowWithSpan(AstTestKit.child(table, 2, "TableRowNode"), false, 2, 72, 95, 72, 95)
        expectCellTextWithSpan(AstTestKit.child(secondBodyRow, 0, "TableCellNode"), "Cell 3", 74, 80, 74, 80)
        expectEmptyCell(AstTestKit.child(secondBodyRow, 1, "TableCellNode"), 72, 95, 72, 95)
    }

    private func expectMultipleRowsTableAst(root: Node): Unit {
        let table = expectTableWithSpan(root, 3, 4, 0, 109, 0, 109)
        expectRow(AstTestKit.child(table, 0, "TableRowNode"), true, ["Name", "Age", "City"])
        expectExactBodyRow(AstTestKit.child(table, 1, "TableRowNode"), ["John", "25", "NYC"], 44, 65, [46, 53, 59], [50, 55, 62])
        expectExactBodyRow(AstTestKit.child(table, 2, "TableRowNode"), ["Jane", "30", "LA"], 66, 87, [68, 75, 81], [72, 77, 83])
        expectExactBodyRow(AstTestKit.child(table, 3, "TableRowNode"), ["Bob", "35", "SF"], 88, 109, [90, 97, 103], [93, 99, 105])
    }

    private func expectTypstWrappingTableAst(root: Node): Unit {
        let table = expectTableWithSpan(root, 2, 2, 0, 99, 0, 99)
        expectRow(AstTestKit.child(table, 0, "TableRowNode"), true, ["Name", "Command"])
        let body = expectTableRowWithSpan(AstTestKit.child(table, 1, "TableRowNode"), false, 2, 33, 99, 33, 99)
        expectCellTextWithSpan(AstTestKit.child(body, 0, "TableCellNode"), "Render", 35, 41, 35, 41)

        let commandCellNode = AstTestKit.child(body, 1, "TableCellNode")
        if (let cell: TableCellNode <- commandCellNode) {
            @Expect(cell.content, "`markit render --input example --output dist-example`")
            @Expect(cell.children.size, 1)
            AstTestKit.expectSpan(cell, 33, 99, 33, 99)
            let codeNode = AstTestKit.child(cell, 0, "InlineCodeNode")
            if (let code: InlineCodeNode <- codeNode) {
                @Expect(code.content, "markit render --input example --output dist-example")
                @Expect(code.fenceLength, 1)
                AstTestKit.expectSpan(code, 44, 97, 44, 97)
                AstTestKit.expectLeaf(code)
                return
            }
        }
        throw IllegalArgumentException("Expected command TableCellNode with InlineCodeNode child")
    }

    private func expectTableWithSpan(
        root: Node,
        columnCount: Int64,
        childCount: Int64,
        startByte: Int64,
        endByte: Int64,
        startRune: Int64,
        endRune: Int64
    ): TableNode {
        AstTestKit.expectRoot(root, 1)
        let tableNode = AstTestKit.child(root, 0, "TableNode")
        if (let table: TableNode <- tableNode) {
            @Expect(table.columnCount, columnCount)
            @Expect(table.children.size, childCount)
            AstTestKit.expectSpan(table, startByte, endByte, startRune, endRune)
            return table
        }
        throw IllegalArgumentException("Expected TableNode, actual ${tableNode.name}")
    }

    private func expectExactBodyRow(
        rowNode: Node,
        contents: Array<String>,
        startByte: Int64,
        endByte: Int64,
        cellStarts: Array<Int64>,
        cellEnds: Array<Int64>
    ): Unit {
        @Expect(contents.size, cellStarts.size)
        @Expect(contents.size, cellEnds.size)
        let row = expectTableRowWithSpan(rowNode, false, contents.size, startByte, endByte, startByte, endByte)
        for (i in 0..contents.size) {
            expectCellTextWithSpan(AstTestKit.child(row, i, "TableCellNode"), contents[i], cellStarts[i], cellEnds[i], cellStarts[i], cellEnds[i])
        }
    }

    private func expectTableRowWithSpan(
        rowNode: Node,
        isHeader: Bool,
        childCount: Int64,
        startByte: Int64,
        endByte: Int64,
        startRune: Int64,
        endRune: Int64
    ): TableRowNode {
        if (let row: TableRowNode <- rowNode) {
            @Expect(row.isHeader, isHeader)
            @Expect(row.children.size, childCount)
            AstTestKit.expectSpan(row, startByte, endByte, startRune, endRune)
            return row
        }
        throw IllegalArgumentException("Expected TableRowNode, actual ${rowNode.name}")
    }

    private func expectRowWithTextSpans(
        rowNode: Node,
        isHeader: Bool,
        contents: Array<String>,
        startByte: Int64,
        endByte: Int64,
        startRune: Int64,
        endRune: Int64,
        cellStartBytes: Array<Int64>,
        cellEndBytes: Array<Int64>,
        cellStartRunes: Array<Int64>,
        cellEndRunes: Array<Int64>
    ): Unit {
        @Expect(contents.size, cellStartBytes.size)
        @Expect(contents.size, cellEndBytes.size)
        @Expect(contents.size, cellStartRunes.size)
        @Expect(contents.size, cellEndRunes.size)
        let row = expectTableRowWithSpan(rowNode, isHeader, contents.size, startByte, endByte, startRune, endRune)
        for (i in 0..contents.size) {
            expectCellTextWithSpan(
                AstTestKit.child(row, i, "TableCellNode"),
                contents[i],
                cellStartBytes[i],
                cellEndBytes[i],
                cellStartRunes[i],
                cellEndRunes[i]
            )
        }
    }

    private func expectEmptyCell(
        cellNode: Node,
        startByte: Int64,
        endByte: Int64,
        startRune: Int64,
        endRune: Int64
    ): Unit {
        if (let cell: TableCellNode <- cellNode) {
            @Expect(cell.content, "")
            @Expect(cell.children.size, 0)
            AstTestKit.expectSpan(cell, startByte, endByte, startRune, endRune)
            return
        }
        throw IllegalArgumentException("Expected empty TableCellNode, actual ${cellNode.name}")
    }

    private func expectRow(rowNode: Node, isHeader: Bool, contents: Array<String>): Unit {
        if (let row: TableRowNode <- rowNode) {
            @Expect(row.isHeader, isHeader)
            @Expect(row.children.size, contents.size)
            for (i in 0..contents.size) {
                expectCellText(AstTestKit.child(row, i, "TableCellNode"), contents[i])
            }
        }
    }

    private func expectCellText(cellNode: Node, content: String): Unit {
        if (let cell: TableCellNode <- cellNode) {
            @Expect(cell.content, content)
            @Expect(cell.children.size, 1)
            let textNode = AstTestKit.child(cell, 0, "TextNode")
            if (let text: TextNode <- textNode) {
                @Expect(text.content, content.replace("\\|", "|"))
            }
        }
    }

    private func expectCellContent(cellNode: Node, content: String): Unit {
        if (let cell: TableCellNode <- cellNode) {
            @Expect(cell.content, content)
            return
        }
        throw IllegalArgumentException("Expected TableCellNode, actual ${cellNode.name}")
    }

    private func expectCellTextWithSpan(
        cellNode: Node,
        content: String,
        startByte: Int64,
        endByte: Int64,
        startRune: Int64,
        endRune: Int64
    ): Unit {
        if (let cell: TableCellNode <- cellNode) {
            @Expect(cell.content, content)
            @Expect(cell.children.size, 1)
            let textNode = AstTestKit.child(cell, 0, "TextNode")
            if (let text: TextNode <- textNode) {
                @Expect(text.content, content.replace("\\|", "|"))
                AstTestKit.expectSpan(text, startByte, endByte, startRune, endRune)
                AstTestKit.expectLeaf(text)
                return
            }
        }
        throw IllegalArgumentException("Expected TableCellNode with TextNode child, actual ${cellNode.name}")
    }
}
