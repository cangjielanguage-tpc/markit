package markit.tests.benchmark

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.plugins.i18n.I18nPlugin
import markit.plugins.i18n.config.I18nConfig

@Test
@Tag[Benchmark]
class ParserBenchmarks {
    @Bench
    func standardSmallDirectParse() {
        let out = Markit().parse(BenchmarkDocuments.smallStandard())
        consume(out.html().size)
    }

    @Bench
    func standardGeneratedDirectParse() {
        let out = Markit().parse(BenchmarkDocuments.generatedStandard(500))
        consume(out.html().size)
    }

    @Bench
    func gfmMixedDirectParse() {
        let out = Markit(GFMBundle()).parse(BenchmarkDocuments.gfmMixed())
        consume(out.toTypst().size)
    }

    @Bench
    func i18nMixedDirectParse() {
        let out = i18nParser("en").parse(BenchmarkDocuments.i18nMixed())
        consume(out.toTypst().size)
    }

    @Bench
    func standardGeneratedIncrementalLines() {
        let session = Markit().createSession()
        for (chunk in BenchmarkDocuments.generatedStandard(500).split("\n")) {
            session.feed(chunk)
            session.feed("\n")
        }
        consume(session.finalize().sealedBlocks.size)
    }

    @Bench
    func standardGeneratedIncrementalBytes() {
        let session = Markit().createSession()
        let bytes = BenchmarkDocuments.generatedStandard(500).toArray()
        var index: Int64 = 0
        while (index < bytes.size) {
            let end = min(index + 64, bytes.size)
            session.feedBytes(bytes[index..end])
            index = end
        }
        consume(session.finalize().sealedBlocks.size)
    }

    @Bench
    func gfmMixedIncrementalBytes() {
        let session = Markit(GFMBundle()).createSession()
        let bytes = BenchmarkDocuments.gfmMixed().toArray()
        for (byte in bytes) {
            session.feedBytes([byte])
        }
        consume(session.finalize().sealedBlocks.size)
    }

    @Bench
    func i18nMixedIncrementalLines() {
        let session = i18nParser("en").createSession()
        for (chunk in BenchmarkDocuments.i18nMixed().split("\n")) {
            session.feed(chunk)
            session.feed("\n")
        }
        consume(session.finalize().astPatches.size)
    }

    private func i18nParser(targetLanguage: String): Markit {
        return Markit(GFMBundle()).use(I18nPlugin(
            config: I18nConfig(defaultLanguage: "zh", targetLanguage: targetLanguage)
        ))
    }

    private func consume(value: Int64): Unit {
        if (value < 0) {
            throw IllegalArgumentException("unreachable")
        }
    }
}
