package markit_kit.services

import markit_kit.utils.KitHooks

import markit.core.nodes.{Node, DocumentNode}
import markit.plugins.commonmark.block.html_block.HTMLBlockNode
import markit.plugins.standard.block.heading.HeadingNode
import markit.plugins.standard.block.list.{UnorderedListNode, UnorderedListItemNode}
import markit.plugins.standard.block.paragraph.ParagraphNode
import markit.plugins.standard.inline.link.LinkNode
import markit.plugins.i18n.nodes.I18nBlockNode
import markit_kit.models.{SummaryConfig, SummaryOptions, Section, Chapter, GlobalContext}
import markit_kit.utils.{CliMarkitFactory, FileHandler}
import std.collection.ArrayList
import std.fs.{Path, exists, Directory}
import markit.core.source.SourceBuffer

/**
 * markit.md 解析器
 * 负责解析 markit.md 文件并提取导航结构和首页内容
 */
public class SummaryParser {
    
    /**
     * 解析 markit.md 并收集文件
     * 
     * @param rootPath 根目录路径
     * @param options Summary 选项
     * @return (收集到的文件列表, SummaryConfig)
     */
    public static func parseAndCollectFiles(
        rootPath: String,
        options: SummaryOptions
    ): (Array<String>, SummaryConfig) {
        // 1. 解析 markit.md
        let summaryConfig = parseSummary(rootPath, options)
        
        if (!summaryConfig.found) {
            // 没有 markit.md，使用默认逻辑
            KitHooks.warn("No ${options.file} found in root directory, using default file system order")
            let files = FileHandler.collectInputFiles(rootPath, summaryFileName: options.file)
            return (files, summaryConfig)
        }
        
        // 2. 按照 markit.md 收集文件
        let files = ArrayList<String>()
        let basePath = rootPath
        
        // 收集根级链接的文件
        for (chapter in summaryConfig.prefixChapters) {
            collectChapterFiles(chapter, basePath, files, options)
        }
        
        // 收集分组章节的文件
        for (section in summaryConfig.sections) {
            for (chapter in section.chapters) {
                collectChapterFiles(chapter, basePath, files, options)
            }
        }
        
        return (files.toArray(), summaryConfig)
    }
    
    /**
     * 递归收集章节中的文件
     * 
     * @param chapter 章节
     * @param basePath 基础路径
     * @param files 用于收集文件的列表
     * @param options Summary 配置选项
     */
    private static func collectChapterFiles(
        chapter: Chapter,
        basePath: String,
        files: ArrayList<String>,
        options: SummaryOptions
    ): Unit {
        if (chapter.isDraft) {
            // 草稿章节不收集文件
            return
        }
        
        let filePath = Path(basePath).join(chapter.filePath).normalize().toString()
        
        // 只排除根目录的 summary 文件（不应该被渲染）
        // 检查是否是根目录的文件（不包含路径分隔符）
        if (chapter.filePath == options.file) {
            return
        }
        
        if (!exists(Path(filePath))) {
            // 文件不存在，打印警告但继续
            KitHooks.warn("File '${chapter.filePath}' referenced in markit.md not found")
            return
        }
        
        files.add(filePath)
        
        // 递归收集子章节
        for (child in chapter.children) {
            collectChapterFiles(child, basePath, files, options)
        }
    }
    
