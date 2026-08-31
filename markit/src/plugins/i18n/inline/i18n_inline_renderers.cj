package markit.plugins.i18n.inline

import markit.core.nodes.Node
import markit.core.render.{HtmlRenderer, HtmlWriter, MarkdownRenderer, RenderRegistry, TextWriter, TypstRenderer}

public class I18nInlineHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "I18nPlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        for (child in node.children) {
            registry.writeHtml(child, out)
        }
        if (node.children.isEmpty()) {
            out.text(node.literal)
        }
    }
}

public class I18nInlineMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "I18nPlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        for (child in node.children) {
            registry.writeMarkdown(child, out)
        }
        if (node.children.isEmpty()) {
            out.write(node.literal)
        }
    }
}

public class I18nInlineTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "I18nPlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        for (child in node.children) {
            registry.writeTypst(child, out)
        }
        if (node.children.isEmpty()) {
            out.write(node.literal)
        }
    }
}
