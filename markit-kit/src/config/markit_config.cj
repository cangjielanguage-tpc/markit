package markit_kit.config

import markit_kit.utils.KitHooks

import codehl.{LanguageAlias, LanguageRegistration}
import markit.plugins.i18n.config.I18nConfig
import markit.plugins.standard.block.heading.HeadingNumberingConfig
import std.collection.ArrayList

/**
 * Markit CLI 配置
 */
public class MarkitConfig {
    /**
     * i18n 配置
     */
    public var i18n: I18nSettings = I18nSettings()
    
    /**
     * 网站标题
     */
    public var title: String = "Documentation"
    
    /**
     * 主题名称
     */
    public var theme: String = "arctic"
    
    /**
     * 输出类型
     */
    public var outputType: String = "website"
    
    /**
     * 代码块配置
     */
    public var codeBlock: CodeBlockSettings = CodeBlockSettings()

    /**
     * 数学公式配置
     */
    public var math: MathSettings = MathSettings()

    /**
     * 列表配置
     */
    public var list: ListSettings = ListSettings()

    /**
     * 表格配置
     */
    public var table: TableSettings = TableSettings()

    /**
     * 通用块级元素配置
     */
    public var block: BlockSettings = BlockSettings()
    
    /**
     * 是否启用目录
     */
    public var toc: Bool = false
    
    /**
     * 标题编号配置
     */
    public var heading: HeadingSettings = HeadingSettings()
    
    /**
     * Summary 配置
     */
    public var summary: SummarySettings = SummarySettings()

    /**
     * PDF 生成配置
     */
    public var pdf: PdfSettings = PdfSettings()

    /**
     * 网站输出配置
     */
    public var website: WebsiteSettings = WebsiteSettings()
    
    /**
     * 创建 I18n 配置
     * 
     * @return I18n 插件配置
     */
    public func createI18nConfig(): I18nConfig {
        return I18nConfig(
            defaultLanguage: i18n.default, 
            targetLanguage: i18n.target,
            homeText: i18n.home,
            documentationText: i18n.documentation
        )
    }
    
    /**
     * 创建标题编号配置
     * 
     * @return 标题编号配置
     */
    public func createHeadingNumberingConfig(): HeadingNumberingConfig {
        // resetFor 策略：
        // - "always": 每个文件自动重置，resetBeforeParse=true
        // - "directory": 切换目录时重置，resetBeforeParse=false（需要手动调用）
        // - "never": 从不重置，resetBeforeParse=false
        let resetBeforeParse = heading.number.resetFor == "always"
        
        let startFrom = heading.number.startFrom
        return HeadingNumberingConfig(
            enabled: heading.number.enabled,
            startFrom: (startFrom[0], startFrom[1], startFrom[2], startFrom[3], startFrom[4], startFrom[5]),
            maxDepth: 6,
            includeInHtml: true,
            separator: ".",
            resetBeforeParse: resetBeforeParse
        )
    }
    
    /**
     * 获取 Summary 选项
     * 
     * @return Summary 选项
     */
    public func getSummaryOptions(): (String, Bool) {
        return (summary.file, summary.showDrafts)
    }
    
    /**
     * 验证配置是否有效
     * 
     * @return 验证结果
     */
    public func validate(): ConfigValidationResult {
        let errors = ArrayList<String>()
        
        // 验证 i18n.default
        if (I18nConfig.validateLanguageId(i18n.default).isNone()) {
            errors.add("无效的默认语言标识符: '${i18n.default}'")
        }
        
        // 验证 i18n.target
        if (I18nConfig.validateLanguageId(i18n.target).isNone()) {
            errors.add("无效的目标语言标识符: '${i18n.target}'")
        }
        
        // 验证主题名称
        if (theme.isEmpty()) {
            errors.add("主题名称不能为空")
        }
        
        // 验证输出类型
        if (outputType != "website" && outputType != "pdf" && outputType != "markdown" && outputType != "typst") {
            errors.add("无效的输出类型: '${outputType}'，支持的类型: website, pdf, markdown, typst")
        }

        if (pdf.typst.pageNumber.position != "header" && pdf.typst.pageNumber.position != "footer") {
            errors.add("无效的 pdf.typst.pageNumber.position: '${pdf.typst.pageNumber.position}'，支持的值: header, footer")
        }

        if (pdf.typst.pageNumber.align != "left" &&
            pdf.typst.pageNumber.align != "center" &&
            pdf.typst.pageNumber.align != "right") {
            errors.add("无效的 pdf.typst.pageNumber.align: '${pdf.typst.pageNumber.align}'，支持的值: left, center, right")
        }

        if (pdf.typst.toc.maxLevel < 1 || pdf.typst.toc.maxLevel > 6) {
            errors.add("无效的 pdf.typst.toc.maxLevel: '${pdf.typst.toc.maxLevel}'，支持的值: 1-6")
        }

        if (errors.isEmpty()) {
            return ConfigValidationResult.success()
        } else {
            return ConfigValidationResult.error(errors.toArray())
        }
    }
}

