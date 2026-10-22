package markit_kit.processors

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.plugins.i18n.I18nPlugin
import markit.plugins.i18n.config.I18nConfig

private func previewParser(): Markit {
    return Markit(GFMBundle()).use(I18nPlugin(config: I18nConfig(defaultLanguage: "zh", targetLanguage: "en")))
}

@Test
class PreviewStreamTests {
    @TestCase
    func chunksPreserveMarkdownSemanticsAndFirstContent() {
        let source = StringBuilder()
        source.append("# 中文 title\n\n[forward][later]\n\n:::en\nEnglish explanation.\n:::\n\n")
        for (_ in 0..500) { source.append("Paragraph **bold** 中文.\n\n") }
        source.append("| A | B |\n| --- | --- |\n| 一 | two |\n\n- first\n  - nested\n\n```cj\nlet x = 1\n```\n\n[later]: https://example.com \"late title\"\n")
        let markdown = source.toString()
        let frames = ArrayList<String>()
        let streamed = PreviewStream.parse(previewParser(), markdown, "<shell>", { html => html },
            emit: { frame => frames.add(frame) })
        @Expect(streamed.toHtml(), previewParser().parse(markdown).toHtml())
        @Expect(frames.size > 2, true)
        @Expect(frames[0].contains("\"shell\":\"<shell>\""), true)
        @Expect(frames[1].contains("\"consumedBytes\":4096"), true)
        @Expect(frames[1].contains("\"kind\":\"append\""), true)
    }

    @TestCase
    func largeFenceIsNotSplitIntoIndependentMarkdown() {
        let source = StringBuilder()
        source.append("# Before fence\n\n```text\n")
        for (_ in 0..2000) { source.append("中文 **not emphasis**\n") }
        source.append("```\n\nAfter fence.\n")
        let markdown = source.toString()
        let frames = ArrayList<String>()
        let streamed = PreviewStream.parse(Markit(), markdown, "shell", { html => html },
            emit: { frame => frames.add(frame) })
        @Expect(streamed.toHtml(), Markit().parse(markdown).toHtml())
        @Expect(frames.size > 3, true)
        @Expect(frames[1].contains("Before fence"), true)
        @Expect(frames[1].contains("not emphasis"), false)
    }

    @TestCase
    func emptyInputStillPublishesShellAndFinalizes() {
        let frames = ArrayList<String>()
        let document = PreviewStream.parse(Markit(), "", "shell", { html => html },
            emit: { frame => frames.add(frame) })
        @Expect(frames.size, 1)
        @Expect(document.toHtml(), Markit().parse("").toHtml())
    }

    @TestCase
    func consumerFailureStopsBeforeFurtherBatches() {
        let frames = ArrayList<String>()
        var cancelled = false
        try {
            PreviewStream.parse(Markit(), "# test\n\n", "shell", { html => html },
                emit: { frame => frames.add(frame); throw IllegalArgumentException("cancelled") })
        } catch (_: IllegalArgumentException) { cancelled = true }
        @Expect(cancelled, true)
        @Expect(frames.size, 1)
    }
}
