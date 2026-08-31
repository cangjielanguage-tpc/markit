package markit_kit.processors

import markit_kit.interfaces.Processor
import markit_kit.models.GlobalContext
import markit.plugins.i18n.config.I18nConfig
import markit.plugins.standard.block.heading.HeadingNumberingConfig
import markit.plugins.standard.inline.link.LinkConfig

/**
 * 处理器工厂
 * 根据格式类型创建相应的处理器实例
 */
public class ProcessorFactory {
    
    /**
     * 根据格式创建处理器
     * 
     * 从 GlobalContext 读取所有配置
     * 
     * @param format 输出格式（website/typst/pdf等，可选，从 GlobalContext 读取）
     * @param themeName 主题名称（可选，从 GlobalContext 读取）
     * @return 对应的处理器实例
     */
    public static func createProcessor(
        format!: String = "",
        themeName!: String = ""
    ): Processor {
        // 从 GlobalContext 获取配置
        let config = GlobalContext.renderConfig.getOrThrow()
        
        let actualFormat = if (format.isEmpty()) { config.outputFormat } else { format }
        let lowerFormat = actualFormat.toAsciiLower()
        
        if (lowerFormat == "markdown") {
            return MarkdownProcessor(themeName: themeName)
        } else if (lowerFormat == "typst" || lowerFormat == "pdf") {
            return TypstProcessor(themeName: themeName)
        } else {
            return WebsiteProcessor(themeName: themeName)
        }
    }
    
    /**
     * 获取支持的格式列表
     * 
     * @return 支持的格式数组
     */
    public static func getSupportedFormats(): Array<String> {
        return ["website", "pdf", "markdown", "typst"]
    }

    public static func isFormatSupported(format: String): Bool {
        let lowerFormat = format.toAsciiLower()
        return lowerFormat == "website" || lowerFormat == "pdf" || lowerFormat == "markdown" || lowerFormat == "typst"
    }
}
