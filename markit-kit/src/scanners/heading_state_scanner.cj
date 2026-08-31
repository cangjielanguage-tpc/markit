package markit_kit.scanners

import markit_kit.utils.KitHooks

import markit.Markit
import markit_kit.models.{RenderConfig, GlobalContext}
import markit_kit.interfaces.Processor
import markit_kit.utils.FileHandler
import std.collection.{HashMap, ArrayList}
import std.sync.AtomicInt64
import markit.bundles.GFMBundle
import markit.plugins.toc.Toc
import markit.plugins.standard.inline.link.{FileTree, HeadingInfo, LinkConfig}
import markit.plugins.i18n.I18nPlugin
import markit.plugins.standard.block.fenced_code_block.FencedCodeBlockConfig
import markit.plugins.standard.block.heading.{HeadingNumberingConfig, HeadingClosableConfig}
import markit_kit.utils.CliMarkitFactory

/**
 * 预扫描结果数据结构
 * 
 * 包含预扫描阶段的所有输出：
 * - initialStates: 文件路径到初始标题状态的映射
 * - headingsMap: 文件路径到 heading 列表的映射
 * 
 * 对应需求：1.1, 1.2, 1.3
 */
public class ScanResult {
    public let initialStates: HashMap<String, Array<Int64>>
    public let headingsMap: HashMap<String, Array<HeadingInfo>>
    
    public init(
        initialStates: HashMap<String, Array<Int64>>,
        headingsMap: HashMap<String, Array<HeadingInfo>>
    ) {
        this.initialStates = initialStates
        this.headingsMap = headingsMap
    }
}

/**
 * 标题状态扫描器
 * 
 * 职责：
 * - 预扫描所有文件提取 heading 信息
 * - 计算每个文件的初始标题状态
 * - 构建完整的 FileTree
 * - 更新 LinkPlugin 配置
 * 
 * 对应需求：1.1, 1.2, 1.3, 5.1, 11.2
 */
public class HeadingStateScanner {
    
