package markit_kit.models

/**
 * 标题信息类
 * 用于存储文档中的标题信息
 */
public struct HeadingInfo {
    public HeadingInfo(
        public let level: Int,
        public let text: String,
        public let id: String,
        public let number: String
    ) {}
}
