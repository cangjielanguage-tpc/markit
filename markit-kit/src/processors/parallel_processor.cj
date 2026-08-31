package markit_kit.processors

import markit_kit.utils.KitHooks

import markit_kit.interfaces.Processor
import markit_kit.models.{RenderConfig, SummaryConfig, SummaryOptions, SiteStructure, GlobalContext}
import markit_kit.services.{SearchIndexBuilder, SearchIndexSection}
import markit_kit.utils.FileHandler
import std.collection.{HashMap, ArrayList}
import std.sync.{AtomicInt64, Mutex, Semaphore}
import std.time.MonoTime
import std.fs.{Path, exists, Directory}
import markit.plugins.standard.inline.link.{HeadingInfo, LinkConfig}

/**
 * 处理结果数据结构
 * 
 * 包含单个文件处理的完整结果信息，包括：
 * - 输入/输出文件路径
 * - 页面标题和相对路径
 * - 搜索索引数据
 * - 成功状态和错误信息
 * 
 * 对应需求：2.1, 11.3, 11.4
 */
public class ProcessedFileResult {
    public let inputFile: String
    public let outputFile: String
    public let relativePath: String
    public let title: String
    public let searchSections: Array<SearchIndexSection>
    public let success: Bool
    public let errorMessage: ?String
    
    /**
     * 构造成功的处理结果
     * 
     * @param inputFile 输入文件路径
     * @param outputFile 输出文件路径
     * @param relativePath 相对路径
     * @param title 页面标题
     * @param searchSections 搜索索引数据
     */
    public init(
        inputFile: String,
        outputFile: String,
        relativePath: String,
        title: String,
        searchSections: Array<SearchIndexSection>
    ) {
        this.inputFile = inputFile
        this.outputFile = outputFile
        this.relativePath = relativePath
        this.title = title
        this.searchSections = searchSections
        this.success = true
        this.errorMessage = None
    }
    
    /**
     * 构造失败的处理结果
     * 
     * @param inputFile 输入文件路径
     * @param errorMessage 错误信息
     */
    public init(inputFile: String, errorMessage: String) {
        this.inputFile = inputFile
        this.outputFile = ""
        this.relativePath = ""
        this.title = ""
        this.searchSections = []
        this.success = false
        this.errorMessage = Some(errorMessage)
    }
}

/**
 * 并行处理器
 * 
 * 负责管理并行工作线程，分发文件处理任务，执行"解析 → 渲染 → 写入"流水线。
 * 
 * 核心功能：
 * - 管理并行工作线程
 * - 分发文件处理任务
 * - 执行完整的"解析 → 渲染 → 写入"流水线
 * - 维护线程安全的进度计数器
 * - 收集处理结果和搜索索引数据
 * 
 * 对应需求：2.1, 11.3, 11.4
 */
public class ParallelProcessor {
    
    /**
     * 并行处理所有文件
     * 
     * 根据 parallelJobs 参数决定使用串行或并行模式：
     * - parallelJobs == 1: 串行处理
     * - parallelJobs > 1: 并行处理
     * 
     * 每个文件独立执行完整的"解析 → 渲染 → 写入"流水线，
     * 使用预计算的初始状态和 FileTree。
     * 
     * 线程安全保证：
     * - 使用 AtomicInt64 实现 parsedCounter 和 renderedCounter
     * - 使用 Mutex 保护进度显示更新
     * - 确保不变式：renderedCounter <= parsedCounter <= totalCount
     * 
     * @param inputFiles 输入文件列表
     * @param initialStates 预计算的初始状态映射
     * @param headingsMap 预扫描的 headings 映射
     * @param processor 处理器实例（用于获取配置，不直接用于并发处理）
     * @param parallelJobs 并行任务数（1=串行，>1=并行）
     * @return 处理结果列表
     * 
     * 对应需求：2.1, 2.8, 2.10, 2.13, 6.3, 10.2, 10.3, 10.4, 12.4, 12.5, 12.6, 12.9
     */
    public static func processFiles(
        inputFiles: Array<String>,
        initialStates: HashMap<String, Array<Int64>>,
        headingsMap: HashMap<String, Array<HeadingInfo>>,
        processor: Processor,
        parallelJobs: Int64
    ): Array<ProcessedFileResult> {
        try {
            return processFilesInternal(inputFiles, initialStates, headingsMap, processor, parallelJobs)
        } catch (e: Exception) {
            // 并行处理失败，降级到串行处理
            KitHooks.err("Parallel processing failed: ${e.message}")
            KitHooks.info("Falling back to serial processing...")
            
            return processFilesInternal(inputFiles, initialStates, headingsMap, processor, 1)
        }
    }
    