    /**
     * 解析 markit.md 文件
     * 
     * @param rootPath 根目录路径
     * @param options Summary 选项
     * @return SummaryConfig
     */
    public static func parseSummary(
        rootPath: String, 
        options: SummaryOptions
    ): SummaryConfig {
        // 1. 检查 markit.md 是否存在
        let summaryPath = Path(rootPath).join(options.file).normalize().toString()
        if (!exists(Path(summaryPath))) {
            return SummaryConfig(
                [],
                [],
                "",
                "",
                false
            )
        }
        
        // 2. 读取并解析文件（带错误处理）
        try {
            let content = FileHandler.readFileContent(summaryPath)
            
            // 检查文件是否为空
            if (content.trimAscii().isEmpty()) {
                KitHooks.warn("${options.file} is empty, using default file system order")
                return SummaryConfig(
                    [],
                    [],
                    "",
                    "",
                    false
                )
            }
            let markit = CliMarkitFactory.buildSummaryParser(GlobalContext.renderConfig.getOrThrow())
            let parseResult = markit.parse(content)
            let document = CliMarkitFactory.documentOf(parseResult)
            
            // 3. 处理 i18n 节点（如果存在）
            // markit 解析器已经通过 i18n post processor 设置了 render meta
            // 我们只需要选择应该渲染的节点
            let targetNode = extractTargetLanguageNode(document)
            

            
            // 4. 查找 <!-- homepage --> 标记
            let (navNode, homepageNode) = splitByHomepageMarker(targetNode)
            

            
            // 5. 从导航部分提取结构
            let (sections, prefixChapters) = extractNavigationStructure(navNode)
            

            
            // 检查是否提取到任何有效内容
            if (sections.size == 0 && prefixChapters.size == 0) {
                KitHooks.warn("No valid chapters found in ${options.file}, using default file system order")
                return SummaryConfig(
                    [],
                    [],
                    "",
                    "",
                    false
                )
            }
            
            // 6. 提取首页内容
            let homepageContent = extractHomepageHtmlContent(homepageNode)
            let homepageTypstContent = extractHomepageTypstContent(homepageNode)
            
            return SummaryConfig(
                sections,
                prefixChapters,
                homepageContent,
                homepageTypstContent,
                true
            )
        } catch (e: Exception) {
            // 解析失败，打印警告并回退到默认逻辑
            KitHooks.warn("Failed to parse ${options.file}: ${e}")
            KitHooks.warn("Using default file system order")
            return SummaryConfig(
                [],
                [],
                "",
                "",
                false
            )
        }
    }
    
    /**
     * 从文档中提取目标语言的内容
     * 
     * 检查文档中的 i18n 块节点，选择应该渲染的节点（render != "false"）。
     * i18n post processor 已经根据目标语言设置了 render meta。
     * 
     * 策略：
     * 1. 如果文档包含 i18n 块节点，选择第一个 render != "false" 的 i18n 块
     * 2. 如果没有找到匹配的 i18n 块，返回整个文档（回退到默认语言）
     * 3. 如果文档不包含 i18n 块，直接返回文档
     * 
     * @param document 文档节点
     * @return 目标语言的节点
     */
    private static func extractTargetLanguageNode(document: DocumentNode): DocumentNode {
        // 检查文档的直接子节点中是否有 i18n 块
        var hasI18nBlocks = false
        let selectedChildren = ArrayList<Node>()
        
        for (child in document.children) {
            if (let i18nBlock: I18nBlockNode <- child) {
                hasI18nBlocks = true
                
                // 检查该块是否应该渲染
                let shouldRender = match (i18nBlock.string("render")) {
                    case Some(value) => value != "false"
                    case None => true  // 没有 render meta 表示应该渲染
                }
                
                if (shouldRender) {
                    for (i18nChild in i18nBlock.children) {
                        selectedChildren.add(i18nChild)
                    }
                }
            } else {
                selectedChildren.add(child)
            }
        }
        
        // 如果没有 i18n 块，直接返回原文档
        if (!hasI18nBlocks) {
            return document
        }
        
        // 保留所有非 i18n 节点，并展开当前目标语言下可渲染的 i18n 内容
        let newDoc = DocumentNode(SourceBuffer())
        for (child in selectedChildren) {
            newDoc.addChild(child)
        }
        return newDoc
    }
    
    /**
     * 检查节点是否为 <!-- homepage --> 标记
     * 支持多种格式：
     * - <!-- homepage -->
     * - <!--homepage-->
     * - <!--  homepage  -->
     * - <!-- - homepage - -->
     * 
     * @param node 节点
     * @return 是否为首页标记
     */
    private static func isHomepageMarker(node: Node): Bool {
        if (let htmlBlock: HTMLBlockNode <- node) {
            let content = htmlBlock.rawContent().trimAscii()
            
            // 检查是否以 <!-- 开头并以 --> 结尾
            if (!content.startsWith("<!--") || !content.endsWith("-->")) {
                return false
            }
            
            // 提取注释内容（去掉 <!-- 和 -->）
            if (content.size <= 7) {  // "<!--" (4) + "-->" (3) = 7
                return false
            }
            
            let innerContent = content[4..(content.size - 3)].trimAscii()
            
            // 移除可能的前后连字符和空格
            var cleaned = innerContent
            while (cleaned.size > 0 && (cleaned.startsWith("-") || cleaned.startsWith(" "))) {
                cleaned = cleaned[1..].trimAscii()
            }
            while (cleaned.size > 0 && (cleaned.endsWith("-") || cleaned.endsWith(" "))) {
                cleaned = cleaned[..(cleaned.size - 1)].trimAscii()
            }
            
            // 检查清理后的内容是否为 "homepage"
            return cleaned.toAsciiLower() == "homepage"
        }
        return false
    }
    
