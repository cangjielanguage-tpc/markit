package markit_kit.models

import std.collection.ArrayList

/**
 * markit.md 解析结果
 * 包含导航结构、根级链接、首页内容等信息
 */
public struct SummaryConfig {
    public SummaryConfig(
        public let sections: Array<Section>,
        public let prefixChapters: Array<Chapter>,
        public let homepageContent: String,
        public let homepageTypstContent: String,
        public let found: Bool
    ) {}
    
    /**
     * 获取所有章节的扁平化列表（按顺序，不包含草稿）
     * 用于生成上一篇/下一篇导航
     * 
     * @return 章节列表
     */
    public func getAllChaptersFlat(): Array<Chapter> {
        let result = ArrayList<Chapter>()
        
        // 添加 prefixChapters
        for (chapter in prefixChapters) {
            collectChapters(chapter, result)
        }
        
        // 添加 sections 中的章节
        for (section in sections) {
            for (chapter in section.chapters) {
                collectChapters(chapter, result)
            }
        }
        
        return result.toArray()
    }
    
    /**
     * 递归收集章节（不包含草稿）
     */
    private static func collectChapters(chapter: Chapter, result: ArrayList<Chapter>): Unit {
        // 只收集非草稿章节
        if (!chapter.isDraft && !chapter.filePath.isEmpty()) {
            result.add(chapter)
        }
        
        // 递归收集子章节
        for (child in chapter.children) {
            collectChapters(child, result)
        }
    }
}
