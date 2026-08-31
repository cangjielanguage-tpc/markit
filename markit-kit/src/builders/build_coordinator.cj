package markit_kit.builders

import markit_kit.utils.KitHooks

import markit_kit.config.{ConfigLoader, ConfigLoadResult, MultiConfigLoader, MarkitConfig}
import markit_kit.models.GlobalContext
import std.fs.Path

/**
 * 构建协调器
 * 
 * 统一管理单语言和多语言构建流程，提供给 RenderCommand 和 ServeCommand 使用
 */
public class BuildCoordinator {
    
    /**
     * 执行构建（自动检测单语言或多语言模式）
     * 
     * @param configPaths 配置文件路径数组
     * @param inputPath 输入路径
     * @param outputPath 输出路径
     * @param devMode 是否为开发模式
     * @param parallelJobs 并行任务数（1=串行，>1=并行，0=自动检测CPU核心数）
     * @return 构建结果（0 = 成功，1 = 失败）
     */
    public static func build(
        configPaths: Array<String>,
        inputPath: String,
        outputPath: String,
        assetRoot: String,
        devMode!: Bool = false,
        parallelJobs!: Int64 = 1
    ): Int {
        return buildInternal(configPaths, inputPath, outputPath, assetRoot, devMode, None, parallelJobs)
    }
    
    /**
     * 执行增量构建（仅重新构建变化的文件）
     * 
     * @param configPaths 配置文件路径数组
     * @param inputPath 输入路径
     * @param outputPath 输出路径
     * @param devMode 是否为开发模式
     * @param changedFile 变化的文件路径
     * @param parallelJobs 并行任务数
     * @return 构建结果（0 = 成功，1 = 失败）
     */
    public static func incrementalBuild(
        configPaths: Array<String>,
        inputPath: String,
        outputPath: String,
        assetRoot: String,
        devMode: Bool,
        changedFile: String,
        parallelJobs!: Int64 = 1
    ): Int {
        return buildInternal(configPaths, inputPath, outputPath, assetRoot, devMode, Some(changedFile), parallelJobs)
    }
    
    /**
     * 内部构建方法（支持完整构建和增量构建）
     * 
     * @param configPaths 配置文件路径数组
     * @param inputPath 输入路径
     * @param outputPath 输出路径
     * @param devMode 是否为开发模式
     * @param incrementalFile 增量构建的文件路径（None 表示完整构建）
     * @param parallelJobs 并行任务数
     * @return 构建结果（0 = 成功，1 = 失败）
     */
    private static func buildInternal(
        configPaths: Array<String>,
        inputPath: String,
        outputPath: String,
        assetRoot: String,
        devMode: Bool,
        incrementalFile: ?String,
        parallelJobs: Int64
    ): Int {
        GlobalContext.assetRoot = assetRoot
        if (configPaths.size > 1) {
            // 多语言构建模式
            return executeMultiLanguageBuild(configPaths, inputPath, outputPath, devMode, incrementalFile, parallelJobs)
        } else {
            // 单语言构建模式（使用统一目录结构）
            return executeSingleLanguageBuild(configPaths, inputPath, outputPath, devMode, incrementalFile, parallelJobs)
        }
    }
    
