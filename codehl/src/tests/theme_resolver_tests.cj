package codehl.tests

import std.unittest.*
import std.unittest.testmacro.*
import codehl.{DualThemeOptions, Highlighter, HighlightOptions, ThemeLoader, ThemeRegistry, ThemeResolver}

@Test
@Tag[ThemeResolver]
class ThemeResolverTests {
    @TestCase
    func loaderParsesTokenColorsAndEditorDefaults() {
        let theme = ThemeLoader().loadFromJson("{\"name\":\"Test Theme\",\"colors\":{\"editor.foreground\":\"#111111\",\"editor.background\":\"#ffffff\"},\"tokenColors\":[{\"scope\":\"keyword, string.quoted\",\"settings\":{\"foreground\":\"#ff0000\",\"fontStyle\":\"bold italic\"}}]}")

        @Expect(theme.name, "Test Theme")
        @Expect(theme.foreground, "#111111")
        @Expect(theme.background, "#ffffff")
        @Expect(theme.rules.size, 2)
        @Expect(theme.rules[0].scope, "keyword")
        @Expect(theme.rules[1].scope, "string.quoted")
    }

    @TestCase
    func resolverPrefersMoreSpecificSelectorAndLaterTie() {
        let theme = ThemeLoader().loadFromJson("{\"name\":\"Test\",\"tokenColors\":[{\"scope\":\"keyword\",\"settings\":{\"foreground\":\"#111111\"}},{\"scope\":\"keyword.control\",\"settings\":{\"foreground\":\"#222222\"}},{\"scope\":\"keyword.control\",\"settings\":{\"foreground\":\"#333333\",\"fontStyle\":\"underline\"}}]}")
        let resolver = ThemeResolver(theme)

        @Expect(resolver.styleForScope("keyword-control-cangjie"), "color:#333333;text-decoration:underline;")
    }

    @TestCase
    func resolverMatchesParentScopeSelectorsAndExclusions() {
        let theme = ThemeLoader().loadFromJson("{\"name\":\"Test\",\"tokenColors\":[{\"scope\":\"string.quoted\",\"settings\":{\"foreground\":\"#111111\"}},{\"scope\":\"source.ts meta.object-literal.ts string.quoted\",\"settings\":{\"foreground\":\"#222222\"}},{\"scope\":\"string.quoted - meta.object-literal.ts\",\"settings\":{\"foreground\":\"#333333\"}}]}")
        let resolver = ThemeResolver(theme)

        @Expect(
            resolver.styleForScopeStack(["source.ts", "meta.object-literal.ts", "string.quoted.double.ts"]),
            "color:#222222;"
        )
        @Expect(
            resolver.styleForScopeStack(["source.ts", "meta.import.ts", "string.quoted.double.ts"]),
            "color:#333333;"
        )
    }

    @TestCase
    func resolverMergesForegroundAndFontStyleIndependentlyWithReset() {
        let theme = ThemeLoader().loadFromJson("{\"name\":\"Test\",\"tokenColors\":[{\"scope\":\"keyword\",\"settings\":{\"foreground\":\"#111111\",\"fontStyle\":\"italic\"}},{\"scope\":\"keyword.control\",\"settings\":{\"foreground\":\"#222222\"}},{\"scope\":\"source.ts keyword.control\",\"settings\":{\"fontStyle\":\"\"}}]}")
        let resolver = ThemeResolver(theme)

        @Expect(
            resolver.styleForScopeStack(["source.ts", "keyword.control.ts"]),
            "color:#222222;"
        )
    }

    @TestCase
    func resolverKeepsTokenSpecificityAboveGenericParentSelectors() {
        let theme = ThemeLoader().loadFromJson("{\"name\":\"Test\",\"tokenColors\":[{\"scope\":\"source.ts string\",\"settings\":{\"foreground\":\"#111111\"}},{\"scope\":\"string.quoted.double\",\"settings\":{\"foreground\":\"#222222\"}}]}")
        let resolver = ThemeResolver(theme)

        @Expect(
            resolver.styleForScopeStack(["source.ts", "string.quoted.double.ts"]),
            "color:#222222;"
        )
    }

    @TestCase
    func resolverPrefersCloserParentWhenTokenSpecificityTies() {
        let theme = ThemeLoader().loadFromJson("{\"name\":\"Test\",\"tokenColors\":[{\"scope\":\"source.ts string.quoted\",\"settings\":{\"foreground\":\"#111111\"}},{\"scope\":\"meta.template string.quoted\",\"settings\":{\"foreground\":\"#222222\"}}]}")
        let resolver = ThemeResolver(theme)

        @Expect(
            resolver.styleForScopeStack(["source.ts", "meta.template", "string.quoted.double.ts"]),
            "color:#222222;"
        )
    }

