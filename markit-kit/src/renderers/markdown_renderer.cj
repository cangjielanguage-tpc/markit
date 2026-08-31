package markit_kit.renderers

import markit_kit.utils.KitHooks

import markit_kit.interfaces.Processor
import markit_kit.models.{RenderConfig, RenderResult, SummaryOptions, SummaryConfig, GlobalContext}
import markit_kit.utils.{FileHandler, PathUtils, TypstCliRunner}
import markit_kit.processors.{ProcessorFactory, WebsiteProcessor, ParallelProcessor, MarkdownProcessor}
import markit_kit.scanners.{HeadingStateScanner, ScanResult}
import markit_kit.services.{SiteBuilder, SummaryParser, SearchIndexBuilder, SearchIndexSection}
import markit.core.nodes.DocumentNode
import markit.plugins.standard.inline.link.{FileTree, LinkConfig, RenderMode}
import std.collection.{ArrayList, HashMap}
import std.fs.Path
import std.time.MonoTime
import std.core.StringBuilder
import std.sync.{Mutex, AtomicInt64, Semaphore}
import markit_kit.utils.TypstDocumentBuilder
import markit.utils.HeadingSlugScope

/**
 * 解析后的文件信息（用于两阶段渲染）
 */
class ParsedFileInfo {
    public let inputFile: String
    public let outputFile: String
    public let content: String
    public let title: String
    public let relativePath: String
    public let doc: DocumentNode
    public let searchSections: Array<SearchIndexSection>

    public init(inputFile: String, outputFile: String, content: String, title: String, relativePath: String,
        doc: DocumentNode, searchSections: Array<SearchIndexSection>) {
        this.inputFile = inputFile
        this.outputFile = outputFile
        this.content = content
        this.title = title
        this.relativePath = relativePath
        this.doc = doc
        this.searchSections = searchSections
    }
}

public class MergedTypstHeadingLabel {
    public let slug: String
    public let mergedLabel: String

    public init(slug: String, mergedLabel: String) {
        this.slug = slug
        this.mergedLabel = mergedLabel
    }
}

public class MergedTypstRewritePlan {
    public let firstLabelByPathAndSlug: HashMap<String, String>
    public let primaryLabelByPath: HashMap<String, String>

    public init(
        firstLabelByPathAndSlug: HashMap<String, String>,
        primaryLabelByPath: HashMap<String, String>
    ) {
        this.firstLabelByPathAndSlug = firstLabelByPathAndSlug
        this.primaryLabelByPath = primaryLabelByPath
    }
}

/**
 * Markdown渲染器
 * 负责渲染流程的编排和协调
 */
