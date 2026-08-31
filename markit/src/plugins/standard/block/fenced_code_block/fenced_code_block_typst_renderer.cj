package markit.plugins.standard.block.fenced_code_block

import std.collection.ArrayList
import markit.core.nodes.Node
import markit.core.render.{RenderRegistry, TextWriter, TypstRenderer}
import markit.plugins.anchor.AnchorRenderUtils
import markit.utils.TypstRenderUtils

public class FencedCodeBlockTypstRenderer <: TypstRenderer {
    private let targetLanguage: String

    public init(targetLanguage!: String = "") {
        this.targetLanguage = targetLanguage
    }

    public prop ownerPlugin: String {
        get() {
            return "FencedCodeBlockPlugin"
        }
    }

    public func writeTypst(node: Node, out: TextWriter, _: RenderRegistry): Unit {
        if (let fenced: FencedCodeBlockNode <- node) {
            if (fenced.fileGroups.isEmpty()) {
                let content = FencedCodeBlockLineRuleUtils.filterContentForLanguage(
                    fenced.content(),
                    fenced.i18nLines,
                    targetLanguage
                )
                out.write(TypstRenderUtils.renderRawBlock(content, lang: fenced.language).trimAsciiEnd() + AnchorRenderUtils.typstLabel(fenced) + "\n\n")
                return
            }

            let groups = ArrayList<String>()
            for (group in fenced.fileGroups) {
                let content = FencedCodeBlockLineRuleUtils.filterContentForLanguage(
                    group.content,
                    group.i18nLines,
                    targetLanguage
                )
                groups.add(TypstRenderUtils.renderRawBlock(content, lang: group.language).trimAsciiEnd())
            }
            out.write(String.join(groups.toArray(), delimiter: "\n\n") + AnchorRenderUtils.typstLabel(fenced) + "\n\n")
            return
        }

        out.write(TypstRenderUtils.renderRawBlock(node.literal).trimAsciiEnd() + AnchorRenderUtils.typstLabel(node) + "\n\n")
    }
}
