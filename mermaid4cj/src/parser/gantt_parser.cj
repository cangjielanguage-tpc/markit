package mermaid4cj.parser

import std.collection.{ArrayList, HashMap}
import mermaid4cj.core.{GanttDiagram, GanttParseResult, GanttTask}

public class GanttParser {
    public init() {}

    public func parse(source: String): GanttParseResult {
        let diagnostics = ArrayList<String>()
        let tasks = ArrayList<GanttTask>()
        let sections = ArrayList<String>()
        let excludes = ArrayList<String>()
        let taskById = HashMap<String, GanttTask>()
        var sawHeader = false
        var title: ?String = None
        var dateFormat = "YYYY-MM-DD"
        var axisFormat = "%Y-%m-%d"
        var tickInterval = ""
        var weekday = ""
        var todayMarker = ""
        var inclusiveEndDates = false
        var section = ""
        var cursor: Int64 = 0
        var generatedId: Int64 = 1
        var lineNo: Int64 = 0

        for (raw in source.lines()) {
            lineNo++
            let line = stripComment(raw).trimAscii()
            if (line.isEmpty()) {
                continue
            }
            if (!sawHeader) {
                if (line.toAsciiLower().startsWith("gantt")) {
                    sawHeader = true
                    continue
                }
                diagnostics.add("Line ${lineNo}: expected gantt header")
                break
            }

            let lower = line.toAsciiLower()
            if (lower.startsWith("title ")) {
                title = Some(line["title ".size..line.size].trimAscii())
            } else if (lower.startsWith("dateformat ")) {
                dateFormat = line["dateformat ".size..line.size].trimAscii()
            } else if (lower.startsWith("axisformat ")) {
                axisFormat = line["axisformat ".size..line.size].trimAscii()
            } else if (lower.startsWith("tickinterval ")) {
                tickInterval = line["tickinterval ".size..line.size].trimAscii()
            } else if (lower.startsWith("weekday ")) {
                weekday = line["weekday ".size..line.size].trimAscii()
            } else if (lower == "inclusiveenddates") {
                inclusiveEndDates = true
            } else if (lower.startsWith("todaymarker ")) {
                todayMarker = line["todaymarker ".size..line.size].trimAscii()
            } else if (lower.startsWith("excludes ")) {
                addTokens(excludes, line["excludes ".size..line.size])
            } else if (lower.startsWith("section ")) {
                section = line["section ".size..line.size].trimAscii()
                sections.add(section)
            } else if (lower.startsWith("click ") || lower.startsWith("acc")) {
                ()
            } else if (let Some(colon) <- line.indexOf(":")) {
                let label = line[0..colon].trimAscii()
                let fields = splitCsv(line[(colon + 1)..line.size])
                let built = buildTask(label, section, fields, dateFormat, cursor, tasks.size, generatedId, taskById, inclusiveEndDates, diagnostics, lineNo)
                if (built.isSome()) {
                    let task = built.getOrThrow()
                    tasks.add(task)
                    taskById[task.id] = task
                    cursor = task.end
                    if (task.id.startsWith("task")) {
                        generatedId++
                    }
                }
            } else {
                diagnostics.add("Line ${lineNo}: unsupported gantt statement")
            }
        }

        if (!sawHeader && diagnostics.isEmpty()) {
            diagnostics.add("Missing gantt header")
        }

        return GanttParseResult(
            GanttDiagram(
                source,
                title: title,
                dateFormat: dateFormat,
                axisFormat: axisFormat,
                tickInterval: tickInterval,
                weekday: weekday,
                todayMarker: todayMarker,
                inclusiveEndDates: inclusiveEndDates,
                excludes: excludes.toArray(),
                sections: sections.toArray(),
                tasks: tasks
            ),
            diagnostics: diagnostics.toArray()
        )
    }

