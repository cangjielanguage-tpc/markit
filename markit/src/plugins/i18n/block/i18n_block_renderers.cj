package markit.plugins.i18n.block

import markit.core.nodes.Node
import markit.core.render.{HtmlRenderer, HtmlWriter, MarkdownRenderer, RenderRegistry, TextWriter, TypstRenderer}

public class I18nBlockHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String {
        get() {
            return "I18nPlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        for (child in node.children) {
            registry.writeHtml(child, out)
        }
    }
}

public class I18nBlockMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "I18nPlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        for (child in node.children) {
            registry.writeMarkdown(child, out)
        }
    }
}

public class I18nBlockTypstRenderer <: TypstRenderer {
    public prop ownerPlugin: String {
        get() {
            return "I18nPlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        for (child in node.children) {
            registry.writeTypst(child, out)
        }
    }
}
