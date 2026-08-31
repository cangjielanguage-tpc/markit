package markit.tests.unit.plugins.i18n.block

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.plugins.gfm.block.math_block.MathBlockConfig
import markit.plugins.gfm.inline.inline_math.InlineMathConfig
import markit.plugins.i18n.I18nPlugin
import markit.plugins.i18n.config.I18nConfig
import markit.plugins.standard.block.fenced_code_block.FencedCodeBlockConfig
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

private func i18nEn(): Markit {
    return Markit(GFMBundle(
        fencedCodeBlockConfig: FencedCodeBlockConfig(enableCodehl: false),
        mathBlockConfig: MathBlockConfig(enableHtmlMathtex: false),
        inlineMathConfig: InlineMathConfig(enableHtmlMathtex: false)
    )).use(I18nPlugin(
        config: I18nConfig(defaultLanguage: "zh", targetLanguage: "en")
    ))
}

private func i18nZh(): Markit {
    return Markit(GFMBundle(
        fencedCodeBlockConfig: FencedCodeBlockConfig(enableCodehl: false),
        mathBlockConfig: MathBlockConfig(enableHtmlMathtex: false),
        inlineMathConfig: InlineMathConfig(enableHtmlMathtex: false)
    )).use(I18nPlugin(
        config: I18nConfig(defaultLanguage: "zh", targetLanguage: "zh")
    ))
}

@Test
class I18nListSemanticsTests {
    @TestCase
    func translatedListKeepsFollowingNestedSublistAcrossModes() {
        let markdown = """
- xxx
:::en
- yyy
:::
  - zzz
"""

        ParseModeTestKit.assertHtmlAcrossModes(
            i18nEn,
            markdown,
            "<ul><li>yyy<ul><li>zzz</li></ul></li></ul>"
        )
        ParseModeTestKit.assertAcrossModes(
            i18nEn,
            markdown,
            { result: ParseModeResult =>
                if (result.mode != "direct-parse") {
                    @Expect(result.astPatchCount > 0, true)
                }
            }
        )
        ParseModeTestKit.assertHtmlAcrossModes(
            i18nZh,
            markdown,
            "<ul><li>xxx<ul><li>zzz</li></ul></li></ul>"
        )
    }

    @TestCase
    func translatedListKeepsTranslatedNestedSublistWithBlankLinesAcrossModes() {
        let markdown = """
- xxx

:::en
- yyy
:::

  - zzz

  :::en
  - zzz
  :::
"""

        ParseModeTestKit.assertHtmlAcrossModes(
            i18nEn,
            markdown,
            "<ul><li>yyy<ul><li>zzz</li></ul></li></ul>"
        )
        ParseModeTestKit.assertHtmlAcrossModes(
            i18nZh,
            markdown,
            "<ul><li>xxx<ul><li>zzz</li></ul></li></ul>"
        )
    }

    @TestCase
    func translatedListMergesAcrossHiddenSiblingBlocksAcrossModes() {
        let markdown = """
- xxx

:::en
- yyy
:::

- xxx

:::en
- yyy
:::
"""

        ParseModeTestKit.assertHtmlAcrossModes(
            i18nEn,
            markdown,
            "<ul><li>yyy</li><li>yyy</li></ul>"
        )
        ParseModeTestKit.assertHtmlAcrossModes(
            i18nZh,
            markdown,
            "<ul><li>xxx</li><li>xxx</li></ul>"
        )
    }

    @TestCase
    func translatedNestedOrderedListsMergeAcrossHiddenSiblingBlocksAcrossModes() {
        let markdown = """
- do

:::en
- do it
:::

  1. xxx

  :::en
  1. yyy
  :::

  2. xxx

  :::en
  2. yyy
  :::
"""

        ParseModeTestKit.assertHtmlAcrossModes(
            i18nEn,
            markdown,
            "<ul><li>do it<ol><li>yyy</li><li>yyy</li></ol></li></ul>"
        )
        ParseModeTestKit.assertHtmlAcrossModes(
            i18nZh,
            markdown,
            "<ul><li>do<ol><li>xxx</li><li>xxx</li></ol></li></ul>"
        )
    }

    @TestCase
    func translatedListKeepsFollowingIndentedCodeBlockAcrossModes() {
        let markdown = """
- xxx
:::en
- yyy
:::
  ```cangjie
  let x = 1
  ```
"""

        ParseModeTestKit.assertHtmlAcrossModes(
            i18nEn,
            markdown,
            "<ul><li>yyy<pre><code class=\"language-cangjie\">let x = 1</code></pre></li></ul>"
        )
        ParseModeTestKit.assertHtmlAcrossModes(
            i18nZh,
            markdown,
            "<ul><li>xxx<pre><code class=\"language-cangjie\">let x = 1</code></pre></li></ul>"
        )
    }

    @TestCase
    func translatedListKeepsFollowingMathBlockAcrossModes() {
        let markdown = """
- aaa
:::en
- bbb
:::
  1. ccc
  :::en
  1. ddd
  :::
    $$
    \\sigma = [T_1 \\mapsto T_{i1}, ..., T_p \\mapsto T_{ip}]
    $$
"""

        ParseModeTestKit.assertHtmlAcrossModes(
            i18nEn,
            markdown,
            "<ul><li>bbb<ol><li>ddd<div class=\"math-block\">\\sigma = [T_1 \\mapsto T_{i1}, ..., T_p \\mapsto T_{ip}]</div></li></ol></li></ul>"
        )
        ParseModeTestKit.assertHtmlAcrossModes(
            i18nZh,
            markdown,
            "<ul><li>aaa<ol><li>ccc<div class=\"math-block\">\\sigma = [T_1 \\mapsto T_{i1}, ..., T_p \\mapsto T_{ip}]</div></li></ol></li></ul>"
        )
    }

    @TestCase
    func translatedNestedParagraphRespectsTargetLanguageAcrossModes() {
        let markdown = """
- aaa

:::en
- bbb
:::

  aaa paragraph

  :::en
  bbb paragraph
  :::
"""

        ParseModeTestKit.assertHtmlAcrossModes(
            i18nEn,
            markdown,
            "<ul><li>bbb<p>bbb paragraph</p></li></ul>"
        )
        ParseModeTestKit.assertHtmlAcrossModes(
            i18nZh,
            markdown,
            "<ul><li>aaa<p>aaa paragraph</p></li></ul>"
        )
    }
}
