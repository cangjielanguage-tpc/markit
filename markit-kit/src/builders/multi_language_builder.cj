package markit_kit.builders

import markit_kit.utils.KitHooks

import markit_kit.config.{MarkitConfig, MultiConfigLoader}
import markit_kit.processors.{ProcessorFactory}
import markit_kit.interfaces.Processor
import markit_kit.utils.{FileHandler, ResourceResolver}
import markit_kit.models.GlobalContext
import markit_kit.renderers.MarkdownRenderer
import markit_kit.models.{RenderConfig, SummaryOptions}
import markit_kit.generators.LandingPageGenerator
import std.collection.ArrayList
import std.fs.{Path, exists, Directory, File}

/**
 * 多语言构建器
 * 
 * 负责协调多语言文档构建流程：
 * - 为每个语言创建独立的构建上下文
 * - 处理 route_prefix 路径映射
 * - 生成 Landing Page
 * - 管理资源文件拷贝（主题资源和用户资源）
 * 
 * Validates: Requirements 4.1, 4.2, 4.3, 10.1, 10.2, 9.1, 9.2, 9.3, 9.4, 13.1, 13.5,
 *            16.1, 16.2, 16.3, 16.4
 */
public class MultiLanguageBuilder {
    private let configs: Array<MarkitConfig>
    private let inputPath: String
    private let outputPath: String
    private let devMode: Bool
    private let parallelJobs: Int64
    
    /**
     * 构造函数
     * 
     * @param configs 配置对象数组（每个语言一个配置）
     * @param inputPath 输入路径（配置文件所在目录）
     * @param outputPath 输出路径
     * @param devMode 是否为开发模式（启用自动刷新）
     * @param parallelJobs 并行任务数（1=串行，>1=并行，0=自动检测）
     * 
     * Validates: Requirements 4.1, 4.2, 13.1
     */
    public init(configs: Array<MarkitConfig>, inputPath: String, outputPath: String, devMode!: Bool = false, parallelJobs!: Int64 = 1) {
        this.configs = configs
        this.inputPath = inputPath
        this.outputPath = outputPath
        this.devMode = devMode
        this.parallelJobs = parallelJobs
    }
    
    /**
     * 执行多语言构建
     * 
     * Validates: Requirements 4.1, 4.3, 10.1, 10.2, 9.1, 9.2, 9.3, 9.4, 13.5
     */
    public func build(): Unit {
        buildInternal(None)
    }
    
    /**
     * 执行增量构建（仅重新构建变化的文件）
     * 
     * @param changedFile 变化的文件路径（相对于输入目录）
     */
    public func incrementalBuild(changedFile: String): Unit {
        buildInternal(Some(changedFile))
    }
    
    /**
     * 内部构建方法（支持完整构建和增量构建）
     * 
     * @param incrementalFile 增量构建的文件路径（None 表示完整构建）
     */
    private func buildInternal(incrementalFile: ?String): Unit {
        let isIncremental = match (incrementalFile) {
            case Some(_) => true
            case None => false
        }
        
        // 获取目标语言列表
        let languages = MultiConfigLoader.getTargetLanguages(configs)
        
        if (!isIncremental) {
            // 完整构建：记录要构建的语言列表（Req 9.1）
            let languageList = String.join(languages, delimiter: ", ")
            KitHooks.info("Building languages: ${languageList}")
            KitHooks.newLine()
            
            // 1. 清理输出目录（会打印成功消息）
            cleanOutputDirectory()
            KitHooks.newLine()
        }
        
        // 检查输出格式
        let outputFormat = if (configs.size > 0) {
            configs[0].outputType.toAsciiLower()
        } else {
            "website"
        }
        
        // 2. 为每个语言构建文档（Req 9.2）
        for (i in 0..configs.size) {
            let config = configs[i]
            let language = MultiConfigLoader.getTargetLanguage(config)
            
            if (!isIncremental) {
                KitHooks.info("Building language ${i + 1}/${configs.size}: ${language}")
            }
            
            if (!isIncremental && outputFormat == "pdf") {
                let langOutputPath = Path(outputPath).join(language).normalize().toString()
                
                // 确保语言输出目录存在
                if (!exists(Path(langOutputPath))) {
                    Directory.create(langOutputPath, recursive: true)
                }
            }
            buildLanguageVersion(config, language, incrementalFile)
            
            if (!isIncremental) {
                KitHooks.success("Language ${language} built successfully")
                KitHooks.newLine()
            }
        }
        
        if (!isIncremental) {
            if (outputFormat == "markdown") {
                KitHooks.newLine()
                KitHooks.success("Merged Markdown build completed successfully!")
            } else if (outputFormat == "typst") {
                KitHooks.newLine()
                KitHooks.success("Typst build completed successfully!")
            } else if (outputFormat == "pdf") {
                KitHooks.newLine()
                KitHooks.success("PDF build completed successfully!")
            } else {
                // 网站模式：执行完整的后处理
                // 打印网站生成成功消息
                KitHooks.success("Website generated successfully!")
                KitHooks.newLine()
                
                // 3. 生成 Landing Page（传递默认语言）
                KitHooks.info("Generating landing page...")
                generateLandingPage(languages)
                
                // 4. 将共享主题资源复制到根 assets 目录（Req 10.1）
                KitHooks.info("Copying shared theme assets...")
                copySharedThemeAssets()
                
                // 5. 将 public/ 文件夹复制到根目录（如果存在）（Req 10.2）
                KitHooks.info("Copying public assets...")
                copyPublicAssets()
                
                // 记录完成统计信息（Req 9.3）
                KitHooks.newLine()
                KitHooks.success("Website build completed successfully!")
            }
            
            KitHooks.success("Output directory: ${outputPath}")
        } else {
            // 增量构建完成
            KitHooks.success("Incremental build completed")
        }
    }
    
