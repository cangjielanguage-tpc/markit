package markit.plugins.commonmark.block.html_block

public class HtmlBlockConfig {
    public let enableInlineMarkdownParsing: Bool

    public init(enableInlineMarkdownParsing!: Bool = false) {
        this.enableInlineMarkdownParsing = enableInlineMarkdownParsing
    }
}
