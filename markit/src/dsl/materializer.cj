package markit.dsl

import std.collection.ArrayList
import markit.core.nodes.{Node, TextNode}
import markit.plugins.commonmark.block.html_block.HTMLBlockNode
import markit.plugins.commonmark.inline.commonmark_autolink.CommonMarkAutolinkNode
import markit.plugins.commonmark.inline.entity_reference.EntityReferenceNode
import markit.plugins.commonmark.inline.html_inline.HTMLInlineNode
import markit.plugins.gfm.block.alphabetic_list.{AlphabeticListItemNode, AlphabeticListNode}
import markit.plugins.gfm.block.math_block.MathBlockNode
import markit.plugins.gfm.block.table.{TableAlignment, TableCellNode, TableNode, TableRowNode}
import markit.plugins.gfm.block.task_list.{TaskListItemNode, TaskListNode}
import markit.plugins.gfm.inline.autolink.AutolinkNode
import markit.plugins.gfm.inline.footnote.{FootnoteDefinitionNode, FootnoteReferenceNode}
import markit.plugins.gfm.inline.inline_math.InlineMathNode
import markit.plugins.gfm.inline.strikethrough.StrikethroughNode
import markit.plugins.i18n.nodes.{I18nBlockNode, I18nInlineNode, UniversalBlockNode, UniversalInlineNode}
import markit.plugins.standard.block.blockquote.BlockquoteNode
import markit.plugins.standard.block.divider.DividerNode
import markit.plugins.standard.block.fenced_code_block.{FencedCodeBlockFileGroup, FencedCodeBlockNode}
import markit.plugins.standard.block.heading.HeadingNode
import markit.plugins.standard.block.list.{OrderedListItemNode, OrderedListNode, UnorderedListItemNode, UnorderedListNode}
import markit.plugins.standard.block.paragraph.ParagraphNode
import markit.plugins.standard.inline.bold.BoldNode
import markit.plugins.standard.inline.hard_break.HardBreakNode
import markit.plugins.standard.inline.image.ImageNode
import markit.plugins.standard.inline.inline_code.InlineCodeNode
import markit.plugins.standard.inline.italic.ItalicNode
import markit.plugins.standard.inline.link.LinkNode
import markit.plugins.standard.inline.soft_break.SoftBreakNode
import markit.plugins.toc.{TocItem, TocNode}

public class DslMaterializer {
    public static func block(ctx: DslBuildContext, spec: BlockSpec): Node {
        match (spec) {
            case BlockHeading(level, inlines, options) => return heading(ctx, level, inlines, options)
            case BlockParagraph(inlines) => return paragraph(ctx, inlines)
            case Blockquote(blocks) => return blockquote(ctx, blocks)
            case BlockDivider(marker, markerCount) =>
                return DividerNode(ctx.allocateNodeId(), ctx.allocateSpan(repeatByte(marker, markerCount)), marker: marker, markerCount: markerCount)
            case BlockCode(language, content, options) =>
                return FencedCodeBlockNode(
                    ctx.allocateNodeId(),
                    ctx.allocateSpan(content),
                    content,
                    language,
                    options.fenceMarker,
                    options.fenceLength,
                    highlightLines: options.highlightLines,
                    i18nLines: options.i18nLines,
                    fileGroups: ArrayList<FencedCodeBlockFileGroup>()
                )
            case BlockMath(content, indentLevel) =>
                return MathBlockNode(ctx.allocateNodeId(), ctx.allocateSpan(content), content, indentLevel)
            case BlockUnorderedList(items, options) => return unorderedList(ctx, items, options)
            case BlockOrderedList(startNumber, delimiter, items, options) =>
                return orderedList(ctx, startNumber, delimiter, items, options)
            case BlockAlphabeticList(startLetter, isUpperCase, delimiter, items, options) =>
                return alphabeticList(ctx, startLetter, isUpperCase, delimiter, items, options)
            case BlockTaskList(items, options) => return taskList(ctx, items, options)
            case BlockTable(header, rows, alignments) => return table(ctx, header, rows, alignments)
            case BlockFootnoteDef(id, inlines) => return footnoteDefinition(ctx, id, inlines)
            case BlockHtml(raw, blockType, tagName) =>
                return HTMLBlockNode(ctx.allocateNodeId(), ctx.allocateSpan(raw), raw, blockType, tagName: tagName)
            case BlockI18n(languageId, blocks) => return i18nBlock(ctx, languageId, blocks)
            case BlockUniversal(blocks) => return universalBlock(ctx, blocks)
            case BlockToc(title, items) => return toc(title, items)
            case BlockNode(node) => return node
        }
    }

