package markit_kit.config

import markit_kit.utils.KitHooks

import codehl.{LanguageAlias, LanguageRegistration}
import seajson.*
import markit_kit.utils.JsonUtils
import std.fs.{Path, exists, FileInfo, File}
import std.collection.{ArrayList, HashSet}

/**
 * 配置文件加载器
 *
 * 负责加载和解析 markit.json 配置文件
 * 支持从指定路径或自动检测路径加载配置
 */
public class ConfigLoader {

    /**
     * 从指定路径加载配置文件
     *
     * @param configPath 配置文件路径
     * @return 配置加载结果（包含路径信息）
     */
    public static func loadConfig(configPath: String): (ConfigLoadResult, ?String) {
        try {
            if (!exists(Path(configPath))) {
                return (ConfigLoadResult.error("配置文件不存在: ${configPath}"), None)
            }

            let content = String.fromUtf8(File.readFrom(configPath))
            let jsonObject = parseJson(content)

            let config = parseConfig(jsonObject)

            return (ConfigLoadResult.success(config), Some(configPath))
        } catch (e: Exception) {
            return (ConfigLoadResult.error("加载配置文件失败: ${e.message}"), None)
        }
    }

    /**
     * 自动检测并加载配置文件
     *
     * 检测顺序：
     * 1. 如果输入是文件，检查文件同目录下的 markit.json
     * 2. 如果输入是目录，检查目录下的 markit.json
     *
     * @param inputPath 输入路径（文件或目录）
     * @return 配置加载结果（包含路径信息），如果没有找到配置文件则返回默认配置
     */
    public static func autoLoadConfig(inputPath: String): (ConfigLoadResult, ?String) {
        let inputPathObj = Path(inputPath)

        // 确定配置文件路径
        let configPath = if (exists(inputPathObj) && !FileInfo(inputPathObj).isDirectory()) {
            // 输入是文件，检查文件同目录
            let parentPath = inputPathObj.parent
            parentPath.join("markit.json").toString()
        } else {
            // 输入是目录，检查目录下
            inputPathObj.join("markit.json").toString()
        }

        if (exists(Path(configPath))) {
            return loadConfig(configPath)
        } else {
            // 没有找到配置文件，返回默认配置
            return (ConfigLoadResult.success(MarkitConfig()), None)
        }
    }

    /**
     * 检查 JSON 对象中是否有未知的 key，如果有则打印警告
     *
     * @param obj JSON 对象
     * @param knownKeys 已知的 key 集合
     * @param path 配置路径前缀（用于显示，如 "pdf"、"pdf.margin"）
     */
    private static func warnUnknownKeys(obj: JsonValue, knownKeys: HashSet<String>, path: String) {
        match (obj) {
            case JsonObjVal(_) =>
                let keys = jsonKeys(obj)
                for (key in keys) {
                    if (!knownKeys.contains(key)) {
                        if (path.isEmpty()) {
                            KitHooks.warn("Unknown config option '${key}'")
                        } else {
                            KitHooks.warn("Unknown config option '${path}.${key}'")
                        }
                    }
                }
            case _ => ()
        }
    }

