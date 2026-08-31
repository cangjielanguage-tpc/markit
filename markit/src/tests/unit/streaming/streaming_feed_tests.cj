package markit.tests.unit.streaming

import std.collection.ArrayList
import std.io.{ByteBuffer, InputStream, readToEnd}
import std.unittest.*
import std.unittest.testmacro.*
import markit.{Markit, ParseCallbacks}
import markit.bundles.GFMBundle
import markit.core.incremental.{AstPatch, HtmlFragment, IncrementalUpdate}
import markit.core.session.ParseOptions
import markit.plugins.i18n.I18nPlugin
import markit.plugins.i18n.config.I18nConfig

@Test
@Tag[Streaming]
class StreamingFeedTests {
    @TestCase
    func feedStringEmitsOnlyStableBlocksInOrder() {
        let session = Markit().createSession()
        let fragments = ArrayList<String>()

        collectFragments(fragments, session.feed("# 中文标题"))
        @Expect(fragments.size, 0)

        collectFragments(fragments, session.feed("\n\n第一段"))
        @Expect(fragments.size, 1)
        @Expect(fragments[0], "<h1 id=\"中文标题\">中文标题</h1>")

        collectFragments(fragments, session.feed("继续\n\n```cj\nlet 值 = 1"))
        @Expect(fragments.size, 2)
        @Expect(fragments[1], "<p>第一段继续</p>")

        collectFragments(fragments, session.feed("\n```\n"))
        @Expect(fragments.size, 3)
        @Expect(fragments[2], Markit().parse("```cj\nlet 值 = 1\n```\n").toHtml())

        let finalUpdate = session.finalize()
        @Expect(finalUpdate.emittedHtmlFragments.size, 0)
        @Expect(session.toHtml(), Markit().parse("# 中文标题\n\n第一段继续\n\n```cj\nlet 值 = 1\n```\n").toHtml())
    }

    @TestCase
    func feedBytesHandlesChineseSplitAtEveryByteAndMatchesDirect() {
        let markdown = "# 标题\n\n段落含中文 and `代码`\n\n---\n"
        let direct = Markit().parse(markdown)
        let session = Markit().createSession()
        let fragments = ArrayList<String>()
        var updateCount: Int64 = 0

        for (byte in markdown.toArray()) {
            collectFragments(fragments, session.feedBytes([byte]))
            updateCount += 1
        }
        let finalUpdate = session.finalize()
        collectFragments(fragments, finalUpdate)

        @Expect(updateCount, markdown.toArray().size)
        @Expect(String.join(fragments.toArray()), direct.toHtml())
        @Expect(session.toMarkdown(), direct.toMarkdown())
        @Expect(session.toTypst(), direct.toTypst())
        @Expect(session.toJson(), direct.toJson())
    }

    @TestCase
    func openContinuationBlocksDoNotEmitUntilSealedOrFinalized() {
        let fenceSession = Markit().createSession()
        let firstFence = fenceSession.feed("```cj\nlet x = 1")
        @Expect(firstFence.sealedBlocks.size, 0)
        @Expect(firstFence.emittedHtmlFragments.size, 0)
        let closedFence = fenceSession.feed("\n```\n")
        @Expect(closedFence.sealedBlocks.size, 1)
        @Expect(closedFence.emittedHtmlFragments[0].html, Markit().parse("```cj\nlet x = 1\n```\n").toHtml())

        let listSession = Markit().createSession()
        let openList = listSession.feed("- 第一项\n- 第二项")
        @Expect(openList.sealedBlocks.size, 0)
        @Expect(openList.emittedHtmlFragments.size, 0)
        let finalList = listSession.finalize()
        @Expect(finalList.sealedBlocks.size, 1)
        @Expect(finalList.emittedHtmlFragments[0].html, "<ul><li>第一项</li><li>第二项</li></ul>")
    }