    /**
     * 内部并行处理实现
     * 
     * @param inputFiles 输入文件列表
     * @param initialStates 预计算的初始状态映射
     * @param headingsMap 预扫描的 headings 映射
     * @param processor 处理器实例
     * @param parallelJobs 并行任务数（1=串行，>1=并行）
     * @return 处理结果列表
     * 
     * 对应需求：2.1, 2.8, 9.2, 9.3, 9.7, 10.2, 10.3, 10.4
     */
    private static func processFilesInternal(
        inputFiles: Array<String>,
        initialStates: HashMap<String, Array<Int64>>,
        headingsMap: HashMap<String, Array<HeadingInfo>>,
        processor: Processor,
        parallelJobs: Int64
    ): Array<ProcessedFileResult> {
        // 从全局上下文获取配置
        let config = GlobalContext.renderConfig.getOrThrow()
        let siteStructure = GlobalContext.siteStructure.getOrThrow()
        let summaryConfig = GlobalContext.summaryConfig.getOrThrow()
        let summaryOptions = GlobalContext.summaryOptions.getOrThrow()
        
        // 0. 预先创建所有需要的输出目录（避免并发创建冲突）
        let uniqueDirs = HashMap<String, Bool>()
        for (inputFile in inputFiles) {
            let outputFile = FileHandler.generateDocumentOutputPathWithStructure(
                inputFile, 
                config.inputPath, 
                config.outputPath, 
                processor
            )
            let outputDir = Path(outputFile).parent
            if (!outputDir.isEmpty()) {
                uniqueDirs[outputDir.toString()] = true
            }
        }
        
        // 创建所有唯一的目录（避免并发创建冲突）
        for ((dir, _) in uniqueDirs) {
            if (!exists(Path(dir))) {
                try {
                    Directory.create(dir, recursive: true)
                } catch (e: Exception) {
                    // 忽略 "File exists" 错误（并发创建时可能发生）
                    if (!exists(Path(dir))) {
                        // 如果目录仍然不存在，说明是其他错误，记录警告
                        KitHooks.warn("Failed to create directory ${dir}: ${e.message}")
                    }
                }
            }
        }
        
        // 1. 初始化线程安全的进度计数器
        let parsedCounter = AtomicInt64(0)
        let renderedCounter = AtomicInt64(0)
        let totalFiles = Int64(inputFiles.size)
        
        // 2. 初始化进度显示互斥锁
        let progressMutex = Mutex()
        
        // 3. 初始化结果收集器（线程安全）
        let results = ArrayList<ProcessedFileResult>()
        let resultsMutex = Mutex()
        
        // 4. 计算实际使用的并发数（不超过文件数量）
        let actualParallelJobs = if (parallelJobs > totalFiles) {
            totalFiles
        } else {
            parallelJobs
        }
        
        // 5. 启动进度显示
        let messagePrefix = if (actualParallelJobs > 1) { 
            "Processing (parallel, ${actualParallelJobs} workers)..." 
        } else { 
            "Processing..." 
        }
        let initialProgress = KitHooks.pipelineProgressBar(0, 0, totalFiles)
        KitHooks.spinner("${messagePrefix} ${initialProgress}")
        
        // 6. 根据 actualParallelJobs 选择串行或并行模式
        if (actualParallelJobs == 1) {
            // 串行模式：按顺序处理每个文件
            for (i in 0..inputFiles.size) {
                let inputFile = inputFiles[i]
                let initialState = initialStates.get(inputFile).getOrThrow()
                let relativePath = FileHandler.getRelativePath(inputFile, config.inputPath)
                let htmlRelativePath = relativePath.replace(".md", ".html").replace(".markdown", ".html")
                
                let result = processFilePipeline(
                    inputFile,
                    initialState,
                    headingsMap.get(htmlRelativePath),
                    processor,
                    parsedCounter,
                    renderedCounter,
                    totalFiles,
                    progressMutex,
                    messagePrefix
                )
                
                results.add(result)
            }
        } else {
            // 并行模式：维护一个 processor 资源池（borrow / return），
            // 保证同一时刻每个 processor 仅被一个线程使用，彻底避免状态串扰。
            let pool = ArrayList<Processor>()
            for (_ in 0..actualParallelJobs) {
                pool.add(createFileProcessor(processor))
            }
            let poolMutex = Mutex()
            let poolCond = synchronized(poolMutex) { poolMutex.condition() }

            func borrowProcessor(): Processor {
                synchronized(poolMutex) {
                    while (pool.size == 0) {
                        poolCond.wait()
                    }
                    let p = pool[pool.size - 1]
                    pool.remove(at: pool.size - 1)
                    return p
                }
            }

            func returnProcessor(p: Processor): Unit {
                synchronized(poolMutex) {
                    pool.add(p)
                    poolCond.notify()
                }
            }

            // 收集每个文件对应的 Future，主线程通过 get() 等待，
            // 既能确保所有 spawn 完成（包括写盘 + results.add），
            // 又能把 spawn 内部异常重新抛回主线程触发降级。
            let futures = ArrayList<Future<Unit>>()

            for (i in 0..inputFiles.size) {
                let idx = i
                let fut = spawn {
                    let inputFile = inputFiles[idx]
                    let initialState = initialStates.get(inputFile).getOrThrow()
                    let relativePath = FileHandler.getRelativePath(inputFile, config.inputPath)
                    let htmlRelativePath = relativePath.replace(".md", ".html").replace(".markdown", ".html")

                    // 借一个 processor，使用完成后必定归还
                    let fileProcessor = borrowProcessor()
                    let result = try {
                        processFilePipelineWithProcessor(
                            inputFile,
                            initialState,
                            headingsMap.get(htmlRelativePath),
                            fileProcessor,
                            htmlRelativePath,
                            parsedCounter,
                            renderedCounter,
                            totalFiles,
                            progressMutex,
                            messagePrefix
                        )
                    } finally {
                        returnProcessor(fileProcessor)
                    }

                    // 线程安全地添加结果（在写盘之后执行）
                    synchronized(resultsMutex) {
                        results.add(result)
                    }
                }
                futures.add(fut)
            }

            // 6. 等待所有任务完成；任意 spawn 抛出的异常会在此处重新抛出。
            for (fut in futures) {
                fut.get()
            }
        }
        
        // 7. 停止进度显示
        KitHooks.stopSpinnerSuccess("Processed ${totalFiles} files")
        
        // 8. 汇总错误
        let failures = ArrayList<ProcessedFileResult>()
        for (result in results) {
            if (!result.success) {
                failures.add(result)
            }
        }
        
        if (failures.size > 0) {
            KitHooks.err("${failures.size} file(s) failed to process:")
            for (failure in failures) {
                if (let Some(errorMsg) <- failure.errorMessage) {
                    KitHooks.err("  - ${failure.inputFile}: ${errorMsg}")
                }
            }
        }
        
        // 9. 返回结果列表
        return results.toArray()
    }
    
