package markit_kit.services

import markit_kit.utils.KitHooks

import markit_kit.models.{SiteStructure, SitePage, SummaryConfig}
import markit_kit.utils.FileHandler
import markit_kit.interfaces.Processor
import std.collection.ArrayList
import std.fs.{Path, exists}

/**
 * 网站构建服务
 * 负责生成网站结构、索引页面等
 */
public class SiteBuilder {
    
    /**
     * 从文件列表构建网站结构
     * 
     * @param inputFiles 输入文件列表
     * @param basePath 基础路径
     * @return 网站结构
     */
    public static func buildStructure(inputFiles: Array<String>, basePath: String): SiteStructure {
        let structure = SiteStructure()
        
        for (file in inputFiles) {
            let relativePath = FileHandler.getRelativePath(file, basePath)
            let title = FileHandler.extractTitle(file)
            let htmlPath = relativePath.replace(".md", ".html").replace(".markdown", ".html")
            
            structure.addPage(relativePath, title, htmlPath)
        }
        
        return structure
    }
    
    /**
     * 生成网站首页（带 SummaryConfig）
     * 
     * @param outputPath 输出路径
     * @param structure 网站结构
     * @param processor 处理器
     * @param siteTitle 网站标题
     * @param summaryConfig Summary 配置
     * @param inputBasePath 输入基础路径（用于定位文件）
     */
    public static func generateIndex(
        outputPath: String, 
        structure: SiteStructure, 
        processor: Processor, 
        siteTitle: String,
        summaryConfig: SummaryConfig,
        inputBasePath: String
    ): Unit {
        // 使用新的 generateHomepage 方法
        if (summaryConfig.found) {
            generateHomepage(outputPath, summaryConfig, processor, siteTitle, inputBasePath)
        } else {
            // 没有找到 markit.md，使用默认逻辑
            generateDefaultIndex(outputPath, structure, processor, siteTitle)
        }
        
        // 为每个文件夹生成index.html
        generateFolderIndexes(outputPath, structure, processor)
    }
    
    /**
     * 生成网站首页（不带 SummaryConfig，使用默认逻辑）
     * 
     * @param outputPath 输出路径
     * @param structure 网站结构
     * @param processor 处理器
     * @param siteTitle 网站标题
     */
    public static func generateIndex(
        outputPath: String, 
        structure: SiteStructure, 
        processor: Processor, 
        siteTitle: String
    ): Unit {
        // 没有提供 summaryConfig，使用默认逻辑
        generateDefaultIndex(outputPath, structure, processor, siteTitle)
        
        // 为每个文件夹生成index.html
        generateFolderIndexes(outputPath, structure, processor)
    }
    
    /**
     * 生成首页（支持多种策略）
     * 
     * 策略 1：如果存在 `<!-- homepage -->` 标记后的内容则使用
     * 策略 2：使用第一个非草稿根级链接文件作为后备
     * 策略 3：如果没有可用的首页内容则打印警告
     * 
     * @param outputPath 输出路径
     * @param summaryConfig Summary 配置
     * @param processor 处理器
     * @param siteTitle 网站标题
     * @param inputBasePath 输入基础路径
     */
    private static func generateHomepage(
        outputPath: String,
        summaryConfig: SummaryConfig,
        processor: Processor,
        siteTitle: String,
        inputBasePath: String
    ): Unit {
        let indexPath = "${outputPath}/index.html"
        
        // 策略 1：如果有首页内容，直接使用（已经是 HTML 格式）
        // 无论是单文件还是多文件，只要有 homepage 内容就生成首页
        if (!summaryConfig.homepageContent.isEmpty()) {
            // homepage 内容已经通过 toHtml() 转换为 HTML，不需要再解析
            // 直接包装成完整的网站 HTML
            let processedContent = processor.wrapHtmlContent(summaryConfig.homepageContent, siteTitle, "index.html")
            FileHandler.ensureOutputDirectory(indexPath)
            FileHandler.writeFileContent(indexPath, processedContent)
            return
        }
        
        // 策略 2：使用第一个非草稿根级链接的文件作为后备
        for (chapter in summaryConfig.prefixChapters) {
            if (!chapter.isDraft && !chapter.filePath.isEmpty()) {
                let filePath = Path(inputBasePath).join(chapter.filePath).normalize().toString()
                if (exists(Path(filePath))) {
                    let content = FileHandler.readFileContent(filePath)
                    let (processedContent, _) = processor.process(content, chapter.displayName, currentPagePath: "index.html", asDocument: false)
                    FileHandler.ensureOutputDirectory(indexPath)
                    FileHandler.writeFileContent(indexPath, processedContent)
                    return
                }
            }
        }
    }
    