    public static func inline(ctx: DslBuildContext, spec: InlineSpec): Node {
        match (spec) {
            case InlineText(content) => return TextNode(ctx.allocateNodeId(), ctx.allocateSpan(content), content)
            case InlineStrong(children) => return inlineContainer(
                ctx,
                BoldNode(ctx.allocateNodeId(), ctx.emptySpan(), inlineText(children), "**"),
                children
            )
            case InlineEmphasis(children) => return inlineContainer(
                ctx,
                ItalicNode(ctx.allocateNodeId(), ctx.emptySpan(), inlineText(children), "*"),
                children
            )
            case InlineCodeText(content, fenceLength) =>
                return InlineCodeNode(ctx.allocateNodeId(), ctx.allocateSpan(content), content, fenceLength)
            case InlineLink(url, title, children) => return inlineContainer(
                ctx,
                LinkNode(ctx.allocateNodeId(), ctx.emptySpan(), inlineText(children), url, title),
                children
            )
            case InlineImage(alt, src, title) =>
                return ImageNode(ctx.allocateNodeId(), ctx.allocateSpan(alt), alt, src, title)
            case InlineSoftBreak => return SoftBreakNode(ctx.allocateNodeId(), ctx.allocateSpan("\n"))
            case InlineHardBreak(breakType) => return HardBreakNode(ctx.allocateNodeId(), ctx.allocateSpan("  \n"), breakType)
            case InlineStrike(children) => return inlineContainer(
                ctx,
                StrikethroughNode(ctx.allocateNodeId(), ctx.emptySpan(), inlineText(children)),
                children
            )
            case InlineMathText(content) =>
                return InlineMathNode(ctx.allocateNodeId(), ctx.allocateSpan(content), content, "$${content}$")
            case InlineFootnoteRef(id) =>
                let raw = "[^${id}]"
                return FootnoteReferenceNode(ctx.allocateNodeId(), ctx.allocateSpan(raw), id, ctx.footnoteNumber(id), raw)
            case InlineAutolink(autolinkType, url, displayText, raw) =>
                return AutolinkNode(ctx.allocateNodeId(), ctx.allocateSpan(raw), autolinkType, url, displayText, raw)
            case InlineCommonMarkAutolink(autolinkType, url, displayText, raw) =>
                return CommonMarkAutolinkNode(ctx.allocateNodeId(), ctx.allocateSpan(raw), autolinkType, url, displayText, raw)
            case InlineHtml(tagName, tagType, htmlContent) =>
                return HTMLInlineNode(ctx.allocateNodeId(), ctx.allocateSpan(htmlContent), tagName, tagType, htmlContent)
            case InlineEntity(entityType, entityValue, entityReference) =>
                return EntityReferenceNode(ctx.allocateNodeId(), ctx.allocateSpan(entityReference), entityType, entityValue, entityReference)
            case InlineI18n(languageId, children) => return inlineContainer(
                ctx,
                I18nInlineNode(ctx.allocateNodeId(), ctx.emptySpan(), languageId, inlineText(children), ""),
                children
            )
            case InlineUniversal(children) => return inlineContainer(
                ctx,
                UniversalInlineNode(ctx.allocateNodeId(), ctx.emptySpan(), inlineText(children), ""),
                children
            )
            case InlineNode(node) => return node
        }
    }