    /**
     * 单个文件的完整流水线处理（使用预创建的 processor）
     * 
     * 这个版本接受已经创建并配置好的 processor，避免在并行块内部创建和配置 processor
     * 
     * @param inputFile 输入文件路径
     * @param initialState 初始标题状态
     * @param headings 预扫描的 headings
     * @param fileProcessor 预创建的 processor 实例
     * @param htmlRelativePath HTML 相对路径
     * @param parsedCounter 已解析计数器（线程安全）
     * @param renderedCounter 已渲染计数器（线程安全）
     * @param totalFiles 总文件数
     * @param progressMutex 进度显示互斥锁
     * @param messagePrefix 进度消息前缀
     * @return 处理结果
     */
    private static func processFilePipelineWithProcessor(
        inputFile: String,
        initialState: Array<Int64>,
        headings: ?Array<HeadingInfo>,
        fileProcessor: Processor,
        htmlRelativePath: String,
        parsedCounter: AtomicInt64,
        renderedCounter: AtomicInt64,
        totalFiles: Int64,
        progressMutex: Mutex,
        messagePrefix: String
    ): ProcessedFileResult {
        var stage = "initializing"
        try {
            // 从全局上下文获取配置
            let config = GlobalContext.renderConfig.getOrThrow()
            // 1. 设置 HeadingNumberer 初始状态
            stage = "set heading state"
            setHeadingNumbererState(fileProcessor, initialState)
            
            // 2. 解析阶段：读取文件内容
            stage = "read markdown file"
            let content = FileHandler.readFileContent(inputFile)
            
            // 计算输出路径
            stage = "resolve output path"
            let outputFile = FileHandler.generateDocumentOutputPathWithStructure(
                inputFile, 
                config.inputPath, 
                config.outputPath, 
                fileProcessor
            )
            
            // 从预扫描阶段的 headings 中获取第一个 heading 作为标题，如果没有就用文件名
            let title = if (let Some(headingList) <- headings) {
                if (headingList.size > 0) {
                    headingList[0].text
                } else {
                    FileHandler.extractTitle(inputFile)
                }
            } else {
                FileHandler.extractTitle(inputFile)
            }
            
            // 3. 解析和渲染阶段：使用独立的 fileProcessor 完整处理
            stage = "parse and render markdown"
            let (html, doc) = fileProcessor.process(content, title, currentPagePath: htmlRelativePath, asDocument: false)
            
            // 4. 更新已解析和已渲染计数器
            stage = "update progress"
            let parsed = parsedCounter.fetchAdd(1) + 1
            let renderedNew = renderedCounter.fetchAdd(1) + 1
            
            // 更新进度显示（更新渲染进度）
            synchronized(progressMutex) {
                KitHooks.updatePipelineProgress(
                    renderedNew, 
                    parsed, 
                    totalFiles,
                    prefix: messagePrefix
                )
            }
            
            // 5. 写入阶段：写入输出文件
            stage = "write rendered output"
            FileHandler.ensureOutputDirectory(outputFile)
            FileHandler.writeFileContent(outputFile, html)

            // 6. 计算搜索索引使用的 URL（相对于 outputPath 的父目录，包含语言前缀）
            // 例如：outputFile = "./dist/zh/plugins/i18n.html"
            //       outputPath = "./dist/zh"
            //       outputPath 的父目录 = "./dist"
            //       searchIndexUrl = "zh/plugins/i18n.html"
            let outputPathParent = Path(config.outputPath).parent
            let searchIndexUrl = if (outputPathParent.isEmpty()) {
                htmlRelativePath  // 如果没有父目录，使用原始相对路径
            } else {
                // 计算 outputFile 相对于 outputPath 父目录的路径
                // 这样可以包含语言前缀（如 "zh/"）
                let outputPathParentStr = outputPathParent.toString()
                let normalizedOutputFile = outputFile.replace("\\", "/")
                let normalizedParent = outputPathParentStr.replace("\\", "/")
                
                if (normalizedOutputFile.startsWith(normalizedParent)) {
                    var relative = normalizedOutputFile[normalizedParent.size..]
                    if (relative.startsWith("/")) {
                        relative = relative[1..]
                    }
                    relative
                } else {
                    htmlRelativePath  // 降级到原始路径
                }
            }
            
            // 7. 构建搜索索引（使用包含语言前缀的 URL）
            stage = "build search index"
            let searchSections = SearchIndexBuilder.buildIndex(doc, searchIndexUrl, title)
            
            // 8. 返回成功结果
            return ProcessedFileResult(
                inputFile,
                outputFile,
                searchIndexUrl,
                title,
                searchSections
            )
            
        } catch (e: Exception) {
            let errorMsg = "Failed to process ${inputFile} during ${stage}: ${e.toString()}"
            KitHooks.insertBeforeErr(errorMsg)
            return ProcessedFileResult(inputFile, errorMsg)
        }
    }
    
