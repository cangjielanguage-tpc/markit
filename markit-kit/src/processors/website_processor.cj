package markit_kit.processors

import markit.Markit
import markit_kit.interfaces.Processor
import markit_kit.themes.{Theme, ThemeManager}
import markit_kit.models.{SiteStructure, SiteNavigation, FileTreeNode, HeadingInfo, SitePage, SummaryConfig, SummaryOptions, Chapter, Section, GlobalContext, RenderConfig}
import markit_kit.components.LanguageSwitcher
import markit.plugins.standard.inline.link.LinkConfig
import markit.plugins.i18n.config.I18nConfig
import markit.core.nodes.{Node, DocumentNode}
import markit.core.render.HtmlEscaper
import markit.plugins.standard.block.heading.HeadingNode
import std.collection.ArrayList
import markit.plugins.toc.{Toc, TocItem}
import std.fs.Path
import std.convert.*
import markit_kit.utils.{CliMarkitFactory, PathUtils}

/**
 * 网站处理器
 * 生成带有统一导航的文档网站
 */
public class WebsiteProcessor <: Processor {
    private let renderConfig: RenderConfig
    private var linkConfig: LinkConfig
    private var headingInitialState: Array<Int64>
    public let theme: Theme
    public let enableToc: Bool
    public let devMode: Bool
    public let siteTitle: String
    private var siteStructure: ?SiteStructure = None
    private var siteNavigation: ?SiteNavigation = None
    private var summaryConfig: ?SummaryConfig = None
    private var summaryOptions: SummaryOptions = SummaryOptions()
    private let headingNumberingEnabled: Bool
    private let headingResetFor: String
    private let i18nConfig: ?I18nConfig
    private let chapterNavigation: Bool
    private let chapterPrevText: String
    private let chapterNextText: String
    private let statisticTotalTexts: Bool
    private let statisticTotalTextsTemplate: String
    private let statisticSpentTime: Bool
    private let statisticSpentTimeTemplate: String
    private let statisticSecond: String
    private let statisticMinute: String
    private let gitPrefix: String
    private let reposGithub: String
    private let reposGitcode: String
    private let reposGitee: String
    private let reposGitlab: String
    private let listMultiLevelOrderedList: Bool
    private let currentLanguage: String
    private let availableLanguages: Array<String>
    private let baseUrl: ?String
    private let customJsAssets: Array<String>
    private let customCssAssets: Array<String>
    private let websiteCodeLigatures: Bool
    
    /**
     * 主构造函数
     * 
     * 从 GlobalContext 读取所有配置，不再接受大量参数
     * 
     * @param themeName 主题名称（可选，从 GlobalContext 读取）
     * @param markit Markit解析器实例（可选）
     */
    public init(
        themeName!: String = ""
    ) {
        // 从 GlobalContext 读取配置
        let config = GlobalContext.renderConfig.getOrThrow()
        this.renderConfig = config
        this.linkConfig = GlobalContext.linkConfig ?? LinkConfig()
        this.headingInitialState = CliMarkitFactory.defaultHeadingState(config)
        
        let actualHeadingConfig = CliMarkitFactory.defaultHeadingNumberingConfig(config)
        this.headingNumberingEnabled = actualHeadingConfig.enabled
        this.headingResetFor = config.headingResetFor
        this.chapterNavigation = config.chapterNavigation
        this.chapterPrevText = config.chapterPrevText
        this.chapterNextText = config.chapterNextText
        this.statisticTotalTexts = config.statisticTotalTexts
        this.statisticTotalTextsTemplate = config.statisticTotalTextsTemplate
        this.statisticSpentTime = config.statisticSpentTime
        this.statisticSpentTimeTemplate = config.statisticSpentTimeTemplate
        this.statisticSecond = config.statisticSecond
        this.statisticMinute = config.statisticMinute
        this.gitPrefix = config.gitPrefix
        this.reposGithub = config.reposGithub
        this.reposGitcode = config.reposGitcode
        this.reposGitee = config.reposGitee
        this.reposGitlab = config.reposGitlab
        this.listMultiLevelOrderedList = config.listMultiLevelOrderedList
        
        // 初始化语言上下文
        this.currentLanguage = GlobalContext.currentLanguage
        this.availableLanguages = GlobalContext.availableLanguages
        
        this.baseUrl = GlobalContext.baseUrl
        this.customJsAssets = config.customJsAssets
        this.customCssAssets = config.customCssAssets
        this.websiteCodeLigatures = config.websiteCodeLigatures
        
        let actualThemeName = if (themeName.isEmpty()) { config.themeName } else { themeName }
        this.theme = ThemeManager.getTheme(actualThemeName)
        this.enableToc = config.enableToc
        this.devMode = config.devMode
        this.siteTitle = config.siteTitle
        this.i18nConfig = config.i18nConfig
        
        // 初始化网站导航
        this.siteNavigation = SiteNavigation()
    }
    
    /**
     * 设置网站结构
     * 
     * 已弃用 - 使用 GlobalContext.siteStructure 代替
     * 
     * @param structure 网站结构
     */
    public func setSiteStructure(structure: SiteStructure): Unit {
        GlobalContext.siteStructure = structure
        this.siteStructure = Some(structure)
    }
    
    /**
     * 设置 Summary 配置
     * 
     * 已弃用 - 使用 GlobalContext.summaryConfig 和 GlobalContext.summaryOptions 代替
     * 
     * @param config Summary 配置
     * @param options Summary 选项
     */
    public func setSummaryConfig(config: SummaryConfig, options: SummaryOptions): Unit {
        GlobalContext.summaryConfig = config
        GlobalContext.summaryOptions = options
        this.summaryConfig = Some(config)
        this.summaryOptions = options
    }
    
    /**
     * 重置全局标题编号器
     * 在开始处理新的目录时调用（仅在 directory 模式下需要）
     */
    public func resetGlobalNumbering(): Unit {
        headingInitialState = CliMarkitFactory.defaultHeadingState(renderConfig)
    }

    public func setLinkConfig(config: LinkConfig): Unit {
        this.linkConfig = config
    }

    public func setHeadingInitialState(state: Array<Int64>): Unit {
        this.headingInitialState = state
    }

    private func createParser(currentPagePath: String): Markit {
        return CliMarkitFactory.build(
            renderConfig,
            linkConfig: Some(linkConfig),
            currentPagePath: currentPagePath,
            headingInitialState: Some(headingInitialState)
        )
    }
    
    /**
     * 根据 resetFor 策略决定是否需要重置编号
     * 
     * @return 是否需要在目录切换时重置
     */
    public func shouldResetOnDirectoryChange(): Bool {
        return headingResetFor == "directory"
    }
    
    /**
     * 处理Markdown内容为网站HTML
     * 
     * @param content Markdown内容
     * @param title 页面标题
     * @param currentPagePath 当前页面路径（用于导航高亮）
     * @param asDocument 是否作为简单文档处理（不带侧边栏）
     * @return 元组：(完整的网站HTML文档, 解析后的文档节点)
     */
    public func process(content: String, title: String, currentPagePath!: String = "", asDocument!: Bool = false): (String, DocumentNode) {
        if (asDocument) {
            return processAsDocument(content, title)
        } else {
            return processWithPath(content, title, currentPagePath)
        }
    }
    
    /**
     * 处理Markdown内容为简单文档HTML（不带侧边栏）
     * 
     * @param content Markdown内容
     * @param title 页面标题
     * @return 元组：(完整的文档HTML, 解析后的文档节点)
     */
    public func processAsDocument(content: String, title: String): (String, DocumentNode) {
        // 使用Markit解析Markdown并转换为HTML
        let parseResult = try {
            createParser("").parse(content)
        } catch (e: Exception) {
            throw IllegalArgumentException("WebsiteProcessor parse failed for document '${title}': ${e.toString()}")
        }
        let document = try {
            CliMarkitFactory.documentOf(parseResult)
        } catch (e: Exception) {
            throw IllegalArgumentException("WebsiteProcessor document extraction failed for document '${title}': ${e.toString()}")
        }
        
        // 生成文档HTML
        var htmlContent = try {
            document.toHtml()
        } catch (e: Exception) {
            throw IllegalArgumentException("WebsiteProcessor HTML render failed for document '${title}': ${e.toString()}")
        }
        htmlContent = htmlContent + generateMarkdownSourceStore(content)
        htmlContent = try {
            rewriteLocalImageSources(htmlContent, "")
        } catch (e: Exception) {
            throw IllegalArgumentException("WebsiteProcessor asset rewrite failed for document '${title}': ${e.toString()}")
        }
        
        // 只在启用TOC时生成悬浮TOC（单独传递）
        var floatingToc = ""
        if (enableToc) {
            floatingToc = generateFloatingToc(document)
        }
        
        // 使用简单的文档模板（不带侧边栏）
        return (generateDocumentHtml(htmlContent, title, floatingToc), document)
    }
    