    /**
     * 根据 <!-- homepage --> 标记分割文档
     * 
     * @param node 文档节点或 i18n 子节点
     * @return (导航节点, 首页节点)
     */
    private static func splitByHomepageMarker(node: Node): (DocumentNode, ?DocumentNode) {
        let navChildren = ArrayList<Node>()
        let homepageChildren = ArrayList<Node>()
        var foundMarker = false
        
        for (child in node.children) {
            if (foundMarker) {
                homepageChildren.add(child)
            } else if (isHomepageMarker(child)) {
                foundMarker = true
            } else {
                navChildren.add(child)
            }
        }
        
        // 创建导航节点
        let navNode = DocumentNode(SourceBuffer())
        for (child in navChildren) {
            navNode.addChild(child)
        }
        
        // 创建首页节点（如果有）
        let homepageNode: ?DocumentNode = if (homepageChildren.size > 0) {
            let node = DocumentNode(SourceBuffer())
            for (child in homepageChildren) {
                node.addChild(child)
            }
            Some(node)
        } else {
            None
        }
        
        return (navNode, homepageNode)
    }
    
    /**
     * 从 AST 节点提取 HTML 内容
     * 
     * 对于 LinkNode：只提取子节点的 HTML（不包含 <a> 标签本身）
     * 对于 HeadingNode：只提取子节点的 HTML（不包含 <h1> 等标签）
     * 对于其他节点：递归提取子节点的 HTML
     * 
     * @param node AST 节点
     * @return HTML 内容
     */
    private static func extractTextFromNode(node: Node): String {
        // 特殊处理 LinkNode：只渲染子节点，不包含 <a> 标签
        if (let link: LinkNode <- node) {
            let html = StringBuilder()
            for (child in link.children) {
                html.append(child.toHtml())
            }
            return html.toString()
        }
        
        // 特殊处理 HeadingNode：只渲染子节点，不包含 <h1> 等标签
        if (let heading: HeadingNode <- node) {
            let html = StringBuilder()
            for (child in heading.children) {
                html.append(child.toHtml())
            }
            return html.toString()
        }
        
        // 对于其他节点，递归提取子节点的 HTML
        let html = StringBuilder()
        for (child in node.children) {
            html.append(child.toHtml())
        }
        
        return html.toString()
    }
    
    /**
     * 提取首页内容
     * 
     * @param homepageNode 首页节点（可选）
     * @return HTML 内容
     */
    private static func extractHomepageHtmlContent(homepageNode: ?DocumentNode): String {
        match (homepageNode) {
            case Some(node) =>
                let html = StringBuilder()
                for (child in node.children) {
                    html.append(child.toHtml())
                }
                return html.toString()
            case None =>
                return ""
        }
    }

    /**
     * 提取首页内容的 Typst 表示
     */
    private static func extractHomepageTypstContent(homepageNode: ?DocumentNode): String {
        match (homepageNode) {
            case Some(node) =>
                let typst = StringBuilder()
                for (child in node.children) {
                    typst.append(child.toTypst())
                }
                return typst.toString()
            case None =>
                return ""
        }
    }
    
    /**
     * 从导航节点提取分组和章节
     * 
     * @param navNode 导航节点
     * @return (分组列表, 根级链接列表)
     */
    private static func extractNavigationStructure(navNode: DocumentNode): (Array<Section>, Array<Chapter>) {
        let sections = ArrayList<Section>()
        let prefixChapters = ArrayList<Chapter>()
        var currentSectionTitle: ?String = None
        var currentSectionChapters = ArrayList<Chapter>()
        var order = 0
        
        for (child in navNode.children) {
            if (let heading: HeadingNode <- child) {
                // 一级标题作为分组
                if (heading.level == 1) {
                    // 保存上一个分组
                    match (currentSectionTitle) {
                        case Some(title) =>
                            sections.add(Section(title, currentSectionChapters.toArray()))
                        case None => ()
                    }
                    
                    // 创建新分组
                    let title = extractTextFromNode(heading)
                    currentSectionTitle = Some(title)
                    currentSectionChapters = ArrayList<Chapter>()
                }
            } else if (let list: UnorderedListNode <- child) {
                // 提取列表中的章节
                let chapters = extractChaptersFromList(list, order)
                order += chapters.size
                
                match (currentSectionTitle) {
                    case Some(_) =>
                        // 添加到当前分组
                        for (ch in chapters) {
                            currentSectionChapters.add(ch)
                        }
                    case None =>
                        // 没有分组，作为根级链接
                        for (ch in chapters) {
                            prefixChapters.add(ch)
                        }
                }
            } else if (let paragraph: ParagraphNode <- child) {
                // 段落中可能包含根级链接
                let chapter = extractChapterFromParagraph(paragraph, order)
                match (chapter) {
                    case Some(ch) =>
                        prefixChapters.add(ch)
                        order += 1
                    case None => ()
                }
            }
        }
        
        // 保存最后一个分组
        match (currentSectionTitle) {
            case Some(title) =>
                sections.add(Section(title, currentSectionChapters.toArray()))
            case None => ()
        }
        
        return (sections.toArray(), prefixChapters.toArray())
    }
    