    /**
     * 构建单个语言版本
     * 
     * @param config 语言配置
     * @param language 语言代码
     * @param incrementalFile 增量构建的文件路径（None 表示完整构建）
     * 
     * Validates: Requirements 4.2, 5.6, 5.7, 12.5, 9.4, 16.1, 16.2, 16.3, 16.4
     */
    private func buildLanguageVersion(config: MarkitConfig, language: String, incrementalFile: ?String): Unit {
        try {
            // 获取 route_prefix（如果有）
            let routePrefix = MultiConfigLoader.getRoutePrefix(config)
            
            // 确定输入路径（Req 16.1, 16.2）
            let langInputPath = match (routePrefix) {
                case Some(prefix) =>
                    // 如果有 route_prefix，从前缀路径读取
                    Path(inputPath).join(prefix).normalize().toString()
                case None =>
                    // 如果没有 route_prefix，从根目录读取
                    inputPath
            }
            
            // 创建语言特定的输出路径：${outputPath}/${language}（Req 16.3, 16.4）
            let langOutputPath = Path(outputPath).join(language).normalize().toString()
            
            // 确保输出目录存在（不需要清理，因为最开始已经清理了整个dist）
            if (!exists(Path(langOutputPath))) {
                Directory.create(langOutputPath, recursive: true)
            }
            
            // 使用 ProcessorFactory 创建 WebsiteProcessor 实例
            let processor = createProcessor(config, routePrefix)
            
            // 执行构建（会生成该语言的 index.html）
            buildWebsite(config, processor, langInputPath, langOutputPath, incrementalFile)
        } catch (e: Exception) {
            // 处理错误并记录哪个语言失败（Req 9.4）
            KitHooks.err("Failed to build language ${language}: ${e.message}")
            throw e
        }
    }
    