    /**
     * 单个文件的完整流水线处理
     * 
     * 执行完整的"解析 → 渲染 → 写入"流水线：
     * 1. 为当前文件创建独立的 Processor 实例（避免并发状态冲突）
     * 2. 设置 HeadingNumberer 初始状态
     * 3. 解析并渲染文件
     * 4. 更新 parsedCounter 和 renderedCounter（线程安全）
     * 5. 写入输出文件
     * 6. 更新进度显示（线程安全）
     * 
     * @param inputFile 输入文件路径
     * @param initialState 初始标题状态
     * @param headings 预扫描的 headings
     * @param templateProcessor 模板处理器（用于获取配置）
     * @param parsedCounter 已解析计数器（线程安全）
     * @param renderedCounter 已渲染计数器（线程安全）
     * @param totalFiles 总文件数
     * @param progressMutex 进度显示互斥锁
     * @param messagePrefix 进度消息前缀
     * @return 处理结果
     * 
     * 对应需求：2.2, 2.3, 2.5, 2.6, 2.7, 2.11, 2.12, 2.13, 6.3, 12.4, 12.5, 12.6, 12.9
     */
    private static func processFilePipeline(
        inputFile: String,
        initialState: Array<Int64>,
        headings: ?Array<HeadingInfo>,
        processor: Processor,
        parsedCounter: AtomicInt64,
        renderedCounter: AtomicInt64,
        totalFiles: Int64,
        progressMutex: Mutex,
        messagePrefix: String
    ): ProcessedFileResult {
        var stage = "initializing"
        try {
            // 从全局上下文获取配置
            let config = GlobalContext.renderConfig.getOrThrow()
            
            // 1. 为当前文件创建独立的 Processor 实例（避免并发状态冲突）
            // 注意：每个文件都有自己的 Markit 实例和 HeadingNumberer
            stage = "create file processor"
            let fileProcessor = createFileProcessor(processor)
            
            // 2. 设置 HeadingNumberer 初始状态
            stage = "set heading state"
            setHeadingNumbererState(fileProcessor, initialState)
            
            // 3. 解析阶段：读取文件内容
            stage = "read markdown file"
            let content = FileHandler.readFileContent(inputFile)
            
            // 计算相对路径和输出路径
            stage = "resolve output path"
            let relativePath = FileHandler.getRelativePath(inputFile, config.inputPath)
            let htmlRelativePath = relativePath.replace(".md", ".html").replace(".markdown", ".html")
            let outputFile = FileHandler.generateDocumentOutputPathWithStructure(
                inputFile, 
                config.inputPath, 
                config.outputPath, 
                processor
            )
            
            // 从预扫描阶段的 headings 中获取第一个 heading 作为标题，如果没有就用文件名
            let title = if (let Some(headingList) <- headings) {
                if (headingList.size > 0) {
                    headingList[0].text
                } else {
                    FileHandler.extractTitle(inputFile)
                }
            } else {
                FileHandler.extractTitle(inputFile)
            }
            
            // 4. 解析和渲染阶段：使用独立的 fileProcessor 完整处理
            // process() 返回 (html, document) 元组
            stage = "parse and render markdown"
            let (html, doc) = fileProcessor.process(content, title, currentPagePath: htmlRelativePath, asDocument: false)
            
            // 5. 更新已解析和已渲染计数器
            stage = "update progress"
            let parsed = parsedCounter.fetchAdd(1) + 1
            let renderedNew = renderedCounter.fetchAdd(1) + 1
            
            // 更新进度显示（更新渲染进度）
            synchronized(progressMutex) {
                KitHooks.updatePipelineProgress(
                    renderedNew, 
                    parsed, 
                    totalFiles,
                    prefix: messagePrefix
                )
            }
            
            // 8. 写入阶段：写入输出文件
            stage = "write rendered output"
            FileHandler.ensureOutputDirectory(outputFile)
            FileHandler.writeFileContent(outputFile, html)

            // 9. 计算搜索索引使用的 URL（相对于 outputPath 的父目录，包含语言前缀）
            // 例如：outputFile = "./dist/zh/plugins/i18n.html"
            //       outputPath = "./dist/zh"
            //       outputPath 的父目录 = "./dist"
            //       searchIndexUrl = "zh/plugins/i18n.html"
            let outputPathParent = Path(config.outputPath).parent
            let searchIndexUrl = if (outputPathParent.isEmpty()) {
                htmlRelativePath  // 如果没有父目录，使用原始相对路径
            } else {
                // 计算 outputFile 相对于 outputPath 父目录的路径
                // 这样可以包含语言前缀（如 "zh/"）
                let outputPathParentStr = outputPathParent.toString()
                let normalizedOutputFile = outputFile.replace("\\", "/")
                let normalizedParent = outputPathParentStr.replace("\\", "/")
                
                if (normalizedOutputFile.startsWith(normalizedParent)) {
                    var relative = normalizedOutputFile[normalizedParent.size..]
                    if (relative.startsWith("/")) {
                        relative = relative[1..]
                    }
                    relative
                } else {
                    htmlRelativePath  // 降级到原始路径
                }
            }
            
            // 10. 构建搜索索引（使用已解析的文档，使用包含语言前缀的 URL）
            stage = "build search index"
            let searchSections = SearchIndexBuilder.buildIndex(doc, searchIndexUrl, title)
            
            // 11. 返回成功结果
            return ProcessedFileResult(
                inputFile,
                outputFile,
                searchIndexUrl,  // 使用包含语言前缀的 URL
                title,
                searchSections
            )
            
        } catch (e: Exception) {
            // 捕获并记录错误，返回失败结果
            let errorMsg = "Failed to process ${inputFile} during ${stage}: ${e.toString()}"
            KitHooks.insertBeforeErr(errorMsg)
            return ProcessedFileResult(inputFile, errorMsg)
        }
    }
    
