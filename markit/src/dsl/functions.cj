package markit.dsl

import markit.core.nodes.Node
import markit.plugins.commonmark.block.html_block.HTMLBlockType
import markit.plugins.commonmark.inline.commonmark_autolink.AutolinkType as CommonMarkAutolinkType
import markit.plugins.commonmark.inline.entity_reference.EntityType
import markit.plugins.commonmark.inline.html_inline.HTMLTagType
import markit.plugins.gfm.block.table.TableAlignment
import markit.plugins.gfm.inline.autolink.AutolinkType
import markit.plugins.standard.inline.hard_break.BreakType

public func md(blocks: Array<BlockSpec>): DslDocument {
    return DslDocument(blocks)
}

public func md(options: DslOptions, blocks: Array<BlockSpec>): DslDocument {
    return DslDocument(blocks, options: options)
}

public func emptyDoc(options!: DslOptions = DslOptions()): DslDocument {
    return DslDocument(options: options)
}

public func add(block: BlockSpec): (DslDocument) -> DslDocument {
    return { doc: DslDocument => doc.withBlock(block) }
}

public func addAll(blocks: Array<BlockSpec>): (DslDocument) -> DslDocument {
    return { doc: DslDocument => doc.withBlocks(blocks) }
}

public func text(content: String): InlineSpec {
    return InlineText(content)
}

public func strong(inlines: Array<InlineSpec>): InlineSpec {
    return InlineStrong(inlines)
}

public func bold(inlines: Array<InlineSpec>): InlineSpec {
    return strong(inlines)
}

public func em(inlines: Array<InlineSpec>): InlineSpec {
    return InlineEmphasis(inlines)
}

public func italic(inlines: Array<InlineSpec>): InlineSpec {
    return em(inlines)
}

public func code(content: String, fenceLength!: Int64 = 1): InlineSpec {
    return InlineCodeText(content, fenceLength)
}

public func link(url: String, label: String, title!: String = ""): InlineSpec {
    return InlineLink(url, title, [text(label)])
}

public func link(url: String, inlines: Array<InlineSpec>, title!: String = ""): InlineSpec {
    return InlineLink(url, title, inlines)
}

public func codeLink(url: String, label: String, title!: String = "", fenceLength!: Int64 = 1): InlineSpec {
    return InlineLink(url, title, [code(label, fenceLength: fenceLength)])
}

public func image(src: String, alt!: String = "", title!: String = ""): InlineSpec {
    return InlineImage(alt, src, title)
}

public func softBreak(): InlineSpec {
    return InlineSoftBreak
}

public func hardBreak(breakType!: BreakType = BreakType.TwoSpaces): InlineSpec {
    return InlineHardBreak(breakType)
}

public func backslashBreak(): InlineSpec {
    return InlineHardBreak(BreakType.Backslash)
}

public func strike(inlines: Array<InlineSpec>): InlineSpec {
    return InlineStrike(inlines)
}

public func del(inlines: Array<InlineSpec>): InlineSpec {
    return strike(inlines)
}

public func inlineMath(content: String): InlineSpec {
    return InlineMathText(content)
}

public func footnoteRef(id: String): InlineSpec {
    return InlineFootnoteRef(id)
}

public func autolink(url: String, displayText!: String = ""): InlineSpec {
    let textValue = if (displayText.isEmpty()) { url } else { displayText }
    return InlineAutolink(AutolinkType.Url, url, textValue, url)
}

public func emailAutolink(email: String, displayText!: String = ""): InlineSpec {
    let textValue = if (displayText.isEmpty()) { email } else { displayText }
    return InlineAutolink(AutolinkType.Email, "mailto:${email}", textValue, email)
}

public func commonmarkAutolink(url: String, displayText!: String = ""): InlineSpec {
    let textValue = if (displayText.isEmpty()) { url } else { displayText }
    let raw = "<${url}>"
    return InlineCommonMarkAutolink(CommonMarkAutolinkType.Url, url, textValue, raw)
}

public func commonmarkEmailAutolink(email: String, displayText!: String = ""): InlineSpec {
    let textValue = if (displayText.isEmpty()) { email } else { displayText }
    let raw = "<${email}>"
    return InlineCommonMarkAutolink(CommonMarkAutolinkType.Email, "mailto:${email}", textValue, raw)
}

public func htmlInline(tagName: String, raw: String, tagType!: HTMLTagType = HTMLTagType.OpeningTag): InlineSpec {
    return InlineHtml(tagName, tagType, raw)
}

public func entity(entityValue: String, entityReference: String, entityType!: EntityType = EntityType.Named): InlineSpec {
    return InlineEntity(entityType, entityValue, entityReference)
}

public func i18nInline(languageId: String, inlines: Array<InlineSpec>): InlineSpec {
    return InlineI18n(languageId, inlines)
}

public func universalInline(inlines: Array<InlineSpec>): InlineSpec {
    return InlineUniversal(inlines)
}

public func inlineNode(node: Node): InlineSpec {
    return InlineNode(node)
}

public func h(level: Int64, title: String, options!: HeadingSpecOptions = HeadingSpecOptions()): BlockSpec {
    return BlockHeading(level, [text(title)], options)
}

public func h(level: Int64, inlines: Array<InlineSpec>, options!: HeadingSpecOptions = HeadingSpecOptions()): BlockSpec {
    return BlockHeading(level, inlines, options)
}

public func h1(title: String, options!: HeadingSpecOptions = HeadingSpecOptions()): BlockSpec {
    return h(1, title, options: options)
}

public func h1(inlines: Array<InlineSpec>, options!: HeadingSpecOptions = HeadingSpecOptions()): BlockSpec {
    return h(1, inlines, options: options)
}

