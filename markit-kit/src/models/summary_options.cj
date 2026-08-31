package markit_kit.models

/**
 * Summary 配置选项
 * 用于配置 markit.md 的解析行为
 */
public struct SummaryOptions {
    public SummaryOptions(
        public let file!: String = "markit.md",
        public let showDrafts!: Bool = true
    ) {}
}
