package markit.plugins.standard.block.heading

public class HeadingMarkerUtils {
    public static func isClosableContent(text: String, level: Int64): Bool {
        if (text.isEmpty() || level < 1) {
            return false
        }
        let marker = markerText(level)
        return text.endsWith(" ${marker}") || text.endsWith(marker)
    }

    public static func trimClosableSuffix(text: String, level: Int64): String {
        if (!isClosableContent(text, level)) {
            return text
        }

        let marker = markerText(level)
        if (text.endsWith(" ${marker}")) {
            return text[0..text.size - marker.size - 1].trimAscii()
        }
        return text[0..text.size - marker.size].trimAscii()
    }

    private static func markerText(level: Int64): String {
        let sb = StringBuilder()
        for (_ in 0..level) {
            sb.append("#")
        }
        return sb.toString()
    }
}