public class MarkdownRenderer {
    /**
     * 渲染markdown文件
     *
     * @param config 渲染配置
     * @param summaryOptions Summary 选项
     * @param changedFile 可选的变化文件路径，如果提供则只处理这个文件
     * @param parallelJobs 并行任务数（1=串行，>1=并行，0=自动检测）
     * @return 渲染结果
     */
    public static func render(
        config: RenderConfig,
        summaryOptions: SummaryOptions,
        changedFile!: ?String = None,
        skipCleanup!: Bool = false,
        parallelJobs!: Int64 = 1
    ): RenderResult {
        let lowerOutputFormat = config.outputFormat.toAsciiLower()

        if (lowerOutputFormat == "pdf" && !TypstCliRunner.ensureAvailable()) {
            return RenderResult(
                success: false,
                processedFiles: [],
                errorMessage: Some("PDF output requires the Typst CLI")
            )
        }

        // 如果不是增量编译（changedFile为None）且不跳过清理，清理输出目录
        if (changedFile.isNone() && !skipCleanup) {
            FileHandler.cleanOutputDirectory(config.outputPath)
        }

        // 设置全局上下文的 RenderConfig
        GlobalContext.renderConfig = config

        let processorFormat = if (lowerOutputFormat == "pdf") {
            "typst"
        } else {
            config.outputFormat
        }
        // 先创建处理器（从 GlobalContext 读取配置）
        let processor = ProcessorFactory.createProcessor(format: processorFormat)

        // 收集输入文件（使用 processor 的 markit 实例解析 summary）
        let (inputFiles, summaryConfig) = SummaryParser.parseAndCollectFiles(
            config.inputPath,
            summaryOptions
        )

        // 构建 FileTree（从 inputFiles 提取相对路径）
        let relativeFiles = ArrayList<String>()
        for (inputFile in inputFiles) {
            let relativePath = FileHandler.getRelativePath(inputFile, config.inputPath)
            relativeFiles.add(relativePath)
        }
        let fileTree = FileTree(relativeFiles.toArray())

        // 根据 outputFormat 确定 RenderMode（pdf/markdown/typst 单文件用 Flat）
        let lowerFormat = lowerOutputFormat
        let renderMode = if (lowerFormat == "pdf" || lowerFormat == "markdown" || lowerFormat == "typst") {
            RenderMode.Flat
        } else {
            RenderMode.Normal
        }

        // 创建 LinkConfig 并更新 processor 配置
        let linkConfig = LinkConfig(
            fileTree: Some(fileTree),
            renderMode: renderMode,
            outputExtension: getOutputExtensionForFormat(lowerFormat),
            preserveFlatFilePaths: lowerFormat == "pdf" || lowerFormat == "typst"
        )
        updateProcessorLinkConfig(processor, linkConfig)

        // 设置全局上下文的 LinkConfig
        GlobalContext.linkConfig = linkConfig

        // 设置全局上下文的 SummaryConfig 和 SummaryOptions
        GlobalContext.summaryConfig = summaryConfig
        GlobalContext.summaryOptions = summaryOptions

        if (inputFiles.size == 0) {
            let message = "No markdown files found in '${config.inputPath}'"
            KitHooks.warn(message)
            return RenderResult(success: true, processedFiles: [], errorMessage: Some(message))
        }

        // PDF 模式：先导出 Typst，再编译为 PDF
        if (lowerOutputFormat == "pdf") {
            return renderPdf(inputFiles, processor, parallelJobs)
        }

        // Markdown/Typst 模式：并行解析 -> 并行导出 -> 串行合并为单文件
        if (lowerOutputFormat == "markdown" || lowerOutputFormat == "typst") {
            return renderMergedText(inputFiles, processor, parallelJobs)
        }

        // 网站模式：正常渲染流程
        return renderWebsite(inputFiles, processor, changedFile, parallelJobs)
    }

    /**
     * 渲染 PDF 模式
     */
    private static func renderPdf(
        inputFiles: Array<String>,
        processor: Processor,
        parallelJobs: Int64
    ): RenderResult {
        let config = GlobalContext.renderConfig.getOrThrow()
        let typstResult = renderMergedText(inputFiles, processor, parallelJobs)
        if (!typstResult.success) {
            return typstResult
        }

        let mergedTypRelativePath = "merged.typ"
        let mergedPdfRelativePath = "merged.pdf"
        let typPath = Path(config.outputPath).join(mergedTypRelativePath).normalize().toString()
        let pdfPath = Path(config.outputPath).join(mergedPdfRelativePath).normalize().toString()
        let success = compileTypstToPdf(typPath, pdfPath)
        if (!success) {
            return RenderResult(success: false, processedFiles: [],
                errorMessage: Some("Failed to compile Typst PDF: ${mergedTypRelativePath}"))
        }
        KitHooks.success("Compiled merged PDF from Typst")
        return RenderResult(success: true, processedFiles: [(mergedPdfRelativePath, config.siteTitle)])
    }

