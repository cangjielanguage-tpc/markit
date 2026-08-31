package markit.bundles

import markit.core.plugin.{Bundle, Plugin}
import markit.plugins.anchor.{AutoAnchorConfig, AutoAnchorPlugin}
import markit.plugins.standard.block.blockquote.BlockquotePlugin
import markit.plugins.standard.block.divider.DividerPlugin
import markit.plugins.standard.block.fenced_code_block.{FencedCodeBlockConfig, FencedCodeBlockPlugin}
import markit.plugins.standard.block.heading.{HeadingClosableConfig, HeadingNumberingConfig, HeadingPlugin, HeadingSlugConfig}
import markit.plugins.standard.block.list.{ListConfig, ListPlugin}
import markit.plugins.standard.block.paragraph.ParagraphPlugin
import markit.plugins.standard.inline.bold.BoldPlugin
import markit.plugins.standard.inline.hard_break.HardBreakPlugin
import markit.plugins.standard.inline.image.ImagePlugin
import markit.plugins.standard.inline.inline_code.InlineCodePlugin
import markit.plugins.standard.inline.italic.ItalicPlugin
import markit.plugins.standard.inline.link.{LinkConfig, LinkPlugin}
import markit.plugins.standard.inline.reference_link.ReferenceLinkPlugin

public class StandardMarkdownBundle <: Bundle {
    private let headingNumberingConfig: HeadingNumberingConfig
    private let closableConfig: HeadingClosableConfig
    private let headingSlugConfig: HeadingSlugConfig
    private let fencedCodeBlockConfig: FencedCodeBlockConfig
    private let listConfig: ListConfig
    private let linkConfig: LinkConfig
    private let blockAutoAnchor: Bool

    public init(
        headingNumberingConfig!: HeadingNumberingConfig = HeadingNumberingConfig(),
        closableConfig!: HeadingClosableConfig = HeadingClosableConfig(),
        headingSlugConfig!: HeadingSlugConfig = HeadingSlugConfig(),
        fencedCodeBlockConfig!: FencedCodeBlockConfig = FencedCodeBlockConfig(),
        listConfig!: ListConfig = ListConfig(),
        linkConfig!: LinkConfig = LinkConfig(),
        blockAutoAnchor!: Bool = false
    ) {
        this.headingNumberingConfig = headingNumberingConfig
        this.closableConfig = closableConfig
        this.headingSlugConfig = headingSlugConfig
        this.fencedCodeBlockConfig = fencedCodeBlockConfig
        this.listConfig = listConfig
        this.linkConfig = linkConfig
        this.blockAutoAnchor = blockAutoAnchor
    }

    public override prop name: String {
        get() {
            return "StandardMarkdownBundle"
        }
    }

    public override prop version: String {
        get() {
            return "2.0.0-scaffold"
        }
    }

    public override prop plugins: Array<Plugin> {
        get() {
            return [
                BlockquotePlugin(),
                HeadingPlugin(numberingConfig: headingNumberingConfig, closableConfig: closableConfig, slugConfig: headingSlugConfig),
                AutoAnchorPlugin(config: AutoAnchorConfig(list: listConfig.autoAnchor, code: fencedCodeBlockConfig.autoAnchor, block: blockAutoAnchor)),
                DividerPlugin(),
                FencedCodeBlockPlugin(config: fencedCodeBlockConfig),
                ListPlugin(config: listConfig),
                InlineCodePlugin(),
                LinkPlugin(config: linkConfig),
                ImagePlugin(),
                ReferenceLinkPlugin(),
                BoldPlugin(),
                ItalicPlugin(),
                HardBreakPlugin(),
                ParagraphPlugin()
            ]
        }
    }
}