    public static func inlineText(specs: Array<InlineSpec>): String {
        let sb = StringBuilder()
        for (spec in specs) {
            sb.append(inlinePlainText(spec))
        }
        return sb.toString()
    }

    private static func heading(
        ctx: DslBuildContext,
        level: Int64,
        inlines: Array<InlineSpec>,
        options: HeadingSpecOptions
    ): Node {
        let content = inlineText(inlines)
        let slugData = if (options.slug.isEmpty()) {
            ctx.headingSlug(content)
        } else {
            HeadingSlugData(options.slug, options.slug, 1, options.slug)
        }
        let node = HeadingNode(ctx.allocateNodeId(), ctx.emptySpan(), content, level, slug: slugData.uniqueSlug)
        node.setString("baseSlug", slugData.baseSlug)
        node.setInt("slugOccurrence", slugData.occurrence)
        if (!slugData.typstLabel.isEmpty()) {
            node.setString("typstLabel", slugData.typstLabel)
        }
        let number = if (options.number.isEmpty()) { ctx.headingNumber(level) } else { options.number }
        if (!number.isEmpty()) {
            node.setString("number", number)
            node.setBool("numberInHtml", true)
        }
        if (options.closable) {
            node.setBool("closable", true)
        }
        appendInlineChildren(ctx, node, inlines)
        if (node.children.isEmpty()) {
            node.sourceSpan = ctx.allocateSpan(content)
        } else {
            node.sourceSpan = ctx.spanForChildren(node.children, node.sourceSpan)
        }
        return node
    }

    private static func paragraph(ctx: DslBuildContext, inlines: Array<InlineSpec>): Node {
        let content = inlineText(inlines)
        let node = ParagraphNode(ctx.allocateNodeId(), ctx.emptySpan(), content)
        appendInlineChildren(ctx, node, inlines)
        if (node.children.isEmpty()) {
            node.sourceSpan = ctx.allocateSpan(content)
        } else {
            node.sourceSpan = ctx.spanForChildren(node.children, node.sourceSpan)
        }
        return node
    }

    private static func blockquote(ctx: DslBuildContext, blocks: Array<BlockSpec>): Node {
        let node = BlockquoteNode(ctx.allocateNodeId(), ctx.emptySpan())
        appendBlockChildren(ctx, node, blocks)
        node.sourceSpan = ctx.spanForChildren(node.children, node.sourceSpan)
        return node
    }

    private static func unorderedList(
        ctx: DslBuildContext,
        items: Array<ListItemSpec>,
        options: ListSpecOptions
    ): Node {
        let node = UnorderedListNode(ctx.allocateNodeId(), ctx.emptySpan(), options.tight, options.baseIndent)
        for (itemSpec in items) {
            match (itemSpec) {
                case ListItem(blocks) =>
                    let itemNode = UnorderedListItemNode(
                        ctx.allocateNodeId(),
                        ctx.emptySpan(),
                        blockText(blocks),
                        options.baseIndent,
                        options.marker
                    )
                    appendBlockChildren(ctx, itemNode, blocks)
                    itemNode.sourceSpan = ctx.spanForChildren(itemNode.children, itemNode.sourceSpan)
                    node.addChild(itemNode)
            }
        }
        node.sourceSpan = ctx.spanForChildren(node.children, node.sourceSpan)
        return node
    }

    private static func orderedList(
        ctx: DslBuildContext,
        startNumber: Int64,
        delimiter: Byte,
        items: Array<ListItemSpec>,
        options: ListSpecOptions
    ): Node {
        let node = OrderedListNode(ctx.allocateNodeId(), ctx.emptySpan(), options.tight, options.baseIndent, startNumber, delimiter)
        var number = startNumber
        for (itemSpec in items) {
            match (itemSpec) {
                case ListItem(blocks) =>
                    let itemNode = OrderedListItemNode(
                        ctx.allocateNodeId(),
                        ctx.emptySpan(),
                        blockText(blocks),
                        options.baseIndent,
                        number,
                        delimiter
                    )
                    appendBlockChildren(ctx, itemNode, blocks)
                    itemNode.sourceSpan = ctx.spanForChildren(itemNode.children, itemNode.sourceSpan)
                    node.addChild(itemNode)
                    number += 1
            }
        }
        node.sourceSpan = ctx.spanForChildren(node.children, node.sourceSpan)
        return node
    }