    /**
     * 渲染 Markdown 合并模式：并行解析 -> 并行 toMarkdown -> 串行合并为单文件
     */
    private static func renderMergedText(
        inputFiles: Array<String>,
        processor: Processor,
        parallelJobs: Int64
    ): RenderResult {
        let config = GlobalContext.renderConfig.getOrThrow()
        let summaryConfig = GlobalContext.summaryConfig.getOrThrow()
        let summaryOptions = GlobalContext.summaryOptions.getOrThrow()
        let extension = processor.getExtension()
        let formatName = processor.getType()
        let totalFiles = Int64(inputFiles.size)
        let actualJobs = if (parallelJobs <= 0) {
            4
        } else {
            if (parallelJobs > totalFiles) {
                totalFiles
            } else {
                parallelJobs
            }
        }
        let useParallel = actualJobs > 1 && totalFiles > 1

        let scanResult = HeadingStateScanner.scanAndComputeStates(inputFiles, config, processor)
        let progressBar = KitHooks.progressBar(0, width: 20)
        KitHooks.spinner("Merged ${formatName}: parse + export... ${progressBar}")

        let results = ArrayList<(Int64, String, String, String)>()
        let resultsMutex = Mutex()
        let failures = ArrayList<String>()
        let failuresMutex = Mutex()
        let taskIndex = AtomicInt64(0)
        let completedCounter = AtomicInt64(0)
        let semaphore = Semaphore(actualJobs)

        let processOne = {
            idx: Int64 =>
                let inputFile = inputFiles[idx]
                try {
                    let initialState = scanResult.initialStates.get(inputFile).getOrThrow()
                    let fileProcessor = ProcessorFactory.createProcessor(format: processor.getType())
                    fileProcessor.setHeadingInitialState(initialState)
                    let content = FileHandler.readFileContent(inputFile)
                    let relativePath = FileHandler.getRelativePath(inputFile, config.inputPath)
                    let htmlRelativePath = relativePath.replace(".md", ".html").replace(".markdown", ".html")
                    let outputRelativePath = relativePath
                        .replace(".markdown", ".${extension}")
                        .replace(".md", ".${extension}")
                    let title = if (let Some(headingList) <- scanResult.headingsMap.get(htmlRelativePath)) {
                        if (headingList.size > 0) {
                            headingList[0].text
                        } else {
                            FileHandler.extractTitle(inputFile)
                        }
                    } else {
                        FileHandler.extractTitle(inputFile)
                    }
                    let (exported, _) = fileProcessor.process(content, title, currentPagePath: outputRelativePath,
                        asDocument: true)
                    synchronized(resultsMutex) {
                        results.add((idx, exported, title, outputRelativePath))
                    }
                } catch (e: Exception) {
                    let message = "Failed ${inputFile}: ${e.toString()}"
                    synchronized(failuresMutex) {
                        failures.add(message)
                    }
                    KitHooks.insertBeforeErr(message)
                }
                let done = completedCounter.fetchAdd(1) + 1
                let percent = if (totalFiles == 0) {
                    100
                } else {
                    Int64((done * 100) / totalFiles)
                }
                let bar = KitHooks.progressBar(percent, width: 20)
                KitHooks.updateSpinner("Merged ${formatName}: parse + export... ${bar} (${done}/${totalFiles})")
        }

        if (useParallel) {
            for (_ in 0..inputFiles.size) {
                spawn {
                    semaphore.acquire()
                    let idx = taskIndex.fetchAdd(1)
                    if (idx < totalFiles) {
                        processOne(idx)
                    }
                    semaphore.release()
                }
            }
            while (completedCounter.load() < totalFiles) {
                let startWait = MonoTime.now()
                let waitNanos: Int64 = 10000000
                while (true) {
                    let elapsed = MonoTime.now() - startWait
                    if (elapsed.toNanoseconds() >= waitNanos) {
                        break
                    }
                }
            }
        } else {
            for (i in 0..inputFiles.size) {
                processOne(Int64(i))
            }
        }

        KitHooks.stopSpinner()
        if (failures.size > 0) {
            return RenderResult(
                success: false,
                processedFiles: [],
                errorMessage: Some(String.join(failures.toArray(), delimiter: "\n"))
            )
        }
        var merged = StringBuilder()
        var processedFiles = ArrayList<(String, String)>()
        let isTypst = formatName == "typst"
        let rewritePlan: ?MergedTypstRewritePlan = if (isTypst) {
            Some(buildMergedTypstRewritePlan(scanResult))
        } else {
            None
        }
        for (i in 0..inputFiles.size) {
            var found = false
            for (pair in results) {
                if (pair[0] == Int64(i)) {
                    let exportedContent = if (isTypst) {
                        let currentRelativePath = pair[3]
                        let normalizedContent = rebaseMergedTypstAssetPaths(
                            normalizeMergedTypstAssetPaths(pair[1]),
                            currentRelativePath,
                            "merged.${extension}"
                        )
                        let scopedHeadings = rewriteMergedTypstHeadingLabels(
                            normalizedContent,
                            currentRelativePath,
                            rewritePlan.getOrThrow()
                        )
                        rewriteMergedTypstLinks(
                            scopedHeadings,
                            currentRelativePath,
                            rewritePlan.getOrThrow()
                        )
                    } else {
                        pair[1]
                    }
                    if (i > 0) {
                        if (isTypst) {
                            merged.append("\n#pagebreak()\n\n")
                        } else {
                            merged.append("\n\n")
                        }
                    }
                    if (isTypst) {
                        let relativePath = FileHandler.getRelativePath(inputFiles[i], config.inputPath)
                        merged.append(TypstDocumentBuilder.renderSourceComment(relativePath))
                    }
                    merged.append(exportedContent)
                    let singleOutPath = Path(config.outputPath).join(pair[3]).normalize().toString()
                    FileHandler.ensureOutputDirectory(singleOutPath)
                    let wrappedContent = processor.wrapHtmlContent(pair[1], pair[2], pair[3])
                    FileHandler.writeFileContent(singleOutPath, wrappedContent)
                    processedFiles.add((pair[3], config.siteTitle))
                    found = true
                    break
                }
            }
            if (!found) {
                KitHooks.warn("Missing output for file index ${i}")
            }
        }
        let outPath = Path(config.outputPath).join("merged.${extension}").normalize().toString()
        FileHandler.ensureOutputDirectory(outPath)
        let mergedContent = if (isTypst) {
            let sharedAssetOutputPath = if (config.outputFormat.toAsciiLower() == "pdf") {
                Path(config.outputPath).parent.normalize().toString()
            } else {
                config.outputPath
            }
            FileHandler.copyStaticFiles(config.inputPath, sharedAssetOutputPath)
            FileHandler.copyTypstSupportAssets(sharedAssetOutputPath)
            let coverTemplateFrontMatter = TypstDocumentBuilder.renderCoverFrontMatter(config.siteTitle,
                currentPagePath: "merged.typ")
            let coverFrontMatter = renderTypstHomepageFrontMatter(summaryConfig, summaryOptions,
                rewritePlan.getOrThrow())
            let tocFrontMatter = TypstDocumentBuilder.renderTocFrontMatter()
            processor.wrapHtmlContent(coverTemplateFrontMatter + coverFrontMatter + tocFrontMatter + merged.toString(),
                config.siteTitle, "merged.${extension}")
        } else {
            merged.toString()
        }
        FileHandler.writeFileContent(outPath, mergedContent)
        processedFiles.add(("merged.${extension}", config.siteTitle))
        KitHooks.success("Merged ${totalFiles} file(s) -> ${outPath}, and ${totalFiles} separate .${extension} file(s)")
        return RenderResult(success: true, processedFiles: processedFiles.toArray())
    }

