package markit.tests.benchmark

import std.unittest.*
import std.unittest.testmacro.*
import std.io.InputStream
import markit.Markit
import markit.bundles.{CommonMarkBundle, GFMBundle}
import markit.plugins.i18n.I18nPlugin
import markit.plugins.i18n.config.I18nConfig

@Test
@Tag[Benchmark]
class SharedFixtureBenchmarks {
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
        let out = standardParser.parse(standardSmallDoc)
        consume(out.root().children.size)
    }

    @Bench
    func standardSmallParseAndHtml() {
        let out = standardParser.parse(standardSmallDoc)
        consume(out.html().size)
    }

    @Bench
    func standardGeneratedParseOnly() {
        let out = standardParser.parse(standardGeneratedDoc)
        consume(out.root().children.size)
    }

    @Bench
    func standardGeneratedParseAndHtml() {
        let out = standardParser.parse(standardGeneratedDoc)
        consume(out.html().size)
    }

    @Bench
    func gfmMixedParseOnly() {
        let out = gfmParser.parse(gfmMixedDoc)
        consume(out.root().children.size)
    }

    @Bench
    func gfmMixedParseAndHtml() {
        let out = gfmParser.parse(gfmMixedDoc)
        consume(out.html().size)
    }

    @Bench
    func gfmGeneratedParseOnly() {
        let out = gfmParser.parse(gfmGeneratedDoc)
        consume(out.root().children.size)
    }

    @Bench
    func gfmGeneratedParseAndHtml() {
        let out = gfmParser.parse(gfmGeneratedDoc)
        consume(out.html().size)
    }

    @Bench
    func commonmarkMixedParseAndHtml() {
        let out = commonmarkParser.parse(commonmarkMixedDoc)
        consume(out.html().size)
    }

    @Bench
    func i18nMixedParseAndHtml() {
        let out = i18nParser.parse(i18nMixedDoc)
        consume(out.html().size)
    }

    @Bench
    func largeFenceParseOnly() {
        let out = standardParser.parse(largeFenceDoc)
        consume(out.root().children.size)
    }

    @Bench
    func deepListParseOnly() {
        let out = standardParser.parse(deepListDoc)
        consume(out.root().children.size)
    }

    @Bench
    func largeTableParseAndHtml() {
        let out = gfmParser.parse(largeTableDoc)
        consume(out.html().size)
    }

    @Bench
    func standardGeneratedIncrementalLines() {
        let session = standardParser.createSession()
        for (line in standardGeneratedDoc.split("\n")) {
            session.feed(line)
            session.feed("\n")
        }
        consume(session.finalize().sealedBlocks.size)
    }

    @Bench
    func standardGeneratedIncrementalBytes64() {
        let session = standardParser.createSession()
        let bytes = standardGeneratedDoc.toArray()
        var index: Int64 = 0
        while (index < bytes.size) {
            let end = min(index + 64, bytes.size)
            session.feedBytes(bytes[index..end])
            index = end
        }
        consume(session.finalize().sealedBlocks.size)
    }

    @Bench
    func gfmGeneratedIncrementalBytes64() {
        let session = gfmParser.createSession()
        let bytes = gfmGeneratedDoc.toArray()
        var index: Int64 = 0
        while (index < bytes.size) {
            let end = min(index + 64, bytes.size)
            session.feedBytes(bytes[index..end])
            index = end
        }
        consume(session.finalize().sealedBlocks.size)
    }

    @Bench
    func i18nMixedIncrementalLines() {
        let session = i18nParser.createSession()
        for (line in i18nMixedDoc.split("\n")) {
            session.feed(line)
            session.feed("\n")
        }
        consume(session.finalize().astPatches.size)
    }

    @Bench
    func largeTableIncrementalBytes64() {
        let session = gfmParser.createSession()
        let bytes = largeTableDoc.toArray()
        var index: Int64 = 0
        while (index < bytes.size) {
            let end = min(index + 64, bytes.size)
            session.feedBytes(bytes[index..end])
            index = end
        }
        consume(session.finalize().sealedBlocks.size)
    }

    @Bench
    func standardGeneratedInputStreamBytes64() {
        let out = standardParser.parse(ChunkedBenchmarkInputStream(standardGeneratedDoc.toArray(), 64))
        consume(out.root().children.size)
    }

    @Bench
    func gfmGeneratedInputStreamBytes64() {
        let out = gfmParser.parse(ChunkedBenchmarkInputStream(gfmGeneratedDoc.toArray(), 64))
        consume(out.root().children.size)
    }

    @Bench
    func largeTableInputStreamBytes64() {
        let out = gfmParser.parse(ChunkedBenchmarkInputStream(largeTableDoc.toArray(), 64))
        consume(out.html().size)
    }

    private func consume(value: Int64): Unit {
        if (value < 0) {
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