    /**
     * 生成默认首页（当没有 markit.md 时的后备逻辑）
     * 不生成首页，打印警告
     * 
     * @param outputPath 输出路径
     * @param structure 网站结构
     * @param processor 处理器
     * @param siteTitle 网站标题
     */
    private static func generateDefaultIndex(
        outputPath: String,
        structure: SiteStructure,
        processor: Processor,
        siteTitle: String
    ): Unit {
        // 当没有 markit.md 时，不生成首页（静默处理）
    }
    
    /**
     * 为每个文件夹生成index.html
     */
    private static func generateFolderIndexes(outputPath: String, structure: SiteStructure, processor: Processor): Unit {
        let folders = collectAllFolders(structure)
        
        for (folder in folders) {
            generateFolderIndex(outputPath, folder, structure, processor, verbose: false)
        }
    }
    
    /**
     * 收集所有文件夹路径
     */
    private static func collectAllFolders(structure: SiteStructure): Array<String> {
        let folders = ArrayList<String>()
        
        for (page in structure.getPages()) {
            let pathParts = page.htmlPath.split("/")
            if (pathParts.size > 1) {
                addFolderPaths(pathParts, folders)
            }
        }
        
        return folders.toArray()
    }
    
    /**
     * 添加文件夹路径到列表中
     */
    private static func addFolderPaths(pathParts: Array<String>, folders: ArrayList<String>): Unit {
        for (i in 0..(pathParts.size - 1)) {
            var folderPath = ""
            for (j in 0..(i + 1)) {
                if (j > 0) {
                    folderPath += "/"
                }
                folderPath += pathParts[j]
            }
            
            if (!isFolderExists(folders, folderPath)) {
                folders.add(folderPath)
            }
        }
    }
    
    /**
     * 检查文件夹是否已存在
     */
    private static func isFolderExists(folders: ArrayList<String>, folderPath: String): Bool {
        for (existingFolder in folders) {
            if (existingFolder == folderPath) {
                return true
            }
        }
        return false
    }
    
    /**
     * 生成单个文件夹的index.html
     */
    private static func generateFolderIndex(outputPath: String, folderPath: String, structure: SiteStructure, processor: Processor, verbose!: Bool = true): Unit {
        // Do not overwrite a user-authored index.md / index.markdown page.
        let currentPagePath = "${folderPath}/index.html"
        if (hasExplicitPage(structure, currentPagePath)) {
            return
        }

        let folderPages = ArrayList<SitePage>()
        
        for (page in structure.getPages()) {
            if (page.htmlPath.startsWith(folderPath + "/")) {
                folderPages.add(page)
            }
        }
        
        if (folderPages.size == 0) {
            return
        }
        
        let pathParts = folderPath.split("/")
        let folderName = pathParts[pathParts.size - 1]
        let indexContent = generateFolderIndexContent(folderName, folderPages.toArray())
        
        // 使用完整的相对路径（相对于语言目录）
        let (processedContent, _) = processor.process(indexContent, folderName, currentPagePath: currentPagePath, asDocument: false)
        
        let folderIndexPath = "${outputPath}/${folderPath}/index.html"
        FileHandler.ensureOutputDirectory(folderIndexPath)
        FileHandler.writeFileContent(folderIndexPath, processedContent)
        
        if (verbose) {
            KitHooks.verbose("Generated folder index: ${folderIndexPath}")
        }
    }

    private static func hasExplicitPage(structure: SiteStructure, htmlPath: String): Bool {
        for (page in structure.getPages()) {
            if (page.htmlPath == htmlPath) {
                return true
            }
        }
        return false
    }
    
    /**
     * 生成文件夹首页内容
     */
    private static func generateFolderIndexContent(folderName: String, pages: Array<SitePage>): String {
        let content = ArrayList<String>()
        content.add("# ${folderName}")
        content.add("")
        content.add("This section contains the following pages:")
        content.add("")
        
        for (page in pages) {
            let pathParts = page.htmlPath.split("/")
            let fileName = pathParts[pathParts.size - 1]
            content.add("- [${page.title}](${fileName})")
        }
        
        return String.join(content.toArray(), delimiter: "\n")
    }
}
