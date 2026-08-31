package markit_kit.models

import std.collection.ArrayList

/**
 * 网站导航类
 * 管理整个网站的导航结构和TOC
 */
public class SiteNavigation {
    private let pages: ArrayList<PageInfo>
    
    public init() {
        this.pages = ArrayList<PageInfo>()
    }
    
    public func addPageHeadings(title: String, headings: Array<HeadingInfo>): Unit {
        let pageInfo = PageInfo(title, "", headings)
        pages.add(pageInfo)
    }
    
    public func getPages(): Array<PageInfo> {
        return pages.toArray()
    }
}
