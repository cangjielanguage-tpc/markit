package codehl.tests

import std.unittest.*
import std.unittest.testmacro.*
import codehl.{Highlighter, HighlightOptions}

@Test
@Tag[ShikiMigration, TextMateGrammar]
class ShikiMigrationTests {
    @TestCase
    func engineJavascriptCompareJsonBasicObjectCase() {
        // Migrated from shiki/packages/engine-javascript/test/compare.test.ts: json-basic case 1.
        let html = Highlighter().highlight("{\"foo\":{\"bar\":1}}", options: HighlightOptions(lang: "json"))

        @Expect(
            html,
            "<pre class=\"codehl codehl-lang-json\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-punctuation-definition-dictionary-begin-json\">{</span><span class=\"codehl-token codehl-string-json-support-type-property-name-json\">\"foo\"</span><span class=\"codehl-token codehl-punctuation-separator-dictionary-key-value-json\">:</span><span class=\"codehl-token codehl-punctuation-definition-dictionary-begin-json\">{</span><span class=\"codehl-token codehl-string-json-support-type-property-name-json\">\"bar\"</span><span class=\"codehl-token codehl-punctuation-separator-dictionary-key-value-json\">:</span><span class=\"codehl-token codehl-constant-numeric-json\">1</span><span class=\"codehl-token codehl-punctuation-definition-dictionary-end-json\">}</span><span class=\"codehl-token codehl-punctuation-definition-dictionary-end-json\">}</span></span></code></pre>"
        )
    }

    @TestCase
    func engineJavascriptCompareJsonBasicArrayCase() {
        // Migrated from shiki/packages/engine-javascript/test/compare.test.ts: json-basic case 2.
        let html = Highlighter().highlight("[undefined, null, true, false, 0, 1, 1.1, \"foo\", [], {}]", options: HighlightOptions(lang: "json"))

        @Expect(
            html,
            "<pre class=\"codehl codehl-lang-json\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-punctuation-definition-array-begin-json\">[</span><span class=\"codehl-token codehl-invalid-illegal-expected-array-separator-json\">u</span><span class=\"codehl-token codehl-invalid-illegal-expected-array-separator-json\">n</span><span class=\"codehl-token codehl-invalid-illegal-expected-array-separator-json\">d</span><span class=\"codehl-token codehl-invalid-illegal-expected-array-separator-json\">e</span><span class=\"codehl-token codehl-invalid-illegal-expected-array-separator-json\">f</span><span class=\"codehl-token codehl-invalid-illegal-expected-array-separator-json\">i</span><span class=\"codehl-token codehl-invalid-illegal-expected-array-separator-json\">n</span><span class=\"codehl-token codehl-invalid-illegal-expected-array-separator-json\">e</span><span class=\"codehl-token codehl-invalid-illegal-expected-array-separator-json\">d</span><span class=\"codehl-token codehl-punctuation-separator-array-json\">,</span> <span class=\"codehl-token codehl-constant-language-json\">null</span><span class=\"codehl-token codehl-punctuation-separator-array-json\">,</span> <span class=\"codehl-token codehl-constant-language-json\">true</span><span class=\"codehl-token codehl-punctuation-separator-array-json\">,</span> <span class=\"codehl-token codehl-constant-language-json\">false</span><span class=\"codehl-token codehl-punctuation-separator-array-json\">,</span> <span class=\"codehl-token codehl-constant-numeric-json\">0</span><span class=\"codehl-token codehl-punctuation-separator-array-json\">,</span> <span class=\"codehl-token codehl-constant-numeric-json\">1</span><span class=\"codehl-token codehl-punctuation-separator-array-json\">,</span> <span class=\"codehl-token codehl-constant-numeric-json\">1.1</span><span class=\"codehl-token codehl-punctuation-separator-array-json\">,</span> <span class=\"codehl-token codehl-string-quoted-double-json\">\"foo\"</span><span class=\"codehl-token codehl-punctuation-separator-array-json\">,</span> <span class=\"codehl-token codehl-punctuation-definition-array-begin-json\">[</span><span class=\"codehl-token codehl-punctuation-definition-array-end-json\">]</span><span class=\"codehl-token codehl-punctuation-separator-array-json\">,</span> <span class=\"codehl-token codehl-punctuation-definition-dictionary-begin-json\">{</span><span class=\"codehl-token codehl-punctuation-definition-dictionary-end-json\">}</span><span class=\"codehl-token codehl-punctuation-definition-array-end-json\">]</span></span></code></pre>"
        )
    }

