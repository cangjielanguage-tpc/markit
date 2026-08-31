package codehl.tests

import std.unittest.*
import std.unittest.testmacro.*
import codehl.{GrammarLoader, GrammarTokenizer}
import codehl.languages.TokenizerState

@Test
@Tag[RegexAdapter, TextMateGrammar]
class RegexAdapterTests {
    @TestCase
    func tokenizerDowngradesPossessiveQuantifiersFromTextMatePatterns() {
        let grammar = GrammarLoader().loadFromJson("{\"name\":\"Toy\",\"scopeName\":\"source.toy\",\"patterns\":[{\"match\":\"name\\\\s*+=\",\"name\":\"keyword.operator.assignment.toy\"}]}")
        let tokenizer = GrammarTokenizer(grammar, ["toy"])
        let tokens = tokenizer.tokenizeLine("let name   = value", TokenizerState()).tokens

        @Expect(tokens.size, 1)
        @Expect(tokens[0].startByte, 4)
        @Expect(tokens[0].endByte, 12)
        @Expect(tokens[0].scope, "keyword-operator-assignment-toy")
    }

    @TestCase
    func tokenizerExpandsCommonPosixCharacterClasses() {
        let grammar = GrammarLoader().loadFromJson("{\"name\":\"Toy\",\"scopeName\":\"source.toy\",\"patterns\":[{\"match\":\"[[:upper:]][_$[:digit:][:upper:]]*\",\"name\":\"entity.name.type.toy\"}]}")
        let tokenizer = GrammarTokenizer(grammar, ["toy"])
        let tokens = tokenizer.tokenizeLine("type HTTP2_OK = string", TokenizerState()).tokens

        @Expect(tokens.size, 1)
        @Expect(tokens[0].startByte, 5)
        @Expect(tokens[0].endByte, 13)
        @Expect(tokens[0].scope, "entity-name-type-toy")
    }

    @TestCase
    func tokenizerDowngradesAtomicGroupsWithoutAddingCaptureIndexes() {
        let grammar = GrammarLoader().loadFromJson("{\"name\":\"Toy\",\"scopeName\":\"source.toy\",\"patterns\":[{\"match\":\"(?>foo|bar)(baz)\",\"captures\":{\"1\":{\"name\":\"variable.other.capture.toy\"}},\"name\":\"meta.atomic.toy\"}]}")
        let tokenizer = GrammarTokenizer(grammar, ["toy"])
        let tokens = tokenizer.tokenizeLine("foo foobaz", TokenizerState()).tokens

        @Expect(tokens.size, 1)
        @Expect(tokens[0].startByte, 7)
        @Expect(tokens[0].endByte, 10)
        @Expect(tokens[0].scope, "variable-other-capture-toy")
    }

    @TestCase
    func tokenizerKeepsUtf8LiteralsWhenRewritingExtendedPatterns() {
        let grammar = GrammarLoader().loadFromJson("{\"name\":\"Toy\",\"scopeName\":\"source.toy\",\"patterns\":[{\"match\":\"(?x)中文\",\"name\":\"string.quoted.double.toy\"}]}")
        let tokenizer = GrammarTokenizer(grammar, ["toy"])
        let tokens = tokenizer.tokenizeLine("x 中文 y", TokenizerState()).tokens

        @Expect(tokens.size, 1)
        @Expect(tokens[0].startByte, 2)
        @Expect(tokens[0].endByte, 8)
        @Expect(tokens[0].scope, "string-quoted-double-toy")
    }

    @TestCase
    func tokenizerKeepsUtf8CaptureTextWhenResolvingEndBackReferences() {
        let grammar = GrammarLoader().loadFromJson("{\"name\":\"Toy\",\"scopeName\":\"source.toy\",\"patterns\":[{\"begin\":\"(中文)\",\"end\":\"\\\\1\",\"name\":\"string.quoted.double.toy\"}]}")
        let tokenizer = GrammarTokenizer(grammar, ["toy"])
        let tokens = tokenizer.tokenizeLine("中文 body 中文", TokenizerState()).tokens

        @Expect(tokens.size, 1)
        @Expect(tokens[0].startByte, 0)
        @Expect(tokens[0].endByte, 18)
        @Expect(tokens[0].scope, "string-quoted-double-toy")
    }
}
