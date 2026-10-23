package markit.plugins.standard.inline.link

import markit.core.nodes.Node
import markit.core.render.{MarkdownRenderer, RenderRegistry, TextWriter}

public class LinkMarkdownRenderer <: MarkdownRenderer {
    public LinkMarkdownRenderer(private let resolver!: SmartHeadingLinkResolver = SmartHeadingLinkResolver(LinkConfig())) {}

    public prop ownerPlugin: String {
        get() {
            return "LinkPlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        if (let link: LinkNode <- node) {
            let (resolvedUrl, _) = resolver.resolve(link.url, LinkRenderUtils.extractText(node))
            out.write("[")
            for (child in node.children) {
                registry.writeMarkdown(child, out)
            }
            if (link.title.isEmpty()) {
                out.write("](${resolvedUrl})")
            } else {
                out.write("](${resolvedUrl} \"${link.title}\")")
            }
        }
    }
}
