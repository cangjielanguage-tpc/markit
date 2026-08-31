package markit.plugins.standard.block.fenced_code_block

public class FencedCodeBlockStartInfo {
    public let marker: Byte
    public let fenceLength: Int64
    public let indentWidth: Int64
    public let language: String
    public let highlightLines: String
    public let i18nLines: String

    public init(
        marker: Byte,
        fenceLength: Int64,
        indentWidth: Int64,
        language: String,
        highlightLines: String,
        i18nLines: String
    ) {
        this.marker = marker
        this.fenceLength = fenceLength
        this.indentWidth = indentWidth
        this.language = language
        this.highlightLines = highlightLines
        this.i18nLines = i18nLines
    }
}
