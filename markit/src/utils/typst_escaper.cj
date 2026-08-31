package markit.utils

public class TypstEscaper {
    public static func escapeText(text: String): String {
        if (text.isEmpty()) {
            return ""
        }
        var result = text
        result = result.replace("\\", "\\\\")
        result = result.replace("#", "\\#")
        result = result.replace("<", "\\<")
        result = result.replace(">", "\\>")
        result = result.replace("[", "\\[")
        result = result.replace("]", "\\]")
        result = result.replace("{", "\\{")
        result = result.replace("}", "\\}")
        result = result.replace("*", "\\*")
        result = result.replace("_", "\\_")
        result = result.replace("$", "\\$")
        result = result.replace("@", "\\@")
        return result
    }

    public static func escapeString(text: String): String {
        if (text.isEmpty()) {
            return ""
        }
        var result = text
        result = result.replace("\\", "\\\\")
        result = result.replace("\"", "\\\"")
        return result
    }
}
