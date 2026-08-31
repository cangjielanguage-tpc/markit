package markit.tests.benchmark

import std.runtime.*
import std.unittest.*
import std.unittest.testmacro.*
import std.io.InputStream
import markit.Markit
import markit.bundles.{CommonMarkBundle, GFMBundle}
import markit.plugins.i18n.I18nPlugin
import markit.plugins.i18n.config.I18nConfig

class GCFreedBytesMeasurement <: Measurement {
    public func setup(): Unit {
        gc(heavy: true)
    }

    public func measure(): Float64 {
        return Float64(getGCFreedSize())
    }

    public prop name: String {
        get() {
            "GCFreedBytes"
        }
    }

    public prop textDescription: String {
        get() {
            "Cangjie heap bytes freed by explicit GC after each operation"
        }
    }

    public prop conversionTable: MeasurementUnitTable {
        get() {
            [(1.0, "B"), (1024.0, "KiB"), (1048576.0, "MiB")]
        }
    }
}

@Test
@Tag[Benchmark]
@Measure[GCFreedBytesMeasurement()]
class SharedFixtureMemoryBenchmarks {
    private let standardParser = Markit()
    private let gfmParser = Markit(GFMBundle())
    private let commonmarkParser = Markit(CommonMarkBundle())
    private let i18nParser = Markit(GFMBundle()).use(I18nPlugin(
        config: I18nConfig(defaultLanguage: "zh", targetLanguage: "en")
    ))
    private static let standardSmallDoc = SharedBenchmarkDocuments.standardSmall()
    private static let standardGeneratedDoc = SharedBenchmarkDocuments.generatedStandard(500)
    private static let gfmMixedDoc = SharedBenchmarkDocuments.gfmMixed()
    private static let gfmGeneratedDoc = SharedBenchmarkDocuments.gfmGenerated(300)
    private static let commonmarkMixedDoc = SharedBenchmarkDocuments.commonmarkMixed()
    private static let i18nMixedDoc = SharedBenchmarkDocuments.i18nMixed()
    private static let largeFenceDoc = SharedBenchmarkDocuments.largeFence(1200)
    private static let deepListDoc = SharedBenchmarkDocuments.deepList(120)
    private static let largeTableDoc = SharedBenchmarkDocuments.largeTable(800)

    @Bench
    func standardSmallParseOnly() {
        let marker = standardParseOnlyMarker(standardSmallDoc)
        gc(heavy: true)
        consume(marker)
    }

    @Bench
    func standardSmallParseAndHtml() {
        let marker = standardParseAndHtmlMarker(standardSmallDoc)
        gc(heavy: true)
        consume(marker)
    }

    @Bench
    func standardGeneratedParseOnly() {
        let marker = standardParseOnlyMarker(standardGeneratedDoc)
        gc(heavy: true)
        consume(marker)
    }

    @Bench
    func standardGeneratedParseAndHtml() {
        let marker = standardParseAndHtmlMarker(standardGeneratedDoc)
        gc(heavy: true)
        consume(marker)
    }

    @Bench
    func gfmMixedParseOnly() {
        let marker = gfmParseOnlyMarker(gfmMixedDoc)
        gc(heavy: true)
        consume(marker)
    }

    @Bench
    func gfmMixedParseAndHtml() {
        let marker = gfmParseAndHtmlMarker(gfmMixedDoc)
        gc(heavy: true)
        consume(marker)
    }

    @Bench
    func gfmGeneratedParseOnly() {
        let marker = gfmParseOnlyMarker(gfmGeneratedDoc)
        gc(heavy: true)
        consume(marker)
    }

    @Bench
    func gfmGeneratedParseAndHtml() {
        let marker = gfmParseAndHtmlMarker(gfmGeneratedDoc)
        gc(heavy: true)
        consume(marker)
    }

    @Bench
    func commonmarkMixedParseAndHtml() {
        let marker = commonmarkParseAndHtmlMarker(commonmarkMixedDoc)
        gc(heavy: true)
        consume(marker)
    }

    @Bench
    func i18nMixedParseAndHtml() {
        let marker = i18nParseAndHtmlMarker(i18nMixedDoc)
        gc(heavy: true)
        consume(marker)
    }

    @Bench
    func largeFenceParseOnly() {
        let marker = standardParseOnlyMarker(largeFenceDoc)
        gc(heavy: true)
        consume(marker)
    }

    @Bench
    func deepListParseOnly() {
        let marker = standardParseOnlyMarker(deepListDoc)
        gc(heavy: true)
        consume(marker)
    }

    @Bench
    func largeTableParseAndHtml() {
        let marker = gfmParseAndHtmlMarker(largeTableDoc)
        gc(heavy: true)
        consume(marker)
    }

    @Bench
    func standardGeneratedIncrementalLines() {
        let marker = standardIncrementalLinesMarker(standardGeneratedDoc)
        gc(heavy: true)
        consume(marker)
    }

