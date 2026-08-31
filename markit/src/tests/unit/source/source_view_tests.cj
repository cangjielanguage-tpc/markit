package markit.tests.unit.source

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.core.nodes.TextNode
import markit.core.session.ParseOptions
import markit.core.source.{SourceBuffer, SourceRetentionMode, SourceSpan}
import markit.plugins.standard.inline.soft_break.SoftBreakNode
import markit.plugins.gfm.block.table.TableConfig
import markit.plugins.i18n.I18nPlugin
import markit.plugins.i18n.config.I18nConfig
import markit.plugins.standard.block.heading.HeadingNumberingConfig
import markit.tests.utils.AstTestKit

@Test
class SourceViewTests {
    @TestCase
    func textViewCursorReadsChineseAndEmojiByRuneWithoutRuneArrayCopy() {
        let text = "中a🙂文"
        let source = SourceBuffer(retentionMode: SourceRetentionMode.Full)
        source.append(text)

        let cursor = source.view(SourceSpan(0, text.size, 0, 4)).cursor()

        @Expect(cursor.advanceRune().getOrThrow().toString(), "中")
        @Expect(cursor.bytePosition(), 3)
        @Expect(cursor.runePosition(), 1)
        @Expect(cursor.advanceRune().getOrThrow().toString(), "a")
        @Expect(cursor.bytePosition(), 4)
        @Expect(cursor.runePosition(), 2)
        @Expect(cursor.advanceRune().getOrThrow().toString(), "🙂")
        @Expect(cursor.bytePosition(), 8)
        @Expect(cursor.runePosition(), 3)
        @Expect(cursor.advanceRune().getOrThrow().toString(), "文")
        @Expect(cursor.atEnd(), true)
    }

    @TestCase
    func sourceBufferSliceUsesByteOffsetsForRetainedTextSegments() {
        let text = "段落、列表"
        let source = SourceBuffer(retentionMode: SourceRetentionMode.Full)
        source.append(text)

        @Expect(source.slice(6, 9), "、")
        @Expect(source.slice(9, 15), "列表")
    }

    @TestCase
    func textRawContentFallsBackToLiteralWhenSourceSpanCutsUtf8Boundary() {
        let source = SourceBuffer(retentionMode: SourceRetentionMode.Full)
        source.append("段落")
        let text = TextNode(1, SourceSpan(1, 3, 0, 1), "段")
        text.attachSource(source)

        @Expect(text.rawContent(), "段")
    }

    @TestCase
    func softBreakRawContentFallsBackToLiteralWhenSourceSpanCutsUtf8Boundary() {
        let source = SourceBuffer(retentionMode: SourceRetentionMode.Full)
        source.append("段落\n")
        let softBreak = SoftBreakNode(1, SourceSpan(1, 3, 0, 1))
        softBreak.attachSource(source)

        @Expect(softBreak.rawContent(), "\n")
    }

    @TestCase
    func parsedRawContentHandlesUtf8ByteSpansInsideI18nInlineText() {
        let parser = Markit(cliLikeBundle()).use(I18nPlugin(
            config: I18nConfig(defaultLanguage: "zh", targetLanguage: "zh")
        ))
        let out = parser.parse("# :zh{Markit Typst 示例}:\n\n:zh{段落、链接、列表和双语内容。}:\n")

        AstTestKit.expectRoot(out.root(), 2)
        let heading = AstTestKit.child(out.root(), 0, "Heading1Node")
        let headingI18n = AstTestKit.child(heading, 0, "I18nInlineNode")
        let headingText = AstTestKit.child(headingI18n, 0, "TextNode")
        AstTestKit.expectSpan(headingText, 6, 25, 6, 21)
        @Expect(headingText.rawContent(), "Markit Typst 示例")

        let paragraph = AstTestKit.child(out.root(), 1, "ParagraphNode")
        let paragraphI18n = AstTestKit.child(paragraph, 0, "I18nInlineNode")
        let paragraphText = AstTestKit.child(paragraphI18n, 0, "TextNode")
        AstTestKit.expectSpan(paragraphText, 33, 75, 29, 43)
        @Expect(paragraphText.rawContent(), "段落、链接、列表和双语内容。")
    }

    @TestCase
    func parsedRawContentHandlesCliExampleUniversalLineWithCrLf() {
        let markdown = "# :zh{Markit Typst 示例}: :en{Markit Typst Example}:\r\n\r\n::{本页用于验证 Typst 导出的基础结构，包括标题、段落、链接、列表和双语内容。}:\r\n"
        let source = SourceBuffer(retentionMode: SourceRetentionMode.Full)
        source.append(markdown)
        @Expect(source.slice(140, 143), "、")

        let parser = Markit(cliLikeBundle()).use(I18nPlugin(
            config: I18nConfig(defaultLanguage: "zh", targetLanguage: "zh")
        ))
        let out = parser.parse(markdown)

        AstTestKit.expectRoot(out.root(), 2)
        let paragraph = AstTestKit.child(out.root(), 1, "ParagraphNode")
        let leadingColon = AstTestKit.child(paragraph, 0, "TextNode")
        AstTestKit.expectSpan(leadingColon, 58, 59, 52, 53)
        @Expect(leadingColon.rawContent(), ":")

        let universal = AstTestKit.child(paragraph, 1, "UniversalInlineNode")
        AstTestKit.expectSpan(universal, 59, 169, 53, 97)
        @Expect(universal.rawContent(), "本页用于验证 Typst 导出的基础结构，包括标题、段落、链接、列表和双语内容。")

        let universalText = AstTestKit.child(universal, 0, "TextNode")
        AstTestKit.expectSpan(universalText, 61, 167, 55, 95)
        @Expect(universalText.rawContent(), "本页用于验证 Typst 导出的基础结构，包括标题、段落、链接、列表和双语内容。")
    }

    @TestCase
    func defaultRetentionDoesNotKeepFullDocumentRawContentAfterFinalize() {
        let out = Markit().parse("# 标题\n\n段落\n")

        @Expect(out.root().rawContent(), "")
        @Expect(out.root().children[0].rawContent(), "标题")
        @Expect(out.root().children[1].rawContent(), "段落")
    }

    @TestCase
    func fullRetentionKeepsOriginalSourceForDebugAndLosslessInspection() {
        let session = Markit().createSession(options: ParseOptions(sourceRetentionMode: SourceRetentionMode.Full))
        session.feed("# 标题\n\n段落\n")
        session.finalize()

        @Expect(session.snapshot().root.rawContent(), "# 标题\n\n段落\n")
    }

    private func cliLikeBundle(): GFMBundle {
        return GFMBundle(
            headingNumberingConfig: HeadingNumberingConfig(enabled: true),
            tableConfig: TableConfig(enableThreeLineTable: true)
        )
    }
}
