package markit_kit.themes

import std.collection.{HashMap, ArrayList}

/**
 * 主题管理器
 * 负责加载和管理不同的主题配置
 */
public class ThemeManager {
    private static let themes: HashMap<String, Theme> = HashMap<String, Theme>()
    private static var initialized: Bool = false
    
    /**
     * 初始化主题系统
     */
    public static func initialize() {
        if (initialized) {
            return
        }
        initialized = true
    }
    
    /**
     * 获取主题
     * 
     * @param name 主题名称
     * @return 主题对象
     * @throws Exception 如果主题不存在
     */
    public static func getTheme(name: String): Theme {
        initialize()
        
        match (themes.get(name)) {
            case Some(theme) => theme
            case None => 
                // 尝试动态加载主题
                match (FileThemeLoader.loadTheme(name)) {
                    case Some(theme) => 
                        themes[name] = theme
                        theme
                    case None => 
                        throw Exception("Theme '${name}' not found. Available themes: ${getAvailableThemes()}")
                }
        }
    }
    
    /**
     * 获取可用主题列表
     */
    public static func getAvailableThemes(): Array<String> {
        initialize()
        let availableThemes = ArrayList<String>()
        
        for (themeName in themes.keys()) {
            availableThemes.add(themeName)
        }
        
        return availableThemes.toArray()
    }
    
}