package markit.tests.utils

import std.collection.ArrayList
import std.io.InputStream
import markit.{Markit, ParseCallbacks}
import markit.core.incremental.IncrementalUpdate
import markit.core.nodes.Node

public class ParseModeFixture {
    public let markdown: String
    public let stringChunks: Array<String>
    public let byteChunks: Array<Array<Byte>>

    public init(markdown: String) {
        this.markdown = markdown
        this.stringChunks = defaultStringChunks(markdown)
        this.byteChunks = defaultByteChunks(markdown)
    }

    public init(
        markdown: String,
        stringChunks: Array<String>,
        byteChunks: Array<Array<Byte>>
    ) {
        this.markdown = markdown
        this.stringChunks = stringChunks
        this.byteChunks = byteChunks
    }

    public static func withStringChunks(markdown: String, stringChunks: Array<String>): ParseModeFixture {
        return ParseModeFixture(
            markdown,
            stringChunks,
            defaultByteChunks(markdown)
        )
    }

    public static func withChunks(
        markdown: String,
        stringChunks: Array<String>,
        byteChunks: Array<Array<Byte>>
    ): ParseModeFixture {
        return ParseModeFixture(markdown, stringChunks, byteChunks)
    }

    public static func defaultStringChunks(markdown: String): Array<String> {
        let lineChunks = splitByLines(markdown)
        if (lineChunks.size > 1) {
            return lineChunks.toArray()
        }
        if (markdown.isEmpty()) {
            return ArrayList<String>().toArray()
        }

        let runeChunks = ArrayList<String>()
        for (rune in markdown.runes()) {
            runeChunks.add(String([rune]))
        }
        return runeChunks.toArray()
    }

    public static func defaultByteChunks(markdown: String): Array<Array<Byte>> {
        let byteChunks = ArrayList<Array<Byte>>()
        for (byte in markdown) {
            byteChunks.add([byte])
        }
        return byteChunks.toArray()
    }

    private static func splitByLines(markdown: String): ArrayList<String> {
        let chunks = ArrayList<String>()
        var start: Int64 = 0

        while (let Some(newline) <- markdown.indexOf(b'\n', start)) {
            chunks.add(markdown[start..newline + 1])
            start = newline + 1
        }

        if (start < markdown.size) {
            chunks.add(markdown[start..])
        }
        return chunks
    }
}

public class ParseModeResult {
    public let mode: String
    public let html: String
    public let markdown: String
    public let typst: String
    public let json: String
    public let tree: String
    public let root: Node
    public let finalUpdate: IncrementalUpdate
    public let emittedHtml: String
    public let updateCount: Int64
    public let sealedBlockCount: Int64
    public let astPatchCount: Int64

    public init(
        mode: String,
        html: String,
        markdown: String,
        typst: String,
        json: String,
        tree: String,
        root: Node,
        finalUpdate: IncrementalUpdate,
        emittedHtml: String,
        updateCount: Int64,
        sealedBlockCount: Int64,
        astPatchCount: Int64
    ) {
        this.mode = mode
        this.html = html
        this.markdown = markdown
        this.typst = typst
        this.json = json
        this.tree = tree
        this.root = root
        this.finalUpdate = finalUpdate
        this.emittedHtml = emittedHtml
        this.updateCount = updateCount
        this.sealedBlockCount = sealedBlockCount
        this.astPatchCount = astPatchCount
    }
}

public class ParseModeTestKit {
    public static func collect(markitFactory: () -> Markit, markdown: String): ArrayList<ParseModeResult> {
        return collect(markitFactory, ParseModeFixture(markdown))
    }

    public static func collect(
        markitFactory: () -> Markit,
        fixture: ParseModeFixture
    ): ArrayList<ParseModeResult> {
        let results = ArrayList<ParseModeResult>()
        results.add(runDirect(markitFactory, fixture.markdown))
        results.add(runIncrementalString(markitFactory, fixture))
        results.add(runIncrementalBytes(markitFactory, fixture))
        results.add(runInputStream(markitFactory, fixture))
        return results
    }

    public static func assertHtmlAcrossModes(
        markitFactory: () -> Markit,
        markdown: String,
        expectedHtml: String
    ): Unit {
        assertHtmlAcrossModes(markitFactory, ParseModeFixture(markdown), expectedHtml)
    }

    public static func assertHtmlAcrossModes(
        markitFactory: () -> Markit,
        fixture: ParseModeFixture,
        expectedHtml: String
    ): Unit {
        for (result in collect(markitFactory, fixture)) {
            if (result.html != expectedHtml) {
                throw IllegalArgumentException(
                    "HTML mismatch in ${result.mode}: expected `${expectedHtml}`, actual `${result.html}`"
                )
            }
        }
    }

    public static func assertMarkdownAcrossModes(
        markitFactory: () -> Markit,
        markdown: String,
        expectedMarkdown: String
    ): Unit {
        assertMarkdownAcrossModes(markitFactory, ParseModeFixture(markdown), expectedMarkdown)
    }

