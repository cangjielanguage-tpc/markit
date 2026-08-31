package markit_kit.themes

import markit_kit.utils.KitHooks

import std.fs.{Path, exists, File, Directory}
import std.collection.ArrayList
import seajson.{parseJson, jsonFieldBool, jsonFieldObj, jsonFieldString}
import markit_kit.utils.PathUtils
import markit_kit.utils.ResourceResolver

/**
 * 基于文件的主题加载器
 * 从assets目录加载主题配置和模板
 */
public class FileThemeLoader {
    private static let ASSETS_PATH: String = "assets/themes"

    /**
     * 加载主题
     *
     * @param themeName 主题名称
     * @return 主题对象，如果不存在则返回None
     */
    public static func loadTheme(themeName: String): ?FileTheme {
        let themePath = ResourceResolver.resolveResourcePath("${ASSETS_PATH}/${themeName}")
        let configPath = themePath.join("theme.json")

        if (!exists(configPath)) {
            return None
        }

        try {
            let configContent = String.fromUtf8(File.readFrom(configPath))
            return Some(FileTheme.fromConfigFile(themeName, themePath.toString(), configContent))
        } catch (e: Exception) {
            KitHooks.warn("Failed to load theme '${themeName}': ${e.message}")
            return None
        }
    }

    /**
     * 获取可用主题列表
     *
     * @return 主题名称数组
     */
    public static func getAvailableThemes(): Array<String> {
        let themes = ArrayList<String>()

        for (themesPath in ResourceResolver.getResourceCandidates(ASSETS_PATH)) {
            if (!exists(themesPath)) {
                continue
            }

            try {
                for (entry in Directory.readFrom(themesPath)) {
                    if (entry.isDirectory()) {
                        let themeName = entry.name
                        let configPath = entry.path.join("theme.json")
                        if (exists(configPath) && !themes.contains(themeName)) {
                            themes.add(themeName)
                        }
                    }
                }
            } catch (e: Exception) {
                KitHooks.warn("Failed to scan themes directory: ${e.message}")
            }
        }

        return themes.toArray()
    }

    /**
     * 检查主题是否存在
     *
     * @param themeName 主题名称
     * @return 是否存在
     */
    public static func themeExists(themeName: String): Bool {
        let themePath = ResourceResolver.resolveResourcePath("${ASSETS_PATH}/${themeName}")
        let configPath = themePath.join("theme.json")
        return exists(configPath)
    }
}

/**
 * 基于文件的主题实现
 */
public class FileTheme <: Theme {
    private let name: String
    private let description: String
    private let themePath: String
    private let supportsWebsite: Bool
    private let websiteTemplate: String
    private let stylesFile: String

    private init(name: String, description: String, themePath: String, supportsWebsite: Bool, websiteTemplate: String,
        stylesFile: String) {
        this.name = name
        this.description = description
        this.themePath = themePath
        this.supportsWebsite = supportsWebsite
        this.websiteTemplate = websiteTemplate
        this.stylesFile = stylesFile
    }

    /**
     * 从配置文件创建主题
     *
     * @param themeName 主题名称
     * @param themePath 主题路径
     * @param configContent 配置文件内容
     * @return 主题实例
     */
    public static func fromConfigFile(themeName: String, themePath: String, configContent: String): FileTheme {
        try {
            let jsonObject = parseJson(configContent)

            // 解析配置字段
            let description = jsonFieldString(jsonObject, "description") ?? "File-based theme: ${themeName}"

            let supportsWebsite = jsonFieldBool(jsonObject, "supportsWebsite") ?? true

            let websiteTemplate = match (jsonFieldObj(jsonObject, "templates")) {
                case Some(templatesObj) => jsonFieldString(templatesObj, "website") ?? "website.html"
                case None => "website.html"
            }

            let stylesFile = jsonFieldString(jsonObject, "styles") ?? "styles.css"

            return FileTheme(themeName, description, themePath, supportsWebsite, websiteTemplate, stylesFile)
        } catch (e: Exception) {
            KitHooks.warn("Failed to parse theme config for '${themeName}': ${e.message}")
            // 返回默认配置
            return FileTheme(themeName, "File-based theme: ${themeName}", themePath, true, "website.html", "styles.css")
        }
    }

