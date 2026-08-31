package markit.plugins.gfm.block.table

import std.collection.ArrayList

public class TableParsingUtils {
    public static func isTableRow(line: String): Bool {
        if (line.isEmpty()) {
            return false
        }
        var pipeCount: Int64 = 0
        var escaped = false
        var codeFenceLength: Int64 = 0
        var index: Int64 = 0
        while (index < line.size) {
            let width = nextRuneByteSize(line, index)
            if (width == 0) {
                break
            }
            let byte = line[index]
            if (escaped) {
                escaped = false
            } else if (byte == b'\\') {
                escaped = true
            } else if (byte == b'`') {
                let run = backtickRunLength(line, index)
                if (codeFenceLength == 0) {
                    codeFenceLength = run
                } else if (run == codeFenceLength) {
                    codeFenceLength = 0
                }
                index += run
                continue
            } else if (byte == b'|' && codeFenceLength == 0) {
                pipeCount += 1
            }
            index += width
        }
        return pipeCount > 0
    }

    public static func parseRow(line: String): ArrayList<String> {
        let cells = ArrayList<String>()
        let current = StringBuilder()
        var escaped = false
        var index: Int64 = 0
        while (index < line.size) {
            let width = nextRuneByteSize(line, index)
            if (width == 0) {
                break
            }
            let byte = line[index]
            if (escaped) {
                current.append(line[index..index + width])
                escaped = false
            } else if (byte == b'\\') {
                current.append("\\")
                escaped = true
            } else if (byte == b'`') {
                let run = backtickRunLength(line, index)
                current.append(line[index..index + run])
                index += run
                while (index < line.size) {
                    let innerWidth = nextRuneByteSize(line, index)
                    if (innerWidth == 0) {
                        break
                    }
                    let innerByte = line[index]
                    if (innerByte == b'`') {
                        let closingRun = backtickRunLength(line, index)
                        current.append(line[index..index + closingRun])
                        index += closingRun
                        if (closingRun == run) {
                            break
                        }
                        continue
                    }
                    current.append(line[index..index + innerWidth])
                    index += innerWidth
                }
                continue
            } else if (byte == b'|') {
                cells.add(current.toString())
                current.reset()
            } else {
                current.append(line[index..index + width])
            }
            index += width
        }
        cells.add(current.toString())

        if (!cells.isEmpty() && cells[0].trimAscii().isEmpty()) {
            cells.remove(at: 0)
        }
        if (!cells.isEmpty() && cells[cells.size - 1].trimAscii().isEmpty()) {
            cells.remove(at: cells.size - 1)
        }
        return cells
    }

    private static func backtickRunLength(text: String, startByte: Int64): Int64 {
        var length: Int64 = 0
        while (startByte + length < text.size && text[startByte + length] == b'`') {
            length += 1
        }
        return length
    }

    public static func parseAlignmentRow(line: String): ArrayList<TableAlignment> {
        let alignments = ArrayList<TableAlignment>()
        let cells = parseRow(line)
        if (cells.isEmpty()) {
            return alignments
        }

        for (cell in cells) {
            let trimmed = cell.trimAscii()
            if (!isAlignmentCell(trimmed)) {
                return ArrayList<TableAlignment>()
            }
            alignments.add(parseAlignment(trimmed))
        }
        return alignments
    }

    public static func alignmentMarkdown(alignment: TableAlignment): String {
        match (alignment) {
            case Left => return ":---"
            case Center => return ":---:"
            case Right => return "---:"
            case None => return "---"
        }
    }

    private static func isAlignmentCell(cell: String): Bool {
        if (cell.isEmpty()) {
            return false
        }
        var hasDash = false
        for (byte in cell) {
            if (byte == b'-') {
                hasDash = true
            } else if (byte == b':' || byte == b' ' || byte == b'\t') {
            } else {
                return false
            }
        }
        return hasDash
    }

    private static func parseAlignment(cell: String): TableAlignment {
        let trimmed = cell.trimAscii()
        let startsWithColon = !trimmed.isEmpty() && trimmed[0] == b':'
        let endsWithColon = !trimmed.isEmpty() && trimmed[trimmed.size - 1] == b':'
        if (startsWithColon && endsWithColon) {
            return TableAlignment.Center
        }
        if (startsWithColon) {
            return TableAlignment.Left
        }
        if (endsWithColon) {
            return TableAlignment.Right
        }
        return TableAlignment.None
    }

    private static func nextRuneByteSize(text: String, startByte: Int64): Int64 {
        for (rune in text[startByte..].runes()) {
            return String([rune]).size
        }
        return 0
    }
}
