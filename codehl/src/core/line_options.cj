package codehl.core

import std.collection.{ArrayList, HashMap}
import std.convert.Parsable

public class LineOptions {
    public let highlightLines: Array<Int64>
    public let i18nLines: HashMap<Int64, String>

    public init(highlightLines: Array<Int64>, i18nLines: HashMap<Int64, String>) {
        this.highlightLines = highlightLines
        this.i18nLines = i18nLines
    }
}

public class LineOptionsParser {
    public static func parseHighlightLines(rangeSpec: String, totalLines: Int64): Array<Int64> {
        let result = ArrayList<Int64>()
        for (part in rangeSpec.split(",")) {
            appendRange(result, part.trimAscii(), totalLines)
        }
        return result.toArray()
    }

    public static func parseI18nLines(spec: String, totalLines: Int64): HashMap<Int64, String> {
        let result = HashMap<Int64, String>()
        let pendingRanges = ArrayList<String>()

        for (rawPart in spec.split(",")) {
            let part = rawPart.trimAscii()
            let colonIndex = lastIndexOf(part, b':')
            if (colonIndex < 0) {
                pendingRanges.add(part)
                continue
            }

            let rangePart = part[0..colonIndex].trimAscii()
            let lang = part[colonIndex + 1..part.size].trimAscii()
            if (!rangePart.isEmpty()) {
                pendingRanges.add(rangePart)
            }
            if (!lang.isEmpty()) {
                for (range in pendingRanges) {
                    let lines = parseHighlightLines(range, totalLines)
                    for (line in lines) {
                        result[line] = lang
                    }
                }
            }
            pendingRanges.clear()
        }

        return result
    }

    public static func merge(options: HighlightOptions, totalLines: Int64): LineOptions {
        let highlight = options.highlightLines
        let i18nMap = HashMap<Int64, String>()
        for (line in options.i18nLines) {
            i18nMap[line] = options.targetLang
        }
        return LineOptions(highlight, i18nMap)
    }

    private static func appendRange(result: ArrayList<Int64>, rangeSpec: String, totalLines: Int64): Unit {
        if (rangeSpec.isEmpty()) {
            return
        }

        if (let Some(index) <- rangeSpec.indexOf("..=")) {
            appendRangeBounds(result, rangeSpec[0..index], rangeSpec[index + 3..rangeSpec.size], totalLines, true)
            return
        }
        if (let Some(index) <- rangeSpec.indexOf("..")) {
            appendRangeBounds(result, rangeSpec[0..index], rangeSpec[index + 2..rangeSpec.size], totalLines, false)
            return
        }
        if (let Some(line) <- parsePositiveInt(rangeSpec)) {
            if (line <= totalLines) {
                result.add(line)
            }
        }
    }

    private static func appendRangeBounds(
        result: ArrayList<Int64>,
        before: String,
        after: String,
        totalLines: Int64,
        inclusiveEnd: Bool
    ): Unit {
        let start = parsePositiveInt(before.trimAscii()) ?? 1
        let parsedEnd = parsePositiveInt(after.trimAscii()) ?? totalLines
        let end = if (inclusiveEnd || after.trimAscii().isEmpty()) { parsedEnd } else { parsedEnd - 1 }
        var line = start
        while (line <= end && line <= totalLines) {
            if (line > 0) {
                result.add(line)
            }
            line += 1
        }
    }

    private static func parsePositiveInt(value: String): ?Int64 {
        if (value.isEmpty()) {
            return None
        }
        try {
            let parsed = Int64.parse(value)
            return if (parsed > 0) { Some(parsed) } else { None }
        } catch (e: IllegalArgumentException) {
            return None
        }
    }

    private static func lastIndexOf(value: String, ch: Byte): Int64 {
        var i = value.size - 1
        while (i >= 0) {
            if (value[i] == ch) {
                return i
            }
            i -= 1
        }
        return -1
    }
}