    @Bench
    func standardGeneratedIncrementalBytes64() {
        let marker = standardIncrementalBytes64Marker(standardGeneratedDoc)
        gc(heavy: true)
        consume(marker)
    }

    @Bench
    func gfmGeneratedIncrementalBytes64() {
        let marker = gfmIncrementalBytes64Marker(gfmGeneratedDoc)
        gc(heavy: true)
        consume(marker)
    }

    @Bench
    func i18nMixedIncrementalLines() {
        let marker = i18nIncrementalLinesMarker(i18nMixedDoc)
        gc(heavy: true)
        consume(marker)
    }

    @Bench
    func largeTableIncrementalBytes64() {
        let marker = gfmIncrementalBytes64Marker(largeTableDoc)
        gc(heavy: true)
        consume(marker)
    }

    @Bench
    func standardGeneratedInputStreamBytes64() {
        let marker = standardInputStreamBytes64Marker(standardGeneratedDoc)
        gc(heavy: true)
        consume(marker)
    }

    @Bench
    func gfmGeneratedInputStreamBytes64() {
        let marker = gfmInputStreamBytes64Marker(gfmGeneratedDoc)
        gc(heavy: true)
        consume(marker)
    }

    @Bench
    func largeTableInputStreamBytes64() {
        let marker = gfmInputStreamHtmlBytes64Marker(largeTableDoc)
        gc(heavy: true)
        consume(marker)
    }

    private func standardParseOnlyMarker(doc: String): Int64 {
        let out = standardParser.parse(doc)
        return out.root().children.size
    }

    private func standardParseAndHtmlMarker(doc: String): Int64 {
        let out = standardParser.parse(doc)
        return out.root().children.size + out.html().size
    }

    private func gfmParseOnlyMarker(doc: String): Int64 {
        let out = gfmParser.parse(doc)
        return out.root().children.size
    }

    private func gfmParseAndHtmlMarker(doc: String): Int64 {
        let out = gfmParser.parse(doc)
        return out.root().children.size + out.html().size
    }

    private func commonmarkParseAndHtmlMarker(doc: String): Int64 {
        let out = commonmarkParser.parse(doc)
        return out.root().children.size + out.html().size
    }

    private func i18nParseAndHtmlMarker(doc: String): Int64 {
        let out = i18nParser.parse(doc)
        return out.root().children.size + out.html().size
    }

    private func standardIncrementalLinesMarker(doc: String): Int64 {
        let session = standardParser.createSession()
        for (line in doc.split("\n")) {
            session.feed(line)
            session.feed("\n")
        }
        return session.finalize().sealedBlocks.size
    }

    private func standardIncrementalBytes64Marker(doc: String): Int64 {
        let session = standardParser.createSession()
        let bytes = doc.toArray()
        var index: Int64 = 0
        while (index < bytes.size) {
            let end = min(index + 64, bytes.size)
            session.feedBytes(bytes[index..end])
            index = end
        }
        return session.finalize().sealedBlocks.size
    }

    private func gfmIncrementalBytes64Marker(doc: String): Int64 {
        let session = gfmParser.createSession()
        let bytes = doc.toArray()
        var index: Int64 = 0
        while (index < bytes.size) {
            let end = min(index + 64, bytes.size)
            session.feedBytes(bytes[index..end])
            index = end
        }
        return session.finalize().sealedBlocks.size
    }

    private func i18nIncrementalLinesMarker(doc: String): Int64 {
        let session = i18nParser.createSession()
        for (line in doc.split("\n")) {
            session.feed(line)
            session.feed("\n")
        }
        return session.finalize().astPatches.size
    }

    private func standardInputStreamBytes64Marker(doc: String): Int64 {
        let out = standardParser.parse(ChunkedBenchmarkInputStream(doc.toArray(), 64))
        return out.root().children.size
    }

    private func gfmInputStreamBytes64Marker(doc: String): Int64 {
        let out = gfmParser.parse(ChunkedBenchmarkInputStream(doc.toArray(), 64))
        return out.root().children.size
    }

    private func gfmInputStreamHtmlBytes64Marker(doc: String): Int64 {
        let out = gfmParser.parse(ChunkedBenchmarkInputStream(doc.toArray(), 64))
        return out.root().children.size + out.html().size
    }

    private func consume(value: Int64): Unit {
        if (blackBox(value) < 0) {
            throw IllegalArgumentException("unreachable")
        }
    }
}

private class ChunkedBenchmarkInputStream <: InputStream {
    private let bytes: Array<Byte>
    private let chunkSize: Int64
    private var offset: Int64 = 0

    public init(bytes: Array<Byte>, chunkSize: Int64) {
        this.bytes = bytes
        this.chunkSize = chunkSize
    }

    public func read(buffer: Array<Byte>): Int64 {
        if (offset >= bytes.size) {
            return 0
        }
        let maxSize = min(buffer.size, chunkSize)
        let size = min(maxSize, bytes.size - offset)
        bytes.copyTo(buffer, offset, 0, size)
        offset += size
        return size
    }
}
