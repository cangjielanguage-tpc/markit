package markit_kit.utils

import markit_kit.interfaces.Processor
import std.fs.{Path, File, Directory, exists, FileInfo, canonicalize, copy, remove, OpenMode}
import std.collection.ArrayList

/**
 * 文件处理工具类
 * 负责文件收集、路径生成等文件系统相关操作
 */
public class FileHandler {
    
    /**
     * 收集输入文件（简单模式，不使用 markit.md）
     * 
     * @param inputPath 输入路径（文件或目录）
     * @param summaryFileName Summary 文件名（用于排除，默认 "markit.md"）
     * @return 收集到的markdown文件路径数组
     */
    public static func collectInputFiles(inputPath: String, summaryFileName!: String = "markit.md"): Array<String> {
        let path = Path(inputPath)
        let files = ArrayList<String>()
        
        if (!exists(path)) {
            return []
        }
        
        let fileInfo = FileInfo(path)
        if (fileInfo.isRegular()) {
            // 单个文件
            if (inputPath.endsWith(".md") || inputPath.endsWith(".markdown")) {
                files.add(inputPath)
            }
        } else if (fileInfo.isDirectory()) {
            // 递归收集目录中的所有markdown文件
            collectMarkdownFilesRecursively(path, files, summaryFileName, isRootDir: true)
        }
        
        return files.toArray()
    }
    
    /**
     * 递归收集目录中的markdown文件
     * 按照文件在前、文件夹在后的顺序收集
     * 
     * @param dirPath 目录路径
     * @param files 用于收集文件的列表
     * @param summaryFileName Summary 文件名（用于排除）
     * @param isRootDir 是否为根目录（只在根目录排除 summary 文件）
     */
    private static func collectMarkdownFilesRecursively(dirPath: Path, files: ArrayList<String>, summaryFileName: String, isRootDir!: Bool = false): Unit {
        try {
            let directories = ArrayList<FileInfo>()
            let markdownFiles = ArrayList<FileInfo>()
            
            // 先分类：文件和目录
            for (fileInfo in Directory.readFrom(dirPath)) {
                if (fileInfo.isRegular()) {
                    let pathStr = fileInfo.path.toString()
                    let fileName = fileInfo.name
                    
                    // 只在根目录排除 summary 文件，子目录中允许同名文件
                    if (isRootDir && fileName == summaryFileName) {
                        continue
                    }
                    
                    // 排除配置文件（不应该被渲染）
                    if (fileName.endsWith(".json")) {
                        continue
                    }
                    
                    // 检查是否为markdown文件
                    if (pathStr.endsWith(".md") || pathStr.endsWith(".markdown")) {
                        markdownFiles.add(fileInfo)
                    }
                } else if (fileInfo.isDirectory()) {
                    directories.add(fileInfo)
                }
            }
            
            // 先添加当前目录的文件
            for (fileInfo in markdownFiles) {
                files.add(fileInfo.path.toString())
            }
            
            // 再递归处理子目录（子目录不是根目录）
            for (dirInfo in directories) {
                collectMarkdownFilesRecursively(dirInfo.path, files, summaryFileName, isRootDir: false)
            }
        } catch (e: Exception) {
            // 忽略无法访问的目录
            KitHooks.warn("Cannot access directory ${dirPath}: ${e.message}")
        }
    }
    
    /**
     * 生成输出文件路径
     * 
     * @param inputFile 输入文件路径
     * @param outputPath 输出路径
     * @param processor 处理器（用于获取扩展名）
     * @param index 文件索引
     * @param totalFiles 总文件数
     * @return 生成的输出文件路径
     */
    public static func generateOutputPath(inputFile: String, outputPath: String, processor: Processor, index: Int, totalFiles: Int): String {
        let inputPath = Path(inputFile)
        let outputPathObj = Path(outputPath)
        let extension = processor.getExtension()
        
        // 获取输入文件的基本名称（不含扩展名）
        let baseName = inputPath.fileNameWithoutExtension
        
        // 判断输出是目录还是文件
        let isOutputDir = if (exists(outputPathObj)) {
            FileInfo(outputPathObj).isDirectory()
        } else {
            !outputPath.contains(".") || outputPath.endsWith("/")
        }
        
        if (isOutputDir) {
            // 输出到目录
            let fileName = if (totalFiles > 1) {
                "${baseName}-${index + 1}.${extension}"
            } else {
                "processed-${baseName}.${extension}"
            }
            return outputPathObj.join(fileName).toString()
        } else {
            // 输出到指定文件
            if (totalFiles > 1) {
                // 多个文件时添加编号
                let outputBaseName = outputPathObj.fileNameWithoutExtension
                let outputDir = outputPathObj.parent
                let finalDir = if (outputDir.isEmpty()) { Path(".") } else { outputDir }
                return finalDir.join("${outputBaseName}-${index + 1}.${extension}").toString()
            } else {
                // 单个文件时直接使用指定路径，但修改扩展名
                let outputDir = outputPathObj.parent
                let outputBaseName = outputPathObj.fileNameWithoutExtension
                let finalDir = if (outputDir.isEmpty()) { Path(".") } else { outputDir }
                return finalDir.join("${outputBaseName}.${extension}").toString()
            }
        }
    }
    