    /**
     * 扫描所有文件并计算初始状态
     * 
     * 此方法实现预扫描阶段的核心逻辑：
     * 1. 创建用于预扫描的 Markit 实例（包含完整块边界能力）
     * 2. 按顺序遍历所有文件
     * 3. 对每个文件快速提取 heading 信息
     * 4. 根据 resetFor 模式计算初始标题状态
     * 5. 构建完整的 FileTree
     * 6. 更新 LinkPlugin 的 FileTree
     * 
     * @param inputFiles 输入文件列表（按顺序）
     * @param config 渲染配置
     * @param processor 处理器实例（用于更新链接解析配置）
     * @return ScanResult 包含 initialStates 和 headingsMap
     * 
     * 对应需求：1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9
     */
    public static func scanAndComputeStates(
        inputFiles: Array<String>,
        config: RenderConfig,
        processor: Processor
    ): ScanResult {
        // 1. 创建轻量级 Markit 实例
        let lightweightMarkit = createLightweightMarkit(config)
        
        // 2. 初始化状态和数据结构
        var currentState = getDefaultState(config)
        let initialStates = HashMap<String, Array<Int64>>()
        let headingsMap = HashMap<String, Array<HeadingInfo>>()
        var lastDirectory = ""
        
        // 3. 初始化进度显示（使用 AtomicInt64 确保进度单调递增）
        let totalFiles = inputFiles.size
        let progressCounter = AtomicInt64(0)
        KitHooks.spinner("Analyzing... [░░░░░░░░░░░░░░░░░░░░░░░░] 0 done, ${totalFiles} total")
        
        // 4. 遍历所有文件
        for (i in 0..inputFiles.size) {
            let inputFile = inputFiles[i]
            
            // 更新进度计数器（原子操作，确保线程安全和单调递增）
            let currentProgress = progressCounter.fetchAdd(1) + 1
            
            // 更新进度显示（使用 ▓ 表示已完成，░ 表示未开始）
            let progressBar = KitHooks.scanProgressBar(currentProgress, totalFiles, width: 24)
            KitHooks.updateSpinner("Analyzing... ${progressBar} ${currentProgress} done, ${totalFiles} total")
            
            // 检查是否需要重置状态
            let currentDirectory = getDirectory(inputFile)
            
            if (config.headingResetFor == "always") {
                // "always" 模式：每个文件使用默认状态
                currentState = getDefaultState(config)
            } else if (config.headingResetFor == "directory" && currentDirectory != lastDirectory) {
                // "directory" 模式：目录更改时重置状态
                currentState = getDefaultState(config)
                lastDirectory = currentDirectory
            }
            // "never" 模式：不重置，继续使用当前状态
            
            // 保存初始状态（复制数组以避免引用问题）
            let stateCopy = ArrayList<Int64>()
            for (value in currentState) {
                stateCopy.add(value)
            }
            initialStates[inputFile] = stateCopy.toArray()
            
            // 提取 headings
            try {
                let content = FileHandler.readFileContent(inputFile)
                let relativePath = FileHandler.getRelativePath(inputFile, config.inputPath)
                
                // 转换为 .html 路径（用于 FileTree）
                let htmlPath = relativePath.replace(".md", ".html").replace(".markdown", ".html")
                
                let headings = extractHeadings(content, lightweightMarkit, htmlPath)
                
                // 更新当前状态（模拟标题编号）
                for (heading in headings) {
                    updateState(currentState, heading.level, config)
                }
                
                // 保存 headings 到 map
                headingsMap[htmlPath] = headings
                
            } catch (e: Exception) {
                // 如果解析失败，记录警告并继续处理
                KitHooks.insertBeforeWarn("Failed to scan ${inputFile}: ${e.message}")
                // 使用空 heading 列表
                let relativePath = FileHandler.getRelativePath(inputFile, config.inputPath)
                let htmlPath = relativePath.replace(".md", ".html").replace(".markdown", ".html")
                headingsMap[htmlPath] = []
            }
        }
        
        // 更新最后的进度（确保显示 100% 完成）
        let finalProgress = progressCounter.load()
        let finalProgressBar = KitHooks.scanProgressBar(finalProgress, totalFiles, width: 24)
        KitHooks.updateSpinner("Analyzing... ${finalProgressBar} ${finalProgress} done, ${totalFiles} total")
        
        // 5. 构建 FileTree
        let fileTree = buildFileTree(headingsMap)
        
        // 6. 更新链接解析配置
        updateLinkPluginFileTree(processor, fileTree)
        
        // 停止 spinner 并显示成功消息
        KitHooks.stopSpinnerSuccess("Analyzed ${totalFiles} files")
        
        // 7. 返回扫描结果（包含 initialStates 和 headingsMap）
        return ScanResult(initialStates, headingsMap)
    }
    
    /**
     * 从扫描结果构建 FileTree
     * 
     * 此方法将收集到的 heading 信息组织成 FileTree 结构，
     * 供 LinkPlugin 使用以解析文件间链接。
     * 
     * 支持模糊匹配：为每个 .html 文件自动添加对应的 .md 路径，
     * 以便 LinkPlugin 能够正确解析 Markdown 源文件中的链接。
     * 
     * @param headingsMap 文件路径到 heading 列表的映射
     * @return 完整的 FileTree
     * 
     * 对应需求：1.7, 2.4
     */
    private static func buildFileTree(
        headingsMap: HashMap<String, Array<HeadingInfo>>
    ): FileTree {
        // 1. 从 headingsMap 中提取所有文件路径
        let fileList = ArrayList<String>()
        
        for ((filePath, _) in headingsMap) {
            // 添加原始路径
            fileList.add(filePath)
            
            // 支持模糊匹配：如果是 .html 路径，同时添加对应的 .md 路径
            if (filePath.endsWith(".html")) {
                let mdPath = filePath[0..(filePath.size - 5)] + ".md"
                fileList.add(mdPath)
            }
        }
        
        // 2. 创建包含文件列表的 FileTree
        let fileTree = FileTree(fileList.toArray())
        
        // 3. 添加所有 headings 到 FileTree
        for ((filePath, headings) in headingsMap) {
            for (heading in headings) {
                fileTree.addHeading(heading)
            }
        }
        
        return fileTree
    }