    /**
     * 处理Markdown内容为网站HTML（带路径信息）
     * 
     * @param content Markdown内容
     * @param title 页面标题
     * @param currentPagePath 当前页面的路径（用于准确识别当前页面）
     * @return 元组：(完整的网站HTML文档, 解析后的文档节点)
     */
    public func processWithPath(content: String, title: String, currentPagePath: String): (String, DocumentNode) {
        // 使用Markit解析Markdown并转换为HTML
        let parseResult = try {
            createParser(currentPagePath).parse(content)
        } catch (e: Exception) {
            throw IllegalArgumentException("WebsiteProcessor parse failed for ${currentPagePath}: ${e.toString()}")
        }
        let document = try {
            CliMarkitFactory.documentOf(parseResult)
        } catch (e: Exception) {
            throw IllegalArgumentException("WebsiteProcessor document extraction failed for ${currentPagePath}: ${e.toString()}")
        }
        
        // 提取当前文档的标题信息用于导航
        let headings = extractHeadings(document)
        match (siteNavigation) {
            case Some(nav) => 
                nav.addPageHeadings(title, headings)
            case None => ()
        }
        
        // 生成文档HTML
        var htmlContent = try {
            document.toHtml()
        } catch (e: Exception) {
            throw IllegalArgumentException("WebsiteProcessor HTML render failed for ${currentPagePath}: ${e.toString()}")
        }
        htmlContent = htmlContent + generateMarkdownSourceStore(content)
        htmlContent = try {
            rewriteLocalImageSources(htmlContent, currentPagePath)
        } catch (e: Exception) {
            throw IllegalArgumentException("WebsiteProcessor asset rewrite failed for ${currentPagePath}: ${e.toString()}")
        }
        
        // 生成 article-extra 容器（包含页面复制、git-link 和 statistic）
        var articleExtra = ""
        
        // 如果启用 Git 链接，添加到 article-extra
        let gitLink = generateGitLink(currentPagePath)
        if (!gitLink.isEmpty()) {
            articleExtra = articleExtra + gitLink
        }
        articleExtra = articleExtra + generateCopyMarkdownButton(content)
        
        // 如果启用统计信息，添加到 article-extra
        if (statisticTotalTexts || statisticSpentTime) {
            let statisticHtml = generateStatisticHtml(content)
            if (!statisticHtml.isEmpty()) {
                articleExtra = articleExtra + statisticHtml
            }
        }
        
        // 如果有 article-extra 内容，包装并添加到 htmlContent 开头
        if (!articleExtra.isEmpty()) {
            htmlContent = "<div class=\"article-extra\">" + articleExtra + "</div>" + htmlContent
        }
        
        // 如果启用章节导航，在内容末尾添加上一篇/下一篇导航
        if (chapterNavigation) {
            let chapterNav = generateChapterNavigation(currentPagePath)
            if (!chapterNav.isEmpty()) {
                htmlContent = htmlContent + chapterNav
            }
        }
        
        // 在启用TOC时生成悬浮TOC（单独传递，不添加到 htmlContent）
        var floatingToc = ""
        if (enableToc) {
            floatingToc = generateFloatingToc(document)
        }
        
        // 生成导航HTML（传入当前页面路径用于准确识别）
        let navigationHtml = generateNavigationHtml(currentPageTitle: title, currentPagePath: currentPagePath)
        
        // 使用主题生成完整的网站HTML文档，传递 TOC
        return (generateWebsiteHtmlWithPath(htmlContent, title, navigationHtml, currentPagePath, floatingToc: floatingToc), document)
    }
    
    /**
     * 将已经是HTML的内容包装成完整的网站HTML（不进行Markdown解析）
     * 用于首页内容等已经通过toHtml()转换的内容
     * 
     * @param htmlContent 已经是HTML格式的内容
     * @param title 页面标题
     * @param currentPagePath 当前页面的路径
     * @return 完整的网站HTML文档
     */
    public func wrapHtmlContent(htmlContent: String, title: String, currentPagePath: String): String {
        // 首页不需要导航栏和 TOC
        let navigationHtml = ""
        let rewrittenContent = rewriteLocalImageSources(htmlContent, currentPagePath)
        
        // 直接使用传入的HTML内容，不进行Markdown解析
        return generateWebsiteHtmlWithPath(rewrittenContent, title, navigationHtml, currentPagePath, floatingToc: "")
    }
    
    /**
     * 生成悬浮TOC
     * 使用 Toc 插件生成 TocNode，然后渲染成悬浮 TOC 的 HTML 格式
     */
    private func generateFloatingToc(document: DocumentNode): String {
        // 使用 Toc 插件生成 TocNode（只包含 H1-H3）
        let tocNode = Toc.parse(document, title: uiText("Contents", "目录"), minLevel: 1, maxLevel: 3)
        
        if (tocNode.items.size == 0) {
            return ""
        }
        
        let toc = ArrayList<String>()
        toc.add("<div class=\"floating-toc\" id=\"floating-toc\">")
        toc.add("    <div class=\"floating-toc-header\">")
        toc.add("        <span class=\"floating-toc-title\">${tocNode.title}</span>")
        toc.add("        <button class=\"floating-toc-toggle\" onclick=\"toggleFloatingToc()\">−</button>")
        toc.add("    </div>")
        toc.add("    <div class=\"floating-toc-content\" id=\"floating-toc-content\">")
        toc.add("        <ul class=\"floating-toc-list\">")
        
        // 递归渲染 TocNode 的所有项
        renderFloatingTocItems(tocNode.items.toArray(), toc, 0)
        
        toc.add("        </ul>")
        toc.add("    </div>")
        toc.add("</div>")
        
        return String.join(toc.toArray(), delimiter: "\n")
    }
    
    /**
     * 递归渲染悬浮 TOC 项
     */
    private func renderFloatingTocItems(items: Array<TocItem>, toc: ArrayList<String>, depth: Int): Unit {
        for (item in items) {
            var indent = "            "
            for (_ in 0..depth) {
                indent += "    "
            }
            
            toc.add("${indent}<li class=\"floating-toc-item level-${item.level}\">")
            
            // 渲染链接，如果有编号则显示编号
            let anchorId = item.anchorId
            let text = HtmlEscaper.escape(item.text)
            if (!item.number.isEmpty()) {
                let number = HtmlEscaper.escape(item.number)
                toc.add("${indent}    <a href=\"#${anchorId}\" class=\"floating-toc-link\">${number} ${text}</a>")
            } else {
                toc.add("${indent}    <a href=\"#${anchorId}\" class=\"floating-toc-link\">${text}</a>")
            }
            
            // 如果有子项，递归渲染
            if (item.children.size > 0) {
                toc.add("${indent}    <ul class=\"floating-toc-sublist\">")
                
                // 将 children (ArrayList<Node>) 转换为 Array<TocItem>
                let childItems = ArrayList<TocItem>()
                for (child in item.children) {
                    if (let tocItem: TocItem <- child) {
                        childItems.add(tocItem)
                    }
                }
                renderFloatingTocItems(childItems.toArray(), toc, depth + 1)
                
                toc.add("${indent}    </ul>")
            }
            
            toc.add("${indent}</li>")
        }
    }
    
    /**
     * 从文档中提取标题信息
     */
    private func extractHeadings(document: DocumentNode): Array<HeadingInfo> {
        // 使用 Toc 插件提取标题信息
        let headingList = Toc.extractDetailedHeadingList(document, minLevel: 1, maxLevel: 3)
        let headings = ArrayList<HeadingInfo>()
        
        for ((text, level, number, id) in headingList) {
            let headingInfo = HeadingInfo(level, text, id, number)
            headings.add(headingInfo)
        }
        
        return headings.toArray()
    }
    
    /**
     * 获取处理器支持的文件扩展名
     */
    public func getExtension(): String {
        return "html"
    }
    
    /**
     * 获取处理器类型描述
     */
    public func getType(): String {
        return "Website (${theme.getName()} theme)"
    }
    
    /**
     * 生成简单的文档HTML（不带侧边栏）
     */
    private func generateDocumentHtml(content: String, title: String, floatingToc: String): String {
        let template = theme.getWebsiteTemplateWithPaths(devMode, "")
        let styles = theme.getStyles()
        
        // 将内容和 TOC 组合
        var mainContent = "<div class=\"content\">\n${content}\n</div>"
        if (!floatingToc.isEmpty()) {
            mainContent = mainContent + "\n${floatingToc}"
        }
        
        // 生成自定义assets HTML（document模式使用空相对路径）
        let customCssHtml = generateCustomCssAssetsHtml("")
        let customJsHtml = generateCustomJsAssetsHtml("")
        
        // 使用 document-mode 类来隐藏侧边栏
        var html = template
        html = html.replace("{{title}}", title)
        html = html.replace("{{siteTitle}}", title)
        html = html.replace("{{homeLink}}", "#")
        html = html.replace("{{topNavLinks}}", "")
        html = html.replace("{{styles}}", styles)
        html = html.replace("{{content}}", mainContent)
        html = html.replace("{{navigation}}", "") // 空导航
        html = html.replace("{{lang}}", effectiveLanguage())
        html = html.replace("{{languageSwitcher}}", "")
        html = html.replace("{{repoButtons}}", "")
        html = html.replace("{{hreflangTags}}", "")
        html = html.replace("{{customCssAssets}}", customCssHtml)
        html = html.replace("{{customJsAssets}}", customJsHtml)
        html = applyLocalizedUiText(html)
        
        // 添加 document-mode 类到 body 或 website-container
        var bodyClasses = "document-mode"
        if (listMultiLevelOrderedList) {
            bodyClasses = bodyClasses + " multi-level-ordered-list"
        }
        if (!websiteCodeLigatures) {
            bodyClasses = bodyClasses + " no-ligatures"
        }
        html = html.replace("<body>", "<body class=\"${bodyClasses}\">")
        html = html.replace("class=\"website-container\"", "class=\"website-container ${bodyClasses}\"")
        
        return html
    }
    
    /**
     * 生成网站HTML文档（带路径信息）
     */
    private func generateWebsiteHtmlWithPath(content: String, title: String, navigation: String, currentPagePath: String, floatingToc!: String = ""): String {
        let normalizedPagePath = normalizeWebsitePagePath(currentPagePath)

        // 计算相对路径
        let relativePath = calculateRelativePath(normalizedPagePath)
        
        // 计算首页链接（相对于当前页面）
        let homeLink = relativePath + "index.html"
        
        // 判断是否为首页
        let isHomePage = normalizedPagePath == "index.html" || normalizedPagePath.isEmpty()
        
        // 生成顶部导航链接
        let topNavLinks = generateTopNavLinks(relativePath, isHomePage)
        
        // 生成语言切换器 HTML（仅多语言模式）
        let languageSwitcherHtml = LanguageSwitcher.generate(
            currentLanguage,
            availableLanguages,
            normalizedPagePath
        )
        
        // 生成 hreflang 标签（仅多语言模式）
        let hreflangTags = generateHreflangTags(normalizedPagePath)
        
        // 生成自定义assets HTML
        let customCssHtml = generateCustomCssAssetsHtml(relativePath)
        let customJsHtml = generateCustomJsAssetsHtml(relativePath)
        
        let template = theme.getWebsiteTemplateWithPaths(devMode, relativePath)
        let styles = theme.getStyles()
        
        // 将内容和 TOC 组合
        var mainContent = "<div class=\"content\">\n${content}\n</div>"
        if (!floatingToc.isEmpty()) {
            mainContent = mainContent + "\n${floatingToc}"
        }
        
        var html = template
        html = html.replace("{{title}}", title)
        html = html.replace("{{siteTitle}}", siteTitle)
        html = html.replace("{{homeLink}}", homeLink)
        html = html.replace("{{topNavLinks}}", topNavLinks)
        html = html.replace("{{styles}}", styles)
        html = html.replace("{{content}}", mainContent)
        html = html.replace("{{navigation}}", navigation)
        html = html.replace("{{lang}}", effectiveLanguage())
        html = html.replace("{{languageSwitcher}}", languageSwitcherHtml)
        html = html.replace("{{repoButtons}}", generateRepoButtons())
        html = html.replace("{{hreflangTags}}", hreflangTags)
        html = html.replace("{{customCssAssets}}", customCssHtml)
        html = html.replace("{{customJsAssets}}", customJsHtml)
        html = applyLocalizedUiText(html)
        
        // 构建 body 类列表
        var bodyClasses = ArrayList<String>()
        
        // 如果是首页且有自定义首页内容，添加 homepage 类来隐藏侧边栏
        if (isHomePage) {
            match (summaryConfig) {
                case Some(config) =>
                    if (config.found && !config.homepageContent.isEmpty()) {
                        bodyClasses.add("homepage")
                    }
                case None => ()
            }
        }
        
        // 如果启用了多层级有序列表样式，添加 multi-level-ordered-list 类
        if (listMultiLevelOrderedList) {
            bodyClasses.add("multi-level-ordered-list")
        }

        // 如果禁用了代码连字，添加 no-ligatures 类
        if (!websiteCodeLigatures) {
            bodyClasses.add("no-ligatures")
        }
        
        // 应用 body 类
        if (bodyClasses.size > 0) {
            let classStr = String.join(bodyClasses.toArray(), delimiter: " ")
            html = html.replace("<body>", "<body class=\"${classStr}\">")
            html = html.replace("class=\"website-container\"", "class=\"website-container ${classStr}\"")
        }
        
        return html
    }