    /**
     * 确保输出目录存在
     * 
     * @param outputFile 输出文件路径
     */
    public static func ensureOutputDirectory(outputFile: String): Unit {
        let outputDir = Path(outputFile).parent
        if (!outputDir.isEmpty() && !exists(outputDir)) {
            Directory.create(outputDir.toString(), recursive: true)
        }
    }
    
    /**
     * 读取文件内容
     * 
     * @param filePath 文件路径
     * @return 文件内容字符串
     */
    public static func readFileContent(filePath: String): String {
        return String.fromUtf8(File.readFrom(filePath))
    }
    
    /**
     * 写入文件内容（使用流式写入以支持大文件）
     * 
     * @param filePath 文件路径
     * @param content 要写入的内容
     */
    public static func writeFileContent(filePath: String, content: String): Unit {
        try {
            // 确保目标目录存在
            ensureOutputDirectory(filePath)
            
            // 使用流式写入来避免一次性转换大字符串的问题
            let file = File(filePath, OpenMode.Write)
            let bytes = content.toArray()
            file.write(bytes)
            file.flush()
            file.close()
        } catch (e: Exception) {
            KitHooks.err("Failed to write file: ${e.message}")
            throw e
        }
    }
    
    /**
     * 生成文档输出文件路径（保持目录结构）
     * 
     * @param inputFile 输入文件路径
     * @param outputPath 输出路径
     * @param processor 处理器（用于获取扩展名）
     * @return 生成的输出文件路径
     */
    public static func generateDocumentOutputPath(inputFile: String, outputPath: String, processor: Processor): String {
        let inputPath = Path(inputFile)
        let outputPathObj = Path(outputPath)
        let extension = processor.getExtension()
        
        // 获取输入文件的基本名称（不含扩展名）
        let baseName = inputPath.fileNameWithoutExtension
        
        // 确保输出目录存在
        if (!exists(outputPathObj)) {
            Directory.create(outputPath, recursive: true)
        }
        
        // 使用文档自己的名字，保持相对路径结构
        let fileName = "${baseName}.${extension}"
        return outputPathObj.join(fileName).toString()
    }
    
    /**
     * 生成文档输出文件路径（保持相对目录结构）
     * 
     * @param inputFile 输入文件路径
     * @param inputBasePath 输入基础路径
     * @param outputPath 输出路径
     * @param processor 处理器（用于获取扩展名）
     * @return 生成的输出文件路径
     */
    public static func generateDocumentOutputPathWithStructure(inputFile: String, inputBasePath: String, outputPath: String, processor: Processor): String {
        let inputPath = Path(inputFile)
        let outputPathObj = Path(outputPath)
        let extension = processor.getExtension()
        
        // 计算相对路径（已经规范化，去掉了 ../ 前缀）
        let relativePath = getRelativePath(inputFile, inputBasePath)
        
        // 获取输入文件的基本名称（不含扩展名）
        let baseName = inputPath.fileNameWithoutExtension
        
        // 获取相对目录路径
        let relativeDir = if (relativePath.isEmpty()) {
            Path("")  // 使用空路径对象
        } else {
            Path(relativePath).parent
        }
        
        // 构建输出路径，保持目录结构
        let finalOutputDir = if (relativeDir.isEmpty()) {
            outputPathObj
        } else {
            outputPathObj.join(relativeDir.toString()).normalize()
        }
        
        // 确保输出目录存在
        if (!exists(finalOutputDir)) {
            Directory.create(finalOutputDir.toString(), recursive: true)
        }
        
        // 使用文档自己的名字
        let fileName = "${baseName}.${extension}"
        return finalOutputDir.join(fileName).normalize().toString()
    }
    
    /**
     * 获取文件所在的父文件夹路径（相对于基础路径）
     * 
     * @param filePath 文件路径
     * @param basePath 基础路径
     * @return 父文件夹的相对路径
     */
    public static func getParentFolder(filePath: String, basePath: String): String {
        // 获取相对路径
        let relativePath = getRelativePath(filePath, basePath)
        
        // 获取父目录
        let parentPath = Path(relativePath).parent
        
        // 返回父目录路径（如果为空则返回空字符串）
        return if (parentPath.isEmpty()) { "" } else { parentPath.toString() }
    }
    
