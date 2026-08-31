package markit.plugins.gfm.block.math_block

import markit.core.nodes.Node
import markit.core.render.{HtmlEscaper, HtmlRenderer, HtmlWriter, MarkdownRenderer, RenderRegistry, TextWriter, TypstRenderer}
import markit.plugins.anchor.AnchorRenderUtils
import markit.utils.{TextRenderUtils, TypstRenderUtils}
import mathtex.{MathRenderOptions, MathRenderer}

public class MathBlockConfig {
    public let enableHtmlMathtex: Bool
    public let enableTypstMathtex: Bool
    public let autoAnchor: Bool

    public init(enableHtmlMathtex!: Bool = true, enableTypstMathtex!: Bool = true, autoAnchor!: Bool = false) {
        this.enableHtmlMathtex = enableHtmlMathtex
        this.enableTypstMathtex = enableTypstMathtex
        this.autoAnchor = autoAnchor
    }
}

public class MathBlockHtmlRenderer <: HtmlRenderer {
    private let config: MathBlockConfig

    public init(config!: MathBlockConfig = MathBlockConfig()) {
        this.config = config
    }

    public prop ownerPlugin: String {
        get() {
            return "MathBlockPlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        if (let math: MathBlockNode <- node) {
            if (config.enableHtmlMathtex) {
                let rendered = try {
                    MathRenderer().renderHtmlAndMathMl(math.content, options: MathRenderOptions(displayMode: true))
                } catch (e: Exception) {
                    throw IllegalArgumentException("mathtex HTML render failed for block math node=${node.id}: ${e.toString()}")
                }
                if (rendered.supported && !rendered.output.isEmpty()) {
                    if (let Some(id) <- node.string("anchor.id")) {
                        let escaped = HtmlEscaper.escape(id)
                        out.raw("<div id=\"${escaped}\" data-anchor-id=\"${escaped}\"${AnchorRenderUtils.htmlSourceAttributes(node)} class=\"markit-anchor-target math-anchor\">")
                        out.raw(rendered.output)
                        out.raw("</div>")
                        return
                    }
                    out.raw(rendered.output)
                    return
                }
            }
            out.raw("<div${AnchorRenderUtils.htmlClassAttribute("math-block", node, registry)}>")
            out.raw(HtmlEscaper.escape(math.content))
            out.raw("</div>")
        }
    }
}

public class MathBlockMarkdownRenderer <: MarkdownRenderer {
    public prop ownerPlugin: String {
        get() {
            return "MathBlockPlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, _: RenderRegistry): Unit {
        if (let math: MathBlockNode <- node) {
            let prefix = TextRenderUtils.indentSpaces(math.indentLevel)
            out.write(prefix)
            out.write("$$" + AnchorRenderUtils.markdownLabel(math) + "\n")
            if (!math.content.isEmpty()) {
                let lines = math.content.split("\n")
                for (i in 0..lines.size) {
                    if (i > 0) {
                        out.write("\n")
                    }
                    out.write(prefix)
                    out.write(lines[i])
                }
                out.write("\n")
            }
            out.write(prefix)
            out.write("$$\n\n")
        }
    }
}

public class MathBlockTypstRenderer <: TypstRenderer {
    private let config: MathBlockConfig

    public init(config!: MathBlockConfig = MathBlockConfig()) {
        this.config = config
    }

    public prop ownerPlugin: String {
        get() {
            return "MathBlockPlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, _: RenderRegistry): Unit {
        if (let math: MathBlockNode <- node) {
            if (config.enableTypstMathtex) {
                let rendered = try {
                    MathRenderer().renderTypst(math.content, options: MathRenderOptions(displayMode: true))
                } catch (e: Exception) {
                    throw IllegalArgumentException("mathtex Typst render failed for block math node=${node.id}: ${e.toString()}")
                }
                if (rendered.supported && !rendered.output.isEmpty()) {
                    out.write(rendered.output.trimAsciiEnd() + AnchorRenderUtils.typstLabel(math) + "\n\n")
                    return
                }
            }
            out.write(TypstRenderUtils.renderRawBlock(math.content, lang: "text").trimAsciiEnd() + AnchorRenderUtils.typstLabel(math) + "\n\n")
        }
    }
}
