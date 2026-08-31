package markit_kit.models

/**
 * 页面信息类
 * 包含页面的标题和TOC信息
 */
public class PageInfo {
    public let title: String
    public let path: String
    public let headings: Array<HeadingInfo>
    
    public init(title: String, path: String, headings: Array<HeadingInfo>) {
        this.title = title
        this.path = path
        this.headings = headings
    }
}