    private static func normalizeMergedTypstAssetPaths(content: String): String {
        var normalized = content
        while (normalized.contains("\"../assets/")) {
            normalized = normalized.replace("\"../assets/", "\"assets/")
        }
        return normalized
    }

    private static func rebaseMergedTypstAssetPaths(
        content: String,
        currentRelativePath: String,
        mergedRelativePath: String
    ): String {
        let marker = "\""
        var result = StringBuilder()
        var searchStart = 0

        while (searchStart < content.size) {
            if (let Some(startQuote) <- content.indexOf(marker, searchStart)) {
                result.append(content[searchStart..startQuote + 1])
                if (let Some(endOffset) <- content[startQuote + 1..].indexOf(marker)) {
                    let endQuote = startQuote + 1 + endOffset
                    let originalPath = content[startQuote + 1..endQuote]
                    if (shouldRebaseMergedTypstAssetPath(originalPath)) {
                        let rebased = rebaseTypstAssetPath(originalPath, currentRelativePath, mergedRelativePath)
                        result.append(rebased)
                    } else {
                        result.append(originalPath)
                    }
                    searchStart = endQuote
                } else {
                    result.append(content[startQuote + 1..])
                    break
                }
            } else {
                result.append(content[searchStart..])
                break
            }
        }

        return result.toString()
    }

