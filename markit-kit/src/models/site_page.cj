package markit_kit.models

/**
 * 网站页面类
 * 表示网站中的一个页面
 */
public struct SitePage {
    public SitePage(
        public let path: String,
        public let title: String,
        public let htmlPath: String
    ) {}
}
