package markit_kit.utils

import std.collection.ArrayList

/**
 * 配置文件路径解析工具
 *
 * 提供解析逗号分隔的配置文件路径字符串的功能
 */
public class ConfigPathParser {
    /**
     * 解析配置文件路径（支持逗号分隔）
     *
     * @param pathString 配置文件路径字符串（可能包含逗号分隔的多个路径）
     * @return 配置文件路径数组
     *
     * 示例：
     * - "markit.json" -> ["markit.json"]
     * - "markit.json,markit-en.json" -> ["markit.json", "markit-en.json"]
     * - "markit.json, markit-en.json" -> ["markit.json", "markit-en.json"] (空白字符被修剪)
     */
    public static func parseConfigPaths(pathString: String): Array<String> {
        let paths = ArrayList<String>()
        let parts = pathString.split(",")

        for (part in parts) {
            let trimmed = part.trimAscii()
            if (!trimmed.isEmpty()) {
                // 处理 MSYS/Git Bash 路径格式（/c/Users/... → C:\Users\...）
                let normalized = convertMsysPathIfNeeded(trimmed)
                paths.add(normalized)
            }
        }

        return paths.toArray()
    }

    /**
     * 将 MSYS/Git Bash 风格路径转换为 Windows 原生路径
     * 例如：/c/Users/xxx/file.json → C:\Users\xxx\file.json
     * 非 MSYS 路径原样返回
     */
    private static func convertMsysPathIfNeeded(path: String): String {
        // 检测 MSYS 路径格式：/x/... 其中 x 是单个字母（盘符）
        let driveLetters = [
            "a","b","c","d","e","f","g","h","i","j","k","l","m",
            "n","o","p","q","r","s","t","u","v","w","x","y","z",
            "A","B","C","D","E","F","G","H","I","J","K","L","M",
            "N","O","P","Q","R","S","T","U","V","W","X","Y","Z"
        ]
        for (letter in driveLetters) {
            let prefix = "/" + letter + "/"
            if (path.startsWith(prefix)) {
                let drive = letter.toAsciiUpper()
                let rest = path[2..]
                return drive + ":" + rest
            }
        }
        return path
    }
}