    /**
     * 获取相对路径
     * 
     * @param filePath 文件路径
     * @param basePath 基础路径
     * @return 相对路径（已规范化，去掉 ../ 前缀）
     */
    public static func getRelativePath(filePath: String, basePath: String): String {
        // 使用 PathUtils 的函数获取相对路径
        let relativePath = PathUtils.getRelativePathFromBase(filePath, basePath)
        
        // 规范化路径：去掉 ../ 前缀和对应的目录层
        return PathUtils.normalizePath(relativePath)
    }

    
    /**
     * 获取输出文件名（不含路径）
     * 
     * @param inputFile 输入文件路径
     * @param processor 处理器（用于获取扩展名）
     * @return 输出文件名
     */
    public static func getOutputFileName(inputFile: String, processor: Processor): String {
        let inputPath = Path(inputFile)
        let extension = processor.getExtension()
        let baseName = inputPath.fileNameWithoutExtension
        return "${baseName}.${extension}"
    }
    
    /**
     * 获取相对输出路径（保持目录结构）
     * 
     * @param inputFile 输入文件路径
     * @param inputBasePath 输入基础路径
     * @param processor 处理器（用于获取扩展名）
     * @return 相对输出路径
     */
    public static func getRelativeOutputPath(inputFile: String, inputBasePath: String, processor: Processor): String {
        let inputPath = Path(inputFile)
        let extension = processor.getExtension()
        let baseName = inputPath.fileNameWithoutExtension
        
        // 计算相对路径
        let relativePath = getRelativePath(inputFile, inputBasePath)
        
        // 获取相对目录路径 - 安全处理空路径
        let relativeDir = if (relativePath.isEmpty()) {
            Path("")  // 空路径
        } else {
            Path(relativePath).parent
        }
        
        // 构建相对输出路径
        let fileName = "${baseName}.${extension}"
        if (relativeDir.isEmpty()) {
            return fileName
        } else {
            return "${relativeDir}/${fileName}"
        }
    }
    
    /**
     * 生成 index.html 路径
     * 
     * @param outputPath 输出路径
     * @return index.html 的完整路径
     */
    public static func generateIndexPath(outputPath: String): String {
        let outputPathObj = Path(outputPath)
        return outputPathObj.join("index.html").toString()
    }
    
    /**
     * 根据需要生成 index.html（仅限 HTML 格式）
     * 
     * @param processedFiles 处理过的文件信息数组 (filename, title)
     * @param outputPath 输出路径
     * @param processor 处理器
     * @param verbose 是否显示详细信息
     * @param customJsAssets 自定义JS资源列表
     * @param customCssAssets 自定义CSS资源列表
     */
    public static func generateIndexIfNeeded(
        processedFiles: Array<(String, String)>, 
        outputPath: String, 
        processor: Processor, 
        verbose: Bool,
        customJsAssets!: Array<String> = [],
        customCssAssets!: Array<String> = []
    ): Unit {
        // 只有 HTML 格式才生成 index.html
        if (processor.getExtension() == "html") {
            // 生成根目录的索引
            generateRootIndex(processedFiles, outputPath, verbose, customJsAssets, customCssAssets)
            
            // 为每个子目录生成索引
            generateDirectoryIndexes(processedFiles, outputPath, verbose, customJsAssets, customCssAssets)
        }
    }
    
    /**
     * 生成根目录索引
     * 
     * @param processedFiles 处理过的文件信息数组
     * @param outputPath 输出路径
     * @param verbose 是否显示详细信息
     * @param customJsAssets 自定义JS资源列表
     * @param customCssAssets 自定义CSS资源列表
     */
    private static func generateRootIndex(
        processedFiles: Array<(String, String)>, 
        outputPath: String, 
        verbose: Bool,
        customJsAssets: Array<String>,
        customCssAssets: Array<String>
    ): Unit {
        let indexPath = Path(outputPath).join("index.html").normalize().toString()
        
        // 收集根目录的文件和子目录
        let rootFiles = ArrayList<(String, String)>()
        let subdirectories = ArrayList<String>()
        
        for (i in 0..processedFiles.size) {
            let (filePath, title) = processedFiles[i]
            let pathObj = Path(filePath)
            let parentDir = pathObj.parent.toString()
            
            if (parentDir.isEmpty()) {
                // 根目录文件
                rootFiles.add((pathObj.fileName, title))
            } else {
                // 子目录文件，记录子目录
                let topLevelDir = getTopLevelDirectory(parentDir)
                if (!subdirectories.contains(topLevelDir)) {
                    subdirectories.add(topLevelDir)
                }
            }
        }
        
        let indexContent = generateDirectoryIndexContent("Document Index", "", rootFiles.toArray(), subdirectories.toArray(), customJsAssets, customCssAssets)
        ensureOutputDirectory(indexPath)
        writeFileContent(indexPath, indexContent)
        
        if (verbose) {
            KitHooks.success("Generated root index: ${indexPath}")
        }
    }
    