    /**
     * 解析配置 JSON 对象
     * 使用 JsonUtils 辅助函数和 ?. 操作符简化字段提取
     *
     * @param jsonObject JSON 配置对象
     * @return 解析后的配置对象
     */
    private static func parseConfig(jsonObject: JsonValue): MarkitConfig {
        let config = MarkitConfig()

        // 检查顶层未知 key
        let topLevelKeys = HashSet<String>(
            ["title", "theme", "format", "type", "toc", "codeBlock", "list", "math", "table", "i18n", "heading", "summary",
                "block", "pdf", "website"])
        warnUnknownKeys(jsonObject, topLevelKeys, "")

        config.title = jsonFieldString(jsonObject, "title") ?? config.title
        config.theme = jsonFieldString(jsonObject, "theme") ?? config.theme
        config.outputType = jsonFieldString(jsonObject, "format") ?? jsonFieldString(jsonObject, "type") ?? config
            .outputType
        config.toc = jsonFieldBool(jsonObject, "toc") ?? config.toc

        // 解析 codeBlock 配置
        if (let Some(codeBlockObj) <- jsonFieldObj(jsonObject, "codeBlock")) {
            warnUnknownKeys(
                codeBlockObj,
                HashSet<String>(["group", "enabled", "theme", "lightTheme", "darkTheme", "grammarDirs", "themeDirs", "languages", "aliases", "autoAnchor"]),
                "codeBlock"
            )
            config.codeBlock.group = jsonFieldBool(codeBlockObj, "group") ?? config.codeBlock.group
            config.codeBlock.enabled = jsonFieldBool(codeBlockObj, "enabled") ?? config.codeBlock.enabled
            config.codeBlock.theme = jsonFieldString(codeBlockObj, "theme") ?? config.codeBlock.theme
            config.codeBlock.lightTheme = jsonFieldString(codeBlockObj, "lightTheme") ?? config.codeBlock.lightTheme
            config.codeBlock.darkTheme = jsonFieldString(codeBlockObj, "darkTheme") ?? config.codeBlock.darkTheme
            config.codeBlock.autoAnchor = jsonFieldBool(codeBlockObj, "autoAnchor") ?? config.codeBlock.autoAnchor
            if (let Some(grammarDirs) <- JsonUtils.fieldStringArray(codeBlockObj, "grammarDirs")) {
                config.codeBlock.grammarDirs = grammarDirs
            }
            if (let Some(themeDirs) <- JsonUtils.fieldStringArray(codeBlockObj, "themeDirs")) {
                config.codeBlock.themeDirs = themeDirs
            }
            config.codeBlock.languages = parseCodeBlockLanguages(codeBlockObj)
            config.codeBlock.aliases = parseCodeBlockAliases(codeBlockObj)
        }

        // 解析 list 配置
        if (let Some(listObj) <- jsonFieldObj(jsonObject, "list")) {
            warnUnknownKeys(listObj, HashSet<String>(["orderedList", "autoAnchor"]), "list")
            config.list.autoAnchor = jsonFieldBool(listObj, "autoAnchor") ?? config.list.autoAnchor
            if (let Some(orderedListObj) <- jsonFieldObj(listObj, "orderedList")) {
                warnUnknownKeys(orderedListObj, HashSet<String>(["multiLevel"]), "list.orderedList")
                config.list.orderedList.multiLevel = jsonFieldBool(orderedListObj, "multiLevel") ?? config
                    .list
                    .orderedList
                    .multiLevel
            }
        }

        // 解析 math 配置
        if (let Some(mathObj) <- jsonFieldObj(jsonObject, "math")) {
            warnUnknownKeys(mathObj, HashSet<String>(["autoAnchor"]), "math")
            config.math.autoAnchor = jsonFieldBool(mathObj, "autoAnchor") ?? config.math.autoAnchor
        }

        // 解析 table 配置
        if (let Some(tableObj) <- jsonFieldObj(jsonObject, "table")) {
            warnUnknownKeys(tableObj, HashSet<String>(["threeLine", "autoAnchor"]), "table")
            config.table.threeLine = jsonFieldBool(tableObj, "threeLine") ?? config.table.threeLine
            config.table.autoAnchor = jsonFieldBool(tableObj, "autoAnchor") ?? config.table.autoAnchor
        }

        // 解析 block 配置
        if (let Some(blockObj) <- jsonFieldObj(jsonObject, "block")) {
            warnUnknownKeys(blockObj, HashSet<String>(["autoAnchor"]), "block")
            config.block.autoAnchor = jsonFieldBool(blockObj, "autoAnchor") ?? config.block.autoAnchor
        }

        // 解析 i18n 配置
        if (let Some(i18nObj) <- jsonFieldObj(jsonObject, "i18n")) {
            warnUnknownKeys(i18nObj, HashSet<String>(["default", "target", "route_prefix", "home", "documentation"]),
                "i18n")
            config.i18n.default = jsonFieldString(i18nObj, "default") ?? config.i18n.default
            config.i18n.target = jsonFieldString(i18nObj, "target") ?? config.i18n.target
            config.i18n.routePrefix = jsonFieldString(i18nObj, "route_prefix") ?? config.i18n.routePrefix
            config.i18n.home = jsonFieldString(i18nObj, "home") ?? config.i18n.home
            config.i18n.documentation = jsonFieldString(i18nObj, "documentation") ?? config.i18n.documentation
        }

        // 解析 heading 配置
        if (let Some(headingObj) <- jsonFieldObj(jsonObject, "heading")) {
            warnUnknownKeys(headingObj, HashSet<String>(["closable", "number"]), "heading")
            config.heading.closable = jsonFieldBool(headingObj, "closable") ?? config.heading.closable

            if (let Some(numberObj) <- jsonFieldObj(headingObj, "number")) {
                warnUnknownKeys(numberObj, HashSet<String>(["enabled", "resetFor", "startFrom"]), "heading.number")
                config.heading.number.enabled = jsonFieldBool(numberObj, "enabled") ?? config.heading.number.enabled

                if (let Some(resetFor) <- jsonFieldString(numberObj, "resetFor")) {
                    if (resetFor == "never" || resetFor == "directory" || resetFor == "always") {
                        config.heading.number.resetFor = resetFor
                    } else {
                        KitHooks.warn("Invalid resetFor value '${resetFor}', using default 'always'")
                    }
                }

                if (let Some(arr) <- JsonUtils.fieldIntArray(numberObj, "startFrom")) {
                    if (arr.size == 6) {
                        config.heading.number.startFrom = arr
                    }
                }
            }
        }

        // 解析 summary 配置
        if (let Some(summaryObj) <- jsonFieldObj(jsonObject, "summary")) {
            warnUnknownKeys(summaryObj, HashSet<String>(["file", "showDrafts"]), "summary")
            config.summary.file = jsonFieldString(summaryObj, "file") ?? config.summary.file
            config.summary.showDrafts = jsonFieldBool(summaryObj, "showDrafts") ?? config.summary.showDrafts
        }

        // 解析 pdf 配置
        if (let Some(pdfObj) <- jsonFieldObj(jsonObject, "pdf")) {
            warnUnknownKeys(pdfObj,
                HashSet<String>(
                    ["format", "landscape", "printBackground", "scale", "displayHeaderFooter", "headerTemplate",
                        "footerTemplate", "timeout", "tagged", "outline", "margin", "typst"]), "pdf")
            config.pdf.format = jsonFieldString(pdfObj, "format") ?? config.pdf.format
            config.pdf.landscape = jsonFieldBool(pdfObj, "landscape") ?? config.pdf.landscape
            config.pdf.printBackground = jsonFieldBool(pdfObj, "printBackground") ?? config.pdf.printBackground
            if (let Some(scaleValue) <- jsonField(pdfObj, "scale")) {
                config.pdf.scale = jsonAsFloat(scaleValue) ?? config.pdf.scale
            }
            config.pdf.displayHeaderFooter = jsonFieldBool(pdfObj, "displayHeaderFooter") ?? config
                .pdf
                .displayHeaderFooter
            config.pdf.headerTemplate = jsonFieldString(pdfObj, "headerTemplate") ?? config.pdf.headerTemplate
            config.pdf.footerTemplate = jsonFieldString(pdfObj, "footerTemplate") ?? config.pdf.footerTemplate
            config.pdf.timeout = jsonFieldInt(pdfObj, "timeout") ?? config.pdf.timeout
            config.pdf.tagged = jsonFieldBool(pdfObj, "tagged") ?? config.pdf.tagged
            config.pdf.outline = jsonFieldBool(pdfObj, "outline") ?? config.pdf.outline

            if (let Some(marginObj) <- jsonFieldObj(pdfObj, "margin")) {
                warnUnknownKeys(marginObj, HashSet<String>(["top", "right", "bottom", "left"]), "pdf.margin")
                config.pdf.margin.top = jsonFieldString(marginObj, "top") ?? config.pdf.margin.top
                config.pdf.margin.right = jsonFieldString(marginObj, "right") ?? config.pdf.margin.right
                config.pdf.margin.bottom = jsonFieldString(marginObj, "bottom") ?? config.pdf.margin.bottom
                config.pdf.margin.left = jsonFieldString(marginObj, "left") ?? config.pdf.margin.left
            }

            if (let Some(typstObj) <- jsonFieldObj(pdfObj, "typst")) {
                warnUnknownKeys(typstObj, HashSet<String>(["code", "pageNumber", "cover", "toc"]), "pdf.typst")

                if (let Some(codeObj) <- jsonFieldObj(typstObj, "code")) {
                    warnUnknownKeys(codeObj,
                        HashSet<String>(["useBundledSyntaxes", "useBundledTheme", "syntaxes", "theme", "ligatures"]),
                        "pdf.typst.code")
                    config.pdf.typst.code.useBundledSyntaxes = jsonFieldBool(codeObj, "useBundledSyntaxes") ?? config
                        .pdf
                        .typst
                        .code
                        .useBundledSyntaxes
                    config.pdf.typst.code.useBundledTheme = jsonFieldBool(codeObj, "useBundledTheme") ?? config
                        .pdf
                        .typst
                        .code
                        .useBundledTheme
                    config.pdf.typst.code.theme = jsonFieldString(codeObj, "theme") ?? config.pdf.typst.code.theme
                    config.pdf.typst.code.ligatures = jsonFieldBool(codeObj, "ligatures") ?? config
                        .pdf
                        .typst
                        .code
                        .ligatures

                    if (let Some(syntaxes) <- JsonUtils.fieldStringArray(codeObj, "syntaxes")) {
                        config.pdf.typst.code.syntaxes = syntaxes
                    }
                }

                if (let Some(pageNumberObj) <- jsonFieldObj(typstObj, "pageNumber")) {
                    warnUnknownKeys(pageNumberObj, HashSet<String>(["enabled", "position", "align"]),
                        "pdf.typst.pageNumber")
                    config.pdf.typst.pageNumber.enabled = jsonFieldBool(pageNumberObj, "enabled") ?? config
                        .pdf
                        .typst
                        .pageNumber
                        .enabled
                    config.pdf.typst.pageNumber.position = jsonFieldString(pageNumberObj, "position") ?? config
                        .pdf
                        .typst
                        .pageNumber
                        .position
                    config.pdf.typst.pageNumber.align = jsonFieldString(pageNumberObj, "align") ?? config
                        .pdf
                        .typst
                        .pageNumber
                        .align
                }

                if (let Some(tocObj) <- jsonFieldObj(typstObj, "toc")) {
                    warnUnknownKeys(tocObj, HashSet<String>(["maxLevel"]), "pdf.typst.toc")
                    config.pdf.typst.toc.maxLevel = jsonFieldInt(tocObj, "maxLevel") ?? config.pdf.typst.toc.maxLevel
                }

                if (let Some(coverObj) <- jsonFieldObj(typstObj, "cover")) {
                    warnUnknownKeys(coverObj,
                        HashSet<String>(
                            ["enabled", "logo", "title", "subtitle", "authors", "version", "organization",
                                "suborganization"]), "pdf.typst.cover")
                    config.pdf.typst.cover.enabled = jsonFieldBool(coverObj, "enabled") ?? config
                        .pdf
                        .typst
                        .cover
                        .enabled
                    config.pdf.typst.cover.logo = jsonFieldString(coverObj, "logo") ?? config.pdf.typst.cover.logo
                    config.pdf.typst.cover.title = jsonFieldString(coverObj, "title") ?? config.pdf.typst.cover.title
                    config.pdf.typst.cover.subtitle = jsonFieldString(coverObj, "subtitle") ?? config
                        .pdf
                        .typst
                        .cover
                        .subtitle
                    config.pdf.typst.cover.version = jsonFieldString(coverObj, "version") ?? config
                        .pdf
                        .typst
                        .cover
                        .version
                    config.pdf.typst.cover.organization = jsonFieldString(coverObj, "organization") ?? config
                        .pdf
                        .typst
                        .cover
                        .organization
                    config.pdf.typst.cover.suborganization = jsonFieldString(coverObj, "suborganization") ?? config
                        .pdf
                        .typst
                        .cover
                        .suborganization

                    if (let Some(authors) <- JsonUtils.fieldStringArray(coverObj, "authors")) {
                        config.pdf.typst.cover.authors = authors
                    }
                }
            }
        }

        // 解析 website 配置
        if (let Some(websiteObj) <- jsonFieldObj(jsonObject, "website")) {
            warnUnknownKeys(websiteObj,
                HashSet<String>(["code", "chapter", "statistic", "git", "repos", "assets"]), "website")

            if (let Some(codeObj) <- jsonFieldObj(websiteObj, "code")) {
                warnUnknownKeys(codeObj, HashSet<String>(["ligatures"]), "website.code")
                config.website.code.ligatures = jsonFieldBool(codeObj, "ligatures") ?? config
                    .website
                    .code
                    .ligatures
            }

            if (let Some(chapterObj) <- jsonFieldObj(websiteObj, "chapter")) {
                warnUnknownKeys(chapterObj, HashSet<String>(["navigation", "prevText", "nextText"]),
                    "website.chapter")
                config.website.chapter.navigation = jsonFieldBool(chapterObj, "navigation") ?? config
                    .website.chapter.navigation
                config.website.chapter.prevText = jsonFieldString(chapterObj, "prevText") ?? config
                    .website.chapter.prevText
                config.website.chapter.nextText = jsonFieldString(chapterObj, "nextText") ?? config
                    .website.chapter.nextText
            }

            if (let Some(statisticObj) <- jsonFieldObj(websiteObj, "statistic")) {
                warnUnknownKeys(statisticObj,
                    HashSet<String>(["totalTexts", "totalTextsTemplate", "spentTime", "spentTimeTemplate",
                        "second", "minute"]), "website.statistic")
                config.website.statistic.totalTexts = jsonFieldBool(statisticObj, "totalTexts") ?? config
                    .website.statistic.totalTexts
                config.website.statistic.totalTextsTemplate = jsonFieldString(statisticObj, "totalTextsTemplate") ?? config
                    .website.statistic.totalTextsTemplate
                config.website.statistic.spentTime = jsonFieldBool(statisticObj, "spentTime") ?? config
                    .website.statistic.spentTime
                config.website.statistic.spentTimeTemplate = jsonFieldString(statisticObj, "spentTimeTemplate") ?? config
                    .website.statistic.spentTimeTemplate
                config.website.statistic.second = jsonFieldString(statisticObj, "second") ?? config
                    .website.statistic.second
                config.website.statistic.minute = jsonFieldString(statisticObj, "minute") ?? config
                    .website.statistic.minute
            }

            if (let Some(gitObj) <- jsonFieldObj(websiteObj, "git")) {
                warnUnknownKeys(gitObj, HashSet<String>(["prefix"]), "website.git")
                config.website.git.prefix = jsonFieldString(gitObj, "prefix") ?? config.website.git.prefix
            }

            if (let Some(reposObj) <- jsonFieldObj(websiteObj, "repos")) {
                warnUnknownKeys(reposObj, HashSet<String>(["github", "gitcode", "gitee", "gitlab"]),
                    "website.repos")
                config.website.repos.github = jsonFieldString(reposObj, "github") ?? config.website.repos.github
                config.website.repos.gitcode = jsonFieldString(reposObj, "gitcode") ?? config.website.repos.gitcode
                config.website.repos.gitee = jsonFieldString(reposObj, "gitee") ?? config.website.repos.gitee
                config.website.repos.gitlab = jsonFieldString(reposObj, "gitlab") ?? config.website.repos.gitlab
            }

            if (let Some(assetsObj) <- jsonFieldObj(websiteObj, "assets")) {
                warnUnknownKeys(assetsObj, HashSet<String>(["scripts", "styles"]), "website.assets")
                if (let Some(scriptsArray) <- JsonUtils.fieldStringArray(assetsObj, "scripts")) {
                    config.website.assets.scripts = scriptsArray
                }
                if (let Some(stylesArray) <- JsonUtils.fieldStringArray(assetsObj, "styles")) {
                    config.website.assets.styles = stylesArray
                }
            }
        }

        return config
    }

