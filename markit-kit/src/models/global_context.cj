package markit_kit.models

import markit.plugins.standard.inline.link.LinkConfig

/**
 * 全局上下文
 * 
 * 存储全局配置信息，避免在各个函数之间传递参数
 */
public class GlobalContext {
    // 当前语言
    private static var _currentLanguage: String = ""
    
    // 所有可用语言
    private static var _availableLanguages: Array<String> = []
    
    // LinkConfig
    private static var _linkConfig: ?LinkConfig = None
    
    // RenderConfig
    private static var _renderConfig: ?RenderConfig = None
    
    // SiteStructure
    private static var _siteStructure: ?SiteStructure = None
    
    // SummaryConfig
    private static var _summaryConfig: ?SummaryConfig = None
    
    // SummaryOptions
    private static var _summaryOptions: ?SummaryOptions = None
    
    // BaseUrl（用于SEO的多语言hreflang标签）
    private static var _baseUrl: ?String = None
    
    // ParallelJobs（并行任务数）
    private static var _parallelJobs: Int64 = 1

    // AssetRoot（由上游传入的资源根目录）
    private static var _assetRoot: String = ""
    
    /**
     * 当前语言属性
     */
    public static mut prop currentLanguage: String {
        get() {
            _currentLanguage
        }
        set(value) {
            _currentLanguage = value
        }
    }
    
    /**
     * 所有可用语言属性
     */
    public static mut prop availableLanguages: Array<String> {
        get() {
            _availableLanguages
        }
        set(value) {
            _availableLanguages = value
        }
    }
    
    /**
     * LinkConfig 属性
     */
    public static mut prop linkConfig: ?LinkConfig {
        get() {
            _linkConfig
        }
        set(value) {
            _linkConfig = value
        }
    }
    
    /**
     * RenderConfig 属性
     */
    public static mut prop renderConfig: ?RenderConfig {
        get() {
            _renderConfig
        }
        set(value) {
            _renderConfig = value
        }
    }
    
    /**
     * SiteStructure 属性
     */
    public static mut prop siteStructure: ?SiteStructure {
        get() {
            _siteStructure
        }
        set(value) {
            _siteStructure = value
        }
    }
    
    /**
     * SummaryConfig 属性
     */
    public static mut prop summaryConfig: ?SummaryConfig {
        get() {
            _summaryConfig
        }
        set(value) {
            _summaryConfig = value
        }
    }
    
    /**
     * SummaryOptions 属性
     */
    public static mut prop summaryOptions: ?SummaryOptions {
        get() {
            _summaryOptions
        }
        set(value) {
            _summaryOptions = value
        }
    }
    
    /**
     * BaseUrl 属性（用于SEO）
     */
    public static mut prop baseUrl: ?String {
        get() {
            _baseUrl
        }
        set(value) {
            _baseUrl = value
        }
    }
    
    /**
     * ParallelJobs 属性（并行任务数）
     */
    public static mut prop parallelJobs: Int64 {
        get() {
            _parallelJobs
        }
        set(value) {
            _parallelJobs = value
        }
    }

    /**
     * AssetRoot 属性（由 CLI/docchir 等上游传入）
     */
    public static mut prop assetRoot: String {
        get() {
            _assetRoot
        }
        set(value) {
            _assetRoot = value
        }
    }
    
    /**
     * 重置全局上下文
     */
    public static func reset(): Unit {
        _currentLanguage = ""
        _availableLanguages = []
        _linkConfig = None
        _renderConfig = None
        _siteStructure = None
        _summaryConfig = None
        _summaryOptions = None
        _baseUrl = None
        _parallelJobs = 1
        _assetRoot = ""
    }
}
