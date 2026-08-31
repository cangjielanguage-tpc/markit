package markit.plugins.gfm.inline.footnote

import markit.core.nodes.Node
import markit.core.render.{HtmlEscaper, HtmlRenderer, HtmlWriter, MarkdownRenderer, RenderRegistry, StringTextWriter, TextWriter, TypstRenderer}

public class FootnoteDefinitionHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "FootnotePlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        if (let definition: FootnoteDefinitionNode <- node) {
            out.raw("<div id=\"fn:")
            out.raw(HtmlEscaper.escape(definition.footnoteId))
            out.raw("\" class=\"footnote-definition${registry.htmlClassSuffix(node)}\">")
            for (child in definition.children) {
                registry.writeHtml(child, out)
            }
            out.raw("</div>")
        }
    }
}

public class FootnoteDefinitionMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "FootnotePlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        if (let definition: FootnoteDefinitionNode <- node) {
            out.write("[^${definition.footnoteId}]: ")
            for (child in definition.children) {
                registry.writeMarkdown(child, out)
            }
            out.write("\n\n")
        }
    }
}

public class FootnoteDefinitionTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "FootnotePlugin"
        }
    }

    public func writeTypst(_: Node, _: TextWriter, _: RenderRegistry): Unit {
    }
}

public class FootnoteReferenceHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "FootnotePlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        if (let reference: FootnoteReferenceNode <- node) {
            out.raw("<a id=\"fnref:")
            out.raw(HtmlEscaper.escape(reference.footnoteId))
            out.raw("\" href=\"#fn:")
            out.raw(HtmlEscaper.escape(reference.footnoteId))
            out.raw("\" class=\"footnote-ref${registry.htmlClassSuffix(node)}\">")
            out.raw(reference.footnoteNumber.toString())
            out.raw("</a>")
        }
    }
}

public class FootnoteReferenceMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "FootnotePlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, _: RenderRegistry): Unit {
        if (let reference: FootnoteReferenceNode <- node) {
            out.write("[^${reference.footnoteId}]")
        }
    }
}

public class FootnoteReferenceTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "FootnotePlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        if (let reference: FootnoteReferenceNode <- node) {
            if (let Some(definition) <- findDefinition(reference)) {
                let body = renderDefinitionBody(definition, registry).trimAscii()
                if (!body.isEmpty()) {
                    out.write("#footnote[")
                    out.write(body)
                    out.write("]")
                    return
                }
            }
            out.write(reference.rawContent())
        }
    }

    private func findDefinition(reference: FootnoteReferenceNode): ?FootnoteDefinitionNode {
        var current: ?Node = Some(reference)
        while (let Some(node) <- current) {
            if (node.parent.isNone()) {
                return findDefinitionInTree(node, reference.footnoteId)
            }
            current = node.parent
        }
        return None
    }

    private func findDefinitionInTree(node: Node, footnoteId: String): ?FootnoteDefinitionNode {
        if (let definition: FootnoteDefinitionNode <- node) {
            if (definition.footnoteId == footnoteId) {
                return Some(definition)
            }
        }
        for (child in node.children) {
            if (let Some(found) <- findDefinitionInTree(child, footnoteId)) {
                return Some(found)
            }
        }
        return None
    }

    private func renderDefinitionBody(definition: FootnoteDefinitionNode, registry: RenderRegistry): String {
        let writer = StringTextWriter()
        for (child in definition.children) {
            registry.writeTypst(child, writer)
        }
        return writer.toString()
    }
}
