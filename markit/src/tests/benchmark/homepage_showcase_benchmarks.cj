package markit.tests.benchmark

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.plugins.i18n.I18nPlugin
import markit.plugins.i18n.config.I18nConfig

@Test
@Tag[Benchmark]
class HomepageShowcaseBenchmarks {
    private let parser = Markit(GFMBundle()).use(I18nPlugin(
        config: I18nConfig(defaultLanguage: "zh", targetLanguage: "en")
    ))
    private static let showcaseDoc = HomepageShowcaseDocuments.docsSitePage(240)
    private static let showcaseBytes = showcaseDoc.toArray()

    @Bench
    func docsPageParseAndHtml() {
        let out = parser.parse(showcaseDoc)
        consume(out.root().children.size + out.html().size)
    }

    @Bench
    func docsPageParseAndJson() {
        let out = parser.parse(showcaseDoc)
        consume(out.root().children.size + out.json().size)
    }

    @Bench
    func docsPageParseAndTypst() {
        let out = parser.parse(showcaseDoc)
        consume(out.root().children.size + out.typst().size)
    }

    @Bench
    func docsPageParseAndAllOutputs() {
        let out = parser.parse(showcaseDoc)
        consume(
            out.root().children.size +
            out.html().size +
            out.markdown().size +
            out.typst().size +
            out.json().size
        )
    }

    @Bench
    func docsPageStreamingBytes64() {
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
        consume(marker)
    }

    private func consume(value: Int64): Unit {
        if (value < 0) {
            throw IllegalArgumentException("unreachable")
        }
    }
}
