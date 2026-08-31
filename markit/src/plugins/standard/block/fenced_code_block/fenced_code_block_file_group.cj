package markit.plugins.standard.block.fenced_code_block

public class FencedCodeBlockFileGroup {
    public let filename: String
    public let content: String
    public let language: String
    public let highlightLines: String
    public let i18nLines: String

    public init(
        filename: String,
        content: String,
        language!: String = "",
        highlightLines!: String = "",
        i18nLines!: String = ""
    ) {
        this.filename = filename
        this.content = content
        this.language = language
        this.highlightLines = highlightLines
        this.i18nLines = i18nLines
    }
}
