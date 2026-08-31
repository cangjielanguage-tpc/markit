package markit.plugins.standard.block.fenced_code_block

import std.collection.{ArrayList, HashMap}
import std.convert.Parsable

public class FencedCodeBlockLineRuleUtils {
    public static func convertGlobalHighlightLinesToLocal(
        highlightLines: String,
        groupStartLine: Int64,
        groupSize: Int64
    ): String {
        if (highlightLines.isEmpty()) {
            return ""
        }

        let groupEndLine = groupStartLine + groupSize - 1
        let result = ArrayList<String>()

        for (part in highlightLines.split(",")) {
            let trimmedPart = part.trimAscii()
            if (trimmedPart.isEmpty()) {
                continue
            }

            if (let Some((start, end, separator)) <- parseRange(trimmedPart, allowHyphen: true)) {
                if (end < groupStartLine || start > groupEndLine) {
                    continue
                }
                let localStart = if (start < groupStartLine) { 1 } else { start - groupStartLine + 1 }
                let localEnd = if (end > groupEndLine) { groupSize } else { end - groupStartLine + 1 }
                if (localStart > groupSize || localEnd < 1) {
                    continue
                }
                if (localStart == localEnd) {
                    result.add("${localStart}")
                } else {
                    result.add("${localStart}${separator}${localEnd}")
                }
                continue
            }

            if (let Some(lineNumber) <- parseLineNumber(trimmedPart)) {
                if (lineNumber >= groupStartLine && lineNumber <= groupEndLine) {
                    result.add("${lineNumber - groupStartLine + 1}")
                }
            }
        }

        return joinParts(result)
    }

    public static func convertGlobalI18nLinesToLocal(
        i18nLines: String,
        groupStartLine: Int64,
        groupSize: Int64
    ): String {
        if (i18nLines.isEmpty()) {
            return ""
        }

        let groupEndLine = groupStartLine + groupSize - 1
        let result = ArrayList<String>()

        for ((rangePart, languagePart) in splitI18nRules(i18nLines)) {
            if (let Some((start, end, separator)) <- parseRange(rangePart)) {
                if (end < groupStartLine || start > groupEndLine) {
                    continue
                }
                let localStart = if (start < groupStartLine) { 1 } else { start - groupStartLine + 1 }
                let localEnd = if (end > groupEndLine) { groupSize } else { end - groupStartLine + 1 }
                if (localStart <= groupSize && localEnd >= 1) {
                    result.add("${localStart}${separator}${localEnd}:${languagePart}")
                }
                continue
            }

            if (let Some(lineNumber) <- parseLineNumber(rangePart)) {
                if (lineNumber >= groupStartLine && lineNumber <= groupEndLine) {
                    result.add("${lineNumber - groupStartLine + 1}:${languagePart}")
                }
            }
        }

        return joinParts(result)
    }

    public static func collectI18nLineNumbers(
        i18nRules: String,
        targetLanguage: String,
        totalLines: Int64
    ): ArrayList<Int64> {
        let selected = ArrayList<Int64>()
        if (i18nRules.isEmpty() || targetLanguage.isEmpty() || totalLines <= 0) {
            return selected
        }

        let i18nLineMap = buildI18nLineLanguageMap(i18nRules, totalLines)
        for (lineNumber in 1..(totalLines + 1)) {
            if (!i18nLineMap.contains(lineNumber)) {
                selected.add(lineNumber)
                continue
            }
            if (let Some(language) <- i18nLineMap.get(lineNumber)) {
                if (language == targetLanguage) {
                    selected.add(lineNumber)
                }
            }
        }
        return selected
    }

    /**
     * Projects a fenced block to the target language while preserving all
     * untagged lines and their original order.
     */
    public static func filterContentForLanguage(
        content: String,
        i18nRules: String,
        targetLanguage: String
    ): String {
        if (content.isEmpty() || i18nRules.isEmpty() || targetLanguage.isEmpty()) {
            return content
        }

        let lines = content.split("\n")
        let selected = collectI18nLineNumbers(i18nRules, targetLanguage, Int64(lines.size))
        if (selected.size == lines.size) {
            return content
        }

        let projected = ArrayList<String>()
        for (lineNumber in selected) {
            projected.add(lines[lineNumber - 1])
        }
        return String.join(projected.toArray(), delimiter: "\n")
    }

