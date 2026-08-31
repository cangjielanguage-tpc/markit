package markit_kit.services

import markit.core.nodes.{Node, DocumentNode, TextNode}
import markit.plugins.standard.block.heading.HeadingNode
import markit.utils.slug
import std.collection.ArrayList
import seajson.{JsonWriter, buildJsonArray}

/**
 * 搜索索引项
 */
public class SearchIndexSection {
    public var id: String
    public var title: String
    public var content: String
    public var url: String
    public var pageTitle: String
    public var breadcrumb: Array<String>

    public init(id: String, title: String, content: String, url: String, pageTitle: String, breadcrumb: Array<String>) {
        this.id = id
        this.title = title
        this.content = content
        this.url = url
        this.pageTitle = pageTitle
        this.breadcrumb = breadcrumb
    }

    public func writeObject(w: JsonWriter): JsonWriter {
        w.name("id").value(id)
        w.name("title").value(title)
        w.name("content").value(content)
        w.name("url").value(url)
        w.name("pageTitle").value(pageTitle)
        w.name("breadcrumb").beginArray()
        for (item in breadcrumb) {
            w.value(item)
        }
        w.endArray()
        return w
    }
}

/**
 * 搜索索引构建器
 * 负责从文档中提取章节信息并生成搜索索引
 */
public class SearchIndexBuilder {

    /**
     * 从文档节点构建搜索索引
     *
     * @param doc 文档节点
     * @param pageUrl 页面URL
     * @param pageTitle 页面标题
     * @return 搜索索引项列表
     */
    public static func buildIndex(doc: DocumentNode, pageUrl: String, pageTitle: String): Array<SearchIndexSection> {
        let sections = ArrayList<SearchIndexSection>()
        let breadcrumb = ArrayList<String>()

        // 遍历文档的所有子节点
        extractSections(doc.children.toArray(), pageUrl, pageTitle, breadcrumb, sections)

        return sections.toArray()
    }

    /**
     * 递归提取章节信息
     */
    private static func extractSections(
        nodes: Array<Node>,
        pageUrl: String,
        pageTitle: String,
        breadcrumb: ArrayList<String>,
        sections: ArrayList<SearchIndexSection>
    ) {
        var currentHeading: ?HeadingNode = None
        var currentContent = ArrayList<String>()

        for (node in nodes) {
            // 检查是否为标题节点
            if (let headingNode: HeadingNode <- node) {
                // 如果有之前的标题，先保存它的内容
                if (let Some(heading) <- currentHeading) {
                    saveSection(heading, currentContent, pageUrl, pageTitle, breadcrumb, sections)
                    currentContent.clear()
                }

                // 更新当前标题
                currentHeading = Some(headingNode)

                // 更新面包屑
                updateBreadcrumb(breadcrumb, headingNode)
            } else {
                // 收集内容
                let text = extractTextContent(node)
                if (!text.isEmpty()) {
                    currentContent.add(text)
                }
            }
        }

        // 保存最后一个章节
        if (let Some(heading) <- currentHeading) {
            saveSection(heading, currentContent, pageUrl, pageTitle, breadcrumb, sections)
        }
    }

    /**
     * 保存章节到索引
     */
    private static func saveSection(
        heading: HeadingNode,
        content: ArrayList<String>,
        pageUrl: String,
        pageTitle: String,
        breadcrumb: ArrayList<String>,
        sections: ArrayList<SearchIndexSection>
    ) {
        // 使用toHtml()获取完整的HTML内容（包含所有子节点）
        // 前端会使用stripHtmlTags提取纯文本
        let headingHtml = heading.toHtml()
        let headingId = generateHeadingId(heading.content)
        let sectionUrl = "${pageUrl}#${headingId}"

        // 合并内容
        let contentArray = content.toArray()
        var contentText = ""
        for (i in 0..contentArray.size) {
            if (i > 0) {
                contentText = contentText + " "
            }
            contentText = contentText + contentArray[i]
        }

        // 创建索引项 - title使用HTML格式，前端会提取textContent
        let section = SearchIndexSection(
            "${pageUrl}-${headingId}",
            headingHtml, // 使用HTML格式，前端会stripHtmlTags
            contentText,
            sectionUrl,
            pageTitle,
            breadcrumb.toArray()
        )

        sections.add(section)
    }

    /**
     * 更新面包屑导航
     */
    private static func updateBreadcrumb(breadcrumb: ArrayList<String>, heading: HeadingNode) {
        let level = heading.level

        // 根据标题级别调整面包屑
        // 如果是更高级别的标题，清除后面的面包屑
        while (breadcrumb.size >= level) {
            let lastIndex = breadcrumb.size - 1
            breadcrumb.remove(lastIndex..lastIndex + 1)
        }

        // 添加当前标题 - 使用HTML格式，前端会stripHtmlTags
        breadcrumb.add(heading.toHtml())
    }

    /**
     * 提取节点的文本内容（保留HTML格式）
     */
    private static func extractTextContent(node: Node): String {
        // 使用toHtml()获取HTML内容，在JS端显示时再去除标签
        return node.toHtml()
    }

    /**
     * 生成标题ID（用于锚点）
     */
    private static func generateHeadingId(text: String): String {
        return slug(text)
    }

    /**
     * 将索引列表转换为JSON字符串
     */
    public static func toJson(sections: Array<SearchIndexSection>): String {
        buildJsonArray {
            w =>
                for (section in sections) {
                    w.beginObject()
                    section.writeObject(w)
                    w.endObject()
                }
                w
        }
    }

    /**
     * 生成search-index.js文件内容
     */
    public static func generateSearchIndexJs(allSections: Array<SearchIndexSection>): String {
        let json = toJson(allSections)

        return """
(function() {
  if (window.MarkitSearch && window.MarkitSearch.loadIndex) {
    window.MarkitSearch.loadIndex(${json});
  }
})();
"""
    }
}
