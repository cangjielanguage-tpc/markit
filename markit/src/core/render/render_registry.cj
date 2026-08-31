package markit.core.render

import std.collection.{ArrayList, HashMap}
import std.io.OutputStream
import markit.core.nodes.{Node, NodeRenderHooks}
import markit.utils.TypstEscaper

public class RenderRegistry <: NodeRenderHooks {
    private let htmlRenderers = HashMap<String, HtmlRenderer>()
    private let markdownRenderers = HashMap<String, MarkdownRenderer>()
    private let typstRenderers = HashMap<String, TypstRenderer>()
    private let htmlConfig: HtmlConfig

    public init(htmlConfig!: HtmlConfig = HtmlConfig()) {
        this.htmlConfig = htmlConfig
    }

    public func registerHtmlRenderer(kind: String, renderer: HtmlRenderer): Unit {
        if (htmlRenderers.contains(kind)) {
            throw IllegalArgumentException("Duplicate html renderer for node kind: ${kind}")
        }
        htmlRenderers[kind] = renderer
    }

    public func registerMarkdownRenderer(kind: String, renderer: MarkdownRenderer): Unit {
        if (markdownRenderers.contains(kind)) {
            throw IllegalArgumentException("Duplicate markdown renderer for node kind: ${kind}")
        }
        markdownRenderers[kind] = renderer
    }

    public func registerTypstRenderer(kind: String, renderer: TypstRenderer): Unit {
        if (typstRenderers.contains(kind)) {
            throw IllegalArgumentException("Duplicate typst renderer for node kind: ${kind}")
        }
        typstRenderers[kind] = renderer
    }

    public func writeHtml(node: Node, out: HtmlWriter): Unit {
        if (node.string("render") == Some("false")) {
            return
        }
        if (node.kind == "Document") {
            if (htmlConfig.isRootWrapperEnabled()) {
                out.raw("<")
                out.raw(htmlConfig.getRootWrapperTag())
                out.raw(htmlConfig.rootClassAttribute())
                out.raw(">")
            }
            for (child in node.children) {
                writeHtml(child, out)
            }
            if (htmlConfig.isRootWrapperEnabled()) {
                out.raw("</")
                out.raw(htmlConfig.getRootWrapperTag())
                out.raw(">")
            }
            return
        }

        if (let Some(renderer) <- htmlRenderers.get(node.kind)) {
            renderer.writeHtml(node, out, this)
            return
        }

        out.text(node.literal)
    }

    public func renderHtml(node: Node): String {
        let writer = StringHtmlWriter()
        writeHtml(node, writer)
        return writer.toString()
    }

    public func writeHtml(node: Node, out: OutputStream): Unit {
        let writer = OutputStreamHtmlWriter(out)
        writeHtml(node, writer)
        writer.flush()
    }

    public func toHtml(node: Node): String {
        return renderHtml(node)
    }

    public func htmlClassAttribute(node: Node): String {
        return htmlConfig.classAttribute(htmlClassNodeTypes(node))
    }

    public func htmlClassSuffix(node: Node): String {
        return htmlConfig.classSuffix(htmlClassNodeTypes(node))
    }

    private func htmlClassNodeTypes(node: Node): ArrayList<String> {
        let nodeTypes = ArrayList<String>()
        addNodeType(nodeTypes, node.name)
        if (node.kind == "Heading") {
            addNodeType(nodeTypes, "HeadingNode")
        }
        addNodeType(nodeTypes, node.kind + "Node")
        return nodeTypes
    }

    private func addNodeType(nodeTypes: ArrayList<String>, nodeType: String): Unit {
        if (!nodeType.isEmpty() && !nodeTypes.contains(nodeType)) {
            nodeTypes.add(nodeType)
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter): Unit {
        if (node.string("render") == Some("false")) {
            return
        }
        if (node.kind == "Document") {
            for (child in node.children) {
                writeMarkdown(child, out)
            }
            return
        }

        if (let Some(renderer) <- markdownRenderers.get(node.kind)) {
            renderer.writeMarkdown(node, out, this)
            return
        }

        if (!node.children.isEmpty()) {
            for (child in node.children) {
                writeMarkdown(child, out)
            }
            return
        }
        out.write(node.literal)
    }

    public func renderMarkdown(node: Node): String {
        let writer = StringTextWriter()
        writeMarkdown(node, writer)
        return writer.toString()
    }

    public func writeMarkdown(node: Node, out: OutputStream): Unit {
        let writer = OutputStreamTextWriter(out)
        writeMarkdown(node, writer)
        writer.flush()
    }

    public func toMarkdown(node: Node): String {
        return renderMarkdown(node)
    }

    public func writeTypst(node: Node, out: TextWriter): Unit {
        if (node.string("render") == Some("false")) {
            return
        }
        if (node.kind == "Document") {
            for (child in node.children) {
                writeTypst(child, out)
            }
            return
        }

        if (node.kind == "Text") {
            out.write(TypstEscaper.escapeText(node.literal))
            return
        }

        if (let Some(renderer) <- typstRenderers.get(node.kind)) {
            renderer.writeTypst(node, out, this)
            return
        }

        if (!node.children.isEmpty()) {
            for (child in node.children) {
                writeTypst(child, out)
            }
            return
        }
        out.write(node.literal)
    }

    public func renderTypst(node: Node): String {
        let writer = StringTextWriter()
        writeTypst(node, writer)
        return writer.toString()
    }

    public func writeTypst(node: Node, out: OutputStream): Unit {
        let writer = OutputStreamTextWriter(out)
        writeTypst(node, writer)
        writer.flush()
    }

    public func toTypst(node: Node): String {
        return renderTypst(node)
    }
}

public class HtmlRendererRegistration {
    public let kind: String
    public let renderer: HtmlRenderer

    public init(kind: String, renderer: HtmlRenderer) {
        this.kind = kind
        this.renderer = renderer
    }
}
