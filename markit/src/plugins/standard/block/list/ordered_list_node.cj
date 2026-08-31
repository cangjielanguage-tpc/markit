package markit.plugins.standard.block.list

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class OrderedListNode <: Node {
    public let tight: Bool
    public let baseIndent: Int64
    public let startNumber: Int64
    public let delimiter: Byte

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        tight: Bool,
        baseIndent: Int64,
        startNumber: Int64,
        delimiter: Byte
    ) {
        super("List", id: id, sourceSpan: sourceSpan)
        this.tight = tight
        this.baseIndent = baseIndent
        this.startNumber = startNumber
        this.delimiter = delimiter
        setBool("ordered", true)
        setBool("tight", tight)
        setInt("startNumber", startNumber)
        setInt("baseIndent", baseIndent)
        setString("delimiter", String.fromUtf8([delimiter]))
    }

    public override prop name: String {
        get() {
            return "OrderedListNode"
        }
    }

    public override func toString(): String {
        let sb = StringBuilder()
        sb.append("${name} [tight=${tight}, startNumber=${startNumber}, delimiter=${String.fromUtf8([delimiter])}] (${rawContent()})\n")
        for (child in children) {
            sb.append("  ")
            sb.append(child.toString().replace("\n", "\n  "))
        }
        return sb.toString()
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("tight").value(tight)
        w.name("baseIndent").value(baseIndent)
        w.name("startNumber").value(startNumber)
        w.name("delimiter").value(String.fromUtf8([delimiter]))
        return w
    }
}