    /**
     * 从列表节点提取章节（支持嵌套）
     * 
     * @param listNode 列表节点
     * @param startOrder 起始顺序号
     * @return 章节列表
     */
    private static func extractChaptersFromList(listNode: UnorderedListNode, startOrder: Int): Array<Chapter> {
        let chapters = ArrayList<Chapter>()
        var order = startOrder
        
        for (item in listNode.children) {
            if (let listItem: UnorderedListItemNode <- item) {
                let chapter = extractChapterFromListItem(listItem, order)
                match (chapter) {
                    case Some(ch) =>
                        chapters.add(ch)
                        order += 1
                    case None => ()
                }
            }
        }
        
        return chapters.toArray()
    }
    
    /**
     * 从列表项提取章节
     * 
     * @param listItem 列表项节点
     * @param order 顺序号
     * @return 章节（可选）
     */
    private static func extractChapterFromListItem(listItem: UnorderedListItemNode, order: Int): ?Chapter {
        var displayName = ""
        var filePath = ""
        var icon = ""
        var isDraft = false
        let children = ArrayList<Chapter>()
        
        // 遍历列表项的子节点
        for (child in listItem.children) {
            if (let link: LinkNode <- child) {
                // 直接从列表项中提取链接（tight list 的情况）
                displayName = extractTextFromNode(link)
                filePath = link.url
                icon = extractNavIcon(link)
                isDraft = filePath.isEmpty()
            } else if (let paragraph: ParagraphNode <- child) {
                // 从段落中提取链接（loose list 的情况）
                for (inline in paragraph.children) {
                    if (let link: LinkNode <- inline) {
                        displayName = extractTextFromNode(link)
                        filePath = link.url
                        icon = extractNavIcon(link)
                        isDraft = filePath.isEmpty()
                        break
                    }
                }
            } else if (let sublist: UnorderedListNode <- child) {
                // 递归处理子列表
                let subChapters = extractChaptersFromList(sublist, 0)
                for (subCh in subChapters) {
                    children.add(subCh)
                }
            }
        }
        
        if (displayName.isEmpty()) {
            // 跳过无效的列表项（没有链接或链接文本为空）
            return None
        }
        
        return Some(Chapter(
            displayName,
            filePath,
            icon,
            isDraft,
            children.toArray(),
            order
        ))
    }
    
    /**
     * 从段落提取根级链接
     * 
     * @param paragraph 段落节点
     * @param order 顺序号
     * @return 章节（可选）
     */
    private static func extractChapterFromParagraph(paragraph: ParagraphNode, order: Int): ?Chapter {
        // 查找段落中的第一个链接
        for (child in paragraph.children) {
            if (let link: LinkNode <- child) {
                let displayName = extractTextFromNode(link)
                let filePath = link.url
                let icon = extractNavIcon(link)
                let isDraft = filePath.isEmpty()
                
                if (!displayName.isEmpty()) {
                    return Some(Chapter(
                        displayName,
                        filePath,
                        icon,
                        isDraft,
                        [],
                        order
                    ))
                }
            }
        }
        
        // 没有找到有效的链接，跳过此段落
        return None
    }

    private static func extractNavIcon(link: LinkNode): String {
        let title = link.title.trimAscii()
        if (title.startsWith("nav-icon:")) {
            return title.removePrefix("nav-icon:").trimAscii()
        }
        if (title.startsWith("icon:")) {
            return title.removePrefix("icon:").trimAscii()
        }
        return ""
    }
}
