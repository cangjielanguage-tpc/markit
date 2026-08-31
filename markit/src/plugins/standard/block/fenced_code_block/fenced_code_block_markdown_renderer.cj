package markit.plugins.standard.block.fenced_code_block

import markit.core.nodes.Node
import markit.core.render.{MarkdownRenderer, RenderRegistry, TextWriter}
import markit.plugins.anchor.AnchorRenderUtils
import markit.utils.TextRenderUtils

public class FencedCodeBlockMarkdownRenderer <: MarkdownRenderer {
    private let targetLanguage: String

    public init(targetLanguage!: String = "") {
        this.targetLanguage = targetLanguage
    }

    public prop ownerPlugin: String {
        get() {
            return "FencedCodeBlockPlugin"
        }
    }

    public func writeMarkdown(node: Node, out: TextWriter, _: RenderRegistry): Unit {
        if (let fenced: FencedCodeBlockNode <- node) {
            let fence = TextRenderUtils.repeat(String.fromUtf8([fenced.fenceMarker]), fenced.fenceLength)
            let opening = fence + renderInfoSuffix(fenced) + AnchorRenderUtils.markdownLabel(fenced)
            let content = FencedCodeBlockLineRuleUtils.filterContentForLanguage(
                fenced.content(),
                fenced.i18nLines,
                targetLanguage
            )
            out.write(opening + "\n" + content + "\n" + fence + "\n\n")
            return
        }

        out.write("```" + AnchorRenderUtils.markdownLabel(node) + "\n" + node.literal + "\n```\n\n")
    }

    private func renderInfoSuffix(node: FencedCodeBlockNode): String {
        return node.language
    }
}