    public func getName(): String {
        return name
    }

    public func getDescription(): String {
        return description
    }

    public func getStyles(): String {
        let stylesPath = Path(themePath).join(stylesFile)
        if (exists(stylesPath)) {
            try {
                return String.fromUtf8(File.readFrom(stylesPath))
            } catch (e: Exception) {
                KitHooks.warn("Failed to load styles for theme '${name}': ${e.message}")
            }
        }
        KitHooks.warn("Styles file not found for theme '${name}': ${stylesPath}")
        return ""
    }

    public func getWebsiteTemplate(devMode: Bool): String {
        let templatePath = Path(themePath).join(websiteTemplate)
        if (exists(templatePath)) {
            try {
                let template = String.fromUtf8(File.readFrom(templatePath))
                let devScript = if (devMode) {
                    getDevScript()
                } else {
                    ""
                }
                return template.replace("{{devScript}}", devScript)
            } catch (e: Exception) {
                KitHooks.warn("Failed to load website template for theme '${name}': ${e.message}")
            }
        }
        KitHooks.warn("Website template not found for theme '${name}': ${templatePath}")
        return ""
    }

    /**
     * 获取带相对路径的网站模板
     *
     * @param devMode 是否为开发模式
     * @param relativePath 相对路径前缀（如 "../" 或 ""）
     * @return 处理过的模板
     */
    public func getWebsiteTemplateWithPaths(devMode: Bool, relativePath: String): String {
        let template = getWebsiteTemplate(devMode)
        return processTemplatePaths(template, relativePath)
    }

    /**
     * 处理模板中的路径占位符
     *
     * @param template 原始模板
     * @param relativePath 相对路径前缀
     * @return 处理过的模板
     */
    private func processTemplatePaths(template: String, relativePath: String): String {
        var processedTemplate = template
        // 共享资源在 /assets/ 目录，需要使用 relativePath
        processedTemplate = processedTemplate.replace("{{faviconPath}}", "${relativePath}assets/favicon.ico")
        processedTemplate = processedTemplate.replace("{{themeCssPath}}", "${relativePath}assets/css/styles.css")
        processedTemplate = processedTemplate.replace("{{markitJsPath}}", "${relativePath}assets/js/markit.bundle.js")

        // mathtex HTML 输出使用 KaTeX CSS 和字体资源。
        let katexAssets = "<link rel=\"stylesheet\" href=\"${relativePath}assets/css/katex.min.css\">"
        processedTemplate = processedTemplate.replace("{{katexAssets}}", katexAssets)

        // 搜索索引在当前语言目录下，需要计算相对于语言目录的路径
        let jsRelativePath = PathUtils.calculateLanguageDirRelativePath(relativePath)
        processedTemplate = processedTemplate.replace("{{searchIndexPath}}", "${jsRelativePath}js/search-index.js")

        processedTemplate = processedTemplate.replace("{{rootPath}}", relativePath)
        return processedTemplate
    }

    public func supportsWebsiteMode(): Bool {
        return supportsWebsite
    }

    /**
     * 获取开发模式脚本
     */
    private func getDevScript(): String {
        return """
    <script>
        // Auto-reload script for development server
        (function() {
            let lastModified = null;
            
            function checkForUpdates() {
                const timestamp = new Date().getTime();
                const checkUrl = window.location.href + '?_check=' + timestamp;
                
                fetch(checkUrl, { 
                    method: 'GET',
                    cache: 'no-cache',
                    headers: {
                        'Cache-Control': 'no-cache',
                        'Pragma': 'no-cache'
                    }
                })
                .then(response => {
                    const modified = response.headers.get('Last-Modified');
                    
                    if (lastModified === null) {
                        lastModified = modified;
                        console.log('[Auto-reload] Monitoring enabled');
                    } else if (modified && modified !== lastModified) {
                        console.log('[Auto-reload] Page updated, reloading...');
                        window.location.reload();
                    }
                })
                .catch(error => {
                    console.error('[Auto-reload] Check failed:', error);
                });
            }
            
            checkForUpdates();
            setInterval(checkForUpdates, 3000);
        })();
    </script>"""
    }
}
