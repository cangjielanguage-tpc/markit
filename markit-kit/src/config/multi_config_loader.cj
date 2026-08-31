package markit_kit.config

import markit_kit.utils.KitHooks

import std.fs.{Path, exists, FileInfo}
import std.collection.{ArrayList, HashSet}
import markit_kit.utils.FileHandler
import markit.plugins.i18n.config.I18nConfig

/**
 * 多配置文件加载结果
 */
public class MultiConfigLoadResult {
    public let success: Bool
    public let configs: Array<MarkitConfig>
    public let configPaths: Array<String>
    public let workingDirectory: String
    public let errors: Array<String>
    
    private init(
        success: Bool,
        configs: Array<MarkitConfig>,
        configPaths: Array<String>,
        workingDirectory: String,
        errors: Array<String>
    ) {
        this.success = success
        this.configs = configs
        this.configPaths = configPaths
        this.workingDirectory = workingDirectory
        this.errors = errors
    }
    
    /**
     * 创建成功结果
     */
    public static func createSuccess(
        configs: Array<MarkitConfig>,
        configPaths: Array<String>,
        workingDirectory: String
    ): MultiConfigLoadResult {
        return MultiConfigLoadResult(
            true,
            configs,
            configPaths,
            workingDirectory,
            []
        )
    }
    
    /**
     * 创建失败结果
     */
    public static func createFailure(errors: Array<String>): MultiConfigLoadResult {
        return MultiConfigLoadResult(
            false,
            [],
            [],
            "",
            errors
        )
    }
    
    /**
     * 检查是否成功
     */
    public func isSuccess(): Bool {
        return success
    }
    
    /**
     * 获取第一个配置（默认语言配置）
     */
    public func getDefaultConfig(): ?MarkitConfig {
        if (configs.size > 0) {
            return Some(configs[0])
        }
        return None
    }
    
    /**
     * 获取默认语言代码
     */
    public func getDefaultLanguage(): String {
        if (configs.size > 0) {
            return configs[0].i18n.target
        }
        return "en"
    }
}

/**
 * 验证结果
 */
public class ValidationResult {
    public let isValid: Bool
    public let errors: Array<String>
    
    private init(isValid: Bool, errors: Array<String>) {
        this.isValid = isValid
        this.errors = errors
    }
    
    public static func validResult(): ValidationResult {
        return ValidationResult(true, [])
    }
    
    public static func invalidResult(errors: Array<String>): ValidationResult {
        return ValidationResult(false, errors)
    }
    
    public func getErrorMessage(): String {
        return String.join(errors.toArray(), delimiter: "\n")
    }
}

/**
 * 多配置文件加载器
 * 
 * 负责加载、验证多个配置文件，并确保它们满足多语言构建的要求
 * 
 * Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 
 *            12.1, 12.2, 15.1, 15.2, 15.3, 15.6, 16.1, 16.7, 16.8
 */
public class MultiConfigLoader {
    
    /**
     * 加载多个配置文件
     * 
     * @param configPaths 配置文件路径数组
     * @return 多配置文件加载结果
     * 
     * Validates: Requirement 2.1
     */
    public static func loadConfigs(configPaths: Array<String>): MultiConfigLoadResult {
        if (configPaths.size == 0) {
            return MultiConfigLoadResult.createFailure(["未提供配置文件路径"])
        }
        
        let configs = ArrayList<MarkitConfig>()
        let loadedPaths = ArrayList<String>()
        let errors = ArrayList<String>()
        
        // 循环遍历每个路径并使用现有的 ConfigLoader 加载
        for (path in configPaths) {
            let (result, resolvedPath) = ConfigLoader.loadConfig(path)
            
            match (result) {
                case Success(config) =>
                    configs.add(config)
                    // 使用解析后的路径（如果有）
                    loadedPaths.add(resolvedPath ?? path)
                case Error(message) =>
                    // 捕获 JSON 解析错误并包含文件路径（Req 2.2）
                    errors.add("加载配置文件失败 [${path}]: ${message}")
                }
        }
        
        // 如果有加载错误，返回失败结果
        if (!errors.isEmpty()) {
            return MultiConfigLoadResult.createFailure(errors.toArray())
        }
        
        // 设置配置工作目录（从第一个配置文件路径提取目录，Req 15.3, 15.6）
        let workingDir = extractWorkingDirectory(loadedPaths.toArray())
        
        return MultiConfigLoadResult.createSuccess(
            configs.toArray(),
            loadedPaths.toArray(),
            workingDir
        )
    }
    
