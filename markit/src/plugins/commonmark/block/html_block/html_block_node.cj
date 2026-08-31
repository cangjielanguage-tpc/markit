package markit.plugins.commonmark.block.html_block

import std.collection.{ArrayList, HashMap}
import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan
import markit.plugins.commonmark.HtmlAttributeUtils

public enum HTMLBlockType <: ToString {
    |Comment
    |Processing
    |Declaration
    |CDATA
    |SafeBlockTag

    public override func toString(): String {
        match (this) {
            case Comment => return "Comment"
            case Processing => return "Processing"
            case Declaration => return "Declaration"
            case CDATA => return "CDATA"
            case SafeBlockTag => return "SafeBlockTag"
        }
    }

    public operator func ==(right: HTMLBlockType): Bool {
        return this.toString() == right.toString()
    }
}

public class HTMLBlockNode <: Node {
    public let blockType: HTMLBlockType
    public let tagName: String
    public let isSelfClosing: Bool
    public let isContentProtected: Bool
    public let attributes: HashMap<String, String>

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        raw: String,
        blockType: HTMLBlockType,
        tagName!: String = "",
        isSelfClosing!: Bool = false,
        isContentProtected!: Bool = false,
        attributes!: HashMap<String, String> = HashMap<String, String>()
    ) {
        super("HTMLBlock", id: id, sourceSpan: sourceSpan, literal: raw)
        this.blockType = blockType
        this.tagName = tagName
        this.isSelfClosing = isSelfClosing
        this.isContentProtected = isContentProtected
        this.attributes = attributes
        setRawContent(raw)
    }

    public override prop name: String {
        get() {
            return "HTMLBlockNode"
        }
    }

    public override func toString(): String {
        let result = StringBuilder()
        result.append("${name} [blockType=${blockType.toString()}, tagName=${tagName}] (${rawContent()})")
        for (child in children) {
            let childStr = child.toString()
            for (line in childStr.split('\n')) {
                result.append("\n  ")
                result.append(line)
            }
        }
        return result.toString()
    }

    public func isSafeBlockTagType(): Bool {
        return blockType == SafeBlockTag
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("blockType").value(blockType.toString())
        w.name("tagName").value(tagName)
        w.name("isSelfClosing").value(isSelfClosing)
        w.name("isContentProtected").value(isContentProtected)
        w.name("attributes").value(HtmlAttributeUtils.build(attributes))
        return w
    }
}
