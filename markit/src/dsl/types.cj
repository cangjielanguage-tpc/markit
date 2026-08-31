package markit.dsl

import markit.core.nodes.Node
import markit.plugins.commonmark.block.html_block.HTMLBlockType
import markit.plugins.commonmark.inline.commonmark_autolink.AutolinkType as CommonMarkAutolinkType
import markit.plugins.commonmark.inline.entity_reference.EntityType
import markit.plugins.commonmark.inline.html_inline.HTMLTagType
import markit.plugins.gfm.block.table.TableAlignment
import markit.plugins.gfm.inline.autolink.AutolinkType
import markit.plugins.standard.inline.hard_break.BreakType

public enum InlineSpec {
    | InlineText(String)
    | InlineStrong(Array<InlineSpec>)
    | InlineEmphasis(Array<InlineSpec>)
    | InlineCodeText(String, Int64)
    | InlineLink(String, String, Array<InlineSpec>)
    | InlineImage(String, String, String)
    | InlineSoftBreak
    | InlineHardBreak(BreakType)
    | InlineStrike(Array<InlineSpec>)
    | InlineMathText(String)
    | InlineFootnoteRef(String)
    | InlineAutolink(AutolinkType, String, String, String)
    | InlineCommonMarkAutolink(CommonMarkAutolinkType, String, String, String)
    | InlineHtml(String, HTMLTagType, String)
    | InlineEntity(EntityType, String, String)
    | InlineI18n(String, Array<InlineSpec>)
    | InlineUniversal(Array<InlineSpec>)
    | InlineNode(Node)
}

public enum BlockSpec {
    | BlockHeading(Int64, Array<InlineSpec>, HeadingSpecOptions)
    | BlockParagraph(Array<InlineSpec>)
    | Blockquote(Array<BlockSpec>)
    | BlockDivider(Byte, Int64)
    | BlockCode(String, String, CodeBlockSpecOptions)
    | BlockMath(String, Int64)
    | BlockUnorderedList(Array<ListItemSpec>, ListSpecOptions)
    | BlockOrderedList(Int64, Byte, Array<ListItemSpec>, ListSpecOptions)
    | BlockAlphabeticList(Byte, Bool, Byte, Array<ListItemSpec>, ListSpecOptions)
    | BlockTaskList(Array<TaskItemSpec>, ListSpecOptions)
    | BlockTable(TableRowSpec, Array<TableRowSpec>, Array<TableAlignment>)
    | BlockFootnoteDef(String, Array<InlineSpec>)
    | BlockHtml(String, HTMLBlockType, String)
    | BlockI18n(String, Array<BlockSpec>)
    | BlockUniversal(Array<BlockSpec>)
    | BlockToc(String, Array<TocItemSpec>)
    | BlockNode(Node)
}

public enum ListItemSpec {
    | ListItem(Array<BlockSpec>)
}

public enum TaskItemSpec {
    | TaskItem(Bool, Array<BlockSpec>)
}

public enum TableRowSpec {
    | TableRow(Bool, Array<TableCellSpec>)
}

public enum TableCellSpec {
    | TableCell(Array<InlineSpec>, TableAlignment)
}

public enum TocItemSpec {
    | TocItemValue(String, Int64, String, String, Array<TocItemSpec>)
}

public class HeadingSpecOptions {
    public let slug: String
    public let number: String
    public let closable: Bool

    public init(
        slug!: String = "",
        number!: String = "",
        closable!: Bool = false
    ) {
        this.slug = slug
        this.number = number
        this.closable = closable
    }
}

public class CodeBlockSpecOptions {
    public let fenceMarker: Byte
    public let fenceLength: Int64
    public let highlightLines: String
    public let i18nLines: String

    public init(
        fenceMarker!: Byte = b'`',
        fenceLength!: Int64 = 3,
        highlightLines!: String = "",
        i18nLines!: String = ""
    ) {
        this.fenceMarker = fenceMarker
        this.fenceLength = fenceLength
        this.highlightLines = highlightLines
        this.i18nLines = i18nLines
    }
}

public class ListSpecOptions {
    public let tight: Bool
    public let baseIndent: Int64
    public let marker: Byte

    public init(
        tight!: Bool = true,
        baseIndent!: Int64 = 0,
        marker!: Byte = b'-'
    ) {
        this.tight = tight
        this.baseIndent = baseIndent
        this.marker = marker
    }
}