    private static func alphabeticList(
        ctx: DslBuildContext,
        startLetter: Byte,
        isUpperCase: Bool,
        delimiter: Byte,
        items: Array<ListItemSpec>,
        options: ListSpecOptions
    ): Node {
        let node = AlphabeticListNode(ctx.allocateNodeId(), ctx.emptySpan(), options.tight, options.baseIndent, startLetter, isUpperCase, delimiter)
        var letter = startLetter
        for (itemSpec in items) {
            match (itemSpec) {
                case ListItem(blocks) =>
                    let itemNode = AlphabeticListItemNode(
                        ctx.allocateNodeId(),
                        ctx.emptySpan(),
                        blockText(blocks),
                        options.baseIndent,
                        letter,
                        delimiter
                    )
                    appendBlockChildren(ctx, itemNode, blocks)
                    itemNode.sourceSpan = ctx.spanForChildren(itemNode.children, itemNode.sourceSpan)
                    node.addChild(itemNode)
                    letter = nextLetter(letter, isUpperCase)
            }
        }
        node.sourceSpan = ctx.spanForChildren(node.children, node.sourceSpan)
        return node
    }

    private static func taskList(
        ctx: DslBuildContext,
        items: Array<TaskItemSpec>,
        options: ListSpecOptions
    ): Node {
        let node = TaskListNode(ctx.allocateNodeId(), ctx.emptySpan(), options.tight, options.baseIndent)
        for (itemSpec in items) {
            match (itemSpec) {
                case TaskItem(checked, blocks) =>
                    let itemNode = TaskListItemNode(
                        ctx.allocateNodeId(),
                        ctx.emptySpan(),
                        blockText(blocks),
                        options.baseIndent,
                        checked,
                        options.marker
                    )
                    appendBlockChildren(ctx, itemNode, blocks)
                    itemNode.sourceSpan = ctx.spanForChildren(itemNode.children, itemNode.sourceSpan)
                    node.addChild(itemNode)
            }
        }
        node.sourceSpan = ctx.spanForChildren(node.children, node.sourceSpan)
        return node
    }

    private static func table(
        ctx: DslBuildContext,
        headerSpec: TableRowSpec,
        bodySpecs: Array<TableRowSpec>,
        alignments: Array<TableAlignment>
    ): Node {
        let headerCells = cellsOf(headerSpec)
        let columnCount = headerCells.size
        let alignmentList = ArrayList<TableAlignment>()
        for (i in 0..columnCount) {
            alignmentList.add(alignmentAt(alignments, i, headerCells))
        }
        let node = TableNode(ctx.allocateNodeId(), ctx.emptySpan(), alignmentList, columnCount)
        node.addChild(tableRow(ctx, headerSpec, true, alignments))
        for (rowSpec in bodySpecs) {
            node.addChild(tableRow(ctx, rowSpec, false, alignments))
        }
        node.sourceSpan = ctx.spanForChildren(node.children, node.sourceSpan)
        return node
    }

    private static func footnoteDefinition(ctx: DslBuildContext, id: String, inlines: Array<InlineSpec>): Node {
        let content = inlineText(inlines)
        let raw = "[^${id}]: ${content}"
        let node = FootnoteDefinitionNode(ctx.allocateNodeId(), ctx.allocateSpan(raw), id, content, ctx.footnoteNumber(id), raw)
        appendInlineChildren(ctx, node, inlines)
        return node
    }

    private static func i18nBlock(ctx: DslBuildContext, languageId: String, blocks: Array<BlockSpec>): Node {
        let node = I18nBlockNode(ctx.allocateNodeId(), ctx.emptySpan(), languageId, blockText(blocks))
        appendBlockChildren(ctx, node, blocks)
        node.sourceSpan = ctx.spanForChildren(node.children, node.sourceSpan)
        return node
    }

