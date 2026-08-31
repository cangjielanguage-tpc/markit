package markit_kit.generators

import markit_kit.config.MarkitConfig
import markit_kit.utils.ResourceResolver
import std.collection.ArrayList
import std.fs.*
import seajson.buildJsonArray

/**
 * Landing Page Generator
 *
 * 生成根目录的 index.html 文件，支持自动语言检测和重定向
 */
public class LandingPageGenerator {
    /**
     * 生成 Landing Page HTML
     *
     * @param configs 配置文件数组
     * @return Landing Page HTML 内容
     */
    public static func generate(configs: Array<MarkitConfig>): String {
        // 提取所有语言代码
        let languages = ArrayList<String>()
        for (config in configs) {
            languages.add(config.i18n.target)
        }

        let siteTitle = configs[0].title
        let defaultLanguage = languages[0] // 使用第一个语言作为后备

        // 读取模板文件
        let templatePath = ResourceResolver.resolveResourcePath("assets/templates/landing_page.html")
        let templateBytes = File.readFrom(templatePath)
        let template = String.fromUtf8(templateBytes)

        // 构建语言数组的 JSON 字符串
        let languagesJson = buildJsonArray {
            w =>
                for (lang in languages) {
                    w.value(lang)
                }
                w
        }

        // 替换占位符
        var result = template
        result = result.replace("{{SITE_TITLE}}", siteTitle)
        result = result.replace("{{LANGUAGES_JSON}}", languagesJson)
        result = result.replace("{{DEFAULT_LANGUAGE}}", defaultLanguage)

        return result
    }
}