    private static func parseCodeBlockLanguages(codeBlockObj: JsonValue): Array<LanguageRegistration> {
        let out = ArrayList<LanguageRegistration>()
        match (jsonField(codeBlockObj, "languages")) {
            case Some(languagesObj) =>
                match (languagesObj) {
                    case JsonObjVal(_) =>
                        for (language in jsonKeys(languagesObj)) {
                            let normalizedLanguage = language.trimAscii()
                            if (normalizedLanguage.isEmpty()) {
                                continue
                            }
                            appendCodeBlockLanguage(out, languagesObj, language, normalizedLanguage)
                        }
                    case _ =>
                        KitHooks.warn("Invalid codeBlock.languages; expected object")
                }
            case None => ()
        }
        return out.toArray()
    }

    private static func appendCodeBlockLanguage(
        out: ArrayList<LanguageRegistration>,
        languagesObj: JsonValue,
        language: String,
        normalizedLanguage: String
    ): Unit {
        match (jsonField(languagesObj, language)) {
            case Some(JsonStrVal(grammar)) =>
                if (!grammar.trimAscii().isEmpty()) {
                    out.add(LanguageRegistration(normalizedLanguage, grammar.trimAscii()))
                }
            case Some(languageObj) =>
                match (languageObj) {
                    case JsonObjVal(_) =>
                        warnUnknownKeys(languageObj, HashSet<String>(["grammar", "aliases"]), "codeBlock.languages.${language}")
                        let grammar = jsonFieldString(languageObj, "grammar") ?? ""
                        if (grammar.trimAscii().isEmpty()) {
                            return
                        }
                        let aliases = JsonUtils.fieldStringArray(languageObj, "aliases") ?? []
                        out.add(LanguageRegistration(normalizedLanguage, grammar.trimAscii(), aliases: aliases))
                    case _ =>
                        KitHooks.warn("Invalid codeBlock.languages.${language}; expected string or object")
                }
            case None => ()
        }
    }

    private static func parseCodeBlockAliases(codeBlockObj: JsonValue): Array<LanguageAlias> {
        let out = ArrayList<LanguageAlias>()
        match (jsonField(codeBlockObj, "aliases")) {
            case Some(aliasesObj) =>
                match (aliasesObj) {
                    case JsonObjVal(_) =>
                        for (alias in jsonKeys(aliasesObj)) {
                            match (jsonFieldString(aliasesObj, alias)) {
                                case Some(language) =>
                                    if (!alias.trimAscii().isEmpty() && !language.trimAscii().isEmpty()) {
                                        out.add(LanguageAlias(alias.trimAscii(), language.trimAscii()))
                                    }
                                case None =>
                                    KitHooks.warn("Invalid codeBlock.aliases.${alias}; expected string")
                            }
                        }
                    case _ =>
                        KitHooks.warn("Invalid codeBlock.aliases; expected object")
                }
            case None => ()
        }
        return out.toArray()
    }
}