    private static func shouldRebaseMergedTypstAssetPath(path: String): Bool {
        return PathUtils.isRelativeLocalPath(path) && path.contains("assets/")
    }

    private static func rebaseTypstAssetPath(path: String, currentRelativePath: String, mergedRelativePath: String): String {
        return PathUtils.rebaseRelativeDocumentPath(path, currentRelativePath, mergedRelativePath)
    }

    public static func buildMergedTypstRewritePlan(scanResult: ScanResult): MergedTypstRewritePlan {
        let firstLabelByPathAndSlug = HashMap<String, String>()
        let primaryLabelByPath = HashMap<String, String>()

        for ((path, headings) in scanResult.headingsMap) {
            let normalizedHtmlPath = path.replace("\\", "/")
            let normalizedTypPath = normalizedHtmlPath.replace(".html", ".typ")
            let normalizedPdfPath = normalizedHtmlPath.replace(".html", ".pdf")

            for (heading in headings) {
                if (heading.slug.isEmpty()) {
                    continue
                }
                let mergedLabel = HeadingSlugScope.buildPathLabel(normalizedTypPath, heading.slug)

                let typKey = mergedTypstPathSlugKey(normalizedTypPath, heading.slug)
                if (!firstLabelByPathAndSlug.contains(typKey)) {
                    firstLabelByPathAndSlug[typKey] = mergedLabel
                }
                let pdfKey = mergedTypstPathSlugKey(normalizedPdfPath, heading.slug)
                if (!firstLabelByPathAndSlug.contains(pdfKey)) {
                    firstLabelByPathAndSlug[pdfKey] = mergedLabel
                }
                let htmlKey = mergedTypstPathSlugKey(normalizedHtmlPath, heading.slug)
                if (!firstLabelByPathAndSlug.contains(htmlKey)) {
                    firstLabelByPathAndSlug[htmlKey] = mergedLabel
                }
                if (!primaryLabelByPath.contains(normalizedTypPath)) {
                    primaryLabelByPath[normalizedTypPath] = mergedLabel
                }
                if (!primaryLabelByPath.contains(normalizedPdfPath)) {
                    primaryLabelByPath[normalizedPdfPath] = mergedLabel
                }
                if (!primaryLabelByPath.contains(normalizedHtmlPath)) {
                    primaryLabelByPath[normalizedHtmlPath] = mergedLabel
                }
            }
        }

        return MergedTypstRewritePlan(firstLabelByPathAndSlug, primaryLabelByPath)
    }