    private func effectiveLanguage(): String {
        if (!currentLanguage.isEmpty()) {
            return currentLanguage
        }
        match (i18nConfig) {
            case Some(config) => return config.targetLanguage
            case None => return "en"
        }
    }

    private func isChineseLanguage(): Bool {
        return effectiveLanguage().toAsciiLower().startsWith("zh")
    }

    private func uiText(en: String, zh: String): String {
        if (isChineseLanguage()) {
            return zh
        }
        return en
    }

    private func applyLocalizedUiText(template: String): String {
        var html = template
        html = html.replace("{{sidebarToggleTooltip}}", uiText("Hide sidebar", "隐藏侧边栏"))
        html = html.replace("{{searchTriggerText}}", uiText("Search (Ctrl+K)", "搜索 (Ctrl+K)"))
        html = html.replace("{{themeToggleTooltip}}", uiText("Toggle theme", "切换主题"))
        html = html.replace("{{searchPlaceholder}}", uiText("Search documentation...", "搜索文档..."))
        html = html.replace("{{searchCloseText}}", uiText("Close (Esc)", "关闭 (Esc)"))
        html = html.replace("{{searchHintText}}", uiText("Type to search...", "输入关键词开始搜索..."))
        html = html.replace("{{previousText}}", uiText("Previous", "上一页"))
        html = html.replace("{{nextText}}", uiText("Next", "下一页"))
        html = html.replace("{{backToTopText}}", uiText("Back to top", "返回顶部"))
        html = html.replace("{{copyReferenceLinkText}}", uiText("Copy reference link", "复制引用链接"))
        html = html.replace("{{copyBlockMarkdownText}}", uiText("Copy block Markdown", "复制块 Markdown"))
        html = html.replace("{{copiedText}}", uiText("Copied", "已复制"))
        return html
    }
    
    /**
     * 生成顶部导航链接
     * 
     * @param relativePath 相对路径前缀（到根目录）
     * @param isHomePage 是否为首页
     * @return 顶部导航链接HTML
     */
    private func generateTopNavLinks(relativePath: String, isHomePage: Bool): String {
        // 从 GlobalContext 读取配置
        let summaryConfig = GlobalContext.summaryConfig
        let config = GlobalContext.renderConfig.getOrThrow()
        
        // 检查是否有自定义首页内容
        var hasCustomHomepage = false
        match (summaryConfig) {
            case Some(config) =>
                if (config.found && !config.homepageContent.isEmpty()) {
                    hasCustomHomepage = true
                }
            case None => ()
        }
        
        // 只有在有自定义首页时才显示导航链接
        if (!hasCustomHomepage) {
            return ""
        }
        
        // 获取i18n文本
        var homeText = "Home"
        var documentationText = "Documentation"
        match (config.i18nConfig) {
            case Some(i18nConfig) =>
                homeText = i18nConfig.homeText
                documentationText = i18nConfig.documentationText
            case None => ()
        }
        
        // 找到第一个文档页面
        var firstDocPath = ""
        match (summaryConfig) {
            case Some(config) =>
                // 优先使用 prefixChapters 的第一个非草稿章节
                for (chapter in config.prefixChapters) {
                    if (!chapter.isDraft && !chapter.filePath.isEmpty()) {
                        let normalizedPath = PathUtils.normalizePath(chapter.filePath)
                        firstDocPath = normalizedPath.replace(".md", ".html").replace(".markdown", ".html")
                        break
                    }
                }
                
                // 如果没有找到，使用第一个 section 的第一个章节
                if (firstDocPath.isEmpty()) {
                    for (section in config.sections) {
                        for (chapter in section.chapters) {
                            if (!chapter.isDraft && !chapter.filePath.isEmpty()) {
                                let normalizedPath = PathUtils.normalizePath(chapter.filePath)
                                firstDocPath = normalizedPath.replace(".md", ".html").replace(".markdown", ".html")
                                break
                            }
                        }
                        if (!firstDocPath.isEmpty()) {
                            break
                        }
                    }
                }
            case None => ()
        }
        
        let homeActiveClass = if (isHomePage) { " active" } else { "" }
        let docActiveClass = if (!isHomePage) { " active" } else { "" }
        
        // 计算语言目录内的相对路径（不使用 relativePath，因为链接在同一语言目录内）
        let langRelativePath = PathUtils.calculateLanguageDirRelativePath(relativePath)
        
        let links = ArrayList<String>()
        links.add("<a href=\"${langRelativePath}index.html\" class=\"top-nav-link${homeActiveClass}\">${homeText}</a>")
        
        if (!firstDocPath.isEmpty()) {
            links.add("<a href=\"${langRelativePath}${firstDocPath}\" class=\"top-nav-link${docActiveClass}\">${documentationText}</a>")
        }
        
        return String.join(links.toArray(), delimiter: "\n                    ")
    }
    
    /**
     * 计算相对路径前缀
     * 
     * @param currentPagePath 当前页面路径（如 "docs/guide/intro.html"）
     * @return 相对路径前缀（如 "../../" 或 ""）
     */
    private func calculateRelativePath(currentPagePath: String): String {
        let normalizedPagePath = normalizeCurrentPagePath(currentPagePath)
        if (normalizedPagePath.isEmpty()) {
            return ""
        }
        
        // 计算目录深度
        let pathParts = normalizedPagePath.split("/")
        var depth = 0
        
        // 计算除了文件名之外的目录层级数
        for (i in 0..(pathParts.size - 1)) {
            let part = pathParts[i]
            if (!part.isEmpty()) {
                depth += 1
            }
        }
        
        // 所有页面至少在语言目录中（如 /zh/），需要额外一层
        depth += 1
        
        // 生成相对路径前缀
        var relativePath = ""
        for (_ in 0..depth) {
            relativePath += "../"
        }
        
        return relativePath
    }

    /**
     * 将页面路径规范为语言目录内的路径。
     *
     * 网站输出始终位于 dist/<language>/ 下，而 assets/ 与 public/ 位于 dist/ 根。
     * 某些调用方可能传入 "index.html"，也可能传入 "zh/index.html"；这里统一剥掉语言前缀，
     * 避免共享资源路径被算成 zh/assets 或 zh/public。
     */
    private func normalizeCurrentPagePath(currentPagePath: String): String {
        var normalizedPath = currentPagePath.replace("\\", "/")

        while (normalizedPath.startsWith("./")) {
            normalizedPath = normalizedPath[2..]
        }

        while (normalizedPath.startsWith("/")) {
            normalizedPath = normalizedPath[1..]
        }

        if (!currentLanguage.isEmpty()) {
            if (normalizedPath == currentLanguage) {
                return ""
            }

            let currentLanguagePrefix = currentLanguage + "/"
            if (normalizedPath.startsWith(currentLanguagePrefix)) {
                return normalizedPath[currentLanguagePrefix.size..]
            }
        }

        for (language in availableLanguages) {
            if (language.isEmpty()) {
                continue
            }

            if (normalizedPath == language) {
                return ""
            }

            let languagePrefix = language + "/"
            if (normalizedPath.startsWith(languagePrefix)) {
                return normalizedPath[languagePrefix.size..]
            }
        }

        return normalizedPath
    }

    private func normalizeWebsitePagePath(currentPagePath: String): String {
        let normalizedPagePath = normalizeCurrentPagePath(currentPagePath)
        if (normalizedPagePath.isEmpty() && !currentLanguage.isEmpty()) {
            return "index.html"
        }
        return normalizedPagePath
    }
    
    /**
     * 计算页面深度（路径中的 / 数量）
     * 
     * @param pagePath 页面路径
     * @return 深度值
     */
    private func calculatePageDepth(pagePath: String): Int64 {
        var count: Int64 = 0
        let runes = pagePath.toRuneArray()
        let slashRune = r'/'
        
        // 遍历 RuneArray 中的每个字符
        for (i in 0..runes.size) {
            if (runes[i] == slashRune) {
                count += 1
            }
        }
        return count
    }
    
    /**
     * 生成自定义CSS assets的HTML标签
     * 
     * @param relativePath 相对路径前缀（到根目录）
     * @return CSS link标签的HTML字符串
     */
    private func generateCustomCssAssetsHtml(relativePath: String): String {
        if (customCssAssets.size == 0) {
            return ""
        }
        
        let tags = ArrayList<String>()
        for (cssPath in customCssAssets) {
            let finalPath = resolveAssetPath(cssPath, relativePath)
            tags.add("    <link rel=\"stylesheet\" href=\"${finalPath}\">")
        }
        
        return String.join(tags.toArray(), delimiter: "\n")
    }
    
    /**
     * 生成自定义JS assets的HTML标签
     * 
     * @param relativePath 相对路径前缀（到根目录）
     * @return script标签的HTML字符串
     */
    private func generateCustomJsAssetsHtml(relativePath: String): String {
        if (customJsAssets.size == 0) {
            return ""
        }
        
        let tags = ArrayList<String>()
        for (jsPath in customJsAssets) {
            let finalPath = resolveAssetPath(jsPath, relativePath)
            tags.add("    <script src=\"${finalPath}\"></script>")
        }
        
        return String.join(tags.toArray(), delimiter: "\n")
    }
    
    /**
     * 解析资源路径（处理http/https和相对路径）
     * 
     * @param assetPath 原始资源路径
     * @param relativePath 相对路径前缀（到根目录）
     * @return 解析后的完整路径
     */
    private func resolveAssetPath(assetPath: String, relativePath: String): String {
        // 如果是绝对URL（http://或https://），直接返回
        if (assetPath.startsWith("http://") || assetPath.startsWith("https://")) {
            return assetPath
        }
        
        // 相对路径：映射到public目录
        return "${relativePath}public/${assetPath}"
    }

