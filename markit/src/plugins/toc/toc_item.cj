package markit.plugins.toc

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class TocItem <: Node {
    public let text: String
    public let anchorId: String
    public let number: String

    public init(
        text: String,
        level: Int64,
        anchorId: String,
        number!: String = ""
    ) {
        super("TocItem", sourceSpan: SourceSpan.empty(), literal: text, level: level)
        this.text = text
        this.anchorId = anchorId
        this.number = number
    }

    public override prop name: String {
        get() {
            return "TocItem"
        }
    }

    public func addChild(child: TocItem): Unit {
        super.addChild(child)
    }

    public override func toString(): String {
        let sb = StringBuilder()
        sb.append("${name} - ${text} (level=${level}, id=${anchorId}")
        if (!number.isEmpty()) {
            sb.append(", number=${number}")
        }
        sb.append(")")
        for (child in children) {
            let childStr = child.toString()
            for (line in childStr.split('\n')) {
                if (!line.isEmpty()) {
                    sb.append("\n  ")
                    sb.append(line)
                }
            }
        }
        return sb.toString()
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("text").value(text)
        w.name("level").value(level)
        w.name("id").value(anchorId)
        if (!number.isEmpty()) {
            w.name("number").value(number)
        }
        return w
    }
}