/**
 * i18n 设置
 */
public class I18nSettings {
    /**
     * 默认语言（用于未标记语言的内容）
     */
    public var default: String = "en"
    
    /**
     * 目标语言（用于编译时筛选）
     */
    public var target: String = "en"
    
    /**
     * 路由前缀（用于分文件夹组织的多语言文档）
     * 例如："zh" 表示从 docs/zh 目录读取中文文档
     * 相对于配置文件所在目录解析
     */
    public var routePrefix: String = ""
    
    /**
     * "首页"/"Home"的翻译文本
     */
    public var home: String = "Home"
    
    /**
     * "文档"/"Documentation"的翻译文本
     */
    public var documentation: String = "Documentation"
}

/**
 * 标题编号设置
 */
public class HeadingSettings {
    /**
     * 可关闭标题配置
     * 当标题以 ## 结尾时（如 ## Section ##），该标题及其下所有内容将被移除
     * 默认启用
     */
    public var closable: Bool = true
    
    /**
     * 编号配置
     */
    public var number: HeadingNumberSettings = HeadingNumberSettings()
}

/**
 * 标题编号详细配置
 */
public class HeadingNumberSettings {
    /**
     * 是否启用编号
     */
    public var enabled: Bool = false
    
    /**
     * 标题编号重置策略
     * - "never": 从不重置，跨所有文件连续编号
     * - "directory": 在切换目录时重置编号
     * - "always": 每个文件都重置编号
     */
    public var resetFor: String = "always"
    
    /**
     * 编号起始值（6个级别）
     */
    public var startFrom: Array<Int> = [1, 1, 1, 1, 1, 1]
}

/**
 * Summary 设置
 */
public class SummarySettings {
    /**
     * Summary 文件名
     */
    public var file: String = "markit.md"
    
    /**
     * 是否显示草稿章节
     */
    public var showDrafts: Bool = true
}

/**
 * 章节导航设置
 */
public class ChapterSettings {
    /**
     * 是否启用章节导航（上一篇/下一篇）
     */
    public var navigation: Bool = false
    
    /**
     * "上一篇"的文本
     */
    public var prevText: String = "Previous"
    
    /**
     * "下一篇"的文本
     */
    public var nextText: String = "Next"
}

/**
 * 文章统计设置
 */
public class StatisticSettings {
    /**
     * 是否显示总字数
     */
    public var totalTexts: Bool = false
    
    /**
     * 总字数模板，{total}会被替换为实际字数
     */
    public var totalTextsTemplate: String = "{total} words"
    
    /**
     * 是否显示预计阅读时间
     */
    public var spentTime: Bool = false
    
    /**
     * 预计阅读时间模板，{total}会被替换为时间数字，{unit}会被替换为单位
     */
    public var spentTimeTemplate: String = "{total} {unit} read"
    
    /**
     * 秒的单位文本
     */
    public var second: String = "sec"
    
    /**
     * 分钟的单位文本
     */
    public var minute: String = "min"
}

/**
 * Git 设置
 */
public class GitSettings {
    /**
     * Git 仓库前缀 URL
     */
    public var prefix: String = ""
}

/**
 * 代码仓库链接设置
 */
public class ReposSettings {
    /**
     * GitHub 仓库地址
     */
    public var github: String = ""

    /**
     * GitCode 仓库地址
     */
    public var gitcode: String = ""

    /**
     * Gitee 仓库地址
     */
    public var gitee: String = ""

    /**
     * GitLab 仓库地址
     */
    public var gitlab: String = ""
}

/**
 * 静态资源设置
 */
public class AssetsSettings {
    /**
     * JavaScript 文件列表（支持 http://, https:// 和相对路径）
     */
    public var scripts: Array<String> = []
    
