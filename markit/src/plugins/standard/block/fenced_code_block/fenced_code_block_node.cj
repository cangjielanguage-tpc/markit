package markit.plugins.standard.block.fenced_code_block

import std.collection.ArrayList
import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class FencedCodeBlockNode <: Node {
    public let language: String
    public let fenceMarker: Byte
    public let fenceLength: Int64
    public let highlightLines: String
    public let i18nLines: String
    public let fileGroups: ArrayList<FencedCodeBlockFileGroup>

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        literal: String,
        language: String,
        fenceMarker: Byte,
        fenceLength: Int64,
        highlightLines!: String = "",
        i18nLines!: String = "",
        fileGroups!: ArrayList<FencedCodeBlockFileGroup> = ArrayList<FencedCodeBlockFileGroup>()
    ) {
        super(
            "FencedCodeBlock",
            id: id,
            sourceSpan: sourceSpan,
            literal: literal,
            info: language
        )
        this.language = language
        this.fenceMarker = fenceMarker
        this.fenceLength = fenceLength
        this.highlightLines = highlightLines
        this.i18nLines = i18nLines
        this.fileGroups = fileGroups
    }

    public func content(): String {
        return literal
    }

    public override prop name: String {
        get() {
            return "FencedCodeBlockNode"
        }
    }

    public override func toString(): String {
        let sb = StringBuilder()
        sb.append("${name} [language=${language}, fenceChar=${String.fromUtf8([fenceMarker])}, fenceLength=${fenceLength}] (${rawContent()})\n")
        for (child in children) {
            sb.append("  ")
            sb.append(child.toString().replace("\n", "\n  "))
        }
        return sb.toString()
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("language").value(language)
        w.name("fenceChar").value(String.fromUtf8([fenceMarker]))
        w.name("fenceLength").value(fenceLength)
        w.name("content").value(content())
        w.name("highlightLines").value(highlightLines)
        w.name("i18nLines").value(i18nLines)
        w.name("fileGroupCount").value(fileGroups.size)
        return w
    }
}