    /**
     * 验证所有配置文件在同一目录下
     * 
     * @param configPaths 配置文件路径数组
     * @return 验证结果
     * 
     * Validates: Requirements 2.7, 2.8, 15.1, 15.2
     */
    public static func validateSameDirectory(configPaths: Array<String>): ValidationResult {
        if (configPaths.size <= 1) {
            return ValidationResult.validResult()
        }
        
        // 提取每个配置文件的目录路径
        let directories = ArrayList<String>()
        for (path in configPaths) {
            let dir = extractDirectory(path)
            directories.add(dir)
        }
        
        // 验证所有目录路径相同
        let firstDir = directories[0]
        for (i in 1..directories.size) {
            if (directories[i] != firstDir) {
                // 如果不同，返回错误（Req 2.8）
                return ValidationResult.invalidResult([
                    "所有配置文件必须在同一目录下",
                    "配置文件目录不一致:",
                    "  - ${configPaths[0]} (目录: ${firstDir})",
                    "  - ${configPaths[i]} (目录: ${directories[i]})"
                ])
            }
        }
        
        return ValidationResult.validResult()
    }
    
    /**
     * 实现配置验证逻辑
     * 
     * @param configs 配置对象数组
     * @return 验证结果
     * 
     * Validates: Requirements 2.3, 2.4, 2.5, 12.1, 12.2
     */
    public static func validateConfigs(configs: Array<MarkitConfig>): ValidationResult {
        let errors = ArrayList<String>()
        let targetLanguages = ArrayList<String>()
        var formatValue: ?String = None
        
        for (i in 0..configs.size) {
            let config = configs[i]
            let configLabel = "配置文件 ${i + 1}"
            
            // 验证每个配置都有 i18n.target 字段（Req 2.3）
            if (config.i18n.target.isEmpty()) {
                errors.add("${configLabel}: 缺少 i18n.target 字段")
            } else {
                let target = config.i18n.target
                
                // 验证语言标识符有效
                if (I18nConfig.validateLanguageId(target).isNone()) {
                    errors.add("${configLabel}: 无效的语言标识符 '${target}'")
                } else {
                    // 收集目标语言用于检测重复
                    targetLanguages.add(target)
                }
            }
            
            // 验证 format 值一致性（Req 2.5, 12.1, 12.2）
            let currentFormat = config.outputType
            if (formatValue.isNone()) {
                formatValue = Some(currentFormat)
            } else {
                match (formatValue) {
                    case Some(expectedFormat) =>
                        if (currentFormat != expectedFormat) {
                            errors.add("${configLabel}: format 值不一致 (期望 '${expectedFormat}', 实际 '${currentFormat}')")
                        }
                    case None => ()
                }
            }
        }
        
        // 验证没有重复的 i18n.target 值（Req 2.4）
        let seenLanguages = HashSet<String>()
        let duplicates = ArrayList<String>()
        
        for (lang in targetLanguages) {
            if (seenLanguages.contains(lang)) {
                duplicates.add(lang)
            }
            seenLanguages.add(lang)
        }
        
        if (!duplicates.isEmpty()) {
            let duplicateStr = String.join(duplicates.toArray(), delimiter: ", ")
            errors.add("多个配置文件指定了相同的目标语言: ${duplicateStr}")
        }
        
        if (!errors.isEmpty()) {
            return ValidationResult.invalidResult(errors.toArray())
        }
        
        return ValidationResult.validResult()
    }

    /**
     * 验证 route_prefix 配置
     * 
     * @param configs 配置对象数组
     * @param configDir 配置文件所在目录
     * @return 验证结果
     * 
     * Validates: Requirements 16.1, 16.7, 16.8
     */
    public static func validateRoutePrefix(configs: Array<MarkitConfig>, configDir: String): ValidationResult {
        let errors = ArrayList<String>()
        
        for (i in 0..configs.size) {
            let config = configs[i]
            let configLabel = "配置文件 ${i + 1}"
            
            // 如果配置了 i18n.route_prefix
            if (let Some(routePrefix) <- getRoutePrefix(config)) {
                // 验证不为空字符串（Req 16.1）
                if (routePrefix.isEmpty()) {
                    errors.add("${configLabel}: i18n.route_prefix 不能为空字符串")
                    continue
                }
                
                // 验证 route_prefix 路径存在（相对于配置文件所在目录，Req 16.8）
                let fullPath = Path(configDir).join(routePrefix).normalize().toString()
                if (!exists(Path(fullPath))) {
                    errors.add("${configLabel}: i18n.route_prefix 指定的路径不存在: '${routePrefix}' (完整路径: ${fullPath})")
                }
            }
        }
        
        if (!errors.isEmpty()) {
            return ValidationResult.invalidResult(errors.toArray())
        }
        
        return ValidationResult.validResult()
    }
    