    public static func rewriteMergedTypstLinks(
        content: String,
        currentRelativePath: String,
        rewritePlan: MergedTypstRewritePlan
    ): String {
        let stringLinkPrefix = "#link(\""
        let labelLinkPrefix = "#link(<"
        var result = StringBuilder()
        var searchStart = 0

        while (searchStart < content.size) {
            let stringStart = content.indexOf(stringLinkPrefix, searchStart) ?? content.size
            let labelStart = content.indexOf(labelLinkPrefix, searchStart) ?? content.size
            let nextStart = if (stringStart < labelStart) {
                stringStart
            } else {
                labelStart
            }

            if (nextStart >= content.size) {
                result.append(content[searchStart..])
                break
            }

            result.append(content[searchStart..nextStart])
            if (nextStart == stringStart) {
                let urlStart = nextStart + stringLinkPrefix.size
                let urlEndOpt = content.indexOf("\")", urlStart)
                if (let Some(urlEnd) <- urlEndOpt) {
                    let originalUrl = content[urlStart..urlEnd]
                    if (let Some(anchorLabel) <- resolveMergedTypstLinkAnchor(originalUrl, currentRelativePath,
                        rewritePlan)) {
                        result.append("#link(<${anchorLabel}>)")
                    } else {
                        result.append(content[nextStart..urlEnd + 2])
                    }
                    searchStart = urlEnd + 2
                } else {
                    result.append(content[nextStart..])
                    return result.toString()
                }
            } else {
                let anchorStart = nextStart + labelLinkPrefix.size
                let anchorEndOpt = content.indexOf(">)", anchorStart)
                if (let Some(anchorEnd) <- anchorEndOpt) {
                    let originalAnchor = content[anchorStart..anchorEnd]
                    if (let Some(anchorLabel) <- resolveCurrentFileMergedTypstAnchor(originalAnchor, currentRelativePath,
                        rewritePlan)) {
                        result.append("#link(<${anchorLabel}>)")
                    } else {
                        result.append(content[nextStart..anchorEnd + 2])
                    }
                    searchStart = anchorEnd + 2
                } else {
                    result.append(content[nextStart..])
                    return result.toString()
                }
            }
        }

        return result.toString()
    }

    public static func rewriteMergedTypstHeadingLabels(
        content: String,
        currentRelativePath: String,
        rewritePlan: MergedTypstRewritePlan
    ): String {
        let lines = content.split("\n")
        let rewritten = ArrayList<String>()

        for (line in lines) {
            rewritten.add(rewriteMergedTypstHeadingLabelLine(line, currentRelativePath, rewritePlan))
        }

        return String.join(rewritten.toArray(), delimiter: "\n")
    }

    private static func rewriteMergedTypstHeadingLabelLine(
        line: String,
        currentRelativePath: String,
        rewritePlan: MergedTypstRewritePlan
    ): String {
        let trimmed = line.trimAsciiStart()
        if (!trimmed.startsWith("=") || !line.endsWith(">")) {
            return line
        }

        if (let Some(labelStart) <- findLastPatternIndex(line, " <")) {
            let originalLabel = line[labelStart + 2..line.size - 1]
            if (let Some(mergedLabel) <- resolveCurrentFileMergedTypstAnchor(originalLabel, currentRelativePath,
                rewritePlan)) {
                return line[0..labelStart] + " <${mergedLabel}>"
            }
        }

        return line
    }

    private static func findLastPatternIndex(content: String, pattern: String): ?Int {
        var searchStart = 0
        var lastMatch: ?Int = None

        while (let Some(matchIndex) <- content.indexOf(pattern, searchStart)) {
            lastMatch = Some(matchIndex)
            searchStart = matchIndex + 1
        }

        return lastMatch
    }

    private static func mergedTypstPathSlugKey(path: String, headingSlug: String): String {
        return "${path.replace("\\", "/")}#${headingSlug}"
    }

    private static func resolveCurrentFileMergedTypstAnchor(
        originalAnchor: String,
        currentRelativePath: String,
        rewritePlan: MergedTypstRewritePlan
    ): ?String {
        let normalizedPath = currentRelativePath.replace("\\", "/")
        let key = mergedTypstPathSlugKey(normalizedPath, originalAnchor)
        return rewritePlan.firstLabelByPathAndSlug.get(key)
    }