    private func rewriteLocalImageSources(htmlContent: String, currentPagePath: String): String {
        let relativePath = calculateRelativePath(currentPagePath)
        let parts = htmlContent.split("<img ")
        if (parts.size <= 1) {
            return htmlContent
        }

        var rewritten = parts[0]
        for (i in 1..parts.size) {
            let segment = parts[i]
            rewritten += "<img " + rewriteImageTagSegment(segment, relativePath)
        }
        return rewritten
    }

    private func rewriteImageTagSegment(segment: String, relativePath: String): String {
        let srcToken = "src=\""
        if (let Some(srcIndex) <- segment.indexOf(srcToken)) {
            let valueStart = srcIndex + srcToken.size
            if (let Some(offset) <- segment[valueStart..].indexOf("\"")) {
                let valueEnd = valueStart + offset
                let originalSrc = segment[valueStart..valueEnd]
                if (shouldRewriteLocalImageSource(originalSrc)) {
                    let rewrittenSrc = resolveAssetPath(normalizeLocalAssetPath(originalSrc), relativePath)
                    return segment[..valueStart] + rewrittenSrc + segment[valueEnd..]
                }
            }
        }
        return segment
    }

    private func shouldRewriteLocalImageSource(src: String): Bool {
        return PathUtils.isRelativeLocalPath(src)
    }

    private func normalizeLocalAssetPath(path: String): String {
        return PathUtils.stripLeadingRelativeSegments(path)
    }
    
    /**
     * 生成 SEO hreflang 标签（用于多语言构建）
     * 
     * @param currentPagePath 当前页面路径（如 "docs/guide/intro.html"）
     * @return hreflang 标签的 HTML 字符串
     */
    private func generateHreflangTags(currentPagePath: String): String {
        // 单语言模式不需要 hreflang 标签
        if (availableLanguages.size <= 1) {
            return ""
        }
        
        let tags = ArrayList<String>()
        
        // 为每个可用语言生成 hreflang 标签
        for (lang in availableLanguages) {
            let url = calculateLanguageUrl(lang, currentPagePath)
            tags.add("    <link rel=\"alternate\" hreflang=\"${lang}\" href=\"${url}\">")
        }
        
        // 添加 x-default 指向默认语言（第一个语言）
        let defaultLang = availableLanguages[0]
        let defaultUrl = calculateLanguageUrl(defaultLang, currentPagePath)
        tags.add("    <link rel=\"alternate\" hreflang=\"x-default\" href=\"${defaultUrl}\">")
        
        return String.join(tags.toArray(), delimiter: "\n")
    }
    
    /**
     * 计算语言版本的 URL
     * 
     * @param language 目标语言代码
     * @param pagePath 页面路径（相对于语言文件夹）
     * @return 完整的 URL（绝对或相对）
     */
    private func calculateLanguageUrl(language: String, pagePath: String): String {
        match (baseUrl) {
            case Some(base) =>
                // 如果提供了 baseUrl，使用绝对 URL
                return "${base}/${language}/${pagePath}"
            case None =>
                // 否则使用相对路径
                let depth = calculatePageDepth(pagePath)
                var relativePath = ""
                
                // 回到根目录（深度 + 1）
                for (_ in 0..(depth + 1)) {
                    relativePath += "../"
                }
                
                return "${relativePath}${language}/${pagePath}"
        }
    }
    
    /**
     * 生成导航HTML
     */
    private func generateNavigationHtml(currentPageTitle!: String = "", currentPagePath!: String = ""): String {
        // 从 GlobalContext 读取配置
        let summaryConfig = GlobalContext.summaryConfig
        let summaryOptions = GlobalContext.summaryOptions ?? SummaryOptions()
        
        // 如果有 summaryConfig 且找到了 markit.md，使用 Summary 导航
        match (summaryConfig) {
            case Some(config) =>
                if (config.found) {
                    return generateNavigationFromSummary(config, currentPagePath, summaryOptions.showDrafts)
                }
            case None => ()
        }
        
        // 否则使用默认的文件树导航
        let siteStructure = GlobalContext.siteStructure
        match (siteStructure) {
            case Some(structure) => 
                return generateEnhancedNavigation(structure, currentPageTitle, currentPagePath)
            case None =>
                let emptyNavigationText = uiText("No navigation available", "暂无导航")
                return "<ul class=\"nav-list\"><li>${emptyNavigationText}</li></ul>"
        }
    }
    
    /**
     * 从 SummaryConfig 生成导航 HTML
     * 
     * @param summaryConfig Summary 配置
     * @param currentPagePath 当前页面路径
     * @param showDrafts 是否显示草稿章节
     * @return 导航 HTML
     */
    public func generateNavigationFromSummary(
        summaryConfig: SummaryConfig,
        currentPagePath: String,
        showDrafts: Bool
    ): String {
        let nav = ArrayList<String>()
        nav.add("<ul class=\"nav-list\">")
        
        // 1. 生成根级链接
        for (chapter in summaryConfig.prefixChapters) {
            generateChapterHtml(chapter, nav, 0, currentPagePath, showDrafts)
        }
        
        // 2. 生成分组
        var sectionIndex = 0
        for (section in summaryConfig.sections) {
            let sectionId = "summary-section-${sectionIndex}-${sanitizeHtmlId(section.title)}"
            let sectionTitle = HtmlEscaper.escape(section.title)
            let expanded = sectionContainsPage(section.chapters, currentPagePath)
            let sectionState = expandedStateClass(expanded)
            let sectionAriaExpanded = ariaExpanded(expanded)
            
            // 分组标题
            nav.add("    <li class=\"nav-section ${sectionState}\" id=\"${sectionId}\">")
            nav.add("        <button type=\"button\" class=\"nav-section-title\" title=\"${sectionTitle}\" aria-expanded=\"${sectionAriaExpanded}\" aria-controls=\"${sectionId}-list\" onclick=\"toggleNavSection('${sectionId}', this, event)\">${section.title}</button>")
            nav.add("        <ul class=\"nav-section-list\" id=\"${sectionId}-list\">")
            
            // 分组中的章节
            for (chapter in section.chapters) {
                generateChapterHtml(chapter, nav, 1, currentPagePath, showDrafts)
            }
            
            nav.add("        </ul>")
            nav.add("    </li>")
            sectionIndex += 1
        }
        
        nav.add("</ul>")
        return String.join(nav.toArray(), delimiter: "\n")
    }

    private func expandedStateClass(expanded: Bool): String {
        return if (expanded) { "expanded" } else { "collapsed" }
    }

    private func ariaExpanded(expanded: Bool): String {
        return if (expanded) { "true" } else { "false" }
    }
    
    /**
     * 检查section是否包含指定页面
     * 
     * @param chapters 章节列表
     * @param currentPagePath 当前页面路径
     * @return 是否包含
     */
    private func sectionContainsPage(chapters: Array<Chapter>, currentPagePath: String): Bool {
        let normalizedCurrentPath = PathUtils.normalizePath(currentPagePath)
        
        for (chapter in chapters) {
            // 规范化章节路径进行比较
            let normalizedChapterPath = PathUtils.normalizePath(chapter.filePath)
            let normalizedChapterHtmlPath = normalizedChapterPath.replace(".md", ".html").replace(".markdown", ".html")
            
            // 检查当前章节
            if (normalizedChapterPath == normalizedCurrentPath || 
                normalizedChapterHtmlPath == normalizedCurrentPath) {
                return true
            }
            
            // 递归检查子章节
            if (chapter.children.size > 0) {
                if (sectionContainsPage(chapter.children, currentPagePath)) {
                    return true
                }
            }
        }
        return false
    }
    
    /**
     * 递归生成章节 HTML
     * 
     * @param chapter 章节
     * @param nav 导航 HTML 列表
     * @param level 层级（用于缩进）
     * @param currentPagePath 当前页面路径
     * @param showDrafts 是否显示草稿章节
     */
    private func generateChapterHtml(
        chapter: Chapter,
        nav: ArrayList<String>,
        level: Int,
        currentPagePath: String,
        showDrafts: Bool
    ): Unit {
        let indent = "    "
        var indentStr = ""
        for (_ in 0..(level + 1)) {
            indentStr += indent
        }
        
        // 检查是否为当前页面
        let normalizedChapterPath = PathUtils.normalizePath(chapter.filePath)
        let normalizedChapterHtmlPath = normalizedChapterPath.replace(".md", ".html").replace(".markdown", ".html")
        let normalizedCurrentPath = PathUtils.normalizePath(currentPagePath)
        
        let isActive = normalizedChapterPath == normalizedCurrentPath || 
                       normalizedChapterHtmlPath == normalizedCurrentPath
        let activeClass = if (isActive) { " active" } else { "" }
        let chapterTitle = HtmlEscaper.escape(chapter.displayName)
        
        if (chapter.isDraft) {
            // 草稿章节
            if (showDrafts) {
                nav.add("${indentStr}<li class=\"nav-item draft\">")
                nav.add("${indentStr}    <span class=\"nav-draft\" title=\"${chapterTitle}\">${navLinkContent(chapter)}</span>")
                nav.add("${indentStr}</li>")
            }
        } else {
            // 正常章节
            // 规范化路径：去掉 ../ 和对应数量的目录层
            let normalizedPath = PathUtils.normalizePath(chapter.filePath)
            let htmlPath = normalizedPath.replace(".md", ".html").replace(".markdown", ".html")
            
            // 规范化当前页面路径
            let normalizedCurrentPagePath = PathUtils.normalizePath(currentPagePath)
            
            // 计算相对路径：从当前页面到目标页面
            let relativePath = PathUtils.calculateRelativePath(normalizedCurrentPagePath, htmlPath)
            
            let hasChildren = chapter.children.size > 0
            let childClass = if (hasChildren) { " has-children" } else { "" }
            let containsActivePage = isActive || (hasChildren && sectionContainsPage(chapter.children, currentPagePath))
            let stateClass = expandedStateClass(containsActivePage)
            let ariaState = ariaExpanded(containsActivePage)
            
            nav.add("${indentStr}<li class=\"nav-item${activeClass}${childClass}\">")
            if (hasChildren) {
                let folderId = summaryFolderId(chapter, level)
                nav.add("${indentStr}    <div class=\"nav-folder summary-nav-folder ${stateClass}\" data-nav-folder=\"${folderId}\">")
                nav.add("${indentStr}        <a href=\"${relativePath}\" class=\"nav-link nav-folder-link\" title=\"${chapterTitle}\">")
                nav.add("${indentStr}            ${navLinkContent(chapter)}")
                nav.add("${indentStr}        </a>")
                nav.add("${indentStr}        <button type=\"button\" class=\"nav-folder-toggle\" aria-expanded=\"${ariaState}\" aria-controls=\"${folderId}\" onclick=\"toggleFolder('${folderId}', this)\"></button>")
                nav.add("${indentStr}    </div>")
            } else {
                nav.add("${indentStr}    <a href=\"${relativePath}\" class=\"nav-link\" title=\"${chapterTitle}\">")
                nav.add("${indentStr}        ${navLinkContent(chapter)}")
                nav.add("${indentStr}    </a>")
            }
            
            // 子章节
            if (hasChildren) {
                let folderId = summaryFolderId(chapter, level)
                nav.add("${indentStr}    <ul class=\"nav-sublist ${stateClass}\" id=\"${folderId}\">")
                for (child in chapter.children) {
                    generateChapterHtml(child, nav, level + 1, currentPagePath, showDrafts)
                }
                nav.add("${indentStr}    </ul>")
            }
            
            nav.add("${indentStr}</li>")
        }
    }
    