    /**
     * 加载并验证多个配置文件
     * 
     * 此方法整合了加载和验证流程，聚合所有错误并以用户友好的格式显示
     * 
     * @param configPaths 配置文件路径数组
     * @return 验证后的配置结果，失败时返回 None
     * 
     * Validates: Requirements 2.2, 2.6
     */
    public static func loadAndValidate(configPaths: Array<String>): ?MultiConfigLoadResult {
        // 1. 加载配置文件
        let loadResult = loadConfigs(configPaths)
        
        if (!loadResult.isSuccess()) {
            // 聚合所有验证错误（Req 2.6）
            printErrors("配置文件加载失败", loadResult.errors)
            return None
        }
        
        // 2. 验证配置文件在同一目录（Req 2.7, 2.8）
        let dirValidation = validateSameDirectory(loadResult.configPaths)
        if (!dirValidation.isValid) {
            printErrors("配置文件目录验证失败", dirValidation.errors)
            return None
        }
        
        // 3. 验证配置内容（Req 2.3, 2.4, 2.5）
        let configValidation = validateConfigs(loadResult.configs)
        if (!configValidation.isValid) {
            printErrors("配置内容验证失败", configValidation.errors)
            return None
        }
        
        // 4. 验证 route_prefix 配置（Req 16.1, 16.7, 16.8）
        let routePrefixValidation = validateRoutePrefix(loadResult.configs, loadResult.workingDirectory)
        if (!routePrefixValidation.isValid) {
            printErrors("route_prefix 配置验证失败", routePrefixValidation.errors)
            return None
        }
        
        // 所有验证通过
        KitHooks.success("All configuration files validated successfully")
        return Some(loadResult)
    }
    
    /**
     * 获取配置的目标语言列表
     * 
     * @param configs 配置对象数组
     * @return 目标语言代码数组
     */
    public static func getTargetLanguages(configs: Array<MarkitConfig>): Array<String> {
        let languages = ArrayList<String>()
        for (config in configs) {
            languages.add(config.i18n.target)
        }
        return languages.toArray()
    }
    
    /**
     * 获取配置的目标语言（单个）
     * 
     * @param config 配置对象
     * @return 目标语言代码
     */
    public static func getTargetLanguage(config: MarkitConfig): String {
        return config.i18n.target
    }
    
    /**
     * 获取配置的 route_prefix
     * 
     * @param config 配置对象
     * @return route_prefix 值，如果未设置则返回 None
     */
    public static func getRoutePrefix(config: MarkitConfig): ?String {
        let prefix = config.i18n.routePrefix
        if (prefix.isEmpty()) {
            return None
        }
        return Some(prefix)
    }
    
    /**
     * 设置配置的 route_prefix
     * 
     * @param config 配置对象
     * @param routePrefix route_prefix 值
     */
    public static func setRoutePrefix(config: MarkitConfig, routePrefix: String): Unit {
        config.i18n.routePrefix = routePrefix
    }
    
    /**
     * 提取配置文件所在目录
     * 
     * @param configPath 配置文件路径
     * @return 目录路径
     */
    private static func extractDirectory(configPath: String): String {
        let path = Path(configPath)
        let parent = path.parent
        return if (parent.isEmpty()) { "" } else { parent.toString() }
    }
    
    /**
     * 提取工作目录（从第一个配置文件路径）
     * 
     * @param configPaths 配置文件路径数组
     * @return 工作目录路径
     * 
     * Validates: Requirements 15.3, 15.6
     */
    private static func extractWorkingDirectory(configPaths: Array<String>): String {
        if (configPaths.size == 0) {
            return ""
        }
        return extractDirectory(configPaths[0])
    }
    
    /**
     * 打印错误信息（用户友好的格式）
     * 
     * @param title 错误标题
     * @param errors 错误列表
     */
    private static func printErrors(title: String, errors: Array<String>): Unit {
        KitHooks.newLine()
        KitHooks.err("${title}:")
        for (error in errors) {
            KitHooks.plain("   ${error}")
        }
        KitHooks.newLine()
        KitHooks.warn("构建已停止，请修复上述错误后重试")
    }
}
