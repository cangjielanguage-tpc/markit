package markit.plugins.i18n.inline

import markit.core.inline.{InlineParseResult, InlineParser, InlineUtils}
import markit.core.nodes.Node
import markit.core.session.ParseSession
import markit.core.source.SourceSpan
import markit.plugins.i18n.nodes.{I18nInlineNode, UniversalInlineNode}

public class I18nInlineParser <: InlineParser {
    public prop name: String {
        get() {
            return "I18nInlineParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "I18nPlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 450
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b':']
        }
    }

    public func tryParse(session: ParseSession, input: String, startByte: Int64, endByte: Int64, baseSpan: SourceSpan): ?InlineParseResult {
        if (endByte - startByte < 4 || input[startByte] != b':') {
            return None
        }

        var pos: Int64 = startByte + 1
        let languageStart = pos
        while (pos < endByte && input[pos] != b'{') {
            if (input[pos] == b'\n' || input[pos] == b'\r' || input[pos] == b':') {
                return None
            }
            pos += InlineUtils.nextRuneByteSize(input, pos)
        }

        if (pos >= endByte || input[pos] != b'{') {
            return None
        }
        let languageId = input[languageStart..pos]
        pos += 1

        let contentStart = pos
        var braceDepth: Int64 = 1
        while (pos < endByte && braceDepth > 0) {
            if (input[pos] == b'\n' || input[pos] == b'\r') {
                return None
            }
            if (!InlineUtils.isEscaped(input, pos, startByte) && input[pos] == b'{') {
                braceDepth += 1
                pos += 1
                continue
            }
            if (!InlineUtils.isEscaped(input, pos, startByte) && input[pos] == b'}') {
                braceDepth -= 1
                pos += 1
                continue
            }
            pos += InlineUtils.nextRuneByteSize(input, pos)
        }

        if (braceDepth != 0 || pos >= endByte || input[pos] != b':') {
            return None
        }

        let contentEnd = pos - 1
        let content = input[contentStart..contentEnd]
        pos += 1

        let raw = input[startByte..pos]
        let consumedBytes = pos - startByte
        let rawRunes = InlineUtils.countRunes(input, startByte, pos)
        let contentRunes = InlineUtils.countRunes(content)
        let node: Node = if (languageId.isEmpty()) {
            session.attachNode(UniversalInlineNode(
                session.allocateNodeId(),
                InlineUtils.spanWithRunes(baseSpan, 0, consumedBytes, 0, rawRunes),
                content,
                raw
            ))
        } else {
            session.attachNode(I18nInlineNode(
                session.allocateNodeId(),
                InlineUtils.spanWithRunes(baseSpan, 0, consumedBytes, 0, rawRunes),
                languageId,
                content,
                raw
            ))
        }

        if (!content.isEmpty()) {
            let contentStartRunes = InlineUtils.countRunes(input, startByte, contentStart)
            session.appendInlineChildren(
                node,
                content,
                InlineUtils.spanWithRunes(
                    baseSpan,
                    contentStart - startByte,
                    contentEnd - startByte,
                    contentStartRunes,
                    contentStartRunes + contentRunes
                )
            )
        }

        return Some(InlineParseResult(node, consumedBytes, rawRunes))
    }
}