    /**
     * 为所有子目录生成索引
     * 
     * @param processedFiles 处理过的文件信息数组
     * @param outputPath 输出路径
     * @param verbose 是否显示详细信息
     * @param customJsAssets 自定义JS资源列表
     * @param customCssAssets 自定义CSS资源列表
     */
    private static func generateDirectoryIndexes(
        processedFiles: Array<(String, String)>, 
        outputPath: String, 
        verbose: Bool,
        customJsAssets: Array<String>,
        customCssAssets: Array<String>
    ): Unit {
        let processedDirs = ArrayList<String>()
        
        for (i in 0..processedFiles.size) {
            let (filePath, _) = processedFiles[i]
            let pathObj = Path(filePath)
            let parentDir = pathObj.parent.toString()
            
            if (!parentDir.isEmpty() && !processedDirs.contains(parentDir)) {
                generateDirectoryIndex(parentDir, processedFiles, outputPath, verbose, customJsAssets, customCssAssets)
                processedDirs.add(parentDir)
            }
        }
    }
    
    /**
     * 为指定目录生成索引
     * 
     * @param dirPath 目录路径
     * @param allFiles 所有文件信息
     * @param outputPath 输出根路径
     * @param verbose 是否显示详细信息
     * @param customJsAssets 自定义JS资源列表
     * @param customCssAssets 自定义CSS资源列表
     */
    private static func generateDirectoryIndex(
        dirPath: String, 
        allFiles: Array<(String, String)>, 
        outputPath: String, 
        verbose: Bool,
        customJsAssets: Array<String>,
        customCssAssets: Array<String>
    ): Unit {
        let indexPath = Path(outputPath).join(dirPath).join("index.html").normalize().toString()
        
        // 收集该目录下的文件和子目录
        let dirFiles = ArrayList<(String, String)>()
        let subdirectories = ArrayList<String>()
        
        for (i in 0..allFiles.size) {
            let (filePath, title) = allFiles[i]
            let pathObj = Path(filePath)
            let fileParentDir = pathObj.parent.toString()
            
            if (fileParentDir == dirPath) {
                // 直接在该目录下的文件
                dirFiles.add((pathObj.fileName, title))
            } else if (fileParentDir.startsWith("${dirPath}/")) {
                // 子目录中的文件，记录子目录
                let relativePath = fileParentDir[dirPath.size + 1..]
                let topLevelSubdir = getTopLevelDirectory(relativePath)
                if (!subdirectories.contains(topLevelSubdir)) {
                    subdirectories.add(topLevelSubdir)
                }
            }
        }
        
        let dirName = Path(dirPath).fileName
        let indexContent = generateDirectoryIndexContent(dirName, dirPath, dirFiles.toArray(), subdirectories.toArray(), customJsAssets, customCssAssets)
        ensureOutputDirectory(indexPath)
        writeFileContent(indexPath, indexContent)
        
        if (verbose) {
            KitHooks.success("Generated index for ${dirPath}: ${indexPath}")
        }
    }
    
    /**
     * 获取路径的顶级目录名
     * 
     * @param path 路径
     * @return 顶级目录名
     */
    private static func getTopLevelDirectory(path: String): String {
        if (let Some(slashIndex) <- path.indexOf("/")) {
            return path[..slashIndex]
        }
        return path
    }
    
    /**
     * 生成目录索引内容
     * 
     * @param title 目录标题
     * @param currentPath 当前路径
     * @param files 文件列表
     * @param subdirectories 子目录列表
     * @param customJsAssets 自定义JS资源列表
     * @param customCssAssets 自定义CSS资源列表
     * @return HTML内容
     */
    private static func generateDirectoryIndexContent(
        title: String, 
        currentPath: String, 
        files: Array<(String, String)>, 
        subdirectories: Array<String>,
        customJsAssets: Array<String>,
        customCssAssets: Array<String>
    ): String {
        // 读取模板文件
        let templatePath = ResourceResolver.resolveResourcePathString("assets/themes/arctic/index.html")
        let template = readFileContent(templatePath)
        
        // 生成内容部分
        var contentHtml = ""
        
        // 添加返回上级目录的链接（如果不是根目录）
        if (!currentPath.isEmpty()) {
            contentHtml += "            <li class=\"parent-dir\"><a href=\"../index.html\">📁 .. (Parent Directory)</a></li>\n"
        }
        
        // 添加子目录
        for (i in 0..subdirectories.size) {
            let subdir = subdirectories[i]
            contentHtml += "            <li class=\"directory\"><a href=\"${subdir}/index.html\">📁 ${subdir}/</a></li>\n"
        }
        
        // 添加文件
        for (i in 0..files.size) {
            let (fileName, fileTitle) = files[i]
            contentHtml += "            <li class=\"file\"><a href=\"${fileName}\">📄 ${fileTitle}</a></li>\n"
        }
        
        let totalItems = subdirectories.size + files.size
        let itemsText = if (totalItems == 1) { "item" } else { "items" }
        
        // 生成面包屑
        let breadcrumb = if (!currentPath.isEmpty()) {
            "<div class=\"breadcrumb\">📍 Path: /${currentPath}</div>"
        } else {
            ""
        }
        
        // 生成完整内容
        let content = if (totalItems > 0) {
            "<ul>\n${contentHtml}        </ul>\n        <div class=\"count\">Total: ${totalItems} ${itemsText}</div>"
        } else {
            "<div class=\"empty\">This directory is empty.</div>"
        }
        
        // 生成自定义assets HTML
        let customCssHtml = generateCustomCssAssetsHtmlForIndex(currentPath, customCssAssets)
        let customJsHtml = generateCustomJsAssetsHtmlForIndex(currentPath, customJsAssets)
        
        // 替换模板占位符
        return template
            .replace("{{TITLE}}", title)
            .replace("{{BREADCRUMB}}", breadcrumb)
            .replace("{{CONTENT}}", content)
            .replace("{{customCssAssets}}", customCssHtml)
            .replace("{{customJsAssets}}", customJsHtml)
    }
    
