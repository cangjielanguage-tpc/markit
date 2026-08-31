package markit.plugins.gfm.block

import markit.core.source.SourceSpan
import markit.plugins.standard.block.fenced_code_block.FencedCodeBlockParsingUtils

public class BlockLineUtils {
    public static func indentationWidth(line: String): Int64 {
        return FencedCodeBlockParsingUtils.indentationWidth(line)
    }

    public static func removeLeadingIndent(line: String, spacesToRemove: Int64): String {
        return FencedCodeBlockParsingUtils.removeLeadingIndent(line, spacesToRemove)
    }

    public static func firstNonWhitespaceIndex(line: String): ?Int64 {
        var index: Int64 = 0
        while (index < line.size && (line[index] == b' ' || line[index] == b'\t')) {
            index += 1
        }
        if (index >= line.size) {
            return None
        }
        return Some(index)
    }

    public static func countRunes(text: String): Int64 {
        var count: Int64 = 0
        for (_ in text.runes()) {
            count += 1
        }
        return count
    }

    public static func lineSubSpan(
        baseSpan: SourceSpan,
        line: String,
        startByte: Int64,
        endByte: Int64
    ): SourceSpan {
        let prefix = if (startByte > 0) { line[0..startByte] } else { "" }
        let text = if (endByte > startByte) { line[startByte..endByte] } else { "" }
        let startRuneDelta = countRunes(prefix)
        let endRuneDelta = startRuneDelta + countRunes(text)
        return baseSpan.slice(startByte, endByte, startRuneDelta, endRuneDelta)
    }

    public static func isAsciiLetter(byte: Byte): Bool {
        return (byte >= b'a' && byte <= b'z') || (byte >= b'A' && byte <= b'Z')
    }

    public static func isAsciiUpper(byte: Byte): Bool {
        return byte >= b'A' && byte <= b'Z'
    }

    public static func nextAsciiLetter(byte: Byte): Byte {
        if (byte == b'z') {
            return b'a'
        }
        if (byte == b'Z') {
            return b'A'
        }
        return byte + 1
    }
}