    private func summaryFolderId(chapter: Chapter, level: Int): String {
        let source = if (chapter.filePath.isEmpty()) { chapter.displayName } else { chapter.filePath }
        return "summary-folder-${level}-${sanitizeHtmlId(source)}"
    }

    private func navLinkContent(chapter: Chapter): String {
        return navIconHtml(chapter.icon) + "<span class=\"nav-label\">" + chapter.displayName + "</span>"
    }

    private func navIconHtml(icon: String): String {
        let key = normalizeNavIconKey(icon)
        if (key.isEmpty()) {
            return ""
        }
        let path = navIconPath(key)
        if (path.isEmpty()) {
            return ""
        }
        return "<span class=\"nav-icon nav-icon-${key}\" aria-hidden=\"true\"><svg viewBox=\"0 0 1024 1024\" focusable=\"false\"><path d=\"" +
            path + "\"></path></svg></span>"
    }

    private func normalizeNavIconKey(icon: String): String {
        return icon.trimAscii().toAsciiLower().replace("_", "-")
    }

    private func navIconPath(key: String): String {
        match (key) {
            case "package" => return "M499.095 134.058L104.56 240.988 64 274.173v464.593l22.123 33.185 424.033 117.992 424.033-117.992L960 738.765V274.173l-44.247-33.185-398.222-106.93h-18.436z m283.917 140.115l-62.683 18.436-210.173 55.309-235.984-62.683-36.872-11.062 276.543-70.058 269.169 70.058zM130.37 318.42l346.601 92.181v398.222L130.37 712.955V318.42z m553.087 55.308v176.988l70.058-18.436V355.292L893.63 318.42v394.535l-346.601 95.868V410.601l136.428-36.873z"
            case "method" => return "M904.218 315.019V708.98l-34.864 55.782L545.121 960H478.88L151.16 764.763l-31.377-55.782V315.019l31.377-55.782L478.879 64h66.241l324.233 195.237 34.865 55.782zM478.879 531.175L182.537 370.802v338.179L478.879 883.3V531.175z m31.378-55.782L820.545 304.56 510.257 119.782 199.969 304.56l310.288 170.833z m327.72-104.591L545.121 531.175V883.3l292.856-174.319V370.802z"
            case "interface" => return "M737.408 287.341c38.741 0 74.633 9.685 107.677 29.056 33.044 19.37 59.82 45.008 80.33 76.912s31.904 67.797 34.183 107.677c2.279 39.88-5.127 76.912-22.219 111.095-17.092 34.183-41.589 62.099-73.494 83.749s-67.227 34.753-105.968 39.311-75.772-1.141-111.095-17.093-64.948-39.311-88.876-70.075c-23.928-30.765-38.171-65.518-42.729-104.259H316.955c-9.115 31.904-26.777 56.972-52.984 75.203s-55.832 25.068-88.876 20.51c-33.044-4.558-59.82-18.801-80.33-42.729C74.255 572.77 64 544.284 64 511.24s10.255-61.53 30.765-85.458 47.287-37.601 80.33-41.02 62.669 3.988 88.876 22.219 43.868 42.159 52.984 71.785h198.262c6.837-54.693 31.335-100.271 73.494-136.733s91.725-54.692 148.697-54.692z m0 386.269c43.299 0 80.33-15.952 111.095-47.856 30.765-31.904 46.147-70.075 46.147-114.513s-15.382-82.04-46.147-112.804c-30.765-30.765-68.366-46.147-112.804-46.147s-82.039 15.382-112.804 46.147-46.147 68.366-46.147 112.804 15.382 82.039 46.147 112.804 68.936 46.147 114.513 46.147v3.418z"
            case "variable" => return "M128.977 736h126.534v64.977H94.779L64 766.779V253.802l30.779-30.779h160.733V288H128.977v448zM960 253.802v512.977l-30.779 34.198H768.489V736h129.954V288H768.489v-64.977h160.733L960 253.802zM594.076 291.42h-30.779L276.031 421.374l-20.519 27.359v160.733l17.099 27.359 157.313 95.756h30.779L747.97 606.047l20.519-30.779V414.534l-13.679-27.359-160.734-95.755zM320.489 503.45l95.756 58.137v85.496l-95.756-58.137V503.45z m253.068-147.053l92.336 54.718-215.45 95.756-92.336-54.718 215.45-95.756z m-92.336 208.611l225.71-99.176v88.916l-225.71 99.176v-88.916z"
            case "global-variable" => return navIconPath("variable")
            case "extension" => return "M568.747 398.507l56.747 56.747h277.76L960 398.507v-277.76L903.253 64h-277.76l-56.747 56.747v277.76h0.001z m334.506-277.76v277.76h-277.76v-277.76h277.76zM64 903.253L120.747 960H736l56.747-56.747V622.507L736 568.747H455.253V288l-53.76-56.747H120.747L64 288V903.253z m56.747-334.506V288h280.747v280.747H120.747z m280.746 334.506H120.747V622.507h280.747v280.746h-0.001z m53.76-280.746H736v280.747H455.253V622.507z"
            case "class" => return "M653.198 541.634v-31.377H377.774v261.479h327.72l122.023-122.023h45.323l87.16 87.16v48.809L785.681 960h-48.809l-83.673-87.16v-34.864H346.397l-31.377-31.377V426.584l-73.214 76.7h-48.809L64 370.802v-45.323L325.479 64h45.323l132.483 128.996v48.809L381.261 360.342v83.673h327.72l118.537-118.537h45.323l87.16 87.16v45.323L785.681 632.28h-45.323l-87.16-90.646z m66.242-17.432l41.837 41.837 128.996-132.483-41.837-38.35L719.44 524.202z m0 327.72l41.837 41.837 128.996-132.482-41.837-41.837L719.44 851.922zM433.556 217.401l-87.16-83.673-212.668 212.669 83.673 87.16 216.155-216.156z"
            case "abstract-class" => return "M653.198 541.634v-31.377H377.774v261.479h327.72l122.023-122.023h45.323l87.16 87.16v48.809L785.681 960h-48.809l-83.673-87.16v-34.864H346.397l-31.377-31.377V426.584l-73.214 76.7h-48.809L64 370.802v-45.323L325.479 64h45.323l132.483 128.996v48.809L381.261 360.342v83.673h327.72l118.537-118.537h45.323l87.16 87.16v45.323L785.681 632.28h-45.323l-87.16-90.646z m66.242-17.432l41.837 41.837 128.996-132.483-41.837-38.35L719.44 524.202z m0 327.72l41.837 41.837 128.996-132.482-41.837-41.837L719.44 851.922zM433.556 217.401l-87.16-83.673-212.668 212.669 83.673 87.16 216.155-216.156zM208 736h256v64H208v-64zM240 608h192v64H240v-64z"
            case "enum" => return "M960 192.244V513.71l-61.557 64.977H641.954V513.71h256.489V192.244H512v191.511h-64.977V192.244L512 127.267h386.443L960 192.244z m-383.023 232.55l23.939 23.939h232.55v-64.977H576.977v41.038zM512 448.733l64.977 64.977v321.466L512 896.733H128.977L64 835.176V513.71l64.977-64.977H512z m0 64.977H128.977v321.466H512V513.71zM190.534 640.244h256.489v-61.557H190.534v61.557z m0 129.954h256.489v-64.977H190.534v64.977z m386.443-448h256.489v-64.977H576.977v64.977z"
            case "member" => return "M447.023 383.756H512V192.244h386.443V513.71H641.954v64.977h256.489L960 513.71V192.244l-61.557-64.977H512l-64.977 64.977v191.512z m129.954 451.42L512 896.733H128.977L64 835.176V513.71l64.977-64.977H512l64.977 64.977v321.466z m-448-321.466v321.466H512V513.71H128.977z m704.489-64.977v-64.977H576.977v37.618l27.359 27.359h229.13zM576.977 322.198h256.489v-64.977H576.977v64.977zM447.023 705.221H190.534v-64.977h256.489v64.977z"
            case "property" => return navIconPath("member")
            case "static-property" => return "M447.023 383.756H512V192.244h386.443V513.71H641.954v64.977h256.489L960 513.71V192.244l-61.557-64.977H512l-64.977 64.977v191.512z m129.954 451.42L512 896.733H128.977L64 835.176V513.71l64.977-64.977H512l64.977 64.977v321.466z m-448-321.466v321.466H512V513.71H128.977zM190.534 640.244h256.489v64.977H190.534v-64.977zM190.534 576h126.534v-64.977h64.977V576h64.978v64.977h-64.978v64.977h-64.977v-64.977H190.534V576z"
            case "type" => return "M192 128h640l64 64v640l-64 64H192l-64-64V192l64-64z m32 96v576h576V224H224z m96 128h384v64H320v-64z m0 128h256v64H320v-64z m0 128h320v64H320v-64z"
            case "struct" => return "M160 128h704l64 64v640l-64 64H160l-64-64V192l64-64z m0 224h704V192H160v160z m0 224h288V416H160v160z m352 0h352V416H512v160z m-352 256h288V640H160v192z m352 0h352V640H512v192z"
            case "function" => return "M256 192h320v96H384v160h160v96H384v288H256V544H128v-96h128V288l64-96h-64z m384 256h96v96h-96v-96z m0 192h96v96h-96v-96z m160-192h96v96h-96v-96z m0 192h96v96h-96v-96z"
            case "constructor" => return "M512 96c229.75 0 416 186.25 416 416S741.75 928 512 928 96 741.75 96 512 282.25 96 512 96z m0 96c-176.731 0-320 143.269-320 320s143.269 320 320 320 320-143.269 320-320S688.731 192 512 192z m48 128v144h144v96H560v144h-96V560H320v-96h144V320h96z"
            case "enum-case" => return "M192 192h128v128H192V192z m224 32h416v64H416v-64zM192 448h128v128H192V448z m224 32h416v64H416v-64zM192 704h128v128H192V704z m224 32h416v64H416v-64z"
            case _ => return ""
        }
    }
    