    private static func universalBlock(ctx: DslBuildContext, blocks: Array<BlockSpec>): Node {
        let node = UniversalBlockNode(ctx.allocateNodeId(), ctx.emptySpan(), blockText(blocks))
        appendBlockChildren(ctx, node, blocks)
        node.sourceSpan = ctx.spanForChildren(node.children, node.sourceSpan)
        return node
    }

    private static func toc(title: String, items: Array<TocItemSpec>): Node {
        let node = TocNode(title: title)
        for (item in items) {
            node.addItem(tocItem(item))
        }
        return node
    }

    private static func tocItem(spec: TocItemSpec): TocItem {
        match (spec) {
            case TocItemValue(text, level, anchorId, number, children) =>
                let item = TocItem(text, level, anchorId, number: number)
                for (child in children) {
                    item.addChild(tocItem(child))
                }
                return item
        }
    }

    private static func tableRow(
        ctx: DslBuildContext,
        spec: TableRowSpec,
        forceHeader: Bool,
        alignments: Array<TableAlignment>
    ): Node {
        match (spec) {
            case TableRow(isHeader, cells) =>
                let header = forceHeader || isHeader
                let node = TableRowNode(ctx.allocateNodeId(), ctx.emptySpan(), header)
                for (i in 0..cells.size) {
                    node.addChild(tableCell(ctx, cells[i], header, alignmentAt(alignments, i, cells)))
                }
                node.sourceSpan = ctx.spanForChildren(node.children, node.sourceSpan)
                return node
        }
    }

    private static func tableCell(
        ctx: DslBuildContext,
        spec: TableCellSpec,
        isHeader: Bool,
        fallbackAlignment: TableAlignment
    ): Node {
        match (spec) {
            case TableCell(inlines, alignment) =>
                let resolvedAlignment = if (alignmentName(alignment) == "None") { fallbackAlignment } else { alignment }
                let node = TableCellNode(ctx.allocateNodeId(), ctx.emptySpan(), inlineText(inlines), resolvedAlignment, isHeader)
                appendInlineChildren(ctx, node, inlines)
                node.sourceSpan = ctx.spanForChildren(node.children, node.sourceSpan)
                return node
        }
    }

    private static func inlineContainer(ctx: DslBuildContext, node: Node, children: Array<InlineSpec>): Node {
        appendInlineChildren(ctx, node, children)
        if (node.children.isEmpty()) {
            node.sourceSpan = ctx.allocateSpan(inlineText(children))
        } else {
            node.sourceSpan = ctx.spanForChildren(node.children, node.sourceSpan)
        }
        return node
    }

    private static func appendInlineChildren(ctx: DslBuildContext, node: Node, specs: Array<InlineSpec>): Unit {
        for (spec in specs) {
            node.addChild(inline(ctx, spec))
        }
    }

    private static func appendBlockChildren(ctx: DslBuildContext, node: Node, specs: Array<BlockSpec>): Unit {
        for (spec in specs) {
            node.addChild(block(ctx, spec))
        }
    }

    private static func inlinePlainText(spec: InlineSpec): String {
        match (spec) {
            case InlineText(content) => return content
            case InlineStrong(children) => return inlineText(children)
            case InlineEmphasis(children) => return inlineText(children)
            case InlineCodeText(content, _) => return content
            case InlineLink(_, _, children) => return inlineText(children)
            case InlineImage(alt, _, _) => return alt
            case InlineSoftBreak => return "\n"
            case InlineHardBreak(_) => return "\n"
            case InlineStrike(children) => return inlineText(children)
            case InlineMathText(content) => return content
            case InlineFootnoteRef(id) => return "[^${id}]"
            case InlineAutolink(_, _, displayText, _) => return displayText
            case InlineCommonMarkAutolink(_, _, displayText, _) => return displayText
            case InlineHtml(_, _, htmlContent) => return htmlContent
            case InlineEntity(_, entityValue, _) => return entityValue
            case InlineI18n(_, children) => return inlineText(children)
            case InlineUniversal(children) => return inlineText(children)
            case InlineNode(node) => return node.literal
        }
    }

