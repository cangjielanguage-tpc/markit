package markit.core.inline

import std.collection.ArrayList
import markit.core.nodes.Node
import markit.core.session.ParseSession
import markit.core.source.SourceSpan

public class InlineParserEngine {
    private let dispatchTable: InlineDispatchTable

    public init(dispatchTable: InlineDispatchTable) {
        this.dispatchTable = dispatchTable
    }

    public func parse(session: ParseSession, text: String, baseSpan: SourceSpan): ArrayList<Node> {
        return parseRange(session, text, 0, text.size, baseSpan)
    }

    public func parseRange(session: ParseSession, text: String, startByte: Int64, endByte: Int64, baseSpan: SourceSpan): ArrayList<Node> {
        let nodes = ArrayList<Node>()
        let summary = dispatchTable.scanRange(text, startByte, endByte)
        let totalRunes = summary.runeCount
        if (startByte < endByte && !summary.mayHaveCandidates) {
            nodes.add(session.createTextNode(
                InlineUtils.processEscapes(text, startByte, endByte),
                InlineUtils.spanWithRunes(baseSpan, 0, endByte - startByte, 0, totalRunes)
            ))
            return nodes
        }

        var byteIndex = startByte
        var runeIndex: Int64 = 0
        var textStartByte = startByte
        var textStartRune: Int64 = 0

        func flushText(): Unit {
            if (textStartByte >= byteIndex) {
                return
            }
            nodes.add(session.createTextNode(
                InlineUtils.processEscapes(text, textStartByte, byteIndex),
                InlineUtils.spanWithRunes(baseSpan, textStartByte - startByte, byteIndex - startByte, textStartRune, runeIndex)
            ))
            textStartByte = byteIndex
            textStartRune = runeIndex
        }

        while (byteIndex < endByte) {
            var parsed = false
            let candidates = dispatchTable.candidatesFor(text[byteIndex])
            if (!candidates.isEmpty() && !InlineUtils.isEscaped(text, byteIndex, startByte)) {
                let cursorSpan = InlineUtils.spanWithRunes(baseSpan, byteIndex - startByte, endByte - startByte, runeIndex, totalRunes)
                for (parser in candidates) {
                    if (let Some(result) <- parser.tryParse(
                        session,
                        text,
                        byteIndex,
                        endByte,
                        cursorSpan
                    )) {
                        flushText()
                        nodes.add(result.node)
                        byteIndex += result.consumedBytes
                        runeIndex += result.consumedRunes
                        textStartByte = byteIndex
                        textStartRune = runeIndex
                        parsed = true
                        break
                    }
                }
            }
            if (parsed) {
                continue
            }

            let width = InlineUtils.nextRuneByteSize(text, byteIndex)
            if (width == 0) {
                break
            }
            byteIndex += width
            runeIndex += 1
        }

        flushText()
        return nodes
    }
}