    private func sanitizeHtmlId(value: String): String {
        let sanitized = value
            .replace("\\", "-")
            .replace("/", "-")
            .replace(".", "-")
            .replace(" ", "-")
            .replace(":", "-")
            .replace(";", "-")
            .replace(",", "-")
            .replace("'", "-")
            .replace("\"", "-")
            .replace("<", "-")
            .replace(">", "-")
            .replace("&", "-")
            .replace("#", "-")
            .replace("?", "-")
            .replace("=", "-")
        if (sanitized.isEmpty()) {
            return "item"
        }
        return sanitized
    }
    
    /**
     * 生成增强的导航HTML（包含文件结构和TOC）
     */
    private func generateEnhancedNavigation(structure: SiteStructure, currentPageTitle: String, currentPagePath: String): String {
        let nav = ArrayList<String>()
        nav.add("<ul class=\"nav-list\">")
        
        // 构建文件树结构
        let fileTree = buildFileTree(structure.getPages())
        
        // 使用传入的当前页面路径，如果为空则尝试通过标题查找
        let actualCurrentPagePath = if (currentPagePath.isEmpty()) {
            findCurrentPagePath(structure.getPages(), currentPageTitle)
        } else {
            currentPagePath
        }
        
        // 递归生成导航HTML
        generateNavigationLevel(fileTree, nav, 1, currentPagePath: actualCurrentPagePath, currentPageTitle: currentPageTitle, currentFolderPath: "")
        
        nav.add("</ul>")
        return String.join(nav.toArray(), delimiter: "\n")
    }
    
    /**
     * 找到当前页面的路径
     * 优先使用精确的路径匹配，避免同名文件的冲突
     */
    private func findCurrentPagePath(pages: Array<SitePage>, currentPageTitle: String): String {
        var matchedPages = ArrayList<SitePage>()
        
        // 收集所有标题匹配的页面
        for (page in pages) {
            if (page.title == currentPageTitle) {
                matchedPages.add(page)
            }
        }
        
        // 如果只有一个匹配，直接返回
        if (matchedPages.size == 1) {
            return matchedPages[0].htmlPath
        }
        
        // 如果有多个匹配，返回第一个
        if (matchedPages.size > 0) {
            return matchedPages[0].htmlPath
        }
        
        return ""
    }
    
    /**
     * 构建文件树结构
     */
    private func buildFileTree(pages: Array<SitePage>): FileTreeNode {
        let root = FileTreeNode("", "", "", true)
        
        for (page in pages) {
            let pathParts = page.htmlPath.split("/")
            var currentNode = root
            
            // 遍历路径的每一部分
            for (i in 0..pathParts.size) {
                let part = pathParts[i]
                if (part.isEmpty()) {
                    continue
                }
                
                let isLastPart = (i == pathParts.size - 1)
                
                // 查找是否已存在该节点
                var foundChild: ?FileTreeNode = None
                for (child in currentNode.children) {
                    if (child.name == part) {
                        foundChild = Some(child)
                        break
                    }
                }
                
                match (foundChild) {
                    case Some(child) => 
                        currentNode = child
                    case None => 
                        // 创建新节点
                        let isDirectory = !isLastPart
                        let newNode = FileTreeNode(
                            part,
                            if (isDirectory) { "" } else { page.title },
                            if (isDirectory) { "" } else { page.htmlPath },
                            isDirectory
                        )
                        currentNode.children.add(newNode)
                        currentNode = newNode
                }
            }
        }
        
        return root
    }
    
    /**
     * 递归生成导航层级（按真实文件夹结构显示）
     */
    private func generateNavigationLevel(node: FileTreeNode, nav: ArrayList<String>, level: Int, currentPagePath!: String = "", currentPageTitle!: String = "", currentFolderPath!: String = ""): Unit {
        // 对子节点排序：文件在前，目录在后
        let sortedChildren = ArrayList<FileTreeNode>()
        let directories = ArrayList<FileTreeNode>()
        let files = ArrayList<FileTreeNode>()
        
        for (child in node.children) {
            if (child.isDirectory) {
                directories.add(child)
            } else {
                files.add(child)
            }
        }
        
        // 先添加文件，再添加目录
        for (file in files) {
            sortedChildren.add(file)
        }
        for (dir in directories) {
            sortedChildren.add(dir)
        }
        
        for (child in sortedChildren) {
            if (child.isDirectory) {
                // 目录节点
                let folderId = "folder-${child.name}-${level}"
                
                // 构建当前文件夹的完整路径
                let childFolderPath = if (currentFolderPath.isEmpty()) { child.name } else { "${currentFolderPath}/${child.name}" }
                
                let folderExpanded = isInCurrentFolderPath(childFolderPath, currentPagePath)
                let expandedClass = expandedStateClass(folderExpanded)
                let folderAriaExpanded = ariaExpanded(folderExpanded)
                
                nav.add("    <li class=\"nav-item level-${level} directory\">")
                nav.add("        <div class=\"nav-folder ${expandedClass}\" data-nav-folder=\"${folderId}\" role=\"button\" tabindex=\"0\" aria-expanded=\"${folderAriaExpanded}\" aria-controls=\"${folderId}\" onclick=\"toggleFolder('${folderId}', this)\">")
                nav.add("            <svg aria-hidden=\"true\" focusable=\"false\" class=\"nav-folder-icon octicon octicon-file-directory-open-fill\" viewBox=\"0 0 16 16\" width=\"16\" height=\"16\" fill=\"currentColor\"><path d=\"M.513 1.513A1.75 1.75 0 0 1 1.75 1h3.5c.55 0 1.07.26 1.4.7l.9 1.2a.25.25 0 0 0 .2.1H13a1 1 0 0 1 1 1v.5H2.75a.75.75 0 0 0 0 1.5h11.978a1 1 0 0 1 .994 1.117L15 13.25A1.75 1.75 0 0 1 13.25 15H1.75A1.75 1.75 0 0 1 0 13.25V2.75c0-.464.184-.91.513-1.237Z\"></path></svg>")
                nav.add("            <span class=\"nav-folder-name\">${child.name}</span>")
                nav.add("        </div>")
                
                if (child.children.size > 0) {
                    nav.add("        <ul class=\"nav-sublist ${expandedClass}\" id=\"${folderId}\">")
                    generateNavigationLevel(child, nav, level + 1, currentPagePath: currentPagePath, currentPageTitle: currentPageTitle, currentFolderPath: childFolderPath)
                    nav.add("        </ul>")
                }
                nav.add("    </li>")
            } else {
                // 文件节点
                let isCurrentPage = child.path == currentPagePath
                let activeClass = if (isCurrentPage) { " active" } else { "" }
                
                // 生成正确的相对路径
                let relativePath = generateRelativePathFromCurrent(child.path, currentPagePath)
                
                nav.add("    <li class=\"nav-item level-${level} file${activeClass}\">")
                nav.add("        <a href=\"${relativePath}\" class=\"nav-file-link\">")
                nav.add("            <svg aria-hidden=\"true\" focusable=\"false\" class=\"nav-file-icon octicon octicon-file\" viewBox=\"0 0 16 16\" width=\"16\" height=\"16\" fill=\"currentColor\"><path d=\"M2 1.75C2 .784 2.784 0 3.75 0h6.586c.464 0 .909.184 1.237.513l2.914 2.914c.329.328.513.773.513 1.237v9.586A1.75 1.75 0 0 1 13.25 16h-9.5A1.75 1.75 0 0 1 2 14.25Zm1.75-.25a.25.25 0 0 0-.25.25v12.5c0 .138.112.25.25.25h9.5a.25.25 0 0 0 .25-.25V6h-2.75A1.75 1.75 0 0 1 9 4.25V1.5Zm6.75.062V4.25c0 .138.112.25.25.25h2.688l-.011-.013-2.914-2.914-.013-.011Z\"></path></svg>")
                nav.add("            <span class=\"nav-file-name\">${child.title}</span>")
                nav.add("        </a>")
                nav.add("    </li>")
            }
        }
    }
    
    /**
     * 检查文件夹路径是否在当前页面的路径中
     */
    private func isInCurrentFolderPath(folderPath: String, currentPagePath: String): Bool {
        if (currentPagePath.isEmpty()) {
            return false
        }
        // 检查当前页面路径是否以此文件夹路径开头
        return currentPagePath.startsWith(folderPath + "/") || currentPagePath.startsWith(folderPath)
    }
    
    /**
     * 根据当前页面路径生成到目标页面的相对路径
     */
    private func generateRelativePathFromCurrent(targetPath: String, currentPath: String): String {
        // 如果当前路径为空，直接返回目标路径
        if (currentPath.isEmpty()) {
            return targetPath
        }
        
        // 计算当前页面的目录深度
        let currentParts = currentPath.split("/")
        var depth = 0
        for (part in currentParts) {
            if (!part.isEmpty() && part != currentParts[currentParts.size - 1]) {
                depth += 1
            }
        }
        
        // 生成相对路径前缀
        var relativePath = ""
        for (_ in 0..depth) {
            relativePath += "../"
        }
        
        // 添加目标路径
        relativePath += targetPath
        
        return relativePath
    }
    
    /**
     * 获取主题名称
     */
    public func getThemeName(): String {
        return theme.getName()
    }
    
    /**
     * 检查主题是否支持网站模式
     */
    public func supportsWebsiteMode(): Bool {
        return theme.supportsWebsiteMode()
    }
    
