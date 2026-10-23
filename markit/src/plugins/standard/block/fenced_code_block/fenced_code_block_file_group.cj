package markit.plugins.standard.block.fenced_code_block

public class FencedCodeBlockFileGroup {
    public FencedCodeBlockFileGroup(
        public let filename: String,
        public let content: String,
        public let language!: String = "",
        public let highlightLines!: String = "",
        public let i18nLines!: String = ""
    ) {}
}
