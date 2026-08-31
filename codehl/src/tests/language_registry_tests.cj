package codehl.tests

import std.unittest.*
import std.unittest.testmacro.*
import std.fs.{Path, canonicalize, exists}
import codehl.languages.LanguageRegistry
import codehl.languages.TokenizerState

@Test
@Tag[LanguageRegistry, TextMateGrammar]
class LanguageRegistryTests {
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
}