    /**
     * 生成文章统计信息HTML
     * 
     * @param content Markdown原始内容
     * @return 统计信息HTML
     */
    private func generateStatisticHtml(content: String): String {
        if (!statisticTotalTexts && !statisticSpentTime) {
            return ""
        }
        
        // 计算字数（使用RuneArray来正确处理多字节字符）
        let wordCount = content.toRuneArray().size
        
        let stats = ArrayList<String>()
        stats.add("<div class=\"article-statistic\">")
        
        // 总字数
        if (statisticTotalTexts) {
            let totalTextsHtml = statisticTotalTextsTemplate.replace("{total}", wordCount.toString())
            stats.add("    <span class=\"statistic-item statistic-words\"><svg class=\"statistic-icon\" viewBox=\"0 0 1024 1024\" xmlns=\"http://www.w3.org/2000/svg\" width=\"14\" height=\"14\"><path d=\"M85.333333 245.333333A32 32 0 0 1 117.333333 213.333333h789.333334a32 32 0 0 1 0 64H117.333333A32 32 0 0 1 85.333333 245.333333z m0 277.333334a32 32 0 0 1 32-32h789.333334a32 32 0 0 1 0 64H117.333333a32 32 0 0 1-32-32z m725.333334 277.333333a32 32 0 0 1 32-32h64a32 32 0 0 1 0 64h-64a32 32 0 0 1-32-32zM103.082667 799.488c8.96-5.973333 17.706667-12.8 25.898666-20.266667v170.112a32 32 0 0 0 64 0v-277.333333a32 32 0 0 0-63.274666-6.826667c-5.376 24.661333-29.525333 59.306667-62.122667 81.066667a32 32 0 0 0 35.498667 53.248zM341.333333 747.648c0-22.528 18.944-43.648 42.069334-43.648 17.365333 0 31.36 8.106667 38.101333 18.517333 5.802667 8.96 9.301333 24.149333-3.968 46.72-6.4 10.88-16.042667 20.565333-29.098667 30.890667-6.485333 5.12-13.482667 10.112-21.034666 15.488l-3.157334 2.218667c-6.485333 4.565333-13.44 9.472-20.138666 14.506666-31.744 23.893333-66.773333 57.429333-66.773334 116.992 0 17.664 14.336 32 32 32h147.242667a32 32 0 0 0 0-64H349.354667c6.826667-12.032 18.048-22.4 33.237333-33.834666 5.845333-4.394667 11.904-8.661333 18.432-13.312l3.328-2.304c7.594667-5.418667 15.786667-11.264 23.765333-17.493334 15.872-12.586667 32.426667-28.074667 44.586667-48.725333 23.765333-40.448 23.296-81.962667 2.432-114.005333C455.253333 657.066667 419.882667 640 383.402667 640 320.341333 640 277.333333 694.528 277.333333 747.648a32 32 0 0 0 64 0zM617.429333 731.221333a36.693333 36.693333 0 0 1 10.709334-16.938666c5.461333-4.821333 15.189333-10.282667 33.194666-10.282667 32.469333 0 42.666667 21.333333 42.666667 31.018667 0 10.453333-2.218667 20.906667-8.106667 28.330666-4.736 5.973333-16.128 15.317333-47.018666 15.317334a32 32 0 0 0 0 64c11.690667 0 27.818667 1.536 39.893333 7.253333a27.904 27.904 0 0 1 11.264 8.533333c1.92 2.730667 3.968 7.125333 3.968 15.232 0 20.821333-6.485333 30.037333-11.946667 34.645334-6.485333 5.461333-16.896 9.002667-30.72 9.002666-15.445333 0-24.192-2.688-29.568-6.058666-4.693333-2.986667-10.24-8.704-14.72-22.357334a32 32 0 0 0-60.8 20.010667c7.978667 24.149333 21.162667 43.648 41.301334 56.405333 19.541333 12.373333 41.898667 16 63.786666 16 23.509333 0 50.432-5.888 71.978667-24.106666 22.528-18.986667 34.688-47.616 34.688-83.541334 0-20.224-5.546667-37.888-15.829333-52.352a83.882667 83.882667 0 0 0-11.008-12.544 93.44 93.44 0 0 0 4.821333-5.632c18.688-23.466667 22.016-50.858667 22.016-68.138666C768 689.237333 728.405333 640 661.333333 640c-32.64 0-57.642667 10.538667-75.52 26.282667-17.28 15.232-26.026667 33.664-29.909333 47.36a32 32 0 1 0 61.525333 17.578666z\" fill=\"currentColor\"></path></svg>${totalTextsHtml}</span>")
        }
        
        // 预计阅读时间
        if (statisticSpentTime) {
            let minutes = wordCount / 400
            var unit = statisticMinute
            var timeValue = minutes
            
            // 如果小于1分钟，显示为秒
            if (minutes < 1) {
                timeValue = (wordCount * 60) / 400
                unit = statisticSecond
            }
            
            let spentTimeHtml = statisticSpentTimeTemplate
                .replace("{total}", timeValue.toString())
                .replace("{unit}", unit)
            stats.add("    <span class=\"statistic-item statistic-time\"><svg class=\"statistic-icon\" viewBox=\"0 0 1024 1024\" xmlns=\"http://www.w3.org/2000/svg\" width=\"14\" height=\"14\"><path d=\"M512 192c212.352 0 384 171.648 384 384-1.28 212.352-172.928 384-384 384s-384-171.648-384-384c0-211.072 171.648-384 384-384z m0 64C336.128 256 192 400.128 192 576s142.784 320 320 320 320-144.128 320-320-144.128-320-320-320z m-32 128a32 32 0 0 1 32 32v178.688l118.656 118.656a32 32 0 0 1-45.248 45.248l-128-128.064a32.448 32.448 0 0 1-9.344-22.272L448 416a32 32 0 0 1 32-32z m190.592-320c18.944 0 33.408 13.888 33.408 32 0 18.112-15.552 32-33.344 32H353.408C334.464 128 320 114.112 320 96c0-18.112 14.464-32 33.408-32z\" fill=\"currentColor\"></path></svg>${spentTimeHtml}</span>")
        }
        
        stats.add("</div>")
        
        return String.join(stats.toArray(), delimiter: "\n")
    }
    