    private static func resolveMergedTypstLinkAnchor(
        originalUrl: String,
        currentRelativePath: String,
        rewritePlan: MergedTypstRewritePlan
    ): ?String {
        if (originalUrl.startsWith("http://") || originalUrl.startsWith("https://") || originalUrl.startsWith("file://")) {
            return None
        }
        if (originalUrl.startsWith("#")) {
            return resolveCurrentFileMergedTypstAnchor(originalUrl[1..], currentRelativePath, rewritePlan)
        }
        let isTypLink = originalUrl.endsWith(".typ") || originalUrl.contains(".typ#")
        let isPdfLink = originalUrl.endsWith(".pdf") || originalUrl.contains(".pdf#")
        let isHtmlLink = originalUrl.endsWith(".html") || originalUrl.contains(".html#")
        if (!isTypLink && !isPdfLink && !isHtmlLink) {
            return None
        }

        var targetPath = originalUrl
        var targetAnchor = ""
        if (let Some(hashIndex) <- originalUrl.indexOf("#")) {
            targetPath = originalUrl[0..hashIndex]
            targetAnchor = originalUrl[hashIndex + 1..]
        }

        let resolvedTargetPath = resolveMergedTypstTargetPath(currentRelativePath, targetPath)
        if (!targetAnchor.isEmpty()) {
            let targetKey = mergedTypstPathSlugKey(resolvedTargetPath, targetAnchor)
            return rewritePlan.firstLabelByPathAndSlug.get(targetKey)
        }
        return rewritePlan.primaryLabelByPath.get(resolvedTargetPath)
    }

    private static func resolveMergedTypstTargetPath(currentRelativePath: String, targetPath: String): String {
        let normalizedCurrent = currentRelativePath.replace("\\", "/")
        let normalizedTarget = targetPath.replace("\\", "/")
        let currentDir = Path(normalizedCurrent).parent
        let resolved = if (currentDir.isEmpty()) {
            Path(normalizedTarget).normalize()
        } else {
            currentDir.join(normalizedTarget).normalize()
        }
        return resolved.toString().replace("\\", "/")
    }

    private static func renderTypstHomepageFrontMatter(
        summaryConfig: SummaryConfig,
        summaryOptions: SummaryOptions,
        rewritePlan: MergedTypstRewritePlan
    ): String {
        if (summaryConfig.homepageTypstContent.trimAscii().isEmpty()) {
            return ""
        }

        let homepageRelativePath = summaryOptions
            .file
            .replace(".markdown", ".typ")
            .replace(".md", ".typ")
            .replace("\\", "/")
        let rewritten = rewriteMergedTypstLinks(
            normalizeMergedTypstAssetPaths(summaryConfig.homepageTypstContent),
            homepageRelativePath,
            rewritePlan
        )
        let normalized = if (rewritten.endsWith("\n")) {
            rewritten
        } else {
            rewritten + "\n"
        }
        return TypstDocumentBuilder.renderSourceComment(summaryOptions.file) + normalized + "\n#pagebreak()\n\n"
    }

    private static func setHeadingState(processor: Processor, initialState: Array<Int64>): Unit {
        processor.setHeadingInitialState(initialState)
    }