    public static func assertMarkdownAcrossModes(
        markitFactory: () -> Markit,
        fixture: ParseModeFixture,
        expectedMarkdown: String
    ): Unit {
        for (result in collect(markitFactory, fixture)) {
            if (result.markdown != expectedMarkdown) {
                throw IllegalArgumentException(
                    "Markdown mismatch in ${result.mode}: expected `${expectedMarkdown}`, actual `${result.markdown}`"
                )
            }
        }
    }

    public static func assertTypstAcrossModes(
        markitFactory: () -> Markit,
        markdown: String,
        expectedTypst: String
    ): Unit {
        assertTypstAcrossModes(markitFactory, ParseModeFixture(markdown), expectedTypst)
    }

    public static func assertTypstAcrossModes(
        markitFactory: () -> Markit,
        fixture: ParseModeFixture,
        expectedTypst: String
    ): Unit {
        for (result in collect(markitFactory, fixture)) {
            if (result.typst != expectedTypst) {
                throw IllegalArgumentException(
                    "Typst mismatch in ${result.mode}: expected `${expectedTypst}`, actual `${result.typst}`"
                )
            }
        }
    }

    public static func assertAcrossModes(
        markitFactory: () -> Markit,
        markdown: String,
        verifier: (ParseModeResult) -> Unit
    ): Unit {
        assertAcrossModes(markitFactory, ParseModeFixture(markdown), verifier)
    }

    public static func assertAcrossModes(
        markitFactory: () -> Markit,
        fixture: ParseModeFixture,
        verifier: (ParseModeResult) -> Unit
    ): Unit {
        for (result in collect(markitFactory, fixture)) {
            verifier(result)
        }
    }

    private static func runDirect(markitFactory: () -> Markit, markdown: String): ParseModeResult {
        let out = markitFactory().parse(markdown)
        return ParseModeResult(
            "direct-parse",
            out.html(),
            out.toMarkdown(),
            out.toTypst(),
            out.toJson(),
            out.toString(),
            out.root(),
            out.finalUpdate,
            out.html(),
            0,
            out.finalUpdate.sealedBlocks.size,
            out.finalUpdate.astPatches.size
        )
    }

    private static func runIncrementalString(
        markitFactory: () -> Markit,
        fixture: ParseModeFixture
    ): ParseModeResult {
        let session = markitFactory().createSession()
        let capture = UpdateCapture()

        for (chunk in fixture.stringChunks) {
            capture.record(session.feed(chunk))
        }
        let finalUpdate = session.finalize()
        capture.record(finalUpdate)

        let snapshot = session.snapshot()
        return ParseModeResult(
            "incremental-string",
            session.renderer().renderHtml(snapshot.root),
            session.renderer().renderMarkdown(snapshot.root),
            session.renderer().renderTypst(snapshot.root),
            snapshot.root.toJson(),
            snapshot.root.toString(),
            snapshot.root,
            finalUpdate,
            capture.emittedHtml(),
            capture.updateCount,
            capture.sealedBlockCount,
            capture.astPatchCount
        )
    }

    private static func runIncrementalBytes(
        markitFactory: () -> Markit,
        fixture: ParseModeFixture
    ): ParseModeResult {
        let session = markitFactory().createSession()
        let capture = UpdateCapture()

        for (chunk in fixture.byteChunks) {
            capture.record(session.feedBytes(chunk))
        }
        let finalUpdate = session.finalize()
        capture.record(finalUpdate)

        let snapshot = session.snapshot()
        return ParseModeResult(
            "incremental-bytes",
            session.renderer().renderHtml(snapshot.root),
            session.renderer().renderMarkdown(snapshot.root),
            session.renderer().renderTypst(snapshot.root),
            snapshot.root.toJson(),
            snapshot.root.toString(),
            snapshot.root,
            finalUpdate,
            capture.emittedHtml(),
            capture.updateCount,
            capture.sealedBlockCount,
            capture.astPatchCount
        )
    }

    private static func runInputStream(
        markitFactory: () -> Markit,
        fixture: ParseModeFixture
    ): ParseModeResult {
        let capture = UpdateCapture()
        let callbacks = ParseCallbacks(
            onUpdate: { update: IncrementalUpdate =>
                capture.record(update)
            }
        )
        let out = markitFactory().parseWithCallbacks(
            ChunkedInputStream(fixture.byteChunks),
            callbacks
        )

        return ParseModeResult(
            "input-stream",
            out.html(),
            out.toMarkdown(),
            out.toTypst(),
            out.toJson(),
            out.toString(),
            out.root(),
            out.finalUpdate,
            capture.emittedHtml(),
            capture.updateCount,
            capture.sealedBlockCount,
            capture.astPatchCount
        )
    }
}

private class UpdateCapture {
    private let fragmentHtmls = ArrayList<String>()
    public var updateCount: Int64 = 0
    public var sealedBlockCount: Int64 = 0
    public var astPatchCount: Int64 = 0

    public func record(update: IncrementalUpdate): Unit {
        updateCount += 1
        sealedBlockCount += update.sealedBlocks.size
        astPatchCount += update.astPatches.size
        for (fragment in update.emittedHtmlFragments) {
            fragmentHtmls.add(fragment.html)
        }
    }

    public func emittedHtml(): String {
        return String.join(fragmentHtmls.toArray())
    }
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
