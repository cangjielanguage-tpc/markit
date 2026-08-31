package markit.plugins.standard.block.fenced_code_block

import std.collection.ArrayList
import markit.core.block.{BlockFrame, ContinuationBlockParser, ContinueResult}
import markit.core.nodes.Node
import markit.core.session.ParseSession
import markit.core.source.SourceLine

public class FencedCodeBlockParser <: ContinuationBlockParser {
    private let config: FencedCodeBlockConfig

    public init(config!: FencedCodeBlockConfig = FencedCodeBlockConfig()) {
        this.config = config
    }

    public prop name: String {
        get() {
            return "FencedCodeBlockParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "FencedCodeBlockPlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 100
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b'`', b'~']
        }
    }

    public func tryStart(session: ParseSession, line: String): ?BlockFrame {
        if (let Some(startInfo) <- FencedCodeBlockParsingUtils.detectOpeningFence(line)) {
            return Some(BlockFrame(FencedCodeBlockState(
                startInfo.marker,
                startInfo.fenceLength,
                startInfo.indentWidth,
                startInfo.language,
                startInfo.highlightLines,
                startInfo.i18nLines,
                SourceLine(line, session.currentLineSpan(), terminated: session.currentSourceLine().terminated)
            )))
        }
        return None
    }

    public func continueBlock(session: ParseSession, frame: BlockFrame, line: String): ContinueResult {
        let state = (frame.state as FencedCodeBlockState).getOrThrow()
        if (FencedCodeBlockParsingUtils.isClosingFence(
            line,
            state.marker,
            state.fenceLength,
            state.indentWidth
        )) {
            state.close(session.currentSourceLine())
            return Closed
        }
        state.addContentLine(SourceLine(
            FencedCodeBlockParsingUtils.removeLeadingIndent(line, state.indentWidth),
            session.currentLineSpan(),
            terminated: session.currentSourceLine().terminated
        ))
        return Open
    }

    public func finalize(session: ParseSession, frame: BlockFrame): Node {
        let state = (frame.state as FencedCodeBlockState).getOrThrow()
        let contentLines = ArrayList<String>()
        for (line in state.lines) {
            contentLines.add(line.text)
        }
        let literal = FencedCodeBlockParsingUtils.joinLines(contentLines)
        let fileGroups = if (config.enableGroup) {
            FencedCodeBlockParsingUtils.parseFileGroups(
                literal,
                state.language,
                state.highlightLines,
                state.i18nLines
            )
        } else {
            ArrayList<FencedCodeBlockFileGroup>()
        }

        let node = FencedCodeBlockNode(
            session.allocateNodeId(),
            state.sourceSpan,
            literal,
            state.language,
            state.marker,
            state.fenceLength,
            highlightLines: state.highlightLines,
            i18nLines: state.i18nLines,
            fileGroups: fileGroups
        )
        let attached = session.attachNode(node)
        FencedCodeBlockMermaidRenderer.renderInto(node, config)
        FencedCodeBlockCodehlRenderer.renderInto(node, config)
        return attached
    }
}