    /**
     * 渲染网站模式（三阶段流水线架构）
     *
     * 阶段 1：预扫描 - 提取 heading 信息、计算初始状态、构建 FileTree
     * 阶段 2：并行处理 - 每个文件独立执行"解析 → 渲染 → 写入"流水线
     * 阶段 3：后处理 - 生成搜索索引、网站首页、代码块预渲染
     *
     * 对应需求：11.1, 11.5
     */
    private static func renderWebsite(
        inputFiles: Array<String>,
        processor: Processor,
        changedFile: ?String,
        parallelJobs: Int64
    ): RenderResult {
        // 从全局上下文获取配置
        let config = GlobalContext.renderConfig.getOrThrow()
        let summaryConfig = GlobalContext.summaryConfig.getOrThrow()
        let summaryOptions = GlobalContext.summaryOptions.getOrThrow()
        // 解析完 summary 后，根据 resetFor 策略决定是否重置 heading numberer
        // 注意：增量编译时不应该重置，因为编号应该保持连续
        if (changedFile.isNone() && (config.headingResetFor == "never" || config.headingResetFor == "directory")) {
            match (processor) {
                case websiteProcessor: WebsiteProcessor => websiteProcessor.resetGlobalNumbering()
                case _ => ()
            }
        }

        let isSingleFile = inputFiles.size == 1

        // 构建网站结构
        let siteStructure = SiteBuilder.buildStructure(inputFiles, config.inputPath)

        // 设置全局上下文
        GlobalContext.renderConfig = config
        GlobalContext.siteStructure = siteStructure
        GlobalContext.summaryConfig = summaryConfig
        GlobalContext.summaryOptions = summaryOptions
        GlobalContext.parallelJobs = parallelJobs

        // 如果是WebsiteProcessor，设置网站结构和 SummaryConfig
        match (processor) {
            case websiteProcessor: WebsiteProcessor =>
                websiteProcessor.setSiteStructure(siteStructure)
                websiteProcessor.setSummaryConfig(summaryConfig, summaryOptions)
            case _ => ()
        }

        // ========== 阶段 1：预扫描 ==========
        // 判断是否需要预扫描（所有模式都需要预扫描以构建 FileTree）
        let scanResult = HeadingStateScanner.scanAndComputeStates(
            inputFiles,
            config,
            processor
        )

        // ========== 阶段 2：并行处理 ==========
        let results = ParallelProcessor.processFiles(
            inputFiles,
            scanResult.initialStates,
            scanResult.headingsMap,
            processor,
            parallelJobs
        )

        // 转换结果格式（从 ProcessedFileResult 到 (String, String) 元组）
        let processedFiles = ArrayList<(String, String)>()
        let allSearchSections = ArrayList<SearchIndexSection>()

        for (result in results) {
            if (result.success) {
                processedFiles.add((result.relativePath, result.title))
                for (section in result.searchSections) {
                    allSearchSections.add(section)
                }
            }
        }

        // ========== 阶段 3：后处理 ==========

        // 生成网站首页
        let shouldGenerateIndex = !isSingleFile || !summaryConfig.homepageContent.isEmpty()

        if (shouldGenerateIndex) {
            SiteBuilder.generateIndex(
                config.outputPath,
                siteStructure,
                processor,
                config.siteTitle,
                summaryConfig,
                config.inputPath
            )
        }

        // 生成搜索索引文件
        if (allSearchSections.size > 0) {
            generateSearchIndex(config.outputPath, allSearchSections.toArray())
        }

        return RenderResult(success: true, processedFiles: processedFiles.toArray())
    }

    /**
     * 生成搜索索引文件
     */
    private static func generateSearchIndex(outputPath: String, sections: Array<SearchIndexSection>) {
        let searchIndexJs = SearchIndexBuilder.generateSearchIndexJs(sections)
        let searchIndexPath = Path(outputPath).join("js").join("search-index.js").normalize().toString()

        // 确保js目录存在
        FileHandler.ensureOutputDirectory(searchIndexPath)
        FileHandler.writeFileContent(searchIndexPath, searchIndexJs)
    }

    /**
     * 更新 Processor 的链接配置
     *
     * @param processor 处理器实例
     * @param linkConfig 新的 LinkConfig
     */
    private static func updateProcessorLinkConfig(processor: Processor, linkConfig: LinkConfig): Unit {
        processor.setLinkConfig(linkConfig)
    }

    private static func getOutputExtensionForFormat(format: String): String {
        return if (format == "markdown") {
            "md"
        } else if (format == "typst") {
            "typ"
        } else if (format == "pdf") {
            "pdf"
        } else {
            "html"
        }
    }

    private static func compileTypstToPdf(typPath: String, pdfPath: String): Bool {
        FileHandler.ensureOutputDirectory(pdfPath)
        return TypstCliRunner.compileToPdf(typPath, pdfPath)
    }
}