public func h2(title: String, options!: HeadingSpecOptions = HeadingSpecOptions()): BlockSpec {
    return h(2, title, options: options)
}

public func h2(inlines: Array<InlineSpec>, options!: HeadingSpecOptions = HeadingSpecOptions()): BlockSpec {
    return h(2, inlines, options: options)
}

public func h3(title: String, options!: HeadingSpecOptions = HeadingSpecOptions()): BlockSpec {
    return h(3, title, options: options)
}

public func h3(inlines: Array<InlineSpec>, options!: HeadingSpecOptions = HeadingSpecOptions()): BlockSpec {
    return h(3, inlines, options: options)
}

public func h4(title: String, options!: HeadingSpecOptions = HeadingSpecOptions()): BlockSpec {
    return h(4, title, options: options)
}

public func h5(title: String, options!: HeadingSpecOptions = HeadingSpecOptions()): BlockSpec {
    return h(5, title, options: options)
}

public func h6(title: String, options!: HeadingSpecOptions = HeadingSpecOptions()): BlockSpec {
    return h(6, title, options: options)
}

public func p(content: String): BlockSpec {
    return BlockParagraph([text(content)])
}

public func p(inlines: Array<InlineSpec>): BlockSpec {
    return BlockParagraph(inlines)
}

public func blockquote(blocks: Array<BlockSpec>): BlockSpec {
    return Blockquote(blocks)
}

public func divider(marker!: Byte = b'-', markerCount!: Int64 = 3): BlockSpec {
    return BlockDivider(marker, markerCount)
}

public func codeBlock(language: String, content: String, options!: CodeBlockSpecOptions = CodeBlockSpecOptions()): BlockSpec {
    return BlockCode(language, content, options)
}

public func codeBlock(content: String): BlockSpec {
    return BlockCode("", content, CodeBlockSpecOptions())
}

public func mathBlock(content: String, indentLevel!: Int64 = 0): BlockSpec {
    return BlockMath(content, indentLevel)
}

public func item(content: String): ListItemSpec {
    return ListItem([p(content)])
}

public func item(blocks: Array<BlockSpec>): ListItemSpec {
    return ListItem(blocks)
}

public func task(checked: Bool, content: String): TaskItemSpec {
    return TaskItem(checked, [p(content)])
}

public func task(checked: Bool, blocks: Array<BlockSpec>): TaskItemSpec {
    return TaskItem(checked, blocks)
}

public func ul(items: Array<ListItemSpec>, options!: ListSpecOptions = ListSpecOptions()): BlockSpec {
    return BlockUnorderedList(items, options)
}

public func ol(items: Array<ListItemSpec>, startNumber!: Int64 = 1, delimiter!: Byte = b'.', options!: ListSpecOptions = ListSpecOptions()): BlockSpec {
    return BlockOrderedList(startNumber, delimiter, items, options)
}

public func alphaList(
    items: Array<ListItemSpec>,
    startLetter!: Byte = b'a',
    isUpperCase!: Bool = false,
    delimiter!: Byte = b'.',
    options!: ListSpecOptions = ListSpecOptions()
): BlockSpec {
    return BlockAlphabeticList(startLetter, isUpperCase, delimiter, items, options)
}

public func taskList(items: Array<TaskItemSpec>, options!: ListSpecOptions = ListSpecOptions()): BlockSpec {
    return BlockTaskList(items, options)
}

public func cell(content: String, alignment!: TableAlignment = TableAlignment.None): TableCellSpec {
    return TableCell([text(content)], alignment)
}

public func cell(inlines: Array<InlineSpec>, alignment!: TableAlignment = TableAlignment.None): TableCellSpec {
    return TableCell(inlines, alignment)
}

public func header(cells: Array<TableCellSpec>): TableRowSpec {
    return TableRow(true, cells)
}

public func header(labels: Array<String>): TableRowSpec {
    let cells = Array<TableCellSpec>(labels.size) { i => cell(labels[i]) }
    return TableRow(true, cells)
}

public func row(cells: Array<TableCellSpec>): TableRowSpec {
    return TableRow(false, cells)
}

public func row(values: Array<String>): TableRowSpec {
    let cells = Array<TableCellSpec>(values.size) { i => cell(values[i]) }
    return TableRow(false, cells)
}

public func table(header: TableRowSpec, rows: Array<TableRowSpec>, alignments!: Array<TableAlignment> = []): BlockSpec {
    return BlockTable(header, rows, alignments)
}

public func footnoteDef(id: String, content: String): BlockSpec {
    return BlockFootnoteDef(id, [text(content)])
}

public func footnoteDef(id: String, inlines: Array<InlineSpec>): BlockSpec {
    return BlockFootnoteDef(id, inlines)
}

public func htmlBlock(raw: String, blockType!: HTMLBlockType = HTMLBlockType.SafeBlockTag, tagName!: String = ""): BlockSpec {
    return BlockHtml(raw, blockType, tagName)
}

public func i18nBlock(languageId: String, blocks: Array<BlockSpec>): BlockSpec {
    return BlockI18n(languageId, blocks)
}

public func universalBlock(blocks: Array<BlockSpec>): BlockSpec {
    return BlockUniversal(blocks)
}

public func toc(title!: String = "Table of Contents", items!: Array<TocItemSpec> = []): BlockSpec {
    return BlockToc(title, items)
}

public func tocItem(
    text: String,
    level: Int64,
    anchorId: String,
    number!: String = "",
    children!: Array<TocItemSpec> = []
): TocItemSpec {
    return TocItemValue(text, level, anchorId, number, children)
}

public func blockNode(node: Node): BlockSpec {
    return BlockNode(node)
}