    @TestCase
    func engineJavascriptCompareJsoncCase() {
        // Migrated from shiki/packages/engine-javascript/test/compare.test.ts: jsonc case 1.
        let html = Highlighter().highlight("// comment\n{\"foo\":\"bar\"}", options: HighlightOptions(lang: "jsonc"))

        @Expect(
            html,
            "<pre class=\"codehl codehl-lang-jsonc\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-punctuation-definition-comment-json-comments\">//</span> comment</span>\n<span class=\"codehl-line\" data-line=\"2\"><span class=\"codehl-token codehl-punctuation-definition-dictionary-begin-json-comments\">{</span><span class=\"codehl-token codehl-string-json-comments-support-type-property-name-json-comments\">\"foo\"</span><span class=\"codehl-token codehl-punctuation-separator-dictionary-key-value-json-comments\">:</span><span class=\"codehl-token codehl-string-quoted-double-json-comments\">\"bar\"</span><span class=\"codehl-token codehl-punctuation-definition-dictionary-end-json-comments\">}</span></span></code></pre>"
        )
    }

    @TestCase
    func engineJavascriptCompareHtmlBasicTagCase() {
        // Migrated from shiki/packages/engine-javascript/test/compare.test.ts: html-basic case 1.
        let html = Highlighter().highlight("<div class=\"foo\">bar</div>", options: HighlightOptions(lang: "html"))

        @Expect(
            html,
            "<pre class=\"codehl codehl-lang-html\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-punctuation-definition-tag-html\">&lt;</span><span class=\"codehl-token codehl-entity-name-tag-block-any-html\">div</span> <span class=\"codehl-token codehl-entity-other-attribute-name-generic-html\">class</span><span class=\"codehl-token codehl-punctuation-separator-key-value-html\">=</span><span class=\"codehl-token codehl-string-quoted-double-handlebars\">\"foo\"</span><span class=\"codehl-token codehl-punctuation-definition-tag-html\">&gt;</span>bar<span class=\"codehl-token codehl-punctuation-definition-tag-html\">&lt;/</span><span class=\"codehl-token codehl-entity-name-tag-block-any-html\">div</span><span class=\"codehl-token codehl-punctuation-definition-tag-html\">&gt;</span></span></code></pre>"
        )
    }