    /**
     * 为index.html生成自定义CSS assets的HTML标签
     * 
     * @param currentPath 当前路径（如 "docs/guide"）
     * @param customCssAssets CSS资源列表
     * @return CSS link标签的HTML字符串
     */
    private static func generateCustomCssAssetsHtmlForIndex(currentPath: String, customCssAssets: Array<String>): String {
        if (customCssAssets.size == 0) {
            return ""
        }
        
        // 计算到根目录的相对路径
        let depth = if (currentPath.isEmpty()) { 0 } else { currentPath.split("/").size }
        var relativePath = ""
        for (_ in 0..depth) {
            relativePath += "../"
        }
        
        let tags = ArrayList<String>()
        for (cssPath in customCssAssets) {
            let finalPath = resolveAssetPathForIndex(cssPath, relativePath)
            tags.add("    <link rel=\"stylesheet\" href=\"${finalPath}\">")
        }
        
        return String.join(tags.toArray(), delimiter: "\n")
    }
    
    /**
     * 为index.html生成自定义JS assets的HTML标签
     * 
     * @param currentPath 当前路径（如 "docs/guide"）
     * @param customJsAssets JS资源列表
     * @return script标签的HTML字符串
     */
    private static func generateCustomJsAssetsHtmlForIndex(currentPath: String, customJsAssets: Array<String>): String {
        if (customJsAssets.size == 0) {
            return ""
        }
        
        // 计算到根目录的相对路径
        let depth = if (currentPath.isEmpty()) { 0 } else { currentPath.split("/").size }
        var relativePath = ""
        for (_ in 0..depth) {
            relativePath += "../"
        }
        
        let tags = ArrayList<String>()
        for (jsPath in customJsAssets) {
            let finalPath = resolveAssetPathForIndex(jsPath, relativePath)
            tags.add("    <script src=\"${finalPath}\"></script>")
        }
        
        return String.join(tags.toArray(), delimiter: "\n")
    }
    
    /**
     * 为index.html解析资源路径（处理http/https和相对路径）
     * 
     * @param assetPath 原始资源路径
     * @param relativePath 相对路径前缀（到根目录）
     * @return 解析后的完整路径
     */
    private static func resolveAssetPathForIndex(assetPath: String, relativePath: String): String {
        // 如果是绝对URL（http://或https://），直接返回
        if (assetPath.startsWith("http://") || assetPath.startsWith("https://")) {
            return assetPath
        }
        
        // 相对路径：映射到public目录
        return "${relativePath}public/${assetPath}"
    }
    
    /**
     * 从文件路径提取标题（不含扩展名的文件名）
     * 
     * @param filePath 文件路径
     * @return 提取的标题
     */
    public static func extractTitle(filePath: String): String {
        return Path(filePath).fileNameWithoutExtension
    }
    
    /**
     * 复制favicon到输出目录
     * 
     * @param outputPath 输出路径
     */
    public static func copyFavicon(outputPath: String): Unit {
        let faviconSource = ResourceResolver.resolveResourcePath("assets/icon/markit.ico")
        let faviconTarget = Path(outputPath).join("favicon.ico").normalize().toString()
        
        try {
            if (exists(faviconSource)) {
                // 确保输出目录存在
                ensureOutputDirectory(faviconTarget)
                
                // 复制文件
                copy(faviconSource.toString(), to: faviconTarget, overwrite: true)
            }
        } catch (e: Exception) {
            KitHooks.warn("Failed to copy favicon.ico: ${e.message}")
        }
    }
    
    /**
     * 清理输出目录
     * 
     * @param outputPath 输出路径
     */
    public static func cleanOutputDirectory(outputPath: String): Unit {
        try {
            let outputPathObj = Path(outputPath)
            if (exists(outputPathObj)) {
                // 递归删除整个输出目录
                remove(outputPathObj, recursive: true)
                KitHooks.success("Cleaned output directory: ${outputPath}")
            }
        } catch (e: Exception) {
            KitHooks.warn("Failed to clean output directory: ${e.message}")
        }
    }
    