    /**
     * CSS 文件列表（支持 http://, https:// 和相对路径）
     */
    public var styles: Array<String> = []
}

/**
 * 代码块设置
 */
public class CodeBlockSettings {
    /**
     * 是否启用代码块分组功能（默认禁用）
     */
    public var group: Bool = false

    /**
     * 是否启用 codehl 构建期高亮。
     */
    public var enabled: Bool = true

    /**
     * 代码高亮单主题名称。设置后 light/dark 都使用同一 codehl 主题。
     */
    public var theme: String = ""

    /**
     * 代码高亮浅色主题名称。
     */
    public var lightTheme: String = "light-plus"

    /**
     * 代码高亮深色主题名称。
     */
    public var darkTheme: String = "dark-plus"

    /**
     * 额外 grammar 搜索目录，按配置顺序优先于内置目录。
     */
    public var grammarDirs: Array<String> = []

    /**
     * 额外主题搜索目录，按配置顺序优先于内置目录。
     */
    public var themeDirs: Array<String> = []

    /**
     * 用户注册的语言。
     */
    public var languages: Array<LanguageRegistration> = []

    /**
     * 用户注册的语言别名。
     */
    public var aliases: Array<LanguageAlias> = []

    /**
     * 是否为代码块自动生成锚点
     */
    public var autoAnchor: Bool = false
}

/**
 * 列表设置
 */
public class ListSettings {
    /**
     * 是否为列表项自动生成锚点
     */
    public var autoAnchor: Bool = false

    /**
     * 有序列表配置
     */
    public var orderedList: OrderedListSettings = OrderedListSettings()
}

/**
 * 数学公式设置
 */
public class MathSettings {
    /**
     * 是否为块级数学公式自动生成锚点
     */
    public var autoAnchor: Bool = false
}

/**
 * 表格设置
 */
public class TableSettings {
    /**
     * 是否启用三线表语法
     */
    public var threeLine: Bool = false

    /**
     * 是否为表格自动生成锚点
     */
    public var autoAnchor: Bool = false
}

/**
 * 通用块级元素设置
 */
public class BlockSettings {
    /**
     * 是否为段落、引用、分隔线等通用块级元素自动生成锚点
     */
    public var autoAnchor: Bool = false
}

/**
 * 有序列表设置
 */
public class OrderedListSettings {
    /**
     * 是否启用多层级有序列表样式
     * 启用后：第一层显示阿拉伯数字，第二层显示阿拉伯数字，第三层显示英文字母
     * 默认启用
     */
    public var multiLevel: Bool = true
}

/**
 * PDF 页边距设置
 */
public class PdfMarginSettings {
    /**
     * 上边距（如 "1cm", "0.5in"）
     */
    public var top: String = "1cm"

    /**
     * 右边距
     */
    public var right: String = "1cm"

    /**
     * 下边距
     */
    public var bottom: String = "1cm"

    /**
     * 左边距
     */
    public var left: String = "1cm"
}

/**
 * PDF 生成设置
 */
public class PdfSettings {
    /**
     * 纸张格式
     */
    public var format: String = "A4"

    /**
     * 页边距设置
     */
    public var margin: PdfMarginSettings = PdfMarginSettings()

    /**
     * 是否横向打印
     */
    public var landscape: Bool = false

    /**
     * 是否打印背景图形
     */
    public var printBackground: Bool = true

    /**
     * 缩放比例（0.1-2.0）
     */
    public var scale: Float64 = 1.0

    /**
     * 是否显示页眉页脚
     */
    public var displayHeaderFooter: Bool = false

    /**
     * 页眉模板（HTML）
     */
    public var headerTemplate: String = ""

    /**
     * 页脚模板（HTML）
     */
    public var footerTemplate: String = ""

    /**
     * 页面加载超时时间（毫秒）
     */
    public var timeout: Int64 = 100000

    /**
     * 是否生成带标签的 PDF（可访问性，会增大文件）
     */
    public var tagged: Bool = false

    /**
     * 是否生成 PDF 大纲/书签（会增大文件）
     */
    public var outline: Bool = false

    /**
     * Typst 专用配置
     */
    public var typst: PdfTypstSettings = PdfTypstSettings()