    @TestCase
    func inputStreamCallbacksReceiveUpdatesFragmentsPatchesAndFinalize() {
        let markdown = """
- xxx
:::en
- yyy
:::
  - zzz
"""
        let chunks = byteChunks(markdown, [1, 2, 3, 5, 8])
        let probe = StreamingProbe()
        let callbacks = ParseCallbacks(
            onUpdate: { update: IncrementalUpdate =>
                probe.updateCount += 1
                probe.finalFlags.add(update.isFinal)
            },
            onBlockSealed: { node =>
                probe.sealedKinds.add(node.kind)
            },
            onHtmlFragment: { fragment: HtmlFragment =>
                probe.fragments.add(fragment.html)
            },
            onAstPatch: { patch: AstPatch =>
                probe.patchHtml.add(patch.html)
            },
            onFinalize: { snapshot =>
                probe.finalized = true
                probe.finalHtml = snapshot.root.toHtml()
            }
        )

        let out = Markit(GFMBundle()).use(I18nPlugin(
            config: I18nConfig(defaultLanguage: "zh", targetLanguage: "en")
        )).parseWithCallbacks(ChunkedInputStream(chunks), callbacks)

        @Expect(probe.finalized, true)
        @Expect(probe.updateCount > 1, true)
        @Expect(probe.finalFlags[probe.finalFlags.size - 1], true)
        @Expect(probe.fragments.size > 0, true)
        @Expect(probe.patchHtml.size > 0, true)
        @Expect(out.toHtml(), "<ul><li>yyy<ul><li>zzz</li></ul></li></ul>")
        @Expect(probe.finalHtml, out.toHtml())
    }

    @TestCase
    func emittedHtmlFragmentsCanBeDisabledWithoutChangingFinalOutput() {
        let session = Markit().createSession(options: ParseOptions(emitHtmlFragments: false))
        let update = session.feed("# 标题\n\n段落\n\n")
        let finalUpdate = session.finalize()

        @Expect(update.sealedBlocks.size, 2)
        @Expect(update.emittedHtmlFragments.size, 0)
        @Expect(finalUpdate.emittedHtmlFragments.size, 0)
        @Expect(session.toHtml(), "<h1 id=\"标题\">标题</h1><p>段落</p>")
    }

    @TestCase
    func sessionOutputStreamsMatchDirectApisAfterStreamingFinalize() {
        let markdown = "# 中文标题\n\n段落\n"
        let session = Markit().createSession()
        session.feed(markdown[0..2])
        session.feed(markdown[2..])
        session.finalize()

        let html = ByteBuffer()
        let markdownOut = ByteBuffer()
        let typst = ByteBuffer()
        let json = ByteBuffer()
        let tree = ByteBuffer()

        session.writeHtml(html)
        session.writeMarkdown(markdownOut)
        session.writeTypst(typst)
        session.writeJson(json)
        session.write(tree)

        @Expect(String.fromUtf8(readToEnd(html)), session.toHtml())
        @Expect(String.fromUtf8(readToEnd(markdownOut)), session.toMarkdown())
        @Expect(String.fromUtf8(readToEnd(typst)), session.toTypst())
        @Expect(String.fromUtf8(readToEnd(json)), session.toJson())
        @Expect(String.fromUtf8(readToEnd(tree)), session.toString())
    }

    private func collectFragments(fragments: ArrayList<String>, update: IncrementalUpdate): Unit {
        for (fragment in update.emittedHtmlFragments) {
            fragments.add(fragment.html)
        }
    }
}

private class StreamingProbe {
    public var updateCount: Int64 = 0
    public var finalized: Bool = false
    public var finalHtml: String = ""
    public let finalFlags = ArrayList<Bool>()
    public let sealedKinds = ArrayList<String>()
    public let fragments = ArrayList<String>()
    public let patchHtml = ArrayList<String>()
}

private func byteChunks(markdown: String, sizes: Array<Int64>): Array<Array<Byte>> {
    let bytes = markdown.toArray()
    let chunks = ArrayList<Array<Byte>>()
    var cursor: Int64 = 0
    var sizeIndex: Int64 = 0

    while (cursor < bytes.size) {
        let requested = sizes[sizeIndex % sizes.size]
        let end = if (cursor + requested > bytes.size) {
            bytes.size
        } else {
            cursor + requested
        }
        chunks.add(bytes[cursor..end])
        cursor = end
        sizeIndex += 1
    }

    return chunks.toArray()
}

private class ChunkedInputStream <: InputStream {
    private let chunks: Array<Array<Byte>>
    private var chunkIndex: Int64 = 0
    private var chunkOffset: Int64 = 0

    public init(chunks: Array<Array<Byte>>) {
        this.chunks = chunks
    }

    public func read(buffer: Array<Byte>): Int64 {
        while (chunkIndex < chunks.size) {
            let chunk = chunks[chunkIndex]
            if (chunkOffset >= chunk.size) {
                chunkIndex += 1
                chunkOffset = 0
                continue
            }

            let remaining = chunk.size - chunkOffset
            let size = if (remaining > buffer.size) {
                buffer.size
            } else {
                remaining
            }
            chunk.copyTo(buffer, chunkOffset, 0, size)
            chunkOffset += size
            if (chunkOffset >= chunk.size) {
                chunkIndex += 1
                chunkOffset = 0
            }
            return size
        }

        return 0
    }
}
