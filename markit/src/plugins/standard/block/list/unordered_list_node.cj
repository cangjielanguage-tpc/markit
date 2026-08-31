package markit.plugins.standard.block.list

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class UnorderedListNode <: Node {
    public let tight: Bool
    public let baseIndent: Int64

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        tight: Bool,
        baseIndent: Int64
    ) {
        super("List", id: id, sourceSpan: sourceSpan)
        this.tight = tight
        this.baseIndent = baseIndent
        setBool("ordered", false)
        setBool("tight", tight)
        setInt("baseIndent", baseIndent)
    }

    public override prop name: String {
        get() {
            return "UnorderedListNode"
        }
    }

    public override func toString(): String {
        let sb = StringBuilder()
        sb.append("${name} [tight=${tight}, baseIndent=${baseIndent}] (${rawContent()})\n")
        for (child in children) {
            sb.append("  ")
            sb.append(child.toString().replace("\n", "\n  "))
        }
        return sb.toString()
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("tight").value(tight)
        w.name("baseIndent").value(baseIndent)
        return w
    }
}
