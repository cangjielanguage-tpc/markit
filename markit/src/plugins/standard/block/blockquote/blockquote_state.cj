package markit.plugins.standard.block.blockquote

import std.collection.ArrayList
import markit.core.block.{BlockState, RestorableBlockState}
import markit.core.source.{SourceLine, SourceSpan}
import markit.plugins.standard.editing.StandardBlockRecovery

public class BlockquoteState <: RestorableBlockState {
    public let lines = ArrayList<SourceLine>()
    public var recovery: ?StandardBlockRecovery = None

    public BlockquoteState(public var sourceSpan: SourceSpan) {}

    public func addLine(text: String, line: SourceLine): Unit {
        let prefix = if (recovery.isSome()) { line.text.size - text.size } else { 0 }
        let span = SourceSpan(line.span.startByte + prefix, line.span.endByte,
            line.span.startRune + prefix, line.span.endRune)
        lines.add(SourceLine(text, span, terminated: line.terminated))
        sourceSpan = sourceSpan.merge(line.span)
    }
    public func copyBlockState(): BlockState {
        let copy = BlockquoteState(sourceSpan)
        copy.recovery = recovery
        for (line in lines) { copy.lines.add(SourceLine(line.text, line.span, terminated: line.terminated)) }
        return copy
    }
    public prop blockStateFingerprint: String {
        get() {
            let value = StringBuilder()
            for (line in lines) { value.append("${line.text.size}:${line.text}:${line.terminated};") }
            return value.toString()
        }
    }
}