    @TestCase
    func engineJavascriptCompareHtmlBasicDocumentCase() {
        // Migrated from shiki/packages/engine-javascript/test/compare.test.ts: html-basic case 2.
        let html = Highlighter().highlight("<!DOCTYPE html><html><head><title>foo</title></head><body>bar</body></html>", options: HighlightOptions(lang: "html"))

        @Expect(
            html,
            "<pre class=\"codehl codehl-lang-html\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-punctuation-definition-tag-html\">&lt;!</span><span class=\"codehl-token codehl-entity-name-tag-doctype-html\">DOCTYPE</span> html<span class=\"codehl-token codehl-punctuation-definition-tag-html\">&gt;</span><span class=\"codehl-token codehl-punctuation-definition-tag-html\">&lt;</span><span class=\"codehl-token codehl-entity-name-tag-structure-any-html\">html</span><span class=\"codehl-token codehl-punctuation-definition-tag-html\">&gt;</span><span class=\"codehl-token codehl-punctuation-definition-tag-html\">&lt;</span><span class=\"codehl-token codehl-entity-name-tag-structure-any-html\">head</span><span class=\"codehl-token codehl-punctuation-definition-tag-html\">&gt;</span><span class=\"codehl-token codehl-punctuation-definition-tag-html\">&lt;</span><span class=\"codehl-token codehl-entity-name-tag-inline-any-html\">title</span><span class=\"codehl-token codehl-punctuation-definition-tag-html\">&gt;</span>foo<span class=\"codehl-token codehl-punctuation-definition-tag-html\">&lt;/</span><span class=\"codehl-token codehl-entity-name-tag-inline-any-html\">title</span><span class=\"codehl-token codehl-punctuation-definition-tag-html\">&gt;</span><span class=\"codehl-token codehl-punctuation-definition-tag-html\">&lt;/</span><span class=\"codehl-token codehl-entity-name-tag-structure-any-html\">head</span><span class=\"codehl-token codehl-punctuation-definition-tag-html\">&gt;</span><span class=\"codehl-token codehl-punctuation-definition-tag-html\">&lt;</span><span class=\"codehl-token codehl-entity-name-tag-structure-any-html\">body</span><span class=\"codehl-token codehl-punctuation-definition-tag-html\">&gt;</span>bar<span class=\"codehl-token codehl-punctuation-definition-tag-html\">&lt;/</span><span class=\"codehl-token codehl-entity-name-tag-structure-any-html\">body</span><span class=\"codehl-token codehl-punctuation-definition-tag-html\">&gt;</span><span class=\"codehl-token codehl-punctuation-definition-tag-html\">&lt;/</span><span class=\"codehl-token codehl-entity-name-tag-structure-any-html\">html</span><span class=\"codehl-token codehl-punctuation-definition-tag-html\">&gt;</span></span></code></pre>"
        )
    }

    @TestCase
    func engineJavascriptCompareSqlSelectCase() {
        // Migrated from shiki/packages/engine-javascript/test/compare.test.ts: sql case 1.
        let html = Highlighter().highlight("SELECT * FROM foo", options: HighlightOptions(lang: "sql"))

        @Expect(
            html,
            "<pre class=\"codehl codehl-lang-sql\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-keyword-other-DML-sql\">SELECT</span> <span class=\"codehl-token codehl-keyword-operator-star-sql\">*</span> <span class=\"codehl-token codehl-keyword-other-DML-sql\">FROM</span> foo</span></code></pre>"
        )
    }

    @TestCase
    func engineJavascriptCompareSqlDdlCase() {
        // Migrated from shiki/packages/engine-javascript/test/compare.test.ts: sql case 2.
        let html = Highlighter().highlight("USE AdventureWorks2022;\nGO\nIF OBJECT_ID('dbo.NewProducts', 'U') IS NOT NULL\nDROP TABLE dbo.NewProducts;", options: HighlightOptions(lang: "sql"))

        @Expect(
            html,
            "<pre class=\"codehl codehl-lang-sql\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-keyword-other-sql\">USE</span> AdventureWorks2022;</span>\n<span class=\"codehl-line\" data-line=\"2\"><span class=\"codehl-token codehl-keyword-other-sql\">GO</span></span>\n<span class=\"codehl-line\" data-line=\"3\"><span class=\"codehl-token codehl-keyword-other-sql\">IF</span> <span class=\"codehl-token codehl-support-function-metadata-sql\">OBJECT_ID</span>(<span class=\"codehl-token codehl-punctuation-definition-string-begin-sql\">'</span><span class=\"codehl-token codehl-string-quoted-single-sql\">dbo.NewProducts</span><span class=\"codehl-token codehl-punctuation-definition-string-end-sql\">'</span>, <span class=\"codehl-token codehl-punctuation-definition-string-begin-sql\">'</span><span class=\"codehl-token codehl-string-quoted-single-sql\">U</span><span class=\"codehl-token codehl-punctuation-definition-string-end-sql\">'</span>) <span class=\"codehl-token codehl-keyword-other-DDL-create-II-sql\">IS NOT NULL</span></span>\n<span class=\"codehl-line\" data-line=\"4\"><span class=\"codehl-token codehl-keyword-other-create-sql\">DROP</span> <span class=\"codehl-token codehl-keyword-other-sql\">TABLE</span> <span class=\"codehl-token codehl-constant-other-database-name-sql\">dbo</span>.<span class=\"codehl-token codehl-constant-other-table-name-sql\">NewProducts</span>;</span></code></pre>"
        )
    }