    private static func blockText(specs: Array<BlockSpec>): String {
        let parts = ArrayList<String>()
        for (spec in specs) {
            let text = blockPlainText(spec)
            if (!text.isEmpty()) {
                parts.add(text)
            }
        }
        return String.join(parts.toArray(), delimiter: "\n")
    }

    private static func blockPlainText(spec: BlockSpec): String {
        match (spec) {
            case BlockHeading(_, inlines, _) => return inlineText(inlines)
            case BlockParagraph(inlines) => return inlineText(inlines)
            case Blockquote(blocks) => return blockText(blocks)
            case BlockDivider(_, _) => return ""
            case BlockCode(_, content, _) => return content
            case BlockMath(content, _) => return content
            case BlockUnorderedList(items, _) => return listText(items)
            case BlockOrderedList(_, _, items, _) => return listText(items)
            case BlockAlphabeticList(_, _, _, items, _) => return listText(items)
            case BlockTaskList(items, _) => return taskText(items)
            case BlockTable(header, rows, _) => return tableText(header, rows)
            case BlockFootnoteDef(_, inlines) => return inlineText(inlines)
            case BlockHtml(raw, _, _) => return raw
            case BlockI18n(_, blocks) => return blockText(blocks)
            case BlockUniversal(blocks) => return blockText(blocks)
            case BlockToc(_, _) => return ""
            case BlockNode(node) => return node.literal
        }
    }

    private static func listText(items: Array<ListItemSpec>): String {
        let parts = ArrayList<String>()
        for (item in items) {
            match (item) {
                case ListItem(blocks) => parts.add(blockText(blocks))
            }
        }
        return String.join(parts.toArray(), delimiter: "\n")
    }

    private static func taskText(items: Array<TaskItemSpec>): String {
        let parts = ArrayList<String>()
        for (item in items) {
            match (item) {
                case TaskItem(_, blocks) => parts.add(blockText(blocks))
            }
        }
        return String.join(parts.toArray(), delimiter: "\n")
    }

    private static func tableText(header: TableRowSpec, rows: Array<TableRowSpec>): String {
        let parts = ArrayList<String>()
        parts.add(rowText(header))
        for (row in rows) {
            parts.add(rowText(row))
        }
        return String.join(parts.toArray(), delimiter: "\n")
    }

    private static func rowText(row: TableRowSpec): String {
        match (row) {
            case TableRow(_, cells) =>
                let parts = ArrayList<String>()
                for (cell in cells) {
                    match (cell) {
                        case TableCell(inlines, _) => parts.add(inlineText(inlines))
                    }
                }
                return String.join(parts.toArray(), delimiter: "\t")
        }
    }

    private static func cellsOf(row: TableRowSpec): Array<TableCellSpec> {
        match (row) {
            case TableRow(_, cells) => return cells
        }
    }

    private static func alignmentAt(
        alignments: Array<TableAlignment>,
        index: Int64,
        cells: Array<TableCellSpec>
    ): TableAlignment {
        if (index < alignments.size) {
            return alignments[index]
        }
        if (index < cells.size) {
            match (cells[index]) {
                case TableCell(_, alignment) => return alignment
            }
        }
        return TableAlignment.None
    }

    private static func alignmentName(alignment: TableAlignment): String {
        return alignment.toString()
    }

    private static func nextLetter(letter: Byte, isUpperCase: Bool): Byte {
        if (isUpperCase) {
            return if (letter == b'Z') { b'A' } else { letter + 1 }
        }
        return if (letter == b'z') { b'a' } else { letter + 1 }
    }

    private static func repeatByte(value: Byte, count: Int64): String {
        if (count <= 0) {
            return ""
        }
        let sb = StringBuilder()
        let text = String.fromUtf8([value])
        for (_ in 0..count) {
            sb.append(text)
        }
        return sb.toString()
    }
}
