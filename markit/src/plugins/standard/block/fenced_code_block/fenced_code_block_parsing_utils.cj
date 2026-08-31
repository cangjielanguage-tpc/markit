package markit.plugins.standard.block.fenced_code_block

import std.collection.ArrayList

public class FencedCodeBlockParsingUtils {
    public static func detectOpeningFence(line: String): ?FencedCodeBlockStartInfo {
        let indentWidth = indentationWidth(line)
        if (indentWidth > 4) {
            return None
        }

        if (let Some(firstContentIndex) <- firstNonWhitespaceIndex(line)) {
            let marker = line[firstContentIndex]
            if (marker != b'`' && marker != b'~') {
                return None
            }

            var fenceLength: Int64 = 0
            while (firstContentIndex + fenceLength < line.size &&
                line[firstContentIndex + fenceLength] == marker) {
                fenceLength += 1
            }
            if (fenceLength < 3) {
                return None
            }

            let afterFence = if (firstContentIndex + fenceLength < line.size) {
                line[firstContentIndex + fenceLength..]
            } else {
                ""
            }
            if (!isValidFenceInfo(afterFence)) {
                return None
            }

            return Some(FencedCodeBlockStartInfo(
                marker,
                fenceLength,
                indentWidth,
                extractLanguage(afterFence),
                extractHighlightLines(afterFence),
                extractI18nLines(afterFence)
            ))
        }

        return None
    }

    public static func isClosingFence(
        line: String,
        marker: Byte,
        minimumFenceLength: Int64,
        maximumIndentWidth: Int64
    ): Bool {
        let indentWidth = indentationWidth(line)
        if (indentWidth > maximumIndentWidth) {
            return false
        }

        if (let Some(firstContentIndex) <- firstNonWhitespaceIndex(line)) {
            if (line[firstContentIndex] != marker) {
                return false
            }

            var fenceLength: Int64 = 0
            while (firstContentIndex + fenceLength < line.size &&
                line[firstContentIndex + fenceLength] == marker) {
                fenceLength += 1
            }
            if (fenceLength < minimumFenceLength) {
                return false
            }

            var index = firstContentIndex + fenceLength
            while (index < line.size) {
                if (line[index] != b' ' && line[index] != b'\t') {
                    return false
                }
                index += 1
            }
            return true
        }

        return false
    }

    public static func removeLeadingIndent(line: String, spacesToRemove: Int64): String {
        if (spacesToRemove <= 0 || line.isEmpty()) {
            return line
        }

        var index: Int64 = 0
        var removed: Int64 = 0
        while (index < line.size && removed < spacesToRemove) {
            let current = line[index]
            if (current == b' ') {
                index += 1
                removed += 1
                continue
            }

            if (current == b'\t') {
                let remaining = spacesToRemove - removed
                if (remaining >= 4) {
                    index += 1
                    removed += 4
                } else {
                    let prefix = spaces(4 - remaining)
                    let suffix = if (index + 1 < line.size) { line[index + 1..] } else { "" }
                    return prefix + suffix
                }
                continue
            }

            break
        }

        if (index >= line.size) {
            return ""
        }
        return line[index..]
    }

    public static func joinLines(lines: ArrayList<String>): String {
        if (lines.isEmpty()) {
            return ""
        }
        return String.join(lines.toArray(), delimiter: "\n")
    }

