package markit.plugins.i18n.block

import std.collection.ArrayList
import markit.core.block.{BlockFrame, ContinuationBlockParser, ContinueResult}
import markit.core.nodes.Node
import markit.core.session.{ParagraphTermination, ParseSession}
import markit.core.source.{SourceLine, SyntheticSourceBuilder}
import markit.plugins.gfm.block.BlockLineUtils
import markit.plugins.i18n.nodes.{I18nBlockNode, UniversalBlockNode}

public class I18nBlockParser <: ContinuationBlockParser {
    public prop name: String {
        get() {
            return "I18nBlockParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "I18nPlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 80
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b':']
        }
    }

    public func tryStart(session: ParseSession, line: String): ?BlockFrame {
        if (let Some(start) <- parseOpening(session, line)) {
            return Some(BlockFrame(I18nBlockState(
                start.languageId,
                start.universal,
                start.indentLevel,
                SourceLine(line, session.currentLineSpan(), terminated: session.currentSourceLine().terminated)
            )))
        }
        return None
    }

    public func continueBlock(session: ParseSession, frame: BlockFrame, line: String): ContinueResult {
        let state = (frame.state as I18nBlockState).getOrThrow()
        if (isClosingLine(line, state.indentLevel)) {
            state.close(session.currentSourceLine())
            return Closed
        }

        state.addContentLine(SourceLine(
            BlockLineUtils.removeLeadingIndent(line, state.indentLevel),
            session.currentLineSpan(),
            terminated: session.currentSourceLine().terminated
        ))
        return Open
    }

    public func finalize(session: ParseSession, frame: BlockFrame): Node {
        let state = (frame.state as I18nBlockState).getOrThrow()
        if (!state.closed) {
            return fallbackParagraph(session, state)
        }

        let contentLines = ArrayList<String>()
        for (line in state.contentLines) {
            contentLines.add(line.text)
        }
        let content = String.join(contentLines.toArray(), delimiter: "\n")
        let node = if (state.universal) {
            session.attachNode(UniversalBlockNode(
                session.allocateNodeId(),
                state.sourceSpan,
                content
            ))
        } else {
            session.attachNode(I18nBlockNode(
                session.allocateNodeId(),
                state.sourceSpan,
                state.languageId,
                content
            ))
        }
        node.setRawContent(buildRawContent(state))

        if (!state.contentLines.isEmpty()) {
            let synthetic = SyntheticSourceBuilder.build(state.contentLines, preserveTrailingNewline: false)
            for (child in session.parseDetachedLines(synthetic.lines)) {
                child.attachSource(synthetic.source)
                freezeSyntheticRawContent(child)
                node.addChild(child)
            }
        }
        return node
    }

    private func parseOpening(session: ParseSession, line: String): ?I18nBlockStart {
        let indent = BlockLineUtils.indentationWidth(line)
        if (indent > 4 && !session.allowDeepIndentedBlockStart()) {
            return None
        }
        let trimmed = line.trimAscii()
        if (!trimmed.startsWith(":::")) {
            return None
        }
        let languageId = if (trimmed.size > 3) {
            trimmed[3..].trimAscii()
        } else {
            ""
        }
        if (languageId.contains(" ")) {
            return None
        }
        return Some(I18nBlockStart(languageId, languageId.isEmpty(), indent))
    }

    private func isClosingLine(line: String, openingIndent: Int64): Bool {
        let indent = BlockLineUtils.indentationWidth(line)
        if (indent > openingIndent) {
            return false
        }
        return line.trimAscii() == ":::"
    }

    private func fallbackParagraph(session: ParseSession, state: I18nBlockState): Node {
        let lines = ArrayList<SourceLine>()
        lines.add(state.openingLine)
        for (line in state.contentLines) {
            lines.add(line)
        }
        return session.createParagraphNode(lines, state.sourceSpan, ParagraphTermination.EndOfInput)
    }

    private func buildRawContent(state: I18nBlockState): String {
        let sb = StringBuilder()
        sb.append(state.openingLine.text)
        if (state.openingLine.terminated) {
            sb.append("\n")
        }
        for (line in state.contentLines) {
            sb.append(line.text)
            if (line.terminated) {
                sb.append("\n")
            }
        }
        if (let Some(line) <- state.closingLine) {
            sb.append(line.text)
            if (line.terminated) {
                sb.append("\n")
            }
        }
        return sb.toString()
    }

    private func freezeSyntheticRawContent(node: Node): Unit {
        node.setRawContent(node.rawContent())
        for (child in node.children) {
            freezeSyntheticRawContent(child)
        }
    }
}

private struct I18nBlockStart {
    public let languageId: String
    public let universal: Bool
    public let indentLevel: Int64

    public init(languageId: String, universal: Bool, indentLevel: Int64) {
        this.languageId = languageId
        this.universal = universal
        this.indentLevel = indentLevel
    }
}
