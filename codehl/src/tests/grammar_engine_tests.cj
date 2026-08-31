package codehl.tests

import std.collection.HashMap
import std.unittest.*
import std.unittest.testmacro.*
import codehl.{Grammar, GrammarLoader, GrammarTokenizer, Highlighter, HighlightOptions}
import codehl.languages.TokenizerState

@Test
@Tag[TextMateGrammar]
class GrammarEngineTests {
    @TestCase
    func loaderParsesRepositoryIncludes() {
        let grammar = GrammarLoader().loadFromJson("{\"name\":\"Toy\",\"scopeName\":\"source.toy\",\"patterns\":[{\"include\":\"#keywords\"}],\"repository\":{\"keywords\":{\"patterns\":[{\"match\":\"\\\\b(let|func)\\\\b\",\"name\":\"keyword.control.toy\",\"captures\":{\"1\":{\"name\":\"keyword.control.toy.capture\"}}}]}}}")

        @Expect(grammar.name, "Toy")
        @Expect(grammar.scopeName, "source.toy")
        @Expect(grammar.patterns.size, 1)
        @Expect(grammar.patterns[0].include, "#keywords")
        @Expect(grammar.repository["keywords"].patterns[0].name, "keyword.control.toy")
        @Expect(grammar.repository["keywords"].patterns[0].captures[1].name, "keyword.control.toy.capture")
    }

    @TestCase
    func tokenizerUsesJsonLoadedMatchRules() {
        let grammar = GrammarLoader().loadFromJson("{\"name\":\"Toy\",\"scopeName\":\"source.toy\",\"patterns\":[{\"include\":\"#keywords\"},{\"include\":\"#strings\"}],\"repository\":{\"keywords\":{\"patterns\":[{\"match\":\"\\\\b(let|func)\\\\b\",\"name\":\"keyword.control.toy\"}]},\"strings\":{\"patterns\":[{\"begin\":\"\\\"\",\"end\":\"\\\"\",\"name\":\"string.quoted.double.toy\"}]}}}")
        let tokenizer = GrammarTokenizer(grammar, ["toy"])
        let tokens = tokenizer.tokenizeLine("let name = \"Day\"", TokenizerState()).tokens

        @Expect(tokens.size, 2)
        @Expect(tokens[0].startByte, 0)
        @Expect(tokens[0].endByte, 3)
        @Expect(tokens[0].scope, "keyword-control-toy")
        @Expect(tokens[1].startByte, 11)
        @Expect(tokens[1].endByte, 16)
        @Expect(tokens[1].scope, "string-quoted-double-toy")
    }

    @TestCase
    func tokenizerAppliesCapturePatterns() {
        let grammar = GrammarLoader().loadFromJson("{\"name\":\"Toy\",\"scopeName\":\"source.toy\",\"patterns\":[{\"match\":\"(#[A-Za-z]+)\",\"name\":\"markup.heading.toy\",\"captures\":{\"1\":{\"patterns\":[{\"match\":\"(#)([A-Za-z]+)\",\"captures\":{\"1\":{\"name\":\"punctuation.definition.heading.toy\"},\"2\":{\"name\":\"entity.name.section.toy\"}}}]}}}]}")
        let tokenizer = GrammarTokenizer(grammar, ["toy"])
        let tokens = tokenizer.tokenizeLine("#Title", TokenizerState()).tokens

        @Expect(tokens.size, 2)
        @Expect(tokens[0].startByte, 0)
        @Expect(tokens[0].endByte, 1)
        @Expect(tokens[0].scope, "punctuation-definition-heading-toy")
        @Expect(tokens[1].startByte, 1)
        @Expect(tokens[1].endByte, 6)
        @Expect(tokens[1].scope, "entity-name-section-toy")
    }

    @TestCase
    func loaderParsesInjectionsAndContentName() {
        let grammar = GrammarLoader().loadFromJson("{\"name\":\"Host\",\"scopeName\":\"text.host\",\"patterns\":[{\"begin\":\"<script>\",\"end\":\"</script>\",\"name\":\"meta.embedded.host\",\"contentName\":\"source.js\",\"applyEndPatternLast\":true}],\"injections\":{\"L:text.host\":{\"match\":\"TODO\",\"name\":\"keyword.todo.host\"}}}")

        @Expect(grammar.patterns.size, 1)
        @Expect(grammar.patterns[0].contentName, "source.js")
        @Expect(grammar.patterns[0].applyEndPatternLast, true)
        @Expect(grammar.injections.size, 1)
        @Expect(grammar.injections[0].name, "keyword.todo.host")
    }