    /**
     * 复制所有资源文件到输出目录
     * 
     * @param outputPath 输出路径
     */
    public static func copyAllAssets(outputPath: String): Unit {
        try {
            let assetsSource = ResourceResolver.resolveResourcePath("assets")
            
            if (!exists(assetsSource)) {
                KitHooks.warn("Assets directory not found: ${assetsSource}")
                return
            }
            
            // 白名单：只复制 js 和 css 目录
            let dirsToCopy = ["js", "css"]
            var totalFileCount = 0
            
            for (i in 0..dirsToCopy.size) {
                let dirName = dirsToCopy[i]
                let targetDir = Path(outputPath).join(dirName)
                totalFileCount += copyResourceDirectories("assets/${dirName}", targetDir)
            }
            
            // 复制主题CSS文件到css目录
            let themeCssCount = copyThemeCSS(outputPath)
            totalFileCount += themeCssCount

            // 复制当前输出中实际用到的主题图标
            totalFileCount += copyUsedThemeIcons(outputPath, Path(outputPath))
            
            KitHooks.success("Copied ${totalFileCount} asset files")
        } catch (e: Exception) {
            KitHooks.warn("Failed to copy assets: ${e.message}")
        }
    }
    
    /**
     * 复制共享主题资源到输出目录的 assets/ 子目录
     * 用于多语言构建，将主题资源（CSS、JS、favicon）复制到根目录的 assets/ 仅一次
     * 
     * @param outputPath 输出路径
     * 
     * Validates: Requirements 10.1, 10.4
     */
    public static func copySharedAssets(outputPath: String): Unit {
        try {
            // 创建 assets 目录
            let assetsTargetPath = Path(outputPath).join("assets")
            
            // 清理 assets 目录（如果存在）
            if (exists(assetsTargetPath)) {
                remove(assetsTargetPath, recursive: true)
            }
            
            // 创建新的 assets 目录
            Directory.create(assetsTargetPath.toString(), recursive: true)
            
            let assetsSource = ResourceResolver.resolveResourcePath("assets")
            
            if (!exists(assetsSource)) {
                KitHooks.warn("Assets directory not found: ${assetsSource}")
                return
            }
            
            // 白名单：只复制 js 和 css 目录
            let dirsToCopy = ["js", "css"]
            var totalFileCount = 0
            
            for (i in 0..dirsToCopy.size) {
                let dirName = dirsToCopy[i]
                let targetDir = assetsTargetPath.join(dirName)
                totalFileCount += copyResourceDirectories("assets/${dirName}", targetDir)
            }
            
            // 复制主题CSS文件到 assets/css 目录
            let themeCssCount = copyThemeCSS(assetsTargetPath.toString())
            totalFileCount += themeCssCount

            // 只复制当前站点实际用到的主题图标
            totalFileCount += copyUsedThemeIcons(outputPath, assetsTargetPath)

            // 复制 favicon 到 assets 目录
            copyFaviconToAssets(assetsTargetPath.toString())
            totalFileCount += 1
            
            KitHooks.success("Copied ${totalFileCount} shared asset files to assets/")
        } catch (e: Exception) {
            KitHooks.warn("Failed to copy shared assets: ${e.message}")
        }
    }
    
    /**
     * 复制公共资源到输出目录的 public/ 子目录
     * 用于多语言构建，将用户的 public/ 文件夹复制到输出根目录仅一次
     * 
     * @param inputPath 输入路径（配置文件所在目录）
     * @param outputPath 输出路径
     * 
     * Validates: Requirements 5.4, 10.2, 10.5
     */
    public static func copyPublicAssets(inputPath: String, outputPath: String): Unit {
        let publicPath = Path(inputPath).join("public").normalize().toString()
        
        // 检查 public/ 文件夹是否存在
        if (!exists(Path(publicPath))) {
            return  // 静默跳过
        }
        
        let targetPath = Path(outputPath).join("public").normalize().toString()
        
        try {
            // 拷贝整个 public/ 文件夹到输出目录，保持原始目录结构
            copyDirectoryRecursively(publicPath, targetPath)
            
            KitHooks.success("Copied public assets to ${targetPath}")
        } catch (e: Exception) {
            KitHooks.warn("Failed to copy public assets: ${e.message}")
        }
    }
    
    /**
     * 复制 favicon 到 assets 目录
     * 
     * @param assetsPath assets 目录路径
     */
    private static func copyFaviconToAssets(assetsPath: String): Unit {
        let faviconSource = ResourceResolver.resolveResourcePath("assets/icon/markit.ico")
        let faviconTarget = Path(assetsPath).join("favicon.ico").normalize().toString()
        
        try {
            if (exists(faviconSource)) {
                copy(faviconSource.toString(), to: faviconTarget, overwrite: true)
            }
        } catch (e: Exception) {
            KitHooks.warn("Failed to copy favicon to assets: ${e.message}")
        }
    }
    
