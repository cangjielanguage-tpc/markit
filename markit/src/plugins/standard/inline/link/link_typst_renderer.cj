package markit.plugins.standard.inline.link

import markit.core.nodes.Node
import markit.core.render.{RenderRegistry, TextWriter, TypstRenderer}
import markit.utils.TypstEscaper

public class LinkTypstRenderer <: TypstRenderer {
    private let resolver: SmartHeadingLinkResolver

    public init(resolver!: SmartHeadingLinkResolver = SmartHeadingLinkResolver(LinkConfig())) {
        this.resolver = resolver
    }

    public prop ownerPlugin: String {
        get() {
            return "LinkPlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, registry: RenderRegistry): Unit {
        if (let link: LinkNode <- node) {
            let (resolvedUrl, _) = resolver.resolve(link.url, LinkRenderUtils.extractText(node))
            if (resolvedUrl.startsWith("#") && resolvedUrl.size > 1 && !resolvedUrl.contains(".")) {
                out.write("#link(<${resolvedUrl[1..]}>)[")
            } else {
                out.write("#link(\"${TypstEscaper.escapeString(resolvedUrl)}\")[")
            }
            for (child in node.children) {
                registry.writeTypst(child, out)
            }
            out.write("]")
        }
    }
}
