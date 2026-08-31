package markit.tests.unit.streaming

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.core.incremental.AstPatchKind
import markit.plugins.standard.inline.link.LinkNode

@Test
@Tag[Streaming]
class IncrementalStateTests {
    @TestCase
    func pendingTailDescribesOpenParagraphAfterCompleteLine() {
        let session = Markit().createSession()
        let update = session.feed("段落\n")

        @Expect(update.sealedBlocks.size, 0)
        @Expect(update.pendingTailState.summary, "pending paragraph")
        @Expect(update.pendingTailState.openBlockKind, "Paragraph")
        @Expect(update.pendingTailState.pendingParagraphLineCount, 1)
        @Expect(update.pendingTailState.previewText, "段落")
        @Expect(update.pendingTailState.startByteOffset, 0)
        @Expect(update.pendingTailState.endByteOffset, 6)
        @Expect(update.pendingTailState.startRuneOffset, 0)
        @Expect(update.pendingTailState.endRuneOffset, 2)
    }

    @TestCase
    func pendingTailDescribesOpenContinuationBlock() {
        let session = Markit().createSession()
        let update = session.feed("```cj\n")

        @Expect(update.sealedBlocks.size, 0)
        @Expect(update.pendingTailState.hasPendingContent(), true)
        @Expect(update.pendingTailState.summary, "open block: FencedCodeBlockParser")
        @Expect(update.pendingTailState.openBlockKind, "FencedCodeBlockParser")
        @Expect(update.pendingTailState.previewText, "```cj")
    }

    @TestCase
    func documentSnapshotIndexesNodesLinesAndStableHash() {
        let direct = Markit().parse("# 标题\n\n段落\n")
        let snapshot = direct.snapshot
        let heading = direct.root().children[0]

        @Expect(snapshot.nodeById(heading.id).getOrThrow().kind, "Heading")
        @Expect(snapshot.nodesInByteRange(0, 8).size, 3)
        @Expect(snapshot.lineAt(0).text, "# 标题")
        @Expect(snapshot.lineIndex.size, 3)

        let streaming = Markit().createSession()
        streaming.feed("# 标题\n")
        streaming.feed("\n段落\n")
        streaming.finalize()
        @Expect(streaming.snapshot().stableHash(), snapshot.stableHash())
    }

    @TestCase
    func finalUpdatePatchesForwardReferenceLinkWithRenderedOutputs() {
        let session = Markit().createSession()
        let first = session.feed("[example][ref]\n\n")

        @Expect(first.sealedBlocks.size, 1)
        @Expect(first.emittedHtmlFragments[0].html, "<p><a href=\"\">example</a></p>")
        @Expect(first.astPatches.size, 0)

        session.feed("[ref]: https://example.com \"Example\"\n")
        let finalUpdate = session.finalize()

        @Expect(finalUpdate.astPatches.size, 1)
        let patch = finalUpdate.astPatches[0]
        match (patch.kind) {
            case AstPatchKind.ReplaceNode => ()
            case _ => throw IllegalArgumentException("Expected ReplaceNode patch")
        }
        @Expect(patch.html, "<p><a href=\"https://example.com\" title=\"Example\">example</a></p>")
        @Expect(patch.markdown, "[example](https://example.com \"Example\")\n\n")
        @Expect(patch.typst, "#link(\"https://example.com\")[example]\n\n")
        @Expect(patch.sourceSpan.startByte, 0)
        @Expect(patch.sourceSpan.endByte, 14)
        if (let Some(node) <- patch.node) {
            @Expect(node.kind, "Paragraph")
            if (let link: LinkNode <- node.children[0]) {
                @Expect(link.url, "https://example.com")
                @Expect(link.title, "Example")
            }
        }
        @Expect(session.snapshot().root.toHtml(), "<p><a href=\"https://example.com\" title=\"Example\">example</a></p>")
    }

    @TestCase
    func documentSnapshotRangeLookupFindsNestedInlineNodes() {
        let out = Markit().parse("前缀 [链接](https://example.com) 后缀\n")
        let matches = out.snapshot.nodesInByteRange(7, 13)

        var foundLink = false
        var foundText = false
        for (node in matches) {
            if (node.kind == "Link") {
                foundLink = true
            }
            if (node.kind == "Text" && node.rawContent() == "链接") {
                foundText = true
            }
        }

        @Expect(foundLink, true)
        @Expect(foundText, true)
    }
}
