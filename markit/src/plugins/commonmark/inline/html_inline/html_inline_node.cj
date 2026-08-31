package markit.plugins.commonmark.inline.html_inline

import std.collection.{ArrayList, HashMap}
import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan
import markit.plugins.commonmark.HtmlAttributeUtils

public enum HTMLTagType <: ToString {
    |OpeningTag
    |ClosingTag
    |SelfClosing
    |Container
    |Invalid

    public override func toString(): String {
        match (this) {
            case OpeningTag => return "OpeningTag"
            case ClosingTag => return "ClosingTag"
            case SelfClosing => return "SelfClosing"
            case Container => return "Container"
            case Invalid => return "Invalid"
        }
    }

    public operator func ==(right: HTMLTagType): Bool {
        return this.toString() == right.toString()
    }
}

public class HTMLInlineNode <: Node {
    public let tagName: String
    public let tagType: HTMLTagType
    public let isContentProtected: Bool
    public let attributes: HashMap<String, String>
    public let attributesStr: String

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        tagName: String,
        tagType: HTMLTagType,
        htmlContent: String,
        isContentProtected!: Bool = false,
        attributes!: HashMap<String, String> = HashMap<String, String>(),
        attributesStr!: String = ""
    ) {
        super("HTMLInline", id: id, sourceSpan: sourceSpan, literal: htmlContent)
        this.tagName = tagName
        this.tagType = tagType
        this.isContentProtected = isContentProtected
        this.attributes = attributes
        this.attributesStr = attributesStr
        setRawContent(htmlContent)
    }

    public override prop name: String {
        get() {
            return "HTMLInlineNode"
        }
    }

    public func htmlContent(renderedChildren: String): String {
        if (isContainer()) {
            let attrs = if (attributesStr.isEmpty()) { HtmlAttributeUtils.build(attributes) } else { attributesStr }
            let open = if (attrs.isEmpty()) { "<${tagName}>" } else { "<${tagName} ${attrs}>" }
            return convertMarkdownHref(open + renderedChildren + "</${tagName}>")
        }
        return convertMarkdownHref(rawContent())
    }

    public func isOpeningTag(): Bool {
        return tagType == OpeningTag
    }

    public func isClosingTag(): Bool {
        return tagType == ClosingTag
    }

    public func isContainer(): Bool {
        return tagType == Container
    }

    public func isInvalid(): Bool {
        return tagType == Invalid
    }

    public override func toString(): String {
        let result = StringBuilder()
        result.append("${name} [tagName=${tagName}, tagType=${tagType.toString()}] (${rawContent()})")
        for (child in children) {
            let childStr = child.toString()
            for (line in childStr.split('\n')) {
                result.append("\n  ")
                result.append(line)
            }
        }
        return result.toString()
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("tagName").value(tagName)
        w.name("tagType").value(tagType.toString())
        w.name("isContentProtected").value(isContentProtected)
        return w
    }

    private func convertMarkdownHref(content: String): String {
        if (tagName != "a") {
            return content
        }
        if (let Some(href) <- attributes.get("href")) {
            if (href.endsWith(".md") && !href.startsWith("http://") && !href.startsWith("https://")) {
                return content.replace(href, href[0..href.size - 3] + ".html")
            }
        }
        return content
    }
}
