package markit.plugins.gfm.block.alphabetic_list

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class AlphabeticListNode <: Node {
    public let tight: Bool
    public let baseIndent: Int64
    public let startLetter: Byte
    public let isUpperCase: Bool
    public let delimiter: Byte

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        tight: Bool,
        baseIndent: Int64,
        startLetter: Byte,
        isUpperCase: Bool,
        delimiter: Byte
    ) {
        super("AlphabeticList", id: id, sourceSpan: sourceSpan)
        this.tight = tight
        this.baseIndent = baseIndent
        this.startLetter = startLetter
        this.isUpperCase = isUpperCase
        this.delimiter = delimiter
        setBool("tight", tight)
        setInt("baseIndent", baseIndent)
        setString("startLetter", String.fromUtf8([startLetter]))
        setBool("isUpperCase", isUpperCase)
        setString("delimiter", String.fromUtf8([delimiter]))
    }

    public override prop name: String {
        get() {
            return "AlphabeticListNode"
        }
    }

    public override func toString(): String {
        let sb = StringBuilder()
        sb.append("${name} [tight=${tight}, startLetter=${String.fromUtf8([startLetter])}, isUpperCase=${isUpperCase}] (${rawContent()})\n")
        for (child in children) {
            sb.append("  ")
            sb.append(child.toString().replace("\n", "\n  "))
        }
        return sb.toString()
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("tight").value(tight)
        w.name("baseIndent").value(baseIndent)
        w.name("startLetter").value(String.fromUtf8([startLetter]))
        w.name("isUpperCase").value(isUpperCase)
        w.name("delimiter").value(String.fromUtf8([delimiter]))
        return w
    }
}
