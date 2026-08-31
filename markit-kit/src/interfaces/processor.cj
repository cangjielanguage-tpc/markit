package markit_kit.interfaces

import markit.core.nodes.DocumentNode
import markit.plugins.standard.inline.link.LinkConfig

/**
 * 内容处理器接口
 * 定义了统一的内容处理方法，支持不同的输出格式
 * 
 * 参考文档：
 * - markit/libs/dev-guide/source_en/class_and_interface/interface.md - 接口定义语法
 * - command interface implementations - 接口设计示例
 */
public interface Processor {
    /**
     * 处理Markdown内容
     * 
     * @param content Markdown内容
     * @param title 文档标题
     * @param currentPagePath 当前页面路径（可选，用于导航高亮）
     * @param asDocument 是否作为简单文档处理（可选，不带侧边栏）
     * @return 元组：(处理后的输出内容, 解析后的文档节点)
     */
    func process(content: String, title: String, currentPagePath!: String, asDocument!: Bool): (String, DocumentNode)
    
    /**
     * 将已导出的内容包装成最终文档
     * 用于首页内容或合并模式输出
     * 
     * @param htmlContent 已导出的内容
     * @param title 页面标题
     * @param currentPagePath 当前页面路径
     * @return 包装后的完整文档
     */
    func wrapHtmlContent(htmlContent: String, title: String, currentPagePath: String): String
    
    /**
     * 获取处理器支持的文件扩展名
     * 
     * @return 文件扩展名（如"html", "typ", "pdf"）
     */
    func getExtension(): String
    
    /**
     * 获取处理器类型描述
     * 
     * @return 处理器类型描述
     */
    func getType(): String
    
    /**
     * 更新链接解析配置。Processor 在每次解析时用该配置构造新的 Markit 会话。
     */
    func setLinkConfig(config: LinkConfig): Unit

    /**
     * 设置当前文件解析前的标题编号状态。
     */
    func setHeadingInitialState(state: Array<Int64>): Unit
}
