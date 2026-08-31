package markit_kit.themes

/**
 * 主题接口
 * 定义主题必须提供的方法
 */
public interface Theme {
    /**
     * 获取主题名称
     */
    func getName(): String
    
    /**
     * 获取主题描述
     */
    func getDescription(): String
    
    /**
     * 获取CSS样式
     */
    func getStyles(): String
    
    /**
     * 获取网站模式的模板
     * 
     * @param devMode 是否为开发模式
     * @return 网站模式HTML模板字符串
     */
    func getWebsiteTemplate(devMode: Bool): String
    
    /**
     * 获取带相对路径的网站模板
     * 
     * @param devMode 是否为开发模式
     * @param relativePath 相对路径前缀（如 "../" 或 ""）
     * @return 处理过的模板
     */
    func getWebsiteTemplateWithPaths(devMode: Bool, relativePath: String): String
    
    /**
     * 是否支持网站模式
     */
    func supportsWebsiteMode(): Bool
}
