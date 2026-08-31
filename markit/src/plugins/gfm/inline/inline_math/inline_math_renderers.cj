package markit.plugins.gfm.inline.inline_math

import markit.core.nodes.Node
import markit.core.render.{HtmlEscaper, HtmlRenderer, HtmlWriter, MarkdownRenderer, RenderRegistry, TextWriter, TypstRenderer}
import markit.utils.TypstRenderUtils
import mathtex.{MathRenderOptions, MathRenderer}

public class InlineMathConfig {
    public let enableHtmlMathtex: Bool
    public let enableTypstMathtex: Bool

    public init(enableHtmlMathtex!: Bool = true, enableTypstMathtex!: Bool = true) {
        this.enableHtmlMathtex = enableHtmlMathtex
        this.enableTypstMathtex = enableTypstMathtex
    }
}

public class InlineMathHtmlRenderer <: HtmlRenderer {
    private let config: InlineMathConfig

    public init(config!: InlineMathConfig = InlineMathConfig()) {
        this.config = config
    }

    public prop ownerPlugin: String {
        get() {
            return "InlineMathPlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        if (let math: InlineMathNode <- node) {
            if (config.enableHtmlMathtex) {
                let rendered = try {
                    MathRenderer().renderHtmlAndMathMl(math.content, options: MathRenderOptions(displayMode: false))
                } catch (e: Exception) {
                    throw IllegalArgumentException("mathtex HTML render failed for inline math node=${node.id}: ${e.toString()}")
                }
                if (rendered.supported && !rendered.output.isEmpty()) {
                    out.raw(rendered.output)
                    return
                }
            }
            out.raw("<span class=\"math inline${registry.htmlClassSuffix(node)}\">")
            out.raw(HtmlEscaper.escape(math.content))
            out.raw("</span>")
        }
    }
}

public class InlineMathMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "InlineMathPlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, _: RenderRegistry): Unit {
        if (let math: InlineMathNode <- node) {
            out.write("$")
            out.write(math.content)
            out.write("$")
        }
    }
}

public class InlineMathTypstRenderer <: TypstRenderer {
    private let config: InlineMathConfig

    public init(config!: InlineMathConfig = InlineMathConfig()) {
        this.config = config
    }

    public prop ownerPlugin: String {
        get() {
            return "InlineMathPlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, _: RenderRegistry): Unit {
        if (let math: InlineMathNode <- node) {
            if (config.enableTypstMathtex) {
                let rendered = try {
                    MathRenderer().renderTypst(math.content, options: MathRenderOptions(displayMode: false))
                } catch (e: Exception) {
                    throw IllegalArgumentException("mathtex Typst render failed for inline math node=${node.id}: ${e.toString()}")
                }
                if (rendered.supported && !rendered.output.isEmpty()) {
                    out.write(rendered.output)
                    return
                }
            }
            out.write(TypstRenderUtils.renderRawInline(math.content))
        }
    }
}