    /**
     * 将 PDF 设置转换为命令行参数数组
     */
    public func toArgs(): Array<String> {
        let args = ArrayList<String>()

        args.add("--format=${format}")

        // 页边距
        if (margin.top == margin.right &&
            margin.top == margin.bottom &&
            margin.top == margin.left) {
            args.add("--margin=${margin.top}")
        } else {
            args.add("--margin-top=${margin.top}")
            args.add("--margin-right=${margin.right}")
            args.add("--margin-bottom=${margin.bottom}")
            args.add("--margin-left=${margin.left}")
        }

        if (landscape) {
            args.add("--landscape")
        }
        if (!printBackground) {
            args.add("--no-background")
        }
        if (scale != 1.0) {
            args.add("--scale=${scale}")
        }
        if (timeout != 100000) {
            args.add("--timeout=${timeout}")
        }
        if (displayHeaderFooter) {
            args.add("--header-footer")
        }
        if (tagged) {
            args.add("--tagged")
        }
        if (outline) {
            args.add("--outline")
        }

        return args.toArray()
    }
}

/**
 * Typst 代码高亮设置
 */
public class PdfTypstCodeSettings {
    /**
     * 是否启用仓库内置的 Typst syntax 定义
     */
    public var useBundledSyntaxes: Bool = true

    /**
     * 是否启用仓库内置的 Typst 代码主题
     */
    public var useBundledTheme: Bool = true

    /**
     * 额外的 syntax 文件路径（相对于输出目录）
     */
    public var syntaxes: Array<String> = []

    /**
     * 自定义主题文件路径（相对于输出目录）
     */
    public var theme: String = ""

    /**
     * 是否启用代码字体连字
     */
    public var ligatures: Bool = false
}

/**
 * Typst 页码设置
 */
public class PdfTypstPageNumberSettings {
    /**
     * 是否显示页码
     */
    public var enabled: Bool = true

    /**
     * 页码显示位置：header 或 footer
     */
    public var position: String = "footer"

    /**
     * 页码对齐方式：left / center / right
     */
    public var align: String = "right"
}

/**
 * Typst 目录设置
 */
public class PdfTypstTocSettings {
    /**
     * 目录最大级别
     */
    public var maxLevel: Int64 = 3
}

/**
 * Typst 封面设置
 */
public class PdfTypstCoverSettings {
    /**
     * 是否启用封面模板
     */
    public var enabled: Bool = false

    /**
     * Logo 路径（相对于输出目录）
     */
    public var logo: String = ""

    /**
     * 主标题
     */
    public var title: String = ""

    /**
     * 副标题
     */
    public var subtitle: String = ""

    /**
     * 作者列表
     */
    public var authors: Array<String> = []

    /**
     * 版本号
     */
    public var version: String = ""

    /**
     * 机构
     */
    public var organization: String = ""

    /**
     * 子机构
     */
    public var suborganization: String = ""
}

/**
 * Typst PDF 设置
 */
public class PdfTypstSettings {
    /**
     * Typst 代码块设置
     */
    public var code: PdfTypstCodeSettings = PdfTypstCodeSettings()

    /**
     * Typst 页码设置
     */
    public var pageNumber: PdfTypstPageNumberSettings = PdfTypstPageNumberSettings()

    /**
     * Typst 目录设置
     */
    public var toc: PdfTypstTocSettings = PdfTypstTocSettings()

    /**
     * Typst 封面设置
     */
    public var cover: PdfTypstCoverSettings = PdfTypstCoverSettings()
}

/**
 * 网站代码设置
 */
public class WebsiteCodeSettings {
    /**
     * 是否启用代码字体连字
     */
    public var ligatures: Bool = false
}

/**
 * 网站输出设置
 */
public class WebsiteSettings {
    /**
     * 网站代码设置
     */
    public var code: WebsiteCodeSettings = WebsiteCodeSettings()

    /**
     * 章节导航配置
     */
    public var chapter: ChapterSettings = ChapterSettings()

    /**
     * 文章统计配置
     */
    public var statistic: StatisticSettings = StatisticSettings()

    /**
     * Git 配置
     */
    public var git: GitSettings = GitSettings()

    /**
     * 代码仓库链接配置
     */
    public var repos: ReposSettings = ReposSettings()

    /**
     * 静态资源配置
     */
    public var assets: AssetsSettings = AssetsSettings()
}

public enum ConfigLoadResult {
    | Success(MarkitConfig)
    | Error(String)
    
    public static func success(config: MarkitConfig): ConfigLoadResult {
        return ConfigLoadResult.Success(config)
    }
    
    public static func error(message: String): ConfigLoadResult {
        return ConfigLoadResult.Error(message)
    }
    
