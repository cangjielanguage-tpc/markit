package markit_kit.utils

import markit.core.nodes.Node

/** Visible prose only: 400 CJK characters/minute and 200 Latin words/minute. */
public class ReadingStatistics {
    public ReadingStatistics(public let cjkCharacters: Int64, public let words: Int64) {}

    public prop totalTexts: Int64 {
        get() { cjkCharacters + words }
    }

    public prop estimatedSeconds: Int64 {
        // In twentieths of a second: 3 per CJK character, 6 per Latin word.
        get() { (cjkCharacters * 3 + words * 6 + 19) / 20 }
    }

    public static func fromDocument(document: Node): ReadingStatistics {
        let text = StringBuilder()
        appendText(document, text)
        var cjk = 0
        var words = 0
        var inWord = false
        for (rune in text.toString().runes()) {
            let code = UInt32(rune)
            if (isCjk(code)) {
                cjk++
                inWord = false
            } else if ((code >= 65 && code <= 90) || (code >= 97 && code <= 122) ||
                (code >= 48 && code <= 57) || (code >= 0xC0 && code <= 0xD6) ||
                (code >= 0xD8 && code <= 0xF6) || (code >= 0xF8 && code <= 0x2AF)) {
                if (!inWord) {
                    words++
                }
                inWord = true
            } else if (!((code == 39 || code == 0x2019 || code == 45 || code == 95) && inWord)) {
                inWord = false
            }
        }
        return ReadingStatistics(cjk, words)
    }

    private static func isCjk(code: UInt32): Bool {
        return (code >= 0x3400 && code <= 0x4DBF) || (code >= 0x4E00 && code <= 0x9FFF) ||
            (code >= 0x20000 && code <= 0x323AF) ||
            (code >= 0x3040 && code <= 0x30FF) || (code >= 0xAC00 && code <= 0xD7AF) ||
            (code >= 0xF900 && code <= 0xFAFF)
    }

    private static func appendText(node: Node, text: StringBuilder): Unit {
        if (node.string("render") == Some("false")) {
            return
        }
        if (node.kind == "FencedCodeBlock" || node.kind == "MathBlock" || node.kind == "InlineMath" ||
            node.kind == "HTMLBlock" || node.kind == "HTMLInline" || node.kind == "Image") {
            return
        }
        if (node.kind == "Text" || node.kind == "InlineCode") {
            text.append(node.literal)
            return
        }
        if (node.kind == "SoftBreak" || node.kind == "HardBreak") {
            text.append(" ")
            return
        }
        for (child in node.children) {
            appendText(child, text)
        }
        if (node.kind == "Paragraph" || node.kind == "Heading" || node.kind == "TableCell") {
            text.append(" ")
        }
    }
}
