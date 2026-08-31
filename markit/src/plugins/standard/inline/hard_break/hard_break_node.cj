package markit.plugins.standard.inline.hard_break

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public enum BreakType <: ToString {
    | TwoSpaces
    | Backslash

    public override func toString(): String {
        match (this) {
            case TwoSpaces => return "TwoSpaces"
            case Backslash => return "Backslash"
        }
    }
}

public class HardBreakNode <: Node {
    public let breakType: BreakType

    public init(id: Int64, sourceSpan: SourceSpan, breakType: BreakType) {
        super("HardBreak", id: id, sourceSpan: sourceSpan, literal: match (breakType) {
            case TwoSpaces => "  \n"
            case Backslash => "\\\n"
        })
        this.breakType = breakType
    }

    public override prop name: String {
        get() {
            return "HardBreakNode"
        }
    }

    public override func toString(): String {
        return "${name} [breakType=${breakType}] (${rawContent()})"
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("breakType").value(breakType.toString())
        return w
    }
}