    private static func buildI18nLineLanguageMap(
        i18nRules: String,
        totalLines: Int64
    ): HashMap<Int64, String> {
        let result = HashMap<Int64, String>()
        if (i18nRules.isEmpty() || totalLines <= 0) {
            return result
        }

        for ((rangePart, languagePart) in splitI18nRules(i18nRules)) {
            for (lineNumber in expandRange(rangePart, totalLines)) {
                result[lineNumber] = languagePart
            }
        }
        return result
    }

    private static func splitI18nRules(i18nRules: String): ArrayList<(String, String)> {
        let rules = ArrayList<(String, String)>()
        let pendingRanges = ArrayList<String>()

        for (part in i18nRules.split(",")) {
            let trimmedPart = part.trimAscii()
            if (trimmedPart.isEmpty()) {
                continue
            }

            if (let Some(separatorIndex) <- trimmedPart.lastIndexOf(':')) {
                let rangePart = trimmedPart[0..separatorIndex].trimAscii()
                let languagePart = trimmedPart[separatorIndex + 1..].trimAscii()
                if (!rangePart.isEmpty()) {
                    pendingRanges.add(rangePart)
                }
                if (!rangePart.isEmpty() && !languagePart.isEmpty()) {
                    for (pendingRange in pendingRanges) {
                        rules.add((pendingRange, languagePart))
                    }
                    pendingRanges.clear()
                }
                continue
            }

            pendingRanges.add(trimmedPart)
        }

        return rules
    }

    private static func expandRange(rangePart: String, totalLines: Int64): ArrayList<Int64> {
        let expanded = ArrayList<Int64>()
        let trimmedRange = rangePart.trimAscii()
        if (trimmedRange.isEmpty() || totalLines <= 0) {
            return expanded
        }

        if (trimmedRange.contains("..=")) {
            let separatorIndex = trimmedRange.indexOf("..=").getOrThrow()
            let before = trimmedRange[0..separatorIndex].trimAscii()
            let after = trimmedRange[separatorIndex + 3..].trimAscii()
            let start = parseBoundary(before, 1)
            let end = parseBoundary(after, totalLines)
            if (start <= end) {
                for (lineNumber in start..(end + 1)) {
                    if (lineNumber >= 1 && lineNumber <= totalLines) {
                        expanded.add(lineNumber)
                    }
                }
            }
            return expanded
        }

        if (trimmedRange.contains("..")) {
            let separatorIndex = trimmedRange.indexOf("..").getOrThrow()
            let before = trimmedRange[0..separatorIndex].trimAscii()
            let after = trimmedRange[separatorIndex + 2..].trimAscii()
            let start = parseBoundary(before, 1)
            let endExclusive = parseBoundary(after, totalLines + 1)
            if (start < endExclusive) {
                for (lineNumber in start..endExclusive) {
                    if (lineNumber >= 1 && lineNumber <= totalLines) {
                        expanded.add(lineNumber)
                    }
                }
            }
            return expanded
        }

        if (let Some(lineNumber) <- parseLineNumber(trimmedRange)) {
            if (lineNumber >= 1 && lineNumber <= totalLines) {
                expanded.add(lineNumber)
            }
        }
        return expanded
    }

    private static func parseBoundary(value: String, fallback: Int64): Int64 {
        if (value.isEmpty()) {
            return fallback
        }
        return parseLineNumber(value).getOrDefault({ => fallback })
    }

    private static func parseRange(
        value: String,
        allowHyphen!: Bool = false
    ): ?(Int64, Int64, String) {
        let trimmedValue = value.trimAscii()
        let separator = detectRangeSeparator(trimmedValue, allowHyphen)
        if (separator.isEmpty()) {
            return None
        }
        let parts = trimmedValue.split(separator)
        if (parts.size != 2) {
            return None
        }
        if (let Some(start) <- parseLineNumber(parts[0])) {
            if (let Some(end) <- parseLineNumber(parts[1])) {
                return Some((start, end, separator))
            }
        }
        return None
    }

    private static func detectRangeSeparator(value: String, allowHyphen: Bool): String {
        if (value.contains("..=")) {
            return "..="
        }
        if (value.contains("..")) {
            return ".."
        }
        if (allowHyphen && value.contains("-")) {
            return "-"
        }
        return ""
    }

    private static func parseLineNumber(value: String): ?Int64 {
        try {
            return Some(Int64.parse(value.trimAscii()))
        } catch (_: Exception) {
            return None
        }
    }

    private static func joinParts(parts: ArrayList<String>): String {
        if (parts.isEmpty()) {
            return ""
        }
        return String.join(parts.toArray(), delimiter: ",")
    }
}
