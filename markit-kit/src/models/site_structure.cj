package markit_kit.models

import std.collection.ArrayList

/**
 * 网站结构类
 * 用于管理网站的页面结构
 */
public class SiteStructure {
    private let pages: ArrayList<SitePage>
    
    public init() {
        this.pages = ArrayList<SitePage>()
    }
    
    public func addPage(path: String, title: String, htmlPath: String): Unit {
        pages.add(SitePage(path, title, htmlPath))
    }
    
    public func getPages(): Array<SitePage> {
        return pages.toArray()
    }
}