    private static func createLightweightMarkit(config: RenderConfig): Markit {
        let baseHeadingConfig = config.headingNumberingConfig ?? HeadingNumberingConfig(
            enabled: false,
            startFrom: (1, 1, 1, 1, 1, 1)
        )
        let headingConfig = HeadingNumberingConfig(
            enabled: baseHeadingConfig.enabled,
            startFrom: (
                baseHeadingConfig.startFrom[0],
                baseHeadingConfig.startFrom[1],
                baseHeadingConfig.startFrom[2],
                baseHeadingConfig.startFrom[3],
                baseHeadingConfig.startFrom[4],
                baseHeadingConfig.startFrom[5]
            ),
            maxDepth: baseHeadingConfig.maxDepth,
            includeInHtml: baseHeadingConfig.includeInHtml,
            separator: baseHeadingConfig.separator,
            resetBeforeParse: baseHeadingConfig.resetBeforeParse
        )
        let closableConfig = HeadingClosableConfig(enabled: config.headingClosable)
        let i18nPlugin = if (let Some(i18nConfig) <- config.i18nConfig) {
            I18nPlugin(config: i18nConfig)
        } else {
            I18nPlugin()
        }

        return Markit.empty()
            .use(GFMBundle(
                headingNumberingConfig: headingConfig,
                closableConfig: closableConfig,
                fencedCodeBlockConfig: FencedCodeBlockConfig(
                    enableCodehl: false,
                    enableMermaid: false
                )
            ))
            .use(i18nPlugin)
    }
    
    /**
     * 快速提取文件的 heading 信息
     * 
     * 此方法使用轻量级 Markit 实例快速提取文件中的所有标题，
     * 使用 TOC 插件的 extractDetailedHeadingList 方法来正确处理 i18n 和其他特殊节点。
     * 
     * @param content 文件内容
     * @param lightweightMarkit 轻量级 Markit 实例
     * @param filePath 文件路径（用于构建 HeadingInfo）
     * @return heading 信息列表
     * 
     * 对应需求：1.3, 5.3, 5.5
     */
    private static func extractHeadings(
        content: String,
        lightweightMarkit: Markit,
        filePath: String
    ): Array<HeadingInfo> {
        let headings = ArrayList<HeadingInfo>()
        
        try {
            // 使用轻量级 Markit 解析内容
            let parseResult = lightweightMarkit.parse(content)
            
            // 获取文档节点
            let document = CliMarkitFactory.documentOf(parseResult)
            
            // 使用 TOC 插件提取标题详细信息
            // 返回: (text, level, number, id)
            let headingList = Toc.extractDetailedHeadingList(document, minLevel: 1, maxLevel: 6)
            
            // 转换为 HeadingInfo 对象
            for (i in 0..headingList.size) {
                let (text, level, _, id) = headingList[i]
                let headingInfo = HeadingInfo(
                    text,
                    id,
                    filePath,
                    level
                )
                
                headings.add(headingInfo)
            }
        } catch (e: Exception) {
            // 如果解析失败，返回空列表
            // 错误会在调用方处理
        }
        
        return headings.toArray()
    }
    
