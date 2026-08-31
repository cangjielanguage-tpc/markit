package markit_kit.utils

import markit.Markit
import markit.core.nodes.DocumentNode
import markit.plugins.toc.Toc
import markit.plugins.standard.inline.link.HeadingInfo
import std.collection.ArrayList

/**
 * 标题提取器
 * 
 * 从 Markdown 文档中提取所有标题信息，使用 TOC 插件
 */
public class HeadingExtractor {
    
    /**
     * 从文件中提取所有标题
     * 
     * @param filePath 文件路径（相对路径）
     * @param fileContent 文件内容
     * @param markit Markit 解析器实例
     * @return 标题信息数组
     */
    public static func extractHeadings(filePath: String, fileContent: String, markit: Markit): Array<HeadingInfo> {
        let headings = ArrayList<HeadingInfo>()
        
        try {
            // 解析文档
            let parseResult = markit.parse(fileContent)
            let document = (parseResult.root() as DocumentNode).getOrThrow()
            
            // 使用 TOC 插件提取标题详细信息
            // 返回: (text, level, number, id)
            let headingList = Toc.extractDetailedHeadingList(document, minLevel: 1, maxLevel: 6)
            
            // 转换为 HeadingInfo 对象
            for (i in 0..headingList.size) {
                let (text, level, number, id) = headingList[i]
                let headingInfo = HeadingInfo(text, id, filePath, level)
                headings.add(headingInfo)
            }
        } catch (e: Exception) {
            // 解析失败时返回空数组
            KitHooks.warn("Failed to extract headings from ${filePath}: ${e.message}")
        }
        
        return headings.toArray()
    }
}
