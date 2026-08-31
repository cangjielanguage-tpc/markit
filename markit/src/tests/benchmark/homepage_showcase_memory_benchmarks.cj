package markit.tests.benchmark

import std.runtime.*
import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.plugins.i18n.I18nPlugin
import markit.plugins.i18n.config.I18nConfig

@Test
@Tag[Benchmark]
@Measure[GCFreedBytesMeasurement()]
class HomepageShowcaseMemoryBenchmarks {
    private let parser = Markit(GFMBundle()).use(I18nPlugin(
        config: I18nConfig(defaultLanguage: "zh", targetLanguage: "en")
    ))
    private static let showcaseDoc = HomepageShowcaseDocuments.docsSitePage(240)
    private static let showcaseBytes = showcaseDoc.toArray()

    @Bench
    func docsPageParseAndHtmlHeap() {
        let marker = parseAndHtmlMarker()
        gc(heavy: true)
        consume(marker)
    }

    @Bench
    func docsPageParseAndAllOutputsHeap() {
        let marker = parseAndAllOutputsMarker()
        gc(heavy: true)
        consume(marker)
    }

    @Bench
    func docsPageStreamingBytes64Heap() {
        let marker = streamingBytes64Marker()
        gc(heavy: true)
        consume(marker)
    }

    private func parseAndHtmlMarker(): Int64 {
        let out = parser.parse(showcaseDoc)
        return out.root().children.size + out.html().size
    }

    private func parseAndAllOutputsMarker(): Int64 {
        let out = parser.parse(showcaseDoc)
        return out.root().children.size +
            out.html().size +
            out.markdown().size +
            out.typst().size +
            out.json().size
    }

    private func streamingBytes64Marker(): Int64 {
        let session = parser.createSession()
        var index: Int64 = 0
        var marker: Int64 = 0
        while (index < showcaseBytes.size) {
            let end = min(index + 64, showcaseBytes.size)
            let update = session.feedBytes(showcaseBytes[index..end])
            marker += update.sealedBlocks.size
            marker += update.emittedHtmlFragments.size
            marker += update.astPatches.size
            index = end
        }
        let finalUpdate = session.finalize()
        marker += finalUpdate.sealedBlocks.size
        marker += finalUpdate.emittedHtmlFragments.size
        marker += finalUpdate.astPatches.size
        return marker
    }

    private func consume(value: Int64): Unit {
        if (blackBox(value) < 0) {
            throw IllegalArgumentException("unreachable")
        }
    }
}
