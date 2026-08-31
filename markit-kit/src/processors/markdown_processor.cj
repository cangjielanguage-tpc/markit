package markit_kit.processors

import markit_kit.interfaces.Processor
import markit_kit.models.GlobalContext
import markit_kit.utils.CliMarkitFactory
import markit.plugins.standard.inline.link.LinkConfig
import markit.core.nodes.DocumentNode

/**
 * Markdown 处理器
 * 用于「合并 Markdown」输出：parse 后输出 toMarkdown()，便于并行解析后串行合并为单文件。
 */
public class MarkdownProcessor <: Processor {
    private let config = GlobalContext.renderConfig.getOrThrow()
    private var linkConfig: LinkConfig = GlobalContext.linkConfig ?? LinkConfig()
    private var headingInitialState: Array<Int64> = CliMarkitFactory.defaultHeadingState(config)

    public init(themeName!: String = "") {
    }

    public func setLinkConfig(config: LinkConfig): Unit {
        this.linkConfig = config
    }

    public func setHeadingInitialState(state: Array<Int64>): Unit {
        this.headingInitialState = state
    }

    public func process(content: String, title: String, currentPagePath!: String = "", asDocument!: Bool = false): (String, DocumentNode) {
        let parser = CliMarkitFactory.build(
            config,
            linkConfig: Some(linkConfig),
            currentPagePath: currentPagePath,
            headingInitialState: Some(headingInitialState)
        )
        let parseResult = parser.parse(content)
        let document = CliMarkitFactory.documentOf(parseResult)
        let mdContent = document.toMarkdown()
        return (mdContent, document)
    }

    public func wrapHtmlContent(htmlContent: String, title: String, currentPagePath: String): String {
        return htmlContent
    }

    public func getExtension(): String {
        return "md"
    }

    public func getType(): String {
        return "markdown"
    }
}
