package markit.tests.unit.plugins.i18n.inline

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.plugins.i18n.I18nPlugin
import markit.plugins.i18n.config.I18nConfig
import markit.tests.utils.AstTestKit
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

private func i18nEn(): Markit {
    return Markit(GFMBundle()).use(I18nPlugin(
        config: I18nConfig(defaultLanguage: "zh", targetLanguage: "en")
    ))
}

private func i18nZh(): Markit {
    return Markit(GFMBundle()).use(I18nPlugin(
        config: I18nConfig(defaultLanguage: "zh", targetLanguage: "zh")
    ))
}

@Test
class I18nInlineTests {
    @TestCase
    func rendersTargetLanguageAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            i18nEn,
            "Hello :zh{你好}: :en{world}: :{!}:",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>world!</p>")
                AstTestKit.expectExactJson(result.root, #"{"type":"DocumentNode","startOffset":0,"endOffset":32,"startByteOffset":0,"endByteOffset":36,"children":[{"type":"ParagraphNode","startOffset":0,"endOffset":32,"startByteOffset":0,"endByteOffset":36,"content":"Hello :zh{你好}: :en{world}: :{!}:","children":[{"type":"TextNode","startOffset":0,"endOffset":6,"startByteOffset":0,"endByteOffset":6,"content":"Hello ","children":[],"meta":{"i18n_language":"zh","i18n_target_language":"en","render":"false"}},{"type":"I18nInlineNode","startOffset":6,"endOffset":14,"startByteOffset":6,"endByteOffset":18,"languageId":"zh","content":"你好","originalSyntax":":zh{你好}:","children":[{"type":"TextNode","startOffset":10,"endOffset":12,"startByteOffset":10,"endByteOffset":16,"content":"你好","children":[],"meta":{"i18n_language":"zh","i18n_target_language":"en","render":"false"}}],"meta":{"i18n_language":"zh","i18n_target_language":"en","languageId":"zh","render":"false"}},{"type":"TextNode","startOffset":14,"endOffset":15,"startByteOffset":18,"endByteOffset":19,"content":" ","children":[],"meta":{"i18n_language":"zh","i18n_target_language":"en","render":"false"}},{"type":"I18nInlineNode","startOffset":15,"endOffset":26,"startByteOffset":19,"endByteOffset":30,"languageId":"en","content":"world","originalSyntax":":en{world}:","children":[{"type":"TextNode","startOffset":19,"endOffset":24,"startByteOffset":23,"endByteOffset":28,"content":"world","children":[],"meta":{"i18n_language":"en","i18n_target_language":"en"}}],"meta":{"i18n_language":"en","i18n_target_language":"en","languageId":"en"}},{"type":"TextNode","startOffset":26,"endOffset":27,"startByteOffset":30,"endByteOffset":31,"content":" ","children":[],"meta":{"i18n_language":"zh","i18n_target_language":"en","render":"false"}},{"type":"UniversalInlineNode","startOffset":27,"endOffset":32,"startByteOffset":31,"endByteOffset":36,"content":"!","originalSyntax":":{!}:","children":[{"type":"TextNode","startOffset":29,"endOffset":30,"startByteOffset":33,"endByteOffset":34,"content":"!","children":[],"meta":{"i18n_language":"universal","i18n_target_language":"en"}}],"meta":{"i18n_language":"universal","i18n_target_language":"en"}}],"meta":{"i18n_language":"zh","i18n_target_language":"en"}}],"meta":{"i18n_language":"zh","i18n_target_language":"en"}}"#)
            }
        )
    }

    @TestCase
    func rendersDefaultLanguageWhenTargetMatchesAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            i18nZh,
            "Hello :zh{你好}: :en{world}: :{!}:",
            "<p>Hello 你好  !</p>"
        )
    }

    @TestCase
    func parsesNestedBracesAndInlineMarkdownAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            i18nEn,
            "Code :en{{key: `值`}}: and :zh{**中文**}:",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>{key: <code>值</code>}</p>")
                AstTestKit.expectExactJson(result.root, #"{"type":"DocumentNode","startOffset":0,"endOffset":38,"startByteOffset":0,"endByteOffset":44,"children":[{"type":"ParagraphNode","startOffset":0,"endOffset":38,"startByteOffset":0,"endByteOffset":44,"content":"Code :en{{key: `值`}}: and :zh{**中文**}:","children":[{"type":"TextNode","startOffset":0,"endOffset":5,"startByteOffset":0,"endByteOffset":5,"content":"Code ","children":[],"meta":{"i18n_language":"zh","i18n_target_language":"en","render":"false"}},{"type":"I18nInlineNode","startOffset":5,"endOffset":21,"startByteOffset":5,"endByteOffset":23,"languageId":"en","content":"{key: `值`}","originalSyntax":":en{{key: `值`}}:","children":[{"type":"TextNode","startOffset":9,"endOffset":15,"startByteOffset":9,"endByteOffset":15,"content":"{key: ","children":[],"meta":{"i18n_language":"en","i18n_target_language":"en"}},{"type":"InlineCodeNode","startOffset":15,"endOffset":18,"startByteOffset":15,"endByteOffset":20,"content":"值","fenceLength":1,"children":[],"meta":{"i18n_language":"en","i18n_target_language":"en"}},{"type":"TextNode","startOffset":18,"endOffset":19,"startByteOffset":20,"endByteOffset":21,"content":"}","children":[],"meta":{"i18n_language":"en","i18n_target_language":"en"}}],"meta":{"i18n_language":"en","i18n_target_language":"en","languageId":"en"}},{"type":"TextNode","startOffset":21,"endOffset":26,"startByteOffset":23,"endByteOffset":28,"content":" and ","children":[],"meta":{"i18n_language":"zh","i18n_target_language":"en","render":"false"}},{"type":"I18nInlineNode","startOffset":26,"endOffset":38,"startByteOffset":28,"endByteOffset":44,"languageId":"zh","content":"**中文**","originalSyntax":":zh{**中文**}:","children":[{"type":"BoldNode","startOffset":30,"endOffset":36,"startByteOffset":32,"endByteOffset":42,"content":"中文","delimiter":"**","children":[{"type":"TextNode","startOffset":32,"endOffset":34,"startByteOffset":34,"endByteOffset":40,"content":"中文","children":[],"meta":{"i18n_language":"zh","i18n_target_language":"en","render":"false"}}],"meta":{"i18n_language":"zh","i18n_target_language":"en","render":"false"}}],"meta":{"i18n_language":"zh","i18n_target_language":"en","languageId":"zh","render":"false"}}],"meta":{"i18n_language":"zh","i18n_target_language":"en"}}],"meta":{"i18n_language":"zh","i18n_target_language":"en"}}"#)
            }
        )
    }

    @TestCase
    func invalidSyntaxFallsBackToTextAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            i18nEn,
            "Invalid :zh{content and :missing}brace:",
            ""
        )
    }

    @TestCase
    func supportsChineseByteStreamingAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            i18nEn,
            ":zh{中文}: :en{English 中文}:",
            "<p>English 中文</p>"
        )
    }

    @TestCase
    func rendersMultipleI18nMarksInTargetOrderAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            i18nEn,
            ":zh{你好}: :en{Hello}: :{ }: :zh{世界}: :en{World}:",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>Hello World</p>")
                AstTestKit.expectExactJson(result.root, #"{"type":"DocumentNode","startOffset":0,"endOffset":47,"startByteOffset":0,"endByteOffset":55,"children":[{"type":"ParagraphNode","startOffset":0,"endOffset":47,"startByteOffset":0,"endByteOffset":55,"content":":zh{你好}: :en{Hello}: :{ }: :zh{世界}: :en{World}:","children":[{"type":"I18nInlineNode","startOffset":0,"endOffset":8,"startByteOffset":0,"endByteOffset":12,"languageId":"zh","content":"你好","originalSyntax":":zh{你好}:","children":[{"type":"TextNode","startOffset":4,"endOffset":6,"startByteOffset":4,"endByteOffset":10,"content":"你好","children":[],"meta":{"i18n_language":"zh","i18n_target_language":"en","render":"false"}}],"meta":{"i18n_language":"zh","i18n_target_language":"en","languageId":"zh","render":"false"}},{"type":"TextNode","startOffset":8,"endOffset":9,"startByteOffset":12,"endByteOffset":13,"content":" ","children":[],"meta":{"i18n_language":"zh","i18n_target_language":"en","render":"false"}},{"type":"I18nInlineNode","startOffset":9,"endOffset":20,"startByteOffset":13,"endByteOffset":24,"languageId":"en","content":"Hello","originalSyntax":":en{Hello}:","children":[{"type":"TextNode","startOffset":13,"endOffset":18,"startByteOffset":17,"endByteOffset":22,"content":"Hello","children":[],"meta":{"i18n_language":"en","i18n_target_language":"en"}}],"meta":{"i18n_language":"en","i18n_target_language":"en","languageId":"en"}},{"type":"TextNode","startOffset":20,"endOffset":21,"startByteOffset":24,"endByteOffset":25,"content":" ","children":[],"meta":{"i18n_language":"zh","i18n_target_language":"en","render":"false"}},{"type":"UniversalInlineNode","startOffset":21,"endOffset":26,"startByteOffset":25,"endByteOffset":30,"content":" ","originalSyntax":":{ }:","children":[{"type":"TextNode","startOffset":23,"endOffset":24,"startByteOffset":27,"endByteOffset":28,"content":" ","children":[],"meta":{"i18n_language":"universal","i18n_target_language":"en"}}],"meta":{"i18n_language":"universal","i18n_target_language":"en"}},{"type":"TextNode","startOffset":26,"endOffset":27,"startByteOffset":30,"endByteOffset":31,"content":" ","children":[],"meta":{"i18n_language":"zh","i18n_target_language":"en","render":"false"}},{"type":"I18nInlineNode","startOffset":27,"endOffset":35,"startByteOffset":31,"endByteOffset":43,"languageId":"zh","content":"世界","originalSyntax":":zh{世界}:","children":[{"type":"TextNode","startOffset":31,"endOffset":33,"startByteOffset":35,"endByteOffset":41,"content":"世界","children":[],"meta":{"i18n_language":"zh","i18n_target_language":"en","render":"false"}}],"meta":{"i18n_language":"zh","i18n_target_language":"en","languageId":"zh","render":"false"}},{"type":"TextNode","startOffset":35,"endOffset":36,"startByteOffset":43,"endByteOffset":44,"content":" ","children":[],"meta":{"i18n_language":"zh","i18n_target_language":"en","render":"false"}},{"type":"I18nInlineNode","startOffset":36,"endOffset":47,"startByteOffset":44,"endByteOffset":55,"languageId":"en","content":"World","originalSyntax":":en{World}:","children":[{"type":"TextNode","startOffset":40,"endOffset":45,"startByteOffset":48,"endByteOffset":53,"content":"World","children":[],"meta":{"i18n_language":"en","i18n_target_language":"en"}}],"meta":{"i18n_language":"en","i18n_target_language":"en","languageId":"en"}}],"meta":{"i18n_language":"zh","i18n_target_language":"en"}}],"meta":{"i18n_language":"zh","i18n_target_language":"en"}}"#)
            }
        )
    }

    @TestCase
    func universalInlineKeepsRenderableChildrenAndDropsHiddenLanguageAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            i18nEn,
            ":{Always :zh{中文}: :en{English}:}:",
            { result: ParseModeResult =>
                @Expect(result.html, "<p>Always  English</p>")
                AstTestKit.expectExactJson(result.root, #"{"type":"DocumentNode","startOffset":0,"endOffset":33,"startByteOffset":0,"endByteOffset":37,"children":[{"type":"ParagraphNode","startOffset":0,"endOffset":33,"startByteOffset":0,"endByteOffset":37,"content":":{Always :zh{中文}: :en{English}:}:","children":[{"type":"UniversalInlineNode","startOffset":0,"endOffset":33,"startByteOffset":0,"endByteOffset":37,"content":"Always :zh{中文}: :en{English}:","originalSyntax":":{Always :zh{中文}: :en{English}:}:","children":[{"type":"TextNode","startOffset":2,"endOffset":9,"startByteOffset":2,"endByteOffset":9,"content":"Always ","children":[],"meta":{"i18n_language":"universal","i18n_target_language":"en"}},{"type":"I18nInlineNode","startOffset":9,"endOffset":17,"startByteOffset":9,"endByteOffset":21,"languageId":"zh","content":"中文","originalSyntax":":zh{中文}:","children":[{"type":"TextNode","startOffset":13,"endOffset":15,"startByteOffset":13,"endByteOffset":19,"content":"中文","children":[],"meta":{"i18n_language":"zh","i18n_target_language":"en","render":"false"}}],"meta":{"i18n_language":"zh","i18n_target_language":"en","languageId":"zh","render":"false"}},{"type":"TextNode","startOffset":17,"endOffset":18,"startByteOffset":21,"endByteOffset":22,"content":" ","children":[],"meta":{"i18n_language":"universal","i18n_target_language":"en"}},{"type":"I18nInlineNode","startOffset":18,"endOffset":31,"startByteOffset":22,"endByteOffset":35,"languageId":"en","content":"English","originalSyntax":":en{English}:","children":[{"type":"TextNode","startOffset":22,"endOffset":29,"startByteOffset":26,"endByteOffset":33,"content":"English","children":[],"meta":{"i18n_language":"en","i18n_target_language":"en"}}],"meta":{"i18n_language":"en","i18n_target_language":"en","languageId":"en"}}],"meta":{"i18n_language":"universal","i18n_target_language":"en"}}],"meta":{"i18n_language":"zh","i18n_target_language":"en"}}],"meta":{"i18n_language":"zh","i18n_target_language":"en"}}"#)
            }
        )
    }

    @TestCase
    func universalInlineWorksInsideHeadingAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            i18nEn,
            "# :{Common }: :zh{标题}: :en{Title}:\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<h1 id=\"common-title\">Common Title</h1>")
                AstTestKit.expectExactJson(result.root, #"{"type":"DocumentNode","startOffset":0,"endOffset":34,"startByteOffset":0,"endByteOffset":38,"children":[{"type":"Heading1Node","startOffset":0,"endOffset":34,"startByteOffset":0,"endByteOffset":38,"content":":{Common }: :zh{标题}: :en{Title}:","level":1,"baseSlug":"common-title","slugOccurrence":1,"children":[{"type":"UniversalInlineNode","startOffset":2,"endOffset":13,"startByteOffset":2,"endByteOffset":13,"content":"Common ","originalSyntax":":{Common }:","children":[{"type":"TextNode","startOffset":4,"endOffset":11,"startByteOffset":4,"endByteOffset":11,"content":"Common ","children":[],"meta":{"i18n_language":"universal","i18n_target_language":"en"}}],"meta":{"i18n_language":"universal","i18n_target_language":"en"}},{"type":"TextNode","startOffset":13,"endOffset":14,"startByteOffset":13,"endByteOffset":14,"content":" ","children":[],"meta":{"i18n_language":"zh","i18n_target_language":"en","render":"false"}},{"type":"I18nInlineNode","startOffset":14,"endOffset":22,"startByteOffset":14,"endByteOffset":26,"languageId":"zh","content":"标题","originalSyntax":":zh{标题}:","children":[{"type":"TextNode","startOffset":18,"endOffset":20,"startByteOffset":18,"endByteOffset":24,"content":"标题","children":[],"meta":{"i18n_language":"zh","i18n_target_language":"en","render":"false"}}],"meta":{"i18n_language":"zh","i18n_target_language":"en","languageId":"zh","render":"false"}},{"type":"TextNode","startOffset":22,"endOffset":23,"startByteOffset":26,"endByteOffset":27,"content":" ","children":[],"meta":{"i18n_language":"zh","i18n_target_language":"en","render":"false"}},{"type":"I18nInlineNode","startOffset":23,"endOffset":34,"startByteOffset":27,"endByteOffset":38,"languageId":"en","content":"Title","originalSyntax":":en{Title}:","children":[{"type":"TextNode","startOffset":27,"endOffset":32,"startByteOffset":31,"endByteOffset":36,"content":"Title","children":[],"meta":{"i18n_language":"en","i18n_target_language":"en"}}],"meta":{"i18n_language":"en","i18n_target_language":"en","languageId":"en"}}],"meta":{"baseSlug":"common-title","i18n_language":"zh","i18n_target_language":"en","slugOccurrence":1,"typstLabel":"common-title"}}],"meta":{"i18n_language":"zh","i18n_target_language":"en"}}"#)
            }
        )
    }
}