    /**
     * 为单个文件创建独立的 Processor 实例
     * 
     * 每个文件使用独立的 Processor，避免并发时 HeadingNumberer 状态冲突。
     * 
     * @param templateProcessor 模板处理器（用于复制配置）
     * @return 新的 Processor 实例
     */
    private static func createFileProcessor(
        templateProcessor: Processor
    ): Processor {
        // 从全局上下文创建新的 Processor 实例（无需传递任何参数）
        let newProcessor = ProcessorFactory.createProcessor()
        
        // 从全局上下文获取配置
        let siteStructure = GlobalContext.siteStructure.getOrThrow()
        let summaryConfig = GlobalContext.summaryConfig.getOrThrow()
        let summaryOptions = GlobalContext.summaryOptions.getOrThrow()
        
        // 如果是 WebsiteProcessor，设置网站结构和 SummaryConfig
        match (newProcessor) {
            case websiteProcessor: WebsiteProcessor =>
                websiteProcessor.setSiteStructure(siteStructure)
                websiteProcessor.setSummaryConfig(summaryConfig, summaryOptions)
            case _ => ()
        }
        
        return newProcessor
    }
    
    /**
     * 设置当前文件解析前的标题编号状态。
     */
    private static func setHeadingNumbererState(
        processor: Processor,
        initialState: Array<Int64>
    ): Unit {
        processor.setHeadingInitialState(initialState)
    }
    
}