    @TestCase
    func highlighterCanRenderInlineStylesFromThemeWithoutChangingUnthemedOutput() {
        let theme = ThemeLoader().loadFromJson("{\"name\":\"Test\",\"tokenColors\":[{\"scope\":\"punctuation.definition.dictionary.begin.json\",\"settings\":{\"foreground\":\"#123456\"}},{\"scope\":\"constant.language.json\",\"settings\":{\"foreground\":\"#abcdef\",\"fontStyle\":\"italic\"}}]}")
        let html = Highlighter().highlight("{\"ok\": false}", options: HighlightOptions(lang: "json", theme: Some(theme)))

        @Expect(
            html,
            "<pre class=\"codehl codehl-lang-json\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-punctuation-definition-dictionary-begin-json\" style=\"color:#123456;\">{</span><span class=\"codehl-token codehl-string-json-support-type-property-name-json\">\"ok\"</span><span class=\"codehl-token codehl-punctuation-separator-dictionary-key-value-json\">:</span> <span class=\"codehl-token codehl-constant-language-json\" style=\"color:#abcdef;font-style:italic;\">false</span><span class=\"codehl-token codehl-punctuation-definition-dictionary-end-json\">}</span></span></code></pre>"
        )
    }

    @TestCase
    func highlighterDefaultThemeCanBeSetAndOverriddenPerCall() {
        let defaultTheme = ThemeLoader().loadFromJson("{\"name\":\"Default\",\"tokenColors\":[{\"scope\":\"constant.language.json\",\"settings\":{\"foreground\":\"#111111\"}}]}")
        let overrideTheme = ThemeLoader().loadFromJson("{\"name\":\"Override\",\"tokenColors\":[{\"scope\":\"constant.language.json\",\"settings\":{\"foreground\":\"#222222\"}}]}")
        let highlighter = Highlighter(theme: Some(defaultTheme))

        @Expect(
            highlighter.highlight("false", options: HighlightOptions(lang: "json")),
            "<pre class=\"codehl codehl-lang-json\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-constant-language-json\" style=\"color:#111111;\">false</span></span></code></pre>"
        )
        @Expect(
            highlighter.highlight("false", options: HighlightOptions(lang: "json", theme: Some(overrideTheme))),
            "<pre class=\"codehl codehl-lang-json\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-constant-language-json\" style=\"color:#222222;\">false</span></span></code></pre>"
        )
    }

    @TestCase
    func themeRegistryLoadsThemeAssetsByName() {
        let theme = ThemeRegistry().loadTheme("test-light").getOrThrow()

        @Expect(theme.name, "Test Light")
        @Expect(ThemeResolver(theme).styleForScope("constant-language-json"), "color:#222222;")
    }

    @TestCase
    func highlighterSupportsThemeNamesFromAssets() {
        let highlighter = Highlighter()

        @Expect(highlighter.supportsTheme("light-plus"), true)
        @Expect(highlighter.supportsTheme("dark-plus"), true)
        @Expect(highlighter.supportsTheme("missing-theme"), false)
    }

    @TestCase
    func highlighterCanRenderSingleThemeByName() {
        let html = Highlighter().highlight(
            "false",
            options: HighlightOptions(lang: "json", themeName: "light-plus")
        )

        @Expect(
            html,
            "<pre class=\"codehl codehl-lang-json\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-constant-language-json\" style=\"color:#0000ff;\">false</span></span></code></pre>"
        )
    }

    @TestCase
    func highlighterReturnsDualThemeFragmentsForNodeMetaStorage() {
        let light = ThemeLoader().loadFromJson("{\"name\":\"Light\",\"tokenColors\":[{\"scope\":\"constant.language.json\",\"settings\":{\"foreground\":\"#111111\"}}]}")
        let dark = ThemeLoader().loadFromJson("{\"name\":\"Dark\",\"tokenColors\":[{\"scope\":\"constant.language.json\",\"settings\":{\"foreground\":\"#eeeeee\"}}]}")
        let fragments = Highlighter().highlightDualThemeFragments(
            "false",
            options: DualThemeOptions(
                lightThemeModel: Some(light),
                darkThemeModel: Some(dark),
                base: HighlightOptions(lang: "json")
            )
        )

        @Expect(
            fragments.lightHtml,
            "<pre class=\"codehl codehl-lang-json\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-constant-language-json\" style=\"color:#111111;\">false</span></span></code></pre>"
        )
        @Expect(
            fragments.darkHtml,
            "<pre class=\"codehl codehl-lang-json\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-constant-language-json\" style=\"color:#eeeeee;\">false</span></span></code></pre>"
        )
    }

    @TestCase
    func dualThemeFragmentsLoadThemeNamesWhenModelsAreNotProvided() {
        let fragments = Highlighter().highlightDualThemeFragments(
            "false",
            options: DualThemeOptions(
                lightTheme: "light-plus",
                darkTheme: "dark-plus",
                base: HighlightOptions(lang: "json")
            )
        )

        @Expect(
            fragments.lightHtml,
            "<pre class=\"codehl codehl-lang-json\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-constant-language-json\" style=\"color:#0000ff;\">false</span></span></code></pre>"
        )
        @Expect(
            fragments.darkHtml,
            "<pre class=\"codehl codehl-lang-json\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-constant-language-json\" style=\"color:#569cd6;\">false</span></span></code></pre>"
        )
    }
}