    /**
     * 获取默认初始状态
     * 
     * 根据 HeadingNumberingConfig 的 startFrom 配置创建默认初始状态。
     * 状态是一个长度为 6 的数组，表示 H1-H6 的当前计数器值。
     * 
     * @param config 渲染配置
     * @return 默认初始状态（6 个整数的数组）
     * 
     * 对应需求：1.6
     */
    private static func getDefaultState(config: RenderConfig): Array<Int64> {
        // 根据 headingNumberingConfig 的 startFrom 配置创建初始状态
        // 状态值为 startFrom - 1，因为第一次递增时会变成 startFrom
        if (let Some(numberingConfig) <- config.headingNumberingConfig) {
            let startFrom = numberingConfig.startFrom
            return Array<Int64>(6) { i => Int64(startFrom[i] - 1) }
        }
        
        // 如果没有配置，使用默认值 [0, 0, 0, 0, 0, 0]
        // 这样第一次递增时会变成 [1, 1, 1, 1, 1, 1]
        return Array<Int64>(6) { i => 0 }
    }
    
    /**
     * 更新标题状态
     * 
     * 根据标题级别更新状态数组：
     * - 递增当前级别的计数器
     * - 重置更深层级的计数器
     * 
     * @param state 当前状态（会被修改）
     * @param level 标题级别（1-6）
     * @param config 渲染配置
     * 
     * 对应需求：1.4
     */
    private static func updateState(
        state: Array<Int64>,
        level: Int,
        config: RenderConfig
    ): Unit {
        // 确保 level 在有效范围内（1-6）
        if (level < 1 || level > 6) {
            return
        }
        
        // 获取 maxDepth 配置
        let maxDepth = if (let Some(numberingConfig) <- config.headingNumberingConfig) {
            numberingConfig.maxDepth
        } else {
            6  // 默认最大深度
        }
        
        // 如果级别超过 maxDepth，不更新状态
        if (level > maxDepth) {
            return
        }
        
        // 获取 startFrom 配置
        let startFrom = if (let Some(numberingConfig) <- config.headingNumberingConfig) {
            numberingConfig.startFrom
        } else {
            Array<Int>(6) { i => 1 }  // 默认从 1 开始
        }
        
        // 转换为 0-based 索引
        let index = level - 1
        
        // 1. 递增当前级别的计数器
        state[index] = state[index] + 1
        
        // 2. 重置更深层级的计数器（重置为 startFrom - 1）
        for (i in (index + 1)..6) {
            state[i] = Int64(startFrom[i] - 1)
        }
    }
    
    /**
     * 获取文件所在目录
     * 
     * 用于判断文件是否在新目录中，以支持 "directory" 重置模式。
     * 
     * @param filePath 文件路径
     * @return 目录路径
     * 
     * 对应需求：1.5
     */
    private static func getDirectory(filePath: String): String {
        // 查找最后一个路径分隔符
        let lastSlashIndex = filePath.lastIndexOf('/')
        
        if (let Some(idx) <- lastSlashIndex) {
            // 返回目录部分（不包括文件名）
            return filePath[0..idx]
        }
        
        // 如果没有找到分隔符，说明文件在当前目录
        return ""
    }
    
    /**
     * 更新 LinkPlugin 的 FileTree
     * 
     * 此方法将构建好的 FileTree 更新到 LinkPlugin 的配置中，
     * 使得 LinkPlugin 能够正确解析文件间链接。
     * 
     * @param processor 处理器实例
     * @param fileTree 构建好的 FileTree
     * 
     * 对应需求：1.8
     */
    private static func updateLinkPluginFileTree(
        processor: Processor,
        fileTree: FileTree
    ): Unit {
        let currentConfig = GlobalContext.linkConfig ?? LinkConfig()
        let newConfig = LinkConfig(
            fileTree: Some(fileTree),
            renderMode: currentConfig.renderMode,
            outputExtension: currentConfig.outputExtension,
            preserveFlatFilePaths: currentConfig.preserveFlatFilePaths,
            currentFilePath: currentConfig.currentFilePath
        )
        GlobalContext.linkConfig = Some(newConfig)
        processor.setLinkConfig(newConfig)
    }
}