    /**
     * 生成章节导航HTML（上一篇/下一篇）
     * 
     * @param currentPagePath 当前页面路径
     * @return 章节导航HTML
     */
    private func generateChapterNavigation(currentPagePath: String): String {
        // 如果没有 summaryConfig，返回空
        match (summaryConfig) {
            case None => return ""
            case Some(config) =>
                if (!config.found) {
                    return ""
                }
                
                // 获取所有章节的扁平化列表
                let allChapters = config.getAllChaptersFlat()
                if (allChapters.size == 0) {
                    return ""
                }
                
                // Summary may retain ../ prefixes while rendered pages do not.
                let currentMdPath = PathUtils.normalizePath(currentPagePath.replace(".html", ".md"))
                
                // 查找当前章节的索引
                var currentIndex = -1
                for (i in 0..allChapters.size) {
                    let chapterMdPath = PathUtils.normalizePath(allChapters[i].filePath)
                    if (chapterMdPath == currentMdPath) {
                        currentIndex = i
                        break
                    }
                }
                
                // 如果找不到当前章节，返回空
                if (currentIndex == -1) {
                    return ""
                }
                
                // 获取上一篇和下一篇
                let prevChapter: ?Chapter = if (currentIndex > 0) { Some(allChapters[currentIndex - 1]) } else { None }
                let nextChapter: ?Chapter = if (currentIndex < allChapters.size - 1) { Some(allChapters[currentIndex + 1]) } else { None }
                
                // 如果没有上一篇也没有下一篇，返回空
                if (prevChapter.isNone() && nextChapter.isNone()) {
                    return ""
                }
                
                // 生成导航HTML
                let nav = ArrayList<String>()
                nav.add("<nav class=\"chapter-navigation\">")
                
                // 上一篇
                match (prevChapter) {
                    case Some(chapter) =>
                        let normalizedPath = PathUtils.normalizePath(chapter.filePath)
                        let prevHtmlPath = normalizedPath.replace(".md", ".html").replace(".markdown", ".html")
                        let prevRelativePath = PathUtils.calculateRelativePath(currentPagePath, prevHtmlPath)
                        let chapterTitle = HtmlEscaper.escape(chapter.displayName)
                        nav.add("    <a href=\"${prevRelativePath}\" class=\"chapter-nav-prev\" title=\"${chapterTitle}\">")
                        nav.add("        <span class=\"chapter-nav-label\">← ${chapterPrevText}</span>")
                        nav.add("        <span class=\"chapter-nav-title\">${chapter.displayName}</span>")
                        nav.add("    </a>")
                    case None =>
                        nav.add("    <div class=\"chapter-nav-placeholder\"></div>")
                }
                
                // 下一篇
                match (nextChapter) {
                    case Some(chapter) =>
                        let normalizedPath = PathUtils.normalizePath(chapter.filePath)
                        let nextHtmlPath = normalizedPath.replace(".md", ".html").replace(".markdown", ".html")
                        let nextRelativePath = PathUtils.calculateRelativePath(currentPagePath, nextHtmlPath)
                        let chapterTitle = HtmlEscaper.escape(chapter.displayName)
                        nav.add("    <a href=\"${nextRelativePath}\" class=\"chapter-nav-next\" title=\"${chapterTitle}\">")
                        nav.add("        <span class=\"chapter-nav-label\">${chapterNextText} →</span>")
                        nav.add("        <span class=\"chapter-nav-title\">${chapter.displayName}</span>")
                        nav.add("    </a>")
                    case None =>
                        nav.add("    <div class=\"chapter-nav-placeholder\"></div>")
                }
                
                nav.add("</nav>")
                
                return String.join(nav.toArray(), delimiter: "\n")
        }
    }
    /**
     * 生成代码仓库跳转按钮 HTML
     *
     * @return 仓库按钮 HTML 字符串
     */
    private func generateRepoButtons(): String {
        let buttons = ArrayList<String>()

        if (!reposGithub.isEmpty()) {
            buttons.add("<a href=\"${reposGithub}\" class=\"repo-btn\" data-tooltip=\"GitHub\" target=\"_blank\" rel=\"noopener noreferrer\"><svg viewBox=\"0 0 1024 1024\" xmlns=\"http://www.w3.org/2000/svg\" width=\"20\" height=\"20\"><path d=\"M511.6 76.3C264.3 76.2 64 276.4 64 523.5 64 718.9 189.3 885 363.8 946c23.5 5.9 19.9-10.8 19.9-22.2v-77.5c-135.7 15.9-141.2-73.9-150.3-88.9C215 726 171.5 718 184.5 703c30.9-15.9 62.4 4 98.9 57.9 26.4 37.1 77.9 31 104.5 24.9 5.8-23.5 17.9-44.5 34.7-60.8-140.6-25.2-199.2-111-199.2-213 0-49.5 16.3-95 48.3-131.7-20.4-60.5 1.9-112.3 4.9-120 58.1-5.2 118.5 41.6 123.2 45.3 33-8.9 70.7-13.6 112.9-13.6 42.4 0 80.2 4.9 113.5 13.9 11.3-8.6 67.3-48.8 121.3-43.9 2.9 7.7 24.7 58.3 5.5 118 32.4 36.8 48.9 82.7 48.9 132.3 0 102.2-59 188.1-200 212.9 23.5 23.2 38.1 55.4 38.1 91v112.5c0.8 9 0 17.9 15 17.9 177.1-59.7 304.6-227 304.6-424.1 0-247.2-200.4-447.3-447.5-447.3z\" fill=\"currentColor\"></path></svg></a>")
        }
        if (!reposGitcode.isEmpty()) {
            buttons.add("<a href=\"${reposGitcode}\" class=\"repo-btn\" data-tooltip=\"GitCode\" target=\"_blank\" rel=\"noopener noreferrer\"><svg viewBox=\"0 0 1024 1024\" xmlns=\"http://www.w3.org/2000/svg\" width=\"20\" height=\"20\"><path d=\"M685.679715 183.998617l-40.447039 22.783459-9.343778 5.418538a203.259173 203.259173 0 0 1-124.583708 30.463276 239.268984 239.268984 0 0 0-81.192739 5.20521c-46.71889 12.714365-89.171216 4.778553-132.348856-12.543702a316.749811 316.749811 0 0 0-33.791198-9.045119l1.023976 24.106094c0.597319 14.506322 1.151973 27.988669 2.133283 41.471015 2.389277 31.572583-6.058523 60.286568-21.418158 88.189906a387.190804 387.190804 0 0 0-50.601465 196.390002c2.389277 111.570684 69.630346 194.427382 182.438334 230.010538 99.069647 31.31659 198.736613 29.951289 298.232917 5.546534a279.502695 279.502695 0 0 0 141.649969-83.752677c9.258447-10.026429 17.492918-20.991501 24.575416-32.681891 28.841982-48.68151 9.557106-94.205763-46.505562-103.464209a312.184586 312.184586 0 0 0-44.798936-3.413252l-15.146307-0.255994c-14.079666-0.127997-28.116666-0.255994-42.068334-1.450632-48.169523-3.92524-96.424377-8.277137-144.124577-15.786292-23.679438-3.839909-43.561632-19.412872-46.3349-45.35359-2.986596-28.500656 4.693222-57.214641 31.401921-71.038312a202.917847 202.917847 0 0 1 76.968839-23.46611c81.022076-5.759863 162.470808-0.511988 242.127582 15.487632 139.431355 28.585988 212.261625 166.268051 145.27655 292.259726-94.504422 177.489118-242.468908 279.886686-447.98936 284.707905-160.422857 3.839909-301.731501-47.102881-413.003525-165.244076C-122.365094 582.410488 3.071927 132.074517 369.612555 23.917085c169.979963-49.918814 327.800215-21.332827 471.45547 82.302046 51.625441 37.247115 64.851793 99.112313 34.473848 149.628446-25.258067 42.111-72.104954 61.182547-121.853106 49.66282-31.99924-7.466489-55.124024-38.996407-61.395876-82.472707l-0.98131-8.277137a123.474401 123.474401 0 0 0-1.791957-11.434395l-3.839909-19.327541z\" fill=\"#DA203E\"></path></svg></a>")
        }
        if (!reposGitee.isEmpty()) {
            buttons.add("<a href=\"${reposGitee}\" class=\"repo-btn\" data-tooltip=\"Gitee\" target=\"_blank\" rel=\"noopener noreferrer\"><svg viewBox=\"0 0 1024 1024\" xmlns=\"http://www.w3.org/2000/svg\" width=\"20\" height=\"20\"><path d=\"M512 1024C229.2224 1024 0 794.7776 0 512S229.2224 0 512 0s512 229.2224 512 512-229.2224 512-512 512z m259.1488-568.8832H480.4096a25.2928 25.2928 0 0 0-25.2928 25.2928l-0.0256 63.2064c0 13.952 11.3152 25.2928 25.2672 25.2928h177.024c13.9776 0 25.2928 11.3152 25.2928 25.2672v12.6464a75.8528 75.8528 0 0 1-75.8528 75.8528H366.592a25.2928 25.2928 0 0 1-25.2672-25.2928v-240.1792a75.8528 75.8528 0 0 1 75.8272-75.8528h353.9456a25.2928 25.2928 0 0 0 25.2672-25.2928l0.0768-63.2064a25.2928 25.2928 0 0 0-25.2672-25.2928H417.152a189.6192 189.6192 0 0 0-189.6192 189.6448v353.9456c0 13.9776 11.3152 25.2928 25.2928 25.2928h372.9408a170.6496 170.6496 0 0 0 170.6496-170.6496v-145.408a25.2928 25.2928 0 0 0-25.2928-25.2672z\" fill=\"#C71D23\"></path></svg></a>")
        }
        if (!reposGitlab.isEmpty()) {
            buttons.add("<a href=\"${reposGitlab}\" class=\"repo-btn\" data-tooltip=\"GitLab\" target=\"_blank\" rel=\"noopener noreferrer\"><svg viewBox=\"0 0 1024 1024\" xmlns=\"http://www.w3.org/2000/svg\" width=\"20\" height=\"20\"><path d=\"M932.317184 567.76704L885.10464 422.46144l-93.57312-287.997952c-4.8128-14.81728-25.776128-14.81728-30.590976 0L667.36128 422.459392H356.62848L263.051264 134.46144c-4.8128-14.81728-25.776128-14.81728-30.593024 0l-93.57312 287.997952-47.210496 145.309696a32.165888 32.165888 0 0 0 11.68384 35.96288l408.6272 296.890368L920.61696 603.734016c11.272192-8.192 15.990784-22.71232 11.68384-35.964928\" fill=\"#FC6D26\"></path><path d=\"M512.002048 900.62848l155.365376-478.171136H356.634624z\" fill=\"#E24329\"></path><path d=\"M512.004096 900.62848L356.63872 422.47168H138.901504z\" fill=\"#FC6D26\"></path><path d=\"M138.891264 422.465536l-47.214592 145.309696a32.16384 32.16384 0 0 0 11.685888 35.96288L511.991808 900.62848z\" fill=\"#FCA326\"></path><path d=\"M138.893312 422.459392h217.737216L263.053312 134.46144c-4.8128-14.819328-25.778176-14.819328-30.590976 0z\" fill=\"#E24329\"></path><path d=\"M512.002048 900.62848l155.365376-478.154752H885.10464z\" fill=\"#FC6D26\"></path><path d=\"M885.11488 422.465536l47.214592 145.309696a32.16384 32.16384 0 0 1-11.685888 35.96288L512.014336 900.62848z\" fill=\"#FCA326\"></path><path d=\"M885.096448 422.459392H667.36128l93.577216-287.997952c4.814848-14.819328 25.778176-14.819328 30.590976 0z\" fill=\"#E24329\"></path></svg></a>")
        }

        return String.join(buttons.toArray(), delimiter: "\n                ")
    }

    /**
     * 生成复制 Markdown 按钮 HTML
     *
     * @param markdownContent Markdown 原始内容
     * @return 复制按钮 HTML
     */
    private func generateCopyMarkdownButton(markdownContent: String): String {
        let escaped = escapePlainTextScript(markdownContent)
        let tooltip = uiText("Copy Markdown", "复制 Markdown")
        return "<button class=\"copy-markdown-btn\" data-tooltip=\"${tooltip}\" onclick=\"copyMarkdownSource(this)\"><svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z\"></path><path d=\"M14 2v4a2 2 0 0 0 2 2h4\"></path><path d=\"M10 9H8\"></path><path d=\"M16 13H8\"></path><path d=\"M16 17H8\"></path></svg></button><textarea hidden class=\"markdown-source\">${escaped}</textarea>"
    }

    /**
     * 生成块级复制使用的整页 Markdown 源。
     */
    private func generateMarkdownSourceStore(markdownContent: String): String {
        let hex = encodeHexBytes(markdownContent)
        return "<script type=\"application/x-markit-source-hex\" id=\"markit-page-markdown-source\" data-encoding=\"hex\">${hex}</script>"
    }

    private func escapePlainTextScript(content: String): String {
        return content
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
    }

    private func encodeHexBytes(content: String): String {
        let builder = StringBuilder()
        for (byte in content) {
            builder.append(byte.format("02x"))
        }
        return builder.toString()
    }

    /**
     * 生成 Git 链接
     *
     * @param currentPagePath 当前页面路径（HTML 路径）
     * @return Git 链接 HTML
     */
    private func generateGitLink(currentPagePath: String): String {
        // 如果没有配置 Git 前缀，返回空
        if (gitPrefix.isEmpty()) {
            return ""
        }
        
        // 如果是首页，返回空
        if (currentPagePath.isEmpty() || currentPagePath == "index.html") {
            return ""
        }
        
        // 将 HTML 路径转换为 Markdown 路径
        let mdPath = currentPagePath.replace(".html", ".md")
        
        // 构建完整的 Git URL
        let gitUrl = gitPrefix + "/" + mdPath
        
        // 生成 Git 链接 HTML
        let tooltip = uiText("View source on Git", "在 Git 查看源码")
        return "<a href=\"${gitUrl}\" class=\"git-link\" data-tooltip=\"${tooltip}\" target=\"_blank\" rel=\"noopener noreferrer\"><svg class=\"icon\" viewBox=\"0 0 1024 1024\" version=\"1.1\" xmlns=\"http://www.w3.org/2000/svg\"><path d=\"M246.72 327.296c-12.032-12.032-31.424-12.032-43.456 0L9.024 521.344c-12.032 11.968-12.032 31.36 0 43.392l194.304 194.048c12.032 11.968 31.424 11.968 43.456 0 12.032-12.032 12.032-31.36 0-43.392L74.112 543.04l172.608-172.416C258.752 358.656 258.752 339.264 246.72 327.296zM954.368 521.344l-194.304-194.048c-12.032-12.032-31.488-12.032-43.456 0-12.032 11.968-12.032 31.36 0 43.328l172.608 172.416-172.608 172.352c-12.032 12.032-12.032 31.36 0 43.392 11.968 11.968 31.424 11.968 43.456 0l194.304-194.048C966.4 552.768 966.4 533.312 954.368 521.344zM689.664 132.608c-15.296-8.96-34.88-3.648-43.712 11.84l-384 766.848c-8.896 15.424-3.648 35.2 11.712 44.032 15.296 8.96 34.88 3.648 43.776-11.84l383.936-766.848C710.272 161.28 705.024 141.504 689.664 132.608z\" strick-size='0.1px'></path></svg></a>"
    }
}
