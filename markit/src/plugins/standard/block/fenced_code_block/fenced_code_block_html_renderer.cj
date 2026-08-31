package markit.plugins.standard.block.fenced_code_block

import markit.core.nodes.Node
import markit.core.render.{HtmlEscaper, HtmlRenderer, HtmlWriter, RenderRegistry}
import markit.plugins.anchor.AnchorRenderUtils

public class FencedCodeBlockHtmlRenderer <: HtmlRenderer {
    private let config: FencedCodeBlockConfig

    public init(config!: FencedCodeBlockConfig = FencedCodeBlockConfig()) {
        this.config = config
    }

    public prop ownerPlugin: String {
        get() {
            return "FencedCodeBlockPlugin"
        }
    }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        if (let fenced: FencedCodeBlockNode <- node) {
            if (!fenced.fileGroups.isEmpty()) {
                writeGroupedBlocks(fenced, out, registry)
            } else {
                writeSingleBlock(
                    fenced,
                    fenced.language,
                    fenced.highlightLines,
                    fenced.i18nLines,
                    fenced.literal,
                    out,
                    registry,
                    allowCodehlHtml: true
                )
            }
            return
        }

        writeSingleBlock(node, node.info, "", "", node.literal, out, registry, allowCodehlHtml: true)
    }

    private func writeGroupedBlocks(node: FencedCodeBlockNode, out: HtmlWriter, registry: RenderRegistry): Unit {
        out.raw("<div class=\"code-block-group${registry.htmlClassSuffix(node)}\">")
        out.raw("<div class=\"code-tabs\">")
        for (index in 0..node.fileGroups.size) {
            let group = node.fileGroups[index]
            let activeClass = if (index == 0) { " active" } else { "" }
            let fileIconClass = iconClass(group.filename)
            out.raw("<button class=\"code-tab${activeClass}\" data-tab=\"${index}\">")
            if (!fileIconClass.isEmpty()) {
                out.raw("<span class=\"file-icon ${fileIconClass}\"></span>")
            }
            out.raw("<span class=\"file-name\">")
            out.text(group.filename)
            out.raw("</span>")
            out.raw("</button>")
        }
        out.raw("</div>")

        out.raw("<div class=\"code-panels\">")
        for (index in 0..node.fileGroups.size) {
            let group = node.fileGroups[index]
            let activeClass = if (index == 0) { " active" } else { "" }
            out.raw("<div class=\"code-panel${activeClass}\" data-panel=\"${index}\">")
            writeSingleBlock(
                node,
                group.language,
                group.highlightLines,
                group.i18nLines,
                group.content,
                out,
                registry,
                allowCodehlHtml: true
            )
            out.raw("</div>")
        }
        out.raw("</div>")
        out.raw("</div>")
    }

    private func writeSingleBlock(
        node: Node,
        language: String,
        highlightLines: String,
        i18nLines: String,
        content: String,
        out: HtmlWriter,
        registry: RenderRegistry,
        allowCodehlHtml!: Bool = true
    ): Unit {
        if (allowCodehlHtml && node.string("mermaid4cj.html").isSome()) {
            writeAnchorWrapperOpen(node, out)
            writeMermaidHtml(node, out)
            writeAnchorWrapperClose(node, out)
            return
        }
        if (allowCodehlHtml && shouldWriteCodehlHtml(node, language)) {
            writeAnchorWrapperOpen(node, out)
            writeCodehlHtml(node, language, highlightLines, i18nLines, content, out)
            writeAnchorWrapperClose(node, out)
            return
        }
        out.raw("<pre${AnchorRenderUtils.htmlAttributes(node, registry)}><code")
        if (!language.isEmpty()) {
            out.raw(" class=\"language-${HtmlEscaper.escape(language)}\"")
        }
        if (!highlightLines.isEmpty()) {
            out.raw(" data-highlight-lines=\"${HtmlEscaper.escape(highlightLines)}\"")
        }
        if (!i18nLines.isEmpty()) {
            out.raw(" data-i18n-lines=\"${HtmlEscaper.escape(i18nLines)}\"")
        }
        out.raw(">")
        out.text(content)
        out.raw("</code></pre>")
    }

    private func writeMermaidHtml(node: Node, out: HtmlWriter): Bool {
        if (let Some(html) <- node.string("mermaid4cj.html")) {
            out.raw(html)
            return true
        }
        return false
    }

    private func shouldWriteCodehlHtml(node: Node, language: String): Bool {
        if (node.string("codehl.html.dual").isSome() || node.string("codehl.html.light").isSome() || node.string("codehl.html.dark").isSome()) {
            return true
        }
        return config.enableCodehl && isHighlightableLanguage(language)
    }

    private func writeAnchorWrapperOpen(node: Node, out: HtmlWriter): Unit {
        if (let Some(id) <- node.string("anchor.id")) {
            let escaped = HtmlEscaper.escape(id)
            out.raw("<div id=\"${escaped}\" data-anchor-id=\"${escaped}\"${AnchorRenderUtils.htmlSourceAttributes(node)} class=\"markit-anchor-target generated-block-anchor\">")
        }
    }

    private func writeAnchorWrapperClose(node: Node, out: HtmlWriter): Unit {
        if (node.string("anchor.id").isSome()) {
            out.raw("</div>")
        }
    }

    private func writeCodehlHtml(node: Node, language: String, highlightLines: String, i18nLines: String, content: String, out: HtmlWriter): Bool {
        if (let Some(dual) <- node.string("codehl.html.dual")) {
            out.raw(dual)
            return true
        }

        let light = node.string("codehl.html.light")
        let dark = node.string("codehl.html.dark")
        if (light.isNone() && dark.isNone()) {
            if (!config.enableCodehl || !isHighlightableLanguage(language)) {
                return false
            }
            let fragments = FencedCodeBlockCodehlRenderer.renderContentWithConfig(content, language, highlightLines, i18nLines, config)
            writeDualThemeHtml(fragments.lightHtml, fragments.darkHtml, out)
            return true
        }

        var lightHtml = ""
        var darkHtml = ""
        if (let Some(html) <- light) {
            lightHtml = html
        }
        if (let Some(html) <- dark) {
            darkHtml = html
        }
        writeDualThemeHtml(lightHtml, darkHtml, out)
        return true
    }

    private func isHighlightableLanguage(language: String): Bool {
        if (language.isEmpty()) {
            return false
        }
        let normalized = language.toAsciiLower()
        return normalized != "plain" && normalized != "text"
    }

    private func writeDualThemeHtml(lightHtml: String, darkHtml: String, out: HtmlWriter): Unit {
        out.raw("<div class=\"codehl-dual-theme\" data-codehl=\"native\" data-codehl-theme=\"dual\">")
        out.raw("<div class=\"codehl-theme codehl-theme-light\">")
        out.raw(lightHtml)
        out.raw("</div>")
        out.raw("<div class=\"codehl-theme codehl-theme-dark\">")
        out.raw(darkHtml)
        out.raw("</div>")
        out.raw("</div>")
    }

    private func iconClass(filename: String): String {
        let extension = fileExtension(filename)
        if (extension.isEmpty()) {
            return ""
        }
        match (extension) {
            case "cj" | "cangjie" =>
                return "icon-cj"
            case "js" | "ts" | "json" | "md" | "markdown" | "bash" | "sh" | "shell" =>
                return "icon-${HtmlEscaper.escape(extension)}"
            case _ =>
                return ""
        }
    }

    private func fileExtension(filename: String): String {
        if (let Some(index) <- filename.lastIndexOf('.')) {
            if (index + 1 < filename.size) {
                return filename[(index + 1)..].toAsciiLower()
            }
        }
        return ""
    }
}