    /**
     * 执行多语言构建
     * 
     * @param configPaths 配置文件路径数组
     * @param inputPath 输入路径
     * @param outputPath 输出路径
     * @param devMode 是否为开发模式
     * @param incrementalFile 增量构建的文件路径（None 表示完整构建）
     * @param parallelJobs 并行任务数
     * @return 退出代码
     * 
     * Validates: Requirements 4.1
     */
    private static func executeMultiLanguageBuild(
        configPaths: Array<String>,
        inputPath: String,
        outputPath: String,
        devMode: Bool,
        incrementalFile: ?String,
        parallelJobs: Int64
    ): Int {
        // 验证 PDF/Markdown/Typst 模式不支持多配置文件
        var hasSingleFileFormat = false
        for (configPath in configPaths) {
            let (result, _) = ConfigLoader.loadConfig(configPath)
            match (result) {
                case ConfigLoadResult.Success(cfg) =>
                    if (cfg.outputType == "pdf" || cfg.outputType == "markdown" || cfg.outputType == "typst") {
                        hasSingleFileFormat = true
                    }
                case ConfigLoadResult.Error(_) => ()
            }
        }
        
        if (hasSingleFileFormat) {
            KitHooks.err("PDF、Markdown 与 Typst 单文件模式仅支持单个配置文件")
            return 1
        }
        
        // 加载并验证所有配置文件
        let loadResult = MultiConfigLoader.loadAndValidate(configPaths)
        
        match (loadResult) {
            case Some(result) =>
                // 使用配置文件所在目录作为输入路径
                let workingDir = result.workingDirectory
                
                // 创建 MultiLanguageBuilder 并执行构建
                let builder = MultiLanguageBuilder(
                    result.configs,
                    workingDir,
                    outputPath,
                    devMode: devMode,
                    parallelJobs: parallelJobs
                )
                
                try {
                    match (incrementalFile) {
                        case Some(file) =>
                            // 增量构建
                            builder.incrementalBuild(file)
                        case None =>
                            // 完整构建
                            builder.build()
                    }
                    return 0
                } catch (e: Exception) {
                    KitHooks.err("Multi-language build failed: ${e.message}")
                    return 1
                }
            case None =>
                // 验证失败，错误已在 loadAndValidate 中打印
                return 1
        }
    }
    
    /**
     * 执行单语言构建（使用统一目录结构）
     * 
     * @param configPaths 配置文件路径数组（可能为空或包含一个路径）
     * @param inputPath 输入路径
     * @param outputPath 输出路径
     * @param devMode 是否为开发模式
     * @param incrementalFile 增量构建的文件路径（None 表示完整构建）
     * @param parallelJobs 并行任务数
     * @return 退出代码
     * 
     * Validates: Requirements 3.1
     */
    private static func executeSingleLanguageBuild(
        configPaths: Array<String>,
        inputPath: String,
        outputPath: String,
        devMode: Bool,
        incrementalFile: ?String,
        parallelJobs: Int64
    ): Int {
        // 加载配置
        let (configResult, configPath) = if (configPaths.size > 0) {
            ConfigLoader.loadConfig(configPaths[0])
        } else {
            ConfigLoader.autoLoadConfig(inputPath)
        }
        
        let markitConfig = configResult.validateAndGet(configPath: configPath) ?? return 1
        
        // 对于单语言构建，也使用统一目录结构（语言文件夹 + 根 assets）
        // 将配置包装成数组，使用 MultiLanguageBuilder
        let configs = [markitConfig]
        
        // 确定工作目录
        let workingDir = if (configPaths.size > 0) {
            let path = Path(configPaths[0])
            let parent = path.parent
            if (parent.isEmpty()) { inputPath } else { parent.toString() }
        } else {
            inputPath
        }
        
        // 使用 MultiLanguageBuilder 构建（即使是单语言也使用统一结构）
        let builder = MultiLanguageBuilder(configs, workingDir, outputPath, devMode: devMode, parallelJobs: parallelJobs)
        
        try {
            match (incrementalFile) {
                case Some(file) =>
                    // 增量构建
                    builder.incrementalBuild(file)
                case None =>
                    // 完整构建
                    builder.build()
            }
            return 0
        } catch (e: Exception) {
            if (KitHooks.hasActiveTransientLine()) {
                KitHooks.dismissTransientLine()
            }
            return 1
        }
    }
    
    /**
     * 加载配置文件（用于 serve 模式的配置重载）
     * 
     * @param configPaths 配置文件路径数组
     * @param inputPath 输入路径
     * @return 配置对象和配置路径，失败返回 None
     */
    public static func loadConfig(
        configPaths: Array<String>,
        inputPath: String
    ): ?(MarkitConfig, String) {
        let (configResult, configPath) = if (configPaths.size > 0) {
            ConfigLoader.loadConfig(configPaths[0])
        } else {
            ConfigLoader.autoLoadConfig(inputPath)
        }
        
        match (configResult) {
            case ConfigLoadResult.Success(config) =>
                return Some((config, configPath ?? ""))
            case ConfigLoadResult.Error(_) =>
                return None
        }
    }
}