    /**
     * 创建处理器实例
     * 
     * @param config 配置对象
     * @param routePrefix 路由前缀（可选）
     * @return 处理器实例
     */
    private func createProcessor(config: MarkitConfig, routePrefix: ?String): Processor {
        // 创建 i18n 配置
        let i18nConfig = config.createI18nConfig()
        
        // 创建标题编号配置
        let headingNumberingConfig = config.createHeadingNumberingConfig()
        
        // 获取当前语言
        let currentLanguage = MultiConfigLoader.getTargetLanguage(config)
        
        // 获取所有可用语言
        let availableLanguages = MultiConfigLoader.getTargetLanguages(configs)
        
        // 设置全局上下文的语言信息
        GlobalContext.currentLanguage = currentLanguage
        GlobalContext.availableLanguages = availableLanguages
        
        // baseUrl 暂时为 None（可以在未来从配置中读取）
        GlobalContext.baseUrl = None
        
        // 创建一个临时的 RenderConfig 用于初始化 Processor
        // 注意：真正的 RenderConfig 会在 buildWebsite 中创建并设置
        let tempRenderConfig = RenderConfig(
            "",  // inputPath - 稍后在 buildWebsite 中设置
            "",  // outputPath - 稍后在 buildWebsite 中设置
            config.outputType,
            config.codeBlock.group,
            config.codeBlock.theme,
            config.codeBlock.lightTheme,
            config.codeBlock.darkTheme,
            config.codeBlock.enabled,
            resolveCodeBlockGrammarDirs(config),
            resolveCodeBlockThemeDirs(config),
            config.codeBlock.languages,
            config.codeBlock.aliases,
            config.codeBlock.autoAnchor,
            this.devMode,
            config.toc,
            config.theme,
            config.title,
            Some(i18nConfig),
            Some(headingNumberingConfig),
            config.heading.number.resetFor,
            config.website.chapter.navigation,
            config.website.chapter.prevText,
            config.website.chapter.nextText,
            config.website.statistic.totalTexts,
            config.website.statistic.totalTextsTemplate,
            config.website.statistic.spentTime,
            config.website.statistic.spentTimeTemplate,
            config.website.statistic.second,
            config.website.statistic.minute,
            config.website.git.prefix,
            config.website.repos.github,
            config.website.repos.gitcode,
            config.website.repos.gitee,
            config.website.repos.gitlab,
            config.list.orderedList.multiLevel,
            config.list.autoAnchor,
            config.math.autoAnchor,
            config.table.threeLine,
            config.table.autoAnchor,
            config.block.autoAnchor,
            config.heading.closable,
            config.pdf.typst.code.useBundledSyntaxes,
            config.pdf.typst.code.useBundledTheme,
            config.pdf.typst.code.syntaxes,
            config.pdf.typst.code.theme,
            config.pdf.typst.code.ligatures,
            config.pdf.typst.cover.enabled,
            config.pdf.typst.cover.logo,
            config.pdf.typst.cover.title,
            config.pdf.typst.cover.subtitle,
            config.pdf.typst.cover.authors,
            config.pdf.typst.cover.version,
            config.pdf.typst.cover.organization,
            config.pdf.typst.cover.suborganization,
            config.pdf.typst.toc.maxLevel,
            config.pdf.typst.pageNumber.enabled,
            config.pdf.typst.pageNumber.position,
            config.pdf.typst.pageNumber.align,
            config.website.assets.scripts,
            config.website.assets.styles,
            config.website.code.ligatures
        )
        GlobalContext.renderConfig = tempRenderConfig

        // 使用 ProcessorFactory 创建处理器
        return ProcessorFactory.createProcessor(format: config.outputType)
    }
    
    /**
     * 执行网站构建
     * 
     * @param config 配置对象
     * @param processor 处理器实例
     * @param inputPath 输入路径
     * @param outputPath 输出路径
     * @param incrementalFile 增量构建的文件路径（None 表示完整构建）
     */
    private func buildWebsite(
        config: MarkitConfig,
        processor: Processor,
        inputPath: String,
        outputPath: String,
        incrementalFile: ?String
    ): Unit {
        // 创建渲染配置
        let renderConfig = RenderConfig(
            inputPath,
            outputPath,
            config.outputType,
            config.codeBlock.group,
            config.codeBlock.theme,
            config.codeBlock.lightTheme,
            config.codeBlock.darkTheme,
            config.codeBlock.enabled,
            resolveCodeBlockGrammarDirs(config),
            resolveCodeBlockThemeDirs(config),
            config.codeBlock.languages,
            config.codeBlock.aliases,
            config.codeBlock.autoAnchor,
            this.devMode,
            config.toc,
            config.theme,
            config.title,
            Some(config.createI18nConfig()),
            Some(config.createHeadingNumberingConfig()),
            config.heading.number.resetFor,
            config.website.chapter.navigation,
            config.website.chapter.prevText,
            config.website.chapter.nextText,
            config.website.statistic.totalTexts,
            config.website.statistic.totalTextsTemplate,
            config.website.statistic.spentTime,
            config.website.statistic.spentTimeTemplate,
            config.website.statistic.second,
            config.website.statistic.minute,
            config.website.git.prefix,
            config.website.repos.github,
            config.website.repos.gitcode,
            config.website.repos.gitee,
            config.website.repos.gitlab,
            config.list.orderedList.multiLevel,
            config.list.autoAnchor,
            config.math.autoAnchor,
            config.table.threeLine,
            config.table.autoAnchor,
            config.block.autoAnchor,
            config.heading.closable,
            config.pdf.typst.code.useBundledSyntaxes,
            config.pdf.typst.code.useBundledTheme,
            config.pdf.typst.code.syntaxes,
            config.pdf.typst.code.theme,
            config.pdf.typst.code.ligatures,
            config.pdf.typst.cover.enabled,
            config.pdf.typst.cover.logo,
            config.pdf.typst.cover.title,
            config.pdf.typst.cover.subtitle,
            config.pdf.typst.cover.authors,
            config.pdf.typst.cover.version,
            config.pdf.typst.cover.organization,
            config.pdf.typst.cover.suborganization,
            config.pdf.typst.toc.maxLevel,
            config.pdf.typst.pageNumber.enabled,
            config.pdf.typst.pageNumber.position,
            config.pdf.typst.pageNumber.align,
            config.website.assets.scripts,
            config.website.assets.styles,
            config.website.code.ligatures
        )

        // 获取 SummaryOptions
        let (summaryFile, summaryShowDrafts) = config.getSummaryOptions()
        let summaryOptions = SummaryOptions(file: summaryFile, showDrafts: summaryShowDrafts)
        
        // 获取当前语言和所有可用语言
        let currentLanguage = MultiConfigLoader.getTargetLanguage(config)
        let availableLanguages = MultiConfigLoader.getTargetLanguages(configs)
        
        // 设置全局上下文
        GlobalContext.currentLanguage = currentLanguage
        GlobalContext.availableLanguages = availableLanguages
        
        // 执行渲染（跳过清理，因为MultiLanguageBuilder已经在最开始清理了整个dist）
        let result = MarkdownRenderer.render(
            renderConfig, 
            summaryOptions,
            changedFile: incrementalFile,
            skipCleanup: true,
            parallelJobs: parallelJobs
        )
        
        if (!result.success) {
            match (result.errorMessage) {
                case Some(message) => 
                    throw Exception("Build failed: ${message}")
                case None => 
                    throw Exception("Build failed: Unknown error")
            }
        }
    }
    