    /**
     * 复制 Typst/PDF 构建所需的支持资源到输出目录
     *
     * @param outputPath 输出目录
     */
    public static func copyTypstSupportAssets(outputPath: String): Unit {
        var totalCount = 0

        try {
            let assetsTargetPath = Path(outputPath).join("assets")
            if (!exists(assetsTargetPath)) {
                Directory.create(assetsTargetPath.toString(), recursive: true)
            }

            if (ResourceResolver.resourceExists("assets/fonts")) {
                let fontsTarget = assetsTargetPath.join("fonts")
                totalCount += copyResourceDirectories("assets/fonts", fontsTarget)
            }

            if (ResourceResolver.resourceExists("assets/typst")) {
                let typstTarget = assetsTargetPath.join("typst")
                totalCount += copyResourceDirectories("assets/typst", typstTarget)
            }

            if (totalCount > 0) {
                KitHooks.success("Copied ${totalCount} Typst support asset files")
            }
        } catch (e: Exception) {
            KitHooks.warn("Failed to copy Typst support assets: ${e.message}")
        }
    }
    
    /**
     * 复制主题CSS文件到输出目录的css文件夹
     * 
     * @param outputPath 输出路径
     * @return 复制的文件数量
     */
    private static func copyThemeCSS(outputPath: String): Int {
        try {
            let cssDir = Path(outputPath).join("css")
            if (!exists(cssDir)) {
                Directory.create(cssDir.toString(), recursive: true)
            }
            
            var count = 0
            
            // 复制 Arctic 主题的 CSS 文件
            let themeStylesSource = ResourceResolver.resolveResourcePath("assets/themes/arctic/styles.css")
            let themeStylesTarget = cssDir.join("styles.css")
            
            if (exists(themeStylesSource)) {
                copy(themeStylesSource.toString(), to: themeStylesTarget.toString(), overwrite: true)
                count += 1
            } else {
                KitHooks.warn("Theme CSS not found: ${themeStylesSource}")
            }
            
            return count
        } catch (e: Exception) {
            KitHooks.warn("Failed to copy theme CSS: ${e.message}")
            return 0
        }
    }

    private static func copyUsedThemeIcons(outputRootPath: String, assetsPath: Path): Int {
        let usedIcons = ArrayList<String>()
        collectUsedThemeIcons(Path(outputRootPath), usedIcons)
        if (usedIcons.isEmpty()) {
            return 0
        }

        let iconsTargetDir = assetsPath.join("icons")
        if (!exists(iconsTargetDir)) {
            Directory.create(iconsTargetDir.toString(), recursive: true)
        }

        var count = 0
        for (iconFile in usedIcons) {
            let source = ResourceResolver.resolveResourcePath("assets/themes/arctic/icons/${iconFile}")
            if (!exists(source)) {
                continue
            }
            let target = iconsTargetDir.join(iconFile)
            copy(source.toString(), to: target.toString(), overwrite: true)
            count += 1
        }
        return count
    }

    private static func collectUsedThemeIcons(path: Path, usedIcons: ArrayList<String>): Unit {
        if (!exists(path)) {
            return
        }
        let info = FileInfo(path)
        if (info.isRegular()) {
            let pathText = path.toString()
            if (pathText.endsWith(".html")) {
                collectUsedThemeIconsFromHtml(String.fromUtf8(File.readFrom(pathText)), usedIcons)
            }
            return
        }
        if (!info.isDirectory()) {
            return
        }

        for (entry in Directory.readFrom(path)) {
            collectUsedThemeIcons(entry.path, usedIcons)
        }
    }

    private static func collectUsedThemeIconsFromHtml(html: String, usedIcons: ArrayList<String>): Unit {
        if (html.contains("icon-cj") || html.contains("icon-cangjie")) {
            addUniqueIcon(usedIcons, "cangjie.svg")
        }
        if (html.contains("icon-json")) {
            addUniqueIcon(usedIcons, "json.svg")
        }
        if (html.contains("icon-bash") || html.contains("icon-sh") || html.contains("icon-shell")) {
            addUniqueIcon(usedIcons, "shell.svg")
        }
    }

    private static func addUniqueIcon(usedIcons: ArrayList<String>, iconFile: String): Unit {
        if (!usedIcons.contains(iconFile)) {
            usedIcons.add(iconFile)
        }
    }
    
    /**
     * 递归复制目录内容
     * 
     * @param sourceDir 源目录
     * @param targetDir 目标目录
     * @return 复制的文件数量
     */
    private static func copyAssetsRecursively(sourceDir: String, targetDir: String): Int {
        let sourcePath = Path(sourceDir)
        var fileCount = 0
        
        // 确保目标目录存在
        if (!exists(Path(targetDir))) {
            Directory.create(targetDir, recursive: true)
        }
        
        // 遍历源目录中的所有文件和子目录
        for (entry in Directory.readFrom(sourcePath)) {
            let sourceName = entry.name
            let sourceEntryPath = entry.path
            let targetEntryPath = Path(targetDir).join(sourceName)
            
            if (entry.isDirectory()) {
                // 确保目标目录存在
                if (!exists(targetEntryPath)) {
                    Directory.create(targetEntryPath.toString(), recursive: true)
                }
                // 递归复制子目录
                fileCount += copyAssetsRecursively(sourceEntryPath.toString(), targetEntryPath.toString())
            } else if (entry.isRegular()) {
                // 复制文件
                copy(sourceEntryPath.toString(), to: targetEntryPath.toString(), overwrite: true)
                fileCount += 1
            }
        }
        
        return fileCount
    }