    private func buildTask(
        label: String,
        section: String,
        fields: Array<String>,
        dateFormat: String,
        cursor: Int64,
        order: Int64,
        generatedId: Int64,
        taskById: HashMap<String, GanttTask>,
        inclusiveEndDates: Bool,
        diagnostics: ArrayList<String>,
        lineNo: Int64
    ): ?GanttTask {
        if (label.isEmpty()) {
            diagnostics.add("Line ${lineNo}: gantt task label is empty")
            return None
        }
        var done = false
        var active = false
        var crit = false
        var milestone = false
        var vert = false
        let positional = ArrayList<String>()
        for (field in fields) {
            let trimmed = field.trimAscii()
            if (trimmed.isEmpty()) {
                continue
            }
            match (trimmed.toAsciiLower()) {
                case "done" => done = true
                case "active" => active = true
                case "crit" => crit = true
                case "milestone" => milestone = true
                case "vert" => vert = true
                case _ => positional.add(trimmed)
            }
        }

        var id = "task${generatedId}"
        var start = cursor
        var end = cursor
        if (positional.size == 1) {
            end = resolveEnd(positional[0], dateFormat, start, taskById, diagnostics, lineNo)
        } else if (positional.size == 2) {
            start = resolveStart(positional[0], dateFormat, cursor, taskById, diagnostics, lineNo)
            end = resolveEnd(positional[1], dateFormat, start, taskById, diagnostics, lineNo)
        } else if (positional.size >= 3) {
            id = positional[0]
            start = resolveStart(positional[1], dateFormat, cursor, taskById, diagnostics, lineNo)
            end = resolveEnd(positional[2], dateFormat, start, taskById, diagnostics, lineNo)
        } else {
            end = start + minutesForDuration("1d")
        }

        if (inclusiveEndDates && positional.size > 0 && isDateLike(positional[positional.size - 1], dateFormat)) {
            end += minutesForDuration("1d")
        }
        if (end < start) {
            diagnostics.add("Line ${lineNo}: gantt task end precedes start")
            return None
        }
        return Some(GanttTask(label, section, id, start, end, order, done: done, active: active, crit: crit, milestone: milestone, vert: vert))
    }

    private func resolveStart(token: String, dateFormat: String, cursor: Int64, taskById: HashMap<String, GanttTask>, diagnostics: ArrayList<String>, lineNo: Int64): Int64 {
        let lower = token.toAsciiLower()
        if (lower.startsWith("after ")) {
            return latestEnd(token["after ".size..token.size], cursor, taskById)
        }
        if (isDuration(lower)) {
            return cursor
        }
        if (isDateLike(token, dateFormat)) {
            return parseDate(token, dateFormat, diagnostics, lineNo)
        }
        return cursor
    }

    private func resolveEnd(token: String, dateFormat: String, start: Int64, taskById: HashMap<String, GanttTask>, diagnostics: ArrayList<String>, lineNo: Int64): Int64 {
        let lower = token.toAsciiLower()
        if (lower.startsWith("until ")) {
            return earliestStart(token["until ".size..token.size], start, taskById)
        }
        if (isDuration(lower)) {
            return start + minutesForDuration(lower)
        }
        if (isDateLike(token, dateFormat)) {
            return parseDate(token, dateFormat, diagnostics, lineNo)
        }
        return start + minutesForDuration("1d")
    }

    private func latestEnd(idsText: String, fallback: Int64, taskById: HashMap<String, GanttTask>): Int64 {
        var value = fallback
        for (id in idsText.trimAscii().split(" ", removeEmpty: true)) {
            if (let Some(task) <- taskById.get(id.trimAscii())) {
                if (task.end > value) {
                    value = task.end
                }
            }
        }
        return value
    }

    private func earliestStart(idsText: String, fallback: Int64, taskById: HashMap<String, GanttTask>): Int64 {
        var value = fallback
        var found = false
        for (id in idsText.trimAscii().split(" ", removeEmpty: true)) {
            if (let Some(task) <- taskById.get(id.trimAscii())) {
                if (!found || task.start < value) {
                    value = task.start
                    found = true
                }
            }
        }
        return value
    }