    @TestCase
    func loaderParsesWhileCapturesAndNumericApplyEndPatternLast() {
        let grammar = GrammarLoader().loadFromJson("{\"name\":\"Host\",\"scopeName\":\"text.host\",\"patterns\":[{\"begin\":\"^>\",\"while\":\"^>\",\"name\":\"markup.quote.host\",\"whileCaptures\":{\"0\":{\"name\":\"punctuation.definition.quote.host\"}},\"applyEndPatternLast\":1}]}")

        @Expect(grammar.patterns.size, 1)
        @Expect(grammar.patterns[0].whilePattern, "^>")
        @Expect(grammar.patterns[0].whileCaptures[0].name, "punctuation.definition.quote.host")
        @Expect(grammar.patterns[0].applyEndPatternLast, true)
    }

    @TestCase
    func tokenizerAppliesRootInjections() {
        let grammar = GrammarLoader().loadFromJson("{\"name\":\"Host\",\"scopeName\":\"text.host\",\"patterns\":[],\"injections\":{\"L:text.host\":{\"match\":\"TODO\",\"name\":\"keyword.todo.host\"}}}")
        let tokenizer = GrammarTokenizer(grammar, ["host"])
        let tokens = tokenizer.tokenizeLine("note TODO", TokenizerState()).tokens

        @Expect(tokens.size, 1)
        @Expect(tokens[0].startByte, 5)
        @Expect(tokens[0].endByte, 9)
        @Expect(tokens[0].scope, "keyword-todo-host")
    }

    @TestCase
    func tokenizerResolvesExternalScopeIncludes() {
        let host = GrammarLoader().loadFromJson("{\"name\":\"Host\",\"scopeName\":\"text.host\",\"patterns\":[{\"include\":\"source.js\"}]}")
        let js = GrammarLoader().loadFromJson("{\"name\":\"JS\",\"scopeName\":\"source.js\",\"patterns\":[{\"match\":\"\\\\bconst\\\\b\",\"name\":\"keyword.declaration.const.js\"}]}")
        let external = HashMap<String, Grammar>()
        external["source.js"] = js
        let tokenizer = GrammarTokenizer(host, ["host"], external)
        let tokens = tokenizer.tokenizeLine("const x = 1", TokenizerState()).tokens

        @Expect(tokens.size, 1)
        @Expect(tokens[0].startByte, 0)
        @Expect(tokens[0].endByte, 5)
        @Expect(tokens[0].scope, "keyword-declaration-const-js")
    }

    @TestCase
    func tokenizerResolvesExternalRepositoryIncludes() {
        let host = GrammarLoader().loadFromJson("{\"name\":\"Host\",\"scopeName\":\"text.host\",\"patterns\":[{\"include\":\"source.js#keywords\"}]}")
        let js = GrammarLoader().loadFromJson("{\"name\":\"JS\",\"scopeName\":\"source.js\",\"patterns\":[{\"match\":\"\\\\bignored\\\\b\",\"name\":\"invalid.illegal.js\"}],\"repository\":{\"keywords\":{\"patterns\":[{\"match\":\"\\\\bconst\\\\b\",\"name\":\"keyword.declaration.const.js\"}]}}}")
        let external = HashMap<String, Grammar>()
        external["source.js"] = js
        let tokenizer = GrammarTokenizer(host, ["host"], external)
        let tokens = tokenizer.tokenizeLine("const ignored", TokenizerState()).tokens

        @Expect(tokens.size, 1)
        @Expect(tokens[0].startByte, 0)
        @Expect(tokens[0].endByte, 5)
        @Expect(tokens[0].scope, "keyword-declaration-const-js")
    }

    @TestCase
    func tokenizerUsesContentNameAsExternalChildGrammar() {
        let host = GrammarLoader().loadFromJson("{\"name\":\"Host\",\"scopeName\":\"text.host\",\"patterns\":[{\"begin\":\"<script>\",\"end\":\"</script>\",\"name\":\"meta.embedded.block.host\",\"contentName\":\"source.js\"}]}")
        let js = GrammarLoader().loadFromJson("{\"name\":\"JS\",\"scopeName\":\"source.js\",\"patterns\":[{\"match\":\"\\\\bconst\\\\b\",\"name\":\"keyword.declaration.const.js\"}]}")
        let external = HashMap<String, Grammar>()
        external["source.js"] = js
        let tokenizer = GrammarTokenizer(host, ["host"], external)
        let tokens = tokenizer.tokenizeLine("<script>const x</script>", TokenizerState()).tokens

        @Expect(tokens.size, 1)
        @Expect(tokens[0].startByte, 8)
        @Expect(tokens[0].endByte, 13)
        @Expect(tokens[0].scope, "keyword-declaration-const-js")
    }