    private static func copyResourceDirectories(relativePath: String, targetDir: Path): Int {
        let candidates = ResourceResolver.getResourceCandidates(relativePath)
        var totalCount = 0

        for (i in 0..candidates.size) {
            let sourceDir = candidates[candidates.size - i - 1]
            if (exists(sourceDir)) {
                totalCount += copyAssetsRecursively(sourceDir.toString(), targetDir.toString())
            }
        }

        return totalCount
    }
    
    /**
     * 递归复制目录
     * 
     * @param sourceDir 源目录
     * @param targetDir 目标目录
     */
    private static func copyDirectoryRecursively(sourceDir: String, targetDir: String): Unit {
        let sourcePath = Path(sourceDir)
        let targetPath = Path(targetDir)
        
        // 确保目标目录存在
        if (!exists(targetPath)) {
            Directory.create(targetDir, recursive: true)
        }
        
        // 遍历源目录中的所有文件和子目录
        for (entry in Directory.readFrom(sourcePath)) {
            let sourceName = entry.name
            let sourceEntryPath = entry.path
            let targetEntryPath = targetPath.join(sourceName)
            
            if (entry.isDirectory()) {
                // 递归复制子目录
                copyDirectoryRecursively(sourceEntryPath.toString(), targetEntryPath.toString())
            } else if (entry.isRegular()) {
                // 复制文件
                copy(sourceEntryPath.toString(), to: targetEntryPath.toString(), overwrite: true)
            }
        }
    }
    
    /**
     * 复制输入目录中的静态文件（图片等）到输出目录
     * 保持相对目录结构
     * 
     * @param inputPath 输入路径
     * @param outputPath 输出路径
     */
    public static func copyStaticFiles(inputPath: String, outputPath: String): Unit {
        try {
            let inputPathObj = Path(inputPath)
            
            if (!exists(inputPathObj)) {
                return
            }
            
            let fileInfo = FileInfo(inputPathObj)
            if (fileInfo.isRegular()) {
                // 如果输入是单个文件，不需要复制静态文件
                return
            }
            
            if (!fileInfo.isDirectory()) {
                return
            }
            
            // 定义静态文件扩展名（图片、视频、音频等）
            let staticExtensions = [
                ".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp", ".ico",
                ".mp4", ".webm", ".ogg", ".mp3", ".wav",
                ".pdf", ".zip", ".tar", ".gz", ".css", ".js"
            ]
            
            // 递归复制静态文件
            let fileCount = copyStaticFilesRecursively(inputPath, inputPath, outputPath, staticExtensions)
            
            if (fileCount > 0) {
                KitHooks.success("Copied ${fileCount} static files from input directory")
            }
        } catch (e: Exception) {
            KitHooks.warn("Failed to copy static files: ${e.message}")
        }
    }
    
    /**
     * 递归复制静态文件
     * 
     * @param currentDir 当前目录
     * @param inputBasePath 输入基础路径
     * @param outputBasePath 输出基础路径
     * @param staticExtensions 静态文件扩展名列表
     * @return 复制的文件数量
     */
    private static func copyStaticFilesRecursively(
        currentDir: String,
        inputBasePath: String,
        outputBasePath: String,
        staticExtensions: Array<String>
    ): Int {
        var fileCount = 0
        
        try {
            for (entry in Directory.readFrom(Path(currentDir))) {
                if (entry.isDirectory()) {
                    // 递归处理子目录
                    fileCount += copyStaticFilesRecursively(
                        entry.path.toString(),
                        inputBasePath,
                        outputBasePath,
                        staticExtensions
                    )
                } else if (entry.isRegular()) {
                    // 检查是否为静态文件
                    let fileName = entry.name.toAsciiLower()
                    var isStatic = false
                    
                    for (ext in staticExtensions) {
                        if (fileName.endsWith(ext)) {
                            isStatic = true
                            break
                        }
                    }
                    
                    if (isStatic) {
                        // 计算相对路径
                        let relativePath = getRelativePath(entry.path.toString(), inputBasePath)
                        
                        // 构建目标路径
                        let targetPath = Path(outputBasePath).join(relativePath)
                        
                        // 确保目标目录存在
                        let targetDir = targetPath.parent
                        if (!targetDir.isEmpty() && !exists(targetDir)) {
                            Directory.create(targetDir.toString(), recursive: true)
                        }
                        
                        // 复制文件
                        copy(entry.path.toString(), to: targetPath.toString(), overwrite: true)
                        fileCount += 1
                    }
                }
            }
        } catch (e: Exception) {
            KitHooks.warn("Failed to copy static files from ${currentDir}: ${e.message}")
        }
        
        return fileCount
    }
}
