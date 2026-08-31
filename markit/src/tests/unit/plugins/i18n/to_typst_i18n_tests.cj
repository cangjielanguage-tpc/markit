package markit.tests.unit.plugins.i18n

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.plugins.gfm.block.math_block.MathBlockConfig
import markit.plugins.gfm.inline.inline_math.InlineMathConfig
import markit.plugins.i18n.I18nPlugin
import markit.plugins.i18n.config.I18nConfig
import markit.tests.utils.ParseModeTestKit

private func i18nEn(): Markit {
    return Markit(GFMBundle(
        mathBlockConfig: MathBlockConfig(enableHtmlMathtex: false),
        inlineMathConfig: InlineMathConfig(enableHtmlMathtex: false)
    )).use(I18nPlugin(
        config: I18nConfig(defaultLanguage: "zh", targetLanguage: "en")
    ))
}

private func i18nZh(): Markit {
    return Markit(GFMBundle(
        mathBlockConfig: MathBlockConfig(enableHtmlMathtex: false),
        inlineMathConfig: InlineMathConfig(enableHtmlMathtex: false)
    )).use(I18nPlugin(
        config: I18nConfig(defaultLanguage: "zh", targetLanguage: "zh")
    ))
}

@Test
class ToTypstI18nTests {
    @TestCase
    func rendersTargetLanguageAndUniversalInlineOnlyAcrossModes() {
        ParseModeTestKit.assertTypstAcrossModes(
            i18nEn,
            ":en{Hello}: :zh{你好}: :{shared}:\n",
            "Helloshared\n\n"
        )

        ParseModeTestKit.assertTypstAcrossModes(
            i18nZh,
            ":en{Hello}: :zh{你好}: :{shared}:\n",
            " 你好 shared\n\n"
        )
    }

    @TestCase
    func orderedI18nListKeepsIndentedCodeBlockInTypstAcrossModes() {
        let markdown = """
4. 当类型别名实际指向的类型为 enum 时，可以作为 enum 声明的构造器的类型名
:::en
4. If it is a type alias for enum, it can be used as a type name of data constructor of the enum declaration.
:::
    ```cangjie
    enum TimeUnit { Day | Month | Year }
    ```
"""

        ParseModeTestKit.assertTypstAcrossModes(
            i18nEn,
            markdown,
            "+ If it is a type alias for enum, it can be used as a type name of data constructor of the enum declaration.\n\n" +
            "  ``````cangjie\n" +
            "  enum TimeUnit { Day | Month | Year }\n" +
            "  ``````\n\n"
        )

        ParseModeTestKit.assertTypstAcrossModes(
            i18nZh,
            markdown,
            "+ 当类型别名实际指向的类型为 enum 时，可以作为 enum 声明的构造器的类型名\n\n" +
            "  ``````cangjie\n" +
            "  enum TimeUnit { Day | Month | Year }\n" +
            "  ``````\n\n"
        )
    }

    @TestCase
    func nestedI18nListWithParagraphRespectsTargetLanguageInTypstAcrossModes() {
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

        ParseModeTestKit.assertTypstAcrossModes(
            i18nEn,
            markdown,
            "- bbb\n\n  bbb paragraph\n\n"
        )

        ParseModeTestKit.assertTypstAcrossModes(
            i18nZh,
            markdown,
            "- aaa\n\n  aaa paragraph\n\n"
        )
    }

    @TestCase
    func i18nListWithMultipleMathBlocksDoesNotDuplicateInTypstAcrossModes() {
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

  2. eee

  :::en
  2. fff
  :::

        $$
        \\sigma = [T_1 \\mapsto T_{i1}, ..., T_p \\mapsto T_{ip}]
        $$
"""

        ParseModeTestKit.assertTypstAcrossModes(
            i18nEn,
            markdown,
            "- bbb\n\n" +
            "  + ddd\n\n" +
            "    $\n" +
            "    sigma = [T_1 ↦ T_(i 1), …, T_p ↦ T_(i p)]\n" +
            "    $\n" +
            "  + fff\n\n" +
            "    $\n" +
            "    sigma = [T_1 ↦ T_(i 1), …, T_p ↦ T_(i p)]\n" +
            "    $\n\n"
        )

        ParseModeTestKit.assertTypstAcrossModes(
            i18nZh,
            markdown,
            "- aaa\n\n" +
            "  + ccc\n\n" +
            "    $\n" +
            "    sigma = [T_1 ↦ T_(i 1), …, T_p ↦ T_(i p)]\n" +
            "    $\n" +
            "  + eee\n\n" +
            "    $\n" +
            "    sigma = [T_1 ↦ T_(i 1), …, T_p ↦ T_(i p)]\n" +
            "    $\n\n"
        )
    }

    @TestCase
    func deepNestedI18nListMathBlockDoesNotDuplicateInTypstAcrossModes() {
        let markdown = """
- aaa
:::en
- bbb
:::

    - ccc

    :::en
    - ddd
    :::

        1. eee

        :::en
        1. fff
        :::

          $$
          \\Delta \\vdash (A1, ..., Ak) <: (A_{i1},...,A_{ik})
          $$
"""

        ParseModeTestKit.assertTypstAcrossModes(
            i18nEn,
            markdown,
            "- bbb\n\n" +
            "  - ddd\n\n" +
            "    + $\n" +
            "      Δ ⊢ (A 1, …, A k) <: (A_(i 1), …, A_(i k))\n" +
            "      $\n\n"
        )

        ParseModeTestKit.assertTypstAcrossModes(
            i18nZh,
            markdown,
            "- aaa\n\n" +
            "  - ccc\n\n" +
            "    + eee\n\n" +
            "      $\n" +
            "      Δ ⊢ (A 1, …, A k) <: (A_(i 1), …, A_(i k))\n" +
            "      $\n\n"
        )
    }

    @TestCase
    func nestedOrderedI18nMathBlockDoesNotAppendExtraOrderedListInTypstAcrossModes() {
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
       \\Delta \\vdash (A1, ..., Ak) <: (A_{i1},...,A_{ik})
       $$
"""

        ParseModeTestKit.assertTypstAcrossModes(
            i18nEn,
            markdown,
            "- bbb\n\n" +
            "  + ddd\n\n" +
            "    $\n" +
            "    Δ ⊢ (A 1, …, A k) <: (A_(i 1), …, A_(i k))\n" +
            "    $\n\n"
        )

        ParseModeTestKit.assertTypstAcrossModes(
            i18nZh,
            markdown,
            "- aaa\n\n" +
            "  + ccc\n\n" +
            "    $\n" +
            "    Δ ⊢ (A 1, …, A k) <: (A_(i 1), …, A_(i k))\n" +
            "    $\n\n"
        )
    }
}
