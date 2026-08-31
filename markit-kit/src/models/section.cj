package markit_kit.models

/**
 * 导航分组
 * 表示导航中的一个分组，包含标题和章节列表
 */
public struct Section {
    public Section(
        public let title: String,
        public let chapters: Array<Chapter>
    ) {}
}
