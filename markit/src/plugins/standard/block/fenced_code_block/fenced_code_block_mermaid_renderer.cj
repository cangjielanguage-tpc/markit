package markit.plugins.standard.block.fenced_code_block

import mermaid4cj.{MermaidHtmlOptions, MermaidHtmlThemeMode, MermaidRenderer}

class FencedCodeBlockMermaidRenderer {
    static func renderInto(node: FencedCodeBlockNode, config: FencedCodeBlockConfig): Unit {
        if (!config.enableMermaid || !node.fileGroups.isEmpty() || normalizeLanguage(node.language) != "mermaid") {
            return
        }

        let result = try {
            MermaidRenderer().renderMarkitHtml(
                node.literal,
                options: MermaidHtmlOptions(
                    themeMode: MermaidHtmlThemeMode.Dual,
                    classPrefix: "mk-mermaid",
                    idPrefix: "mk-mermaid-${node.id}"
                )
            )
        } catch (e: Exception) {
            throw IllegalArgumentException("mermaid render failed for fenced code node=${node.id}: ${e.toString()}")
        }
        node.setString("mermaid4cj.html", result.html)
    }

    private static func normalizeLanguage(language: String): String {
        return language.trimAscii().toAsciiLower()
    }
}