    public static func parseFileGroups(
        content: String,
        defaultLanguage: String,
        defaultHighlightLines: String,
        defaultI18nLines: String
    ): ArrayList<FencedCodeBlockFileGroup> {
        let groups = ArrayList<FencedCodeBlockFileGroup>()
        if (content.isEmpty() || !allowsFileGroups(defaultLanguage)) {
            return groups
        }

        let lines = content.split("\n")
        var currentFilename = ""
        var currentLanguage = defaultLanguage
        var currentLines = ArrayList<String>()
        var globalLineNumber: Int64 = 1
        var groupStartLine: Int64 = 1
        var hasSeenSeparator = false

        for (line in lines) {
            if (isGroupSeparator(line)) {
                hasSeenSeparator = true
                if (!currentFilename.isEmpty() || !currentLines.isEmpty()) {
                    saveFileGroup(
                        groups,
                        currentFilename,
                        currentLines,
                        currentLanguage,
                        FencedCodeBlockLineRuleUtils.convertGlobalHighlightLinesToLocal(
                            defaultHighlightLines,
                            groupStartLine,
                            currentLines.size
                        ),
                        FencedCodeBlockLineRuleUtils.convertGlobalI18nLinesToLocal(
                            defaultI18nLines,
                            groupStartLine,
                            currentLines.size
                        )
                    )
                }

                let (filename, language) = parseFileHeader(line, defaultLanguage)
                currentFilename = filename
                currentLanguage = language
                currentLines = ArrayList<String>()
                globalLineNumber += 1
                groupStartLine = globalLineNumber
            } else {
                currentLines.add(line)
                globalLineNumber += 1
            }
        }

        if (hasSeenSeparator && (!currentFilename.isEmpty() || !currentLines.isEmpty())) {
            saveFileGroup(
                groups,
                currentFilename,
                currentLines,
                currentLanguage,
                FencedCodeBlockLineRuleUtils.convertGlobalHighlightLinesToLocal(
                    defaultHighlightLines,
                    groupStartLine,
                    currentLines.size
                ),
                FencedCodeBlockLineRuleUtils.convertGlobalI18nLinesToLocal(
                    defaultI18nLines,
                    groupStartLine,
                    currentLines.size
                )
            )
        }

        return groups
    }

    private static func allowsFileGroups(defaultLanguage: String): Bool {
        let language = defaultLanguage.toAsciiLower()
        return language != "markdown" && language != "md"
    }

    public static func indentationWidth(line: String): Int64 {
        var width: Int64 = 0
        var index: Int64 = 0
        while (index < line.size) {
            if (line[index] == b' ') {
                width += 1
            } else if (line[index] == b'\t') {
                width += 4
            } else {
                break
            }
            index += 1
        }
        return width
    }

    private static func extractLanguage(afterFence: String): String {
        var index: Int64 = 0
        while (index < afterFence.size && (afterFence[index] == b' ' || afterFence[index] == b'\t')) {
            index += 1
        }

        var end = index
        while (end < afterFence.size) {
            let current = afterFence[end]
            if (current == b' ' || current == b'\t' || current == b'{' || current == b'[') {
                break
            }
            end += 1
        }

        if (index >= end) {
            return ""
        }
        return afterFence[index..end]
    }

    private static func extractHighlightLines(afterFence: String): String {
        return extractDelimitedSection(afterFence, b'{', b'}')
    }

    private static func extractI18nLines(afterFence: String): String {
        return extractDelimitedSection(afterFence, b'[', b']')
    }

    private static func extractDelimitedSection(line: String, open: Byte, close: Byte): String {
        var start: Int64 = -1
        var index: Int64 = 0
        while (index < line.size) {
            if (line[index] == open) {
                start = index + 1
                break
            }
            index += 1
        }
        if (start < 0) {
            return ""
        }

        index = start
        while (index < line.size) {
            if (line[index] == close) {
                return line[start..index].trimAscii()
            }
            index += 1
        }
        return ""
    }

    private static func isGroupSeparator(line: String): Bool {
        if (line.size < 5) {
            return false
        }

        var slashCount: Int64 = 0
        while (slashCount < line.size && line[slashCount] == b'/') {
            slashCount += 1
        }
        if (slashCount < 5) {
            return false
        }

        let trimmed = line.trimAsciiEnd()
        if (!trimmed.isEmpty() && trimmed[trimmed.size - 1] == b'\\') {
            return false
        }
        return true
    }

    private static func parseFileHeader(line: String, defaultLanguage: String): (String, String) {
        var slashCount: Int64 = 0
        while (slashCount < line.size && line[slashCount] == b'/') {
            slashCount += 1
        }

        let fileInfo = if (slashCount < line.size) {
            line[slashCount..].trimAscii()
        } else {
            ""
        }

        if (let Some(startIdx) <- fileInfo.indexOf('[')) {
            if (let Some(endIdx) <- fileInfo.indexOf(']')) {
                if (endIdx > startIdx) {
                    return (
                        fileInfo[0..startIdx].trimAscii(),
                        fileInfo[startIdx + 1..endIdx].trimAscii()
                    )
                }
            }
        }

        return (fileInfo, defaultLanguage)
    }