    @TestCase
    func tokenizerCarriesBeginWhileContextAcrossLines() {
        let grammar = GrammarLoader().loadFromJson("{\"name\":\"Quote\",\"scopeName\":\"text.quote\",\"patterns\":[{\"begin\":\"^>\",\"while\":\"^>\",\"name\":\"markup.quote.host\",\"beginCaptures\":{\"0\":{\"name\":\"punctuation.definition.quote.begin.host\"}},\"whileCaptures\":{\"0\":{\"name\":\"punctuation.definition.quote.continue.host\"}}}]}")
        let tokenizer = GrammarTokenizer(grammar, ["quote"])
        let first = tokenizer.tokenizeLine("> one", TokenizerState())
        let second = tokenizer.tokenizeLine("> two", first.state)
        let third = tokenizer.tokenizeLine("plain", second.state)

        @Expect(first.state.isInitial(), false)
        @Expect(second.state.isInitial(), false)
        @Expect(third.state.isInitial(), true)
        @Expect(first.tokens.size, 1)
        @Expect(first.tokens[0].scope, "punctuation-definition-quote-begin-host")
        @Expect(second.tokens.size, 1)
        @Expect(second.tokens[0].scope, "punctuation-definition-quote-continue-host")
    }

    @TestCase
    func tokenizerKeepsLineStartAnchorsRelativeToOriginalLine() {
        let grammar = GrammarLoader().loadFromJson("{\"name\":\"Toy\",\"scopeName\":\"source.toy\",\"patterns\":[{\"begin\":\"const\\\\s+\",\"end\":\"(?=^|;)\",\"patterns\":[{\"begin\":\"([A-Za-z]+)\",\"beginCaptures\":{\"1\":{\"name\":\"variable.other.toy\"}},\"end\":\"(?==|;)\",\"patterns\":[{\"begin\":\"(:)\",\"beginCaptures\":{\"1\":{\"name\":\"keyword.operator.type.annotation.toy\"}},\"end\":\"(?==|;)\",\"patterns\":[{\"match\":\"[A-Za-z]+\",\"name\":\"support.type.primitive.toy\"}]}]}]},{\"match\":\"([A-Za-z]+)\\\\s*(:)\",\"captures\":{\"1\":{\"name\":\"entity.name.label.toy\"},\"2\":{\"name\":\"punctuation.separator.label.toy\"}}}]}")
        let tokenizer = GrammarTokenizer(grammar, ["toy"])
        let tokens = tokenizer.tokenizeLine("const foo: string = \"bar\"", TokenizerState()).tokens

        @Expect(tokens.size, 4)
        @Expect(tokens[0].scope, "variable-other-toy")
        @Expect(tokens[1].scope, "keyword-operator-type-annotation-toy")
        @Expect(tokens[2].scope, "support-type-primitive-toy")
        @Expect(tokens[3].scope, "variable-other-toy")
    }

    @TestCase
    func realHtmlScriptCarriesEmbeddedJavaScriptAcrossLines() {
        let html = Highlighter().highlight("<script>\nconst foo = \"bar\"\n</script>", options: HighlightOptions(lang: "html"))

        @Expect(
            html,
            "<pre class=\"codehl codehl-lang-html\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-punctuation-definition-tag-html\">&lt;</span><span class=\"codehl-token codehl-entity-name-tag-script-html\">script</span><span class=\"codehl-token codehl-punctuation-definition-tag-html\">&gt;</span></span>\n<span class=\"codehl-line\" data-line=\"2\"><span class=\"codehl-token codehl-storage-type-js\">const</span> <span class=\"codehl-token codehl-meta-definition-variable-js-variable-other-constant-js\">foo</span> <span class=\"codehl-token codehl-keyword-operator-assignment-js\">=</span> <span class=\"codehl-token codehl-string-quoted-double-js\">\"bar\"</span></span>\n<span class=\"codehl-line\" data-line=\"3\"><span class=\"codehl-token codehl-punctuation-definition-tag-html\">&lt;/</span><span class=\"codehl-token codehl-entity-name-tag-script-html\">script</span>&gt;</span></code></pre>"
        )
    }

}
