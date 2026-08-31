package markit_kit.components

import std.collection.ArrayList

/**
 * Language Switcher Component
 * 
 * 生成页面右上角的语言切换器 UI 组件
 */
public class LanguageSwitcher {
    /**
     * 生成语言切换器 HTML
     * 
     * @param currentLanguage 当前页面的语言代码
     * @param availableLanguages 所有可用的语言代码数组
     * @param currentPagePath 当前页面的路径（相对于语言文件夹）
     * @return 语言切换器的 HTML 代码，如果只有一种语言则返回空字符串
     */
    public static func generate(
        currentLanguage: String,
        availableLanguages: Array<String>,
        currentPagePath: String
    ): String {
        // 单语言模式不显示切换器
        if (availableLanguages.size <= 1) {
            return ""
        }
        
        // 生成语言选项
        let options = ArrayList<String>()
        for (lang in availableLanguages) {
            let isActive = (lang == currentLanguage)
            let activeClass = if (isActive) { " active" } else { "" }
            let targetUrl = calculateLanguageSwitchUrl(currentLanguage, lang, currentPagePath)
            let displayName = getLanguageDisplayName(lang)
            
            options.add("""
                <a href="${targetUrl}" 
                   class="language-option${activeClass}"
                   data-language="${lang}"
                   onclick="saveLanguagePreference('${lang}')">
                    ${displayName}
                </a>""")
        }
        
        let currentDisplayName = getLanguageDisplayName(currentLanguage)
        let optionsHtml = String.join(options.toArray(), delimiter: "\n                ")
        
        return """
        <div class="language-switcher">
            <button class="language-switcher-toggle" aria-label="Switch language">
                <span class="current-language">${currentDisplayName}</span>
                <svg class="dropdown-icon" width="12" height="8" viewBox="0 0 12 8">
                    <path d="M1 1l5 5 5-5" stroke="currentColor" stroke-width="2" fill="none"/>
                </svg>
            </button>
            <div class="language-switcher-dropdown">
                ${optionsHtml}
            </div>
        </div>"""
    }
    
    /**
     * 计算语言切换 URL
     * 
     * @param fromLang 当前语言
     * @param toLang 目标语言
     * @param currentPagePath 当前页面路径（已去掉 route_prefix）
     * @return 目标语言版本的相对 URL
     */
    private static func calculateLanguageSwitchUrl(
        fromLang: String,
        toLang: String,
        currentPagePath: String
    ): String {
        // 计算页面深度
        let depth = calculatePageDepth(currentPagePath)
        
        // 构建回到根目录的相对路径
        var url = ""
        for (_ in 0..(depth + 1)) {
            url += "../"
        }
        
        // 添加目标语言和页面路径
        url += "${toLang}/${currentPagePath}"
        
        return url
    }
    
    /**
     * 计算页面深度（路径中的 / 数量）
     * 
     * @param pagePath 页面路径
     * @return 深度值
     */
    private static func calculatePageDepth(pagePath: String): Int64 {
        var count: Int64 = 0
        for (ch in pagePath) {
            if (ch == b'/') {
                count += 1
            }
        }
        return count
    }
    
    /**
     * 获取语言的本地化显示名称
     * 
     * @param languageCode 语言代码
     * @return 本地化的语言名称
     */
    private static func getLanguageDisplayName(languageCode: String): String {
        // 语言代码到本地化名称的映射
        match (languageCode) {
            case "zh" => "中文"
            case "en" => "English"
            case "ja" => "日本語"
            case "ko" => "한국어"
            case "fr" => "Français"
            case "de" => "Deutsch"
            case "es" => "Español"
            case "pt" => "Português"
            case "ru" => "Русский"
            case "ar" => "العربية"
            case "it" => "Italiano"
            case "nl" => "Nederlands"
            case "pl" => "Polski"
            case "tr" => "Türkçe"
            case "vi" => "Tiếng Việt"
            case "th" => "ไทย"
            case "id" => "Bahasa Indonesia"
            case "ms" => "Bahasa Melayu"
            case "bn" => "বাংলা"
            case _ => languageCode  // 后备：返回语言代码本身
        }
    }
}
