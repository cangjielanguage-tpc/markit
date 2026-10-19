package codehl.tests

import std.unittest.*
import std.unittest.testmacro.*
import std.fs.{Path, canonicalize, exists}
import codehl.languages.LanguageRegistry
import codehl.languages.TokenizerState
import codehl.{Highlighter, HighlightOptions, LanguageRegistration}

@Test
@Tag[LanguageRegistry, TextMateGrammar]
class LanguageRegistryTests {
    @TestCase
    func cangjieHighlightsOrganizationPrefixes() {
        let tokenizer = LanguageRegistry().findTokenizer("cangjie").getOrThrow()
        for (source in ["package org::pkg.sub", "import org::pkg.Type", "org::pkg", "package `org`::pkg", "org_name::pkg"]) {
            let tokens = tokenizer.tokenizeLine(source, TokenizerState()).tokens
            var organization = false
            var packageName = false
            for (token in tokens) {
                let value = source[token.startByte..token.endByte]
                if (token.scope.endsWith("entity-name-organization-Cangjie")) {
                    if (value == "org" || value == "`org`" || value == "org_name") {
                        organization = true
                    }
                }
                if (value == "pkg" && token.scope.endsWith("entity-name-namespace-Cangjie")) {
                    packageName = true
                }
                if (value == "sub") {
                    @Expect(token.scope.endsWith("variable-other-namespace-member-Cangjie"), true)
                }
                if (value == "Type") {
                    @Expect(token.scope.endsWith("entity-name-type-Cangjie"), true)
                }
            }
            @Expect(organization, true)
            @Expect(packageName, true)
        }
    }

    @TestCase
    func cangjieDoesNotHighlightOrganizationPrefixesInsideStringsOrComments() {
        let tokenizer = LanguageRegistry().findTokenizer("cangjie").getOrThrow()
        let tokens = tokenizer.tokenizeLine("let text = \"org::pkg\" // org::pkg", TokenizerState()).tokens
        for (token in tokens) {
            @Expect(token.scope.contains("entity-name-namespace"), false)
            @Expect(token.scope.contains("entity-name-organization"), false)
        }
    }

    @TestCase
    func discoversBundledGrammarsByDefault() {
        let registry = LanguageRegistry()

        @Expect(registry.findTokenizer("cangjie").isSome(), true)
        @Expect(registry.findTokenizer("json").isSome(), true)
        @Expect(registry.findTokenizer("ts").isSome(), true)
    }

    @TestCase
    func discoversGrammarFromConfiguredDirectory() {
        let registry = LanguageRegistry(grammarDirs: ["tests/fixtures/grammars", "..\\..\\..\\tests\\fixtures\\grammars"])

        @Expect(registry.findTokenizer("autotoy").isSome(), true)
        @Expect(registry.findTokenizer("atoy").isSome(), true)
        @Expect(registry.findTokenizer("toyfile").isSome(), true)
    }

    @TestCase
    func discoversGrammarFromAbsoluteConfiguredDirectory() {
        let relative = if (exists(Path("tests/fixtures/grammars"))) {
            Path("tests/fixtures/grammars")
        } else {
            Path("..\\..\\..\\tests\\fixtures\\grammars")
        }
        let registry = LanguageRegistry(grammarDirs: [canonicalize(relative).toString()])

        @Expect(registry.findTokenizer("autotoy").isSome(), true)
        @Expect(registry.findTokenizer("atoy").isSome(), true)
        @Expect(registry.findTokenizer("toyfile").isSome(), true)
    }

    @TestCase
    func userGrammarDirsOverrideBundledDiscovery() {
        let registry = LanguageRegistry(grammarDirs: ["tests/fixtures/override-grammars", "..\\..\\..\\tests\\fixtures\\override-grammars"])
        let tokenizer = registry.findTokenizer("json").getOrThrow()
        let tokens = tokenizer.tokenizeLine("override", TokenizerState()).tokens

        @Expect(tokens.size, 1)
        @Expect(tokens[0].scope, "keyword-control-user-json")
    }

    @TestCase
    func exactFileNameWinsOverScopeAndFileTypeAliases() {
        let registry = LanguageRegistry(
            grammarDir: "",
            grammarDirs: ["tests/fixtures/discovery-priority", "..\\..\\..\\tests\\fixtures\\discovery-priority"]
        )
        let tokens = registry.findTokenizer("prioritytoy").getOrThrow()
            .tokenizeLine("word", TokenizerState()).tokens

        @Expect(tokens.size, 1)
        @Expect(tokens[0].scope, "keyword-canonical-toy")
        let variantTokens = registry.findTokenizer("a-variant").getOrThrow()
            .tokenizeLine("word", TokenizerState()).tokens
        @Expect(variantTokens[0].scope, "keyword-variant-toy")
    }

    @TestCase
    func metadataAliasTieUsesStablePathOrder() {
        let registry = LanguageRegistry(
            grammarDir: "",
            grammarDirs: ["tests/fixtures/discovery-priority", "..\\..\\..\\tests\\fixtures\\discovery-priority"]
        )
        let tokens = registry.findTokenizer("sharedtoy").getOrThrow()
            .tokenizeLine("word", TokenizerState()).tokens

        @Expect(tokens.size, 1)
        @Expect(tokens[0].scope, "keyword-variant-toy")
    }

    @TestCase
    func userMetadataAliasStillOverridesBundledExactFileName() {
        let registry = LanguageRegistry(
            grammarDirs: ["tests/fixtures/discovery-priority", "..\\..\\..\\tests\\fixtures\\discovery-priority"]
        )
        let tokens = registry.findTokenizer("json").getOrThrow()
            .tokenizeLine("word", TokenizerState()).tokens

        @Expect(tokens.size, 1)
        @Expect(tokens[0].scope, "keyword-variant-toy")
    }

    @TestCase
    func embeddedGrammarKeepsUserScopeOverride() {
        let highlighter = Highlighter(
            grammarDirs: ["tests/fixtures/override-grammars", "..\\..\\..\\tests\\fixtures\\override-grammars"],
            languages: [LanguageRegistration("host", "host.tmLanguage.json")]
        )
        let html = highlighter.highlight("override", options: HighlightOptions(lang: "host"))

        @Expect(html.contains("codehl-keyword-control-user-json"), true)
    }

    @TestCase
    func defaultHtmlUsesExactFileNameGrammar() {
        let source = "<div class=\"foo\">bar</div>\n<script>const x = 1</script>"
        let options = HighlightOptions(lang: "html")
        let explicit = Highlighter(languages: [
            LanguageRegistration("html", "vscode/html/syntaxes/html.tmLanguage.json")
        ])

        @Expect(Highlighter().highlight(source, options: options), explicit.highlight(source, options: options))
    }
}
