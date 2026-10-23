package markit.plugins.standard.block.fenced_code_block

public class FencedCodeBlockStartInfo {
    public FencedCodeBlockStartInfo(
        public let marker: Byte,
        public let fenceLength: Int64,
        public let indentWidth: Int64,
        public let language: String,
        public let highlightLines: String,
        public let i18nLines: String
    ) {}
}