    private static func isValidFenceInfo(afterFence: String): Bool {
        if (afterFence.isEmpty()) {
            return true
        }

        var pos: Int64 = 0
        let len = afterFence.size
        while (pos < len && (afterFence[pos] == b' ' || afterFence[pos] == b'\t')) {
            pos += 1
        }
        if (pos >= len) {
            return true
        }

        while (pos < len) {
            let ch = afterFence[pos]
            if (ch == b' ' || ch == b'\t' || ch == b'{' || ch == b'[') {
                break
            }
            if (!isLanguageIdentifierByte(ch)) {
                return false
            }
            pos += 1
        }

        while (pos < len && (afterFence[pos] == b' ' || afterFence[pos] == b'\t')) {
            pos += 1
        }
        if (pos >= len) {
            return true
        }

        var foundBrace = false
        var foundBracket = false
        if (afterFence[pos] == b'{') {
            foundBrace = true
            pos = consumeDelimitedBlock(afterFence, pos, b'}', isHighlightRuleByte)
            if (pos < 0) {
                return false
            }
        } else if (afterFence[pos] == b'[') {
            foundBracket = true
            pos = consumeDelimitedBlock(afterFence, pos, b']', isI18nRuleByte)
            if (pos < 0) {
                return false
            }
        }

        while (pos < len && (afterFence[pos] == b' ' || afterFence[pos] == b'\t')) {
            pos += 1
        }
        if (pos >= len) {
            return true
        }

        if (foundBrace && afterFence[pos] == b'[') {
            pos = consumeDelimitedBlock(afterFence, pos, b']', isI18nRuleByte)
            if (pos < 0) {
                return false
            }
        } else if (foundBracket && afterFence[pos] == b'{') {
            pos = consumeDelimitedBlock(afterFence, pos, b'}', isHighlightRuleByte)
            if (pos < 0) {
                return false
            }
        } else {
            return false
        }

        while (pos < len && (afterFence[pos] == b' ' || afterFence[pos] == b'\t')) {
            pos += 1
        }
        return pos >= len
    }

    private static func consumeDelimitedBlock(
        text: String,
        start: Int64,
        closing: Byte,
        validator: (Byte) -> Bool
    ): Int64 {
        var index = start + 1
        while (index < text.size) {
            let current = text[index]
            if (current == closing) {
                return index + 1
            }
            if (!validator(current)) {
                return -1
            }
            index += 1
        }
        return -1
    }

    private static func firstNonWhitespaceIndex(line: String): ?Int64 {
        var index: Int64 = 0
        while (index < line.size && (line[index] == b' ' || line[index] == b'\t')) {
            index += 1
        }
        if (index >= line.size) {
            return None
        }
        return Some(index)
    }

    private static func saveFileGroup(
        groups: ArrayList<FencedCodeBlockFileGroup>,
        filename: String,
        lines: ArrayList<String>,
        language: String,
        highlightLines: String,
        i18nLines: String
    ): Unit {
        groups.add(FencedCodeBlockFileGroup(
            filename,
            joinLines(lines),
            language: language,
            highlightLines: highlightLines,
            i18nLines: i18nLines
        ))
    }

    private static func isLanguageIdentifierByte(ch: Byte): Bool {
        return isAsciiAlphaNumeric(ch) ||
            ch == b'-' ||
            ch == b'_' ||
            ch == b'.' ||
            ch == b'/' ||
            ch == b'\\' ||
            ch == b':' ||
            ch == b'+' ||
            ch == b'#'
    }

    private static func isHighlightRuleByte(ch: Byte): Bool {
        return isAsciiAlphaNumeric(ch) ||
            ch == b',' ||
            ch == b'-' ||
            ch == b'.' ||
            ch == b'=' ||
            ch == b' ' ||
            ch == b'\t'
    }

    private static func isI18nRuleByte(ch: Byte): Bool {
        return isAsciiAlphaNumeric(ch) ||
            ch == b'.' ||
            ch == b'=' ||
            ch == b':' ||
            ch == b',' ||
            ch == b' ' ||
            ch == b'\t' ||
            ch == b'-' ||
            ch == b'_'
    }

    private static func isAsciiAlphaNumeric(ch: Byte): Bool {
        return (ch >= b'a' && ch <= b'z') ||
            (ch >= b'A' && ch <= b'Z') ||
            (ch >= b'0' && ch <= b'9')
    }

    private static func spaces(count: Int64): String {
        if (count <= 0) {
            return ""
        }
        let sb = StringBuilder()
        for (_ in 0..count) {
            sb.append(" ")
        }
        return sb.toString()
    }
}