    /**
     * 生成 Landing Page
     * 
     * @param languages 语言列表
     */
    private func generateLandingPage(languages: Array<String>): Unit {
        // 使用 LandingPageGenerator 生成 Landing Page HTML
        let landingPageHtml = LandingPageGenerator.generate(configs)
        
        // 写入到输出目录的根 index.html
        let indexPath = Path(outputPath).join("index.html")
        File.writeTo(indexPath, landingPageHtml.toArray())
        
        KitHooks.success("Landing page generated at ${indexPath}")
    }
    
    /**
     * 拷贝主题资源到根目录
     * 
     * Validates: Requirements 10.1, 10.4
     */
    private func copySharedThemeAssets(): Unit {
        // 将主题资源（CSS、JS、favicon、字体）复制到 ${outputPath}/assets/ 仅一次
        FileHandler.copySharedAssets(outputPath)
    }
    
    /**
     * 拷贝用户共享资源到根目录的 public/ 文件夹
     * 
     * Validates: Requirements 5.4, 10.2, 10.5
     */
    private func copyPublicAssets(): Unit {
        // 复制文档目录中的静态文件（图片、视频等）到 public/
        FileHandler.copyStaticFiles(inputPath, Path(outputPath).join("public").normalize().toString())
    }

    private func resolveCodeBlockGrammarDirs(config: MarkitConfig): Array<String> {
        let dirs = ArrayList<String>()
        appendConfiguredDirs(dirs, config.codeBlock.grammarDirs)
        appendUnique(dirs, ResourceResolver.resolveResourcePathString("assets/codehl/grammars"))
        appendUnique(dirs, ResourceResolver.resolveResourcePathString("assets/grammars"))
        appendUnique(dirs, "codehl/assets/grammars")
        appendUnique(dirs, "../codehl/assets/grammars")
        return dirs.toArray()
    }

    private func resolveCodeBlockThemeDirs(config: MarkitConfig): Array<String> {
        let dirs = ArrayList<String>()
        appendConfiguredDirs(dirs, config.codeBlock.themeDirs)
        appendUnique(dirs, ResourceResolver.resolveResourcePathString("assets/codehl/themes"))
        appendUnique(dirs, ResourceResolver.resolveResourcePathString("assets/themes/codehl"))
        appendUnique(dirs, "codehl/assets/themes")
        appendUnique(dirs, "../codehl/assets/themes")
        appendUnique(dirs, "assets/themes")
        return dirs.toArray()
    }

    private func appendConfiguredDirs(out: ArrayList<String>, dirs: Array<String>): Unit {
        for (dir in dirs) {
            let trimmed = dir.trimAscii()
            if (trimmed.isEmpty()) {
                continue
            }
            let path = Path(trimmed)
            if (path.isAbsolute()) {
                appendUnique(out, path.normalize().toString())
            } else {
                appendUnique(out, Path(inputPath).join(trimmed).normalize().toString())
            }
        }
    }

    private static func appendUnique(out: ArrayList<String>, value: String): Unit {
        let trimmed = value.trimAscii()
        if (!trimmed.isEmpty() && !out.contains(trimmed)) {
            out.add(trimmed)
        }
    }
    
    /**
     * 清理输出目录
     */
    private func cleanOutputDirectory(): Unit {
        FileHandler.cleanOutputDirectory(outputPath)
    }
}