    @TestCase
    func engineJavascriptCompareTomlCase() {
        // Migrated from shiki/packages/engine-javascript/test/compare.test.ts: toml case 1.
        let html = Highlighter().highlight("# This is a TOML document\n\ntitle = \"TOML Example\"\n\n[owner]\nname = \"Tom Preston-Werner\"", options: HighlightOptions(lang: "toml"))

        @Expect(
            html,
            "<pre class=\"codehl codehl-lang-toml\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-comment-line-number-sign-toml\"># This is a TOML document</span></span>\n<span class=\"codehl-line\" data-line=\"2\"></span>\n<span class=\"codehl-line\" data-line=\"3\"><span class=\"codehl-token codehl-variable-other-key-toml\">title</span> <span class=\"codehl-token codehl-punctuation-separator-key-value-toml\">=</span> <span class=\"codehl-token codehl-punctuation-definition-string-begin-toml\">\"</span><span class=\"codehl-token codehl-string-quoted-double-toml\">TOML Example</span><span class=\"codehl-token codehl-punctuation-definition-string-end-toml\">\"</span></span>\n<span class=\"codehl-line\" data-line=\"4\"></span>\n<span class=\"codehl-line\" data-line=\"5\"><span class=\"codehl-token codehl-punctuation-definition-section-begin-toml\">[</span><span class=\"codehl-token codehl-entity-name-section-toml\">owner</span><span class=\"codehl-token codehl-punctuation-definition-section-begin-toml\">]</span></span>\n<span class=\"codehl-line\" data-line=\"6\"><span class=\"codehl-token codehl-variable-other-key-toml\">name</span> <span class=\"codehl-token codehl-punctuation-separator-key-value-toml\">=</span> <span class=\"codehl-token codehl-punctuation-definition-string-begin-toml\">\"</span><span class=\"codehl-token codehl-string-quoted-double-toml\">Tom Preston-Werner</span><span class=\"codehl-token codehl-punctuation-definition-string-end-toml\">\"</span></span></code></pre>"
        )
    }

    @TestCase
    func engineJavascriptCompareMarkdownListCase() {
        // Migrated from shiki/packages/engine-javascript/test/compare.test.ts: markdown case 2.
        let html = Highlighter().highlight("look like:\n\n  * this one\n  * that one\n  * the other one\n\nand this", options: HighlightOptions(lang: "markdown"))

        @Expect(
            html,
            "<pre class=\"codehl codehl-lang-markdown\"><code><span class=\"codehl-line\" data-line=\"1\">look like:</span>\n<span class=\"codehl-line\" data-line=\"2\"></span>\n<span class=\"codehl-line\" data-line=\"3\">  <span class=\"codehl-token codehl-punctuation-definition-list-begin-markdown\">*</span> this one</span>\n<span class=\"codehl-line\" data-line=\"4\"><span class=\"codehl-token codehl-markup-list-unnumbered-markdown\">  </span><span class=\"codehl-token codehl-punctuation-definition-list-begin-markdown\">*</span> that one</span>\n<span class=\"codehl-line\" data-line=\"5\"><span class=\"codehl-token codehl-markup-list-unnumbered-markdown\">  </span><span class=\"codehl-token codehl-punctuation-definition-list-begin-markdown\">*</span> the other one</span>\n<span class=\"codehl-line\" data-line=\"6\"></span>\n<span class=\"codehl-line\" data-line=\"7\">and this</span></code></pre>"
        )
    }