    private func isDateLike(token: String, dateFormat: String): Bool {
        let text = token.trimAscii()
        if (dateFormat == "x" || dateFormat == "X" || dateFormat == "ss") {
            return startsWithDigit(text)
        }
        if (dateFormat == "YYYY") {
            return text.size >= 4 && startsWithDigit(text)
        }
        if (dateFormat == "HH:mm") {
            return text.size >= 5 && text[2] == b':'
        }
        return text.size >= 10 && text[4] == b'-' && text[7] == b'-'
    }

    private func parseDate(token: String, dateFormat: String, diagnostics: ArrayList<String>, lineNo: Int64): Int64 {
        let text = token.trimAscii()
        if (dateFormat == "x") {
            return parseAsciiInt(text) / 60000
        }
        if (dateFormat == "X" || dateFormat == "ss") {
            return parseAsciiInt(text) / 60
        }
        if (dateFormat == "YYYY") {
            return parseAsciiInt(text) * 525600
        }
        if (dateFormat == "HH:mm") {
            return parseAsciiInt(text[0..2]) * 60 + parseAsciiInt(text[3..5])
        }
        if (!isDateLike(text, dateFormat)) {
            diagnostics.add("Line ${lineNo}: invalid gantt date '${text}' for ${dateFormat}")
            return 0
        }
        let year = parseAsciiInt(text[0..4])
        let month = parseAsciiInt(text[5..7])
        let day = parseAsciiInt(text[8..10])
        return (year * 372 + month * 31 + day) * 1440
    }

    private func isDuration(text: String): Bool {
        return text.endsWith("ms") || text.endsWith("s") || text.endsWith("m") || text.endsWith("h") ||
            text.endsWith("d") || text.endsWith("w") || text.endsWith("M") || text.endsWith("y")
    }

    private func minutesForDuration(text: String): Int64 {
        if (text.endsWith("ms")) {
            return max(1, parseAsciiInt(text[0..max(0, text.size - 2)]) / 60000)
        }
        if (text.endsWith("s")) {
            return max(1, parseAsciiInt(text[0..max(0, text.size - 1)]) / 60)
        }
        if (text.endsWith("m")) {
            return max(1, parseAsciiInt(text[0..max(0, text.size - 1)]))
        }
        if (text.endsWith("h")) {
            return max(1, parseAsciiInt(text[0..max(0, text.size - 1)]) * 60)
        }
        if (text.endsWith("w")) {
            return max(1, parseAsciiInt(text[0..max(0, text.size - 1)]) * 10080)
        }
        if (text.endsWith("M")) {
            return max(1, parseAsciiInt(text[0..max(0, text.size - 1)]) * 43200)
        }
        if (text.endsWith("y")) {
            return max(1, parseAsciiInt(text[0..max(0, text.size - 1)]) * 525600)
        }
        return max(1, parseAsciiInt(text[0..max(0, text.size - 1)]) * 1440)
    }

    private func splitCsv(text: String): Array<String> {
        let out = ArrayList<String>()
        for (part in text.split(",", removeEmpty: true)) {
            out.add(part.trimAscii())
        }
        return out.toArray()
    }

    private func addTokens(out: ArrayList<String>, text: String): Unit {
        for (chunk in text.split(",", removeEmpty: true)) {
            for (token in chunk.split(" ", removeEmpty: true)) {
                let trimmed = token.trimAscii()
                if (!trimmed.isEmpty() && !contains(out, trimmed)) {
                    out.add(trimmed)
                }
            }
        }
    }

    private func contains(values: ArrayList<String>, target: String): Bool {
        for (value in values) {
            if (value == target) {
                return true
            }
        }
        return false
    }

    private func startsWithDigit(text: String): Bool {
        return !text.isEmpty() && text[0] >= b'0' && text[0] <= b'9'
    }

    private func parseAsciiInt(text: String): Int64 {
        var value: Int64 = 0
        for (i in 0..text.size) {
            let ch = text[i]
            if (ch >= b'0' && ch <= b'9') {
                value = value * 10 + Int64(ch - b'0')
            }
        }
        return value
    }

    private func stripComment(line: String): String {
        if (let Some(pos) <- line.indexOf("%%")) {
            return line[0..pos]
        }
        return line
    }
}
