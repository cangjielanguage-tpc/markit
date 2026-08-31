package markit.utils

public class TypstRenderUtils {
    private static let inlineCodeExpressionSeparator = "\\u{2060}"

    public static func renderInlineCode(content: String): String {
        return "#markit-inline-code(\"${TypstEscaper.escapeString(content)}\")${inlineCodeExpressionSeparator}"
    }

    public static func renderInlineCodeTable(content: String): String {
        return "#markit-inline-code-table(\"${TypstEscaper.escapeString(content)}\")${inlineCodeExpressionSeparator}"
    }

    public static func renderRawInline(content: String): String {
        return "[#raw(\"${TypstEscaper.escapeString(content)}\")]"
    }

    public static func renderRawBlock(content: String, lang!: String = ""): String {
        let fence = buildRawFence(content)
        if (lang.isEmpty()) {
            return "${fence}\n${content}\n${fence}\n\n"
        }
        return "${fence}${lang}\n${content}\n${fence}\n\n"
    }

    private static func buildRawFence(content: String): String {
        var maxRun: Int64 = 0
        var currentRun: Int64 = 0

        for (byte in content) {
            if (byte == b'`') {
                currentRun += 1
                if (currentRun > maxRun) {
                    maxRun = currentRun
                }
            } else {
                currentRun = 0
            }
        }

        let fenceLength = if (maxRun + 1 > 6) { maxRun + 1 } else { 6 }
        return TextRenderUtils.repeat("`", fenceLength)
    }
}