    @TestCase
    func engineJavascriptCompareMarkdownFencedCodeCase() {
        // Migrated from shiki/packages/engine-javascript/test/compare.test.ts: markdown case 1.
        let html = Highlighter().highlight("# Header\n\nThis is a paragraph\n\n```ts\nconst foo = \"bar\"\n```", options: HighlightOptions(lang: "markdown"))

        @Expect(
            html,
            "<pre class=\"codehl codehl-lang-markdown\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-punctuation-definition-heading-markdown\">#</span> <span class=\"codehl-token codehl-entity-name-section-markdown\">Header</span></span>\n<span class=\"codehl-line\" data-line=\"2\"></span>\n<span class=\"codehl-line\" data-line=\"3\">This is a paragraph</span>\n<span class=\"codehl-line\" data-line=\"4\"></span>\n<span class=\"codehl-line\" data-line=\"5\"><span class=\"codehl-token codehl-punctuation-definition-markdown\">```</span><span class=\"codehl-token codehl-fenced-code-block-language-markdown\">ts</span></span>\n<span class=\"codehl-line\" data-line=\"6\">const foo = \"bar\"</span>\n<span class=\"codehl-line\" data-line=\"7\"><span class=\"codehl-token codehl-punctuation-definition-markdown\">```</span></span></code></pre>"
        )
    }

    @TestCase
    func engineJavascriptCompareTypeScriptConstTypeAnnotationCase() {
        // Migrated from shiki/packages/engine-javascript/test/__records__/ts-basic.js.json.
        let html = Highlighter().highlight("const foo: string = \"bar\"", options: HighlightOptions(lang: "ts"))

        @Expect(
            html,
            "<pre class=\"codehl codehl-lang-typescript\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-storage-type-ts\">const</span> <span class=\"codehl-token codehl-meta-definition-variable-ts-variable-other-constant-ts\">foo</span><span class=\"codehl-token codehl-keyword-operator-type-annotation-ts\">:</span> <span class=\"codehl-token codehl-support-type-primitive-ts\">string</span> <span class=\"codehl-token codehl-keyword-operator-assignment-ts\">=</span> <span class=\"codehl-token codehl-string-quoted-double-ts\">\"bar\"</span></span></code></pre>"
        )
    }

    @TestCase
    func shikiGeneralJavaScriptConsoleCallCase() {
        // Migrated from shiki/packages/shiki/test/general.test.ts: codeToHtml('console.log(1)').
        let html = Highlighter().highlight("console.log(1)", options: HighlightOptions(lang: "js"))

        @Expect(
            html,
            "<pre class=\"codehl codehl-lang-javascript\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-variable-other-object-js\">console</span><span class=\"codehl-token codehl-punctuation-accessor-js\">.</span><span class=\"codehl-token codehl-entity-name-function-js\">log</span><span class=\"codehl-token codehl-meta-brace-round-js\">(</span><span class=\"codehl-token codehl-constant-numeric-decimal-js\">1</span><span class=\"codehl-token codehl-meta-brace-round-js\">)</span></span></code></pre>"
        )
    }

    @TestCase
    func shellCommandNameRangeDoesNotLoopOnZeroWidthBegin() {
        let html = Highlighter().highlight("cd markit-cli\ncjpm build", options: HighlightOptions(lang: "bash"))

        @Expect(
            html,
            "<pre class=\"codehl codehl-lang-bash\"><code><span class=\"codehl-line\" data-line=\"1\"><span class=\"codehl-token codehl-entity-name-function-call-shell-entity-name-command-shell-support-function-builtin-shell\">cd</span> <span class=\"codehl-token codehl-entity-name-function-call-shell-entity-name-command-shell\">markit-cli</span></span>\n<span class=\"codehl-line\" data-line=\"2\"><span class=\"codehl-token codehl-entity-name-function-call-shell-entity-name-command-shell\">cjpm</span> <span class=\"codehl-token codehl-entity-name-function-call-shell-entity-name-command-shell\">build</span></span></code></pre>"
        )
    }

}
