package markit.plugins.commonmark.inline.entity_reference

import markit.core.nodes.Node
import markit.core.render.{HtmlEscaper, HtmlRenderer, HtmlWriter, MarkdownRenderer, RenderRegistry, TextWriter, TypstRenderer}
import markit.utils.TypstEscaper

public class EntityReferenceHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "EntityReferencePlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, _: RenderRegistry): Unit {
        if (let entity: EntityReferenceNode <- node) {
            out.raw(entity.entityReference)
        }
    }
}

public class EntityReferenceMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "EntityReferencePlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, _: RenderRegistry): Unit {
        if (let entity: EntityReferenceNode <- node) {
            out.write(entity.entityReference)
        }
    }
}

public class EntityReferenceTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "EntityReferencePlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, _: RenderRegistry): Unit {
        if (let entity: EntityReferenceNode <- node) {
            out.write(TypstEscaper.escapeText(decodeBasic(entity)))
        }
    }

    private func decodeBasic(entity: EntityReferenceNode): String {
        if (!entity.isNamed()) {
            return entity.entityReference
        }
        match (entity.entityValue) {
            case "lt" => return "<"
            case "gt" => return ">"
            case "amp" => return "&"
            case "quot" => return "\""
            case "apos" => return "'"
            case "nbsp" => return " "
            case _ => return entity.entityReference
        }
    }
}