    public func isSuccess(): Bool {
        match (this) {
            case Success(_) => true
            case Error(_) => false
        }
    }
    
    public func getConfig(): ?MarkitConfig {
        match (this) {
            case Success(config) => Some(config)
            case Error(_) => None
        }
    }
    
    public func getErrorMessage(): ?String {
        match (this) {
            case Success(_) => None
            case Error(message) => Some(message)
        }
    }
    
    /**
     * 验证配置并返回验证后的配置
     * 如果验证失败，打印错误信息并返回 None
     * 
     * @param configPath 配置文件路径（用于显示）
     * @param printInfo 是否打印配置信息（默认为 true）
     * @return 验证成功返回配置，失败返回 None
     */
    public func validateAndGet(configPath!: ?String = None, printInfo!: Bool = true): ?MarkitConfig {
        match (this) {
            case Success(cfg) => 
                let validationResult = cfg.validate()
                match (validationResult) {
                    case ConfigValidationResult.Success => 
                        if (printInfo) {
                            match (configPath) {
                                case Some(path) => 
                                    KitHooks.success("Configuration loaded: ${path}")
                                case None => 
                                    KitHooks.success("Using default configuration")
                            }
                            
                            // 打印配置信息表格
                            printConfigTable(cfg)
                            KitHooks.newLine()
                        }
                        
                        Some(cfg)
                    case ConfigValidationResult.Error(errors) =>
                        KitHooks.err("Configuration validation failed:")
                        for (error in errors) {
                            KitHooks.plain("   - ${error}")
                        }
                        None
                }
            case Error(message) =>
                KitHooks.err(message)
                None
        }
    }
    
    /**
     * 打印配置信息表格
     */
    private func printConfigTable(cfg: MarkitConfig) {
        // 准备表格数据
        let labels = ["Output", "I18n", "Code Group", "Theme"]
        let themeValue = cfg.theme
        let codeGroupValue = if (cfg.codeBlock.group) { "Yes" } else { "No" }
        let values = [
            cfg.outputType,
            "${cfg.i18n.default} -> ${cfg.i18n.target}",
            codeGroupValue,
            themeValue,
        ]
        
        // 计算每列宽度（考虑 emoji 的显示宽度）
        var colWidths = ArrayList<Int64>()
        for (i in 0..labels.size) {
            // 对于包含 emoji 的字符串，需要计算实际显示长度
            let valueDisplayLength = values[i].toRuneArray().size
            let maxWidth = if (labels[i].size > valueDisplayLength) { labels[i].toRuneArray().size } else { valueDisplayLength }
            colWidths.add(maxWidth)
        }
        
        // 构建表格行
        var labelRow = "| "
        var valueRow = "| "
        var separatorRow = "|-"
        
        for (i in 0..labels.size) {
            let width = colWidths[i]
            let labelPadding = width - labels[i].size
            // 使用 rune 数组长度计算实际显示长度
            let valueDisplayLength = values[i].toRuneArray().size
            let valuePadding = width - valueDisplayLength
            
            // 表头行（加粗）
            labelRow += KitHooks.color(labels[i], "bold")
            for (_ in 0..labelPadding) {
                labelRow += " "
            }
            labelRow += " | "
            
            // 分隔行
            for (_ in 0..width) {
                separatorRow += "-"
            }
            separatorRow += "-|-"
            
            // 数据行
            valueRow += values[i]
            for (_ in 0..valuePadding) {
                valueRow += " "
            }
            valueRow += " | "
        }
        
        // 移除最后多余的 "|-"
        separatorRow = separatorRow[..separatorRow.size - 2] + "-"
        
        KitHooks.newLine()
        KitHooks.plain("📋 Configuration:")
        KitHooks.plain(labelRow)
        KitHooks.plain(separatorRow)
        KitHooks.plain(valueRow)
    }
}

/**
 * 配置验证结果
 */
public enum ConfigValidationResult {
    | Success
    | Error(Array<String>)
    
    public static func success(): ConfigValidationResult {
        return ConfigValidationResult.Success
    }
    
    public static func error(errors: Array<String>): ConfigValidationResult {
        return ConfigValidationResult.Error(errors)
    }
    
    public func isSuccess(): Bool {
        match (this) {
            case Success => true
            case Error(_) => false
        }
    }
    
    public func getErrors(): Array<String> {
        match (this) {
            case Success => []
            case Error(errors) => errors
        }
    }
}
