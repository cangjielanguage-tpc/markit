package markit.tests.unit.utils

import std.unittest.*
import std.unittest.testmacro.*
import markit.utils.slug

@Test
class SluggerTests {
    @TestCase
    func testBasicSlug() {
        @Expect(slug("Hello World"), "hello-world")
    }

    @TestCase
    func testSlugWithSpecialCharacters() {
        @Expect(slug("Special Characters: @#$%^&*()"), "special-characters")
    }

    @TestCase
    func testSlugWithMultipleSpaces() {
        @Expect(slug("Multiple   Spaces"), "multiple-spaces")
    }

    @TestCase
    func testSlugWithHtmlTags() {
        @Expect(slug("Introduction to <code>API</code>"), "introduction-to-api")
    }

    @TestCase
    func testSlugWithMarkdownHeading() {
        @Expect(slug("## Getting Started"), "getting-started")
    }

    @TestCase
    func testSlugWithLeadingWhitespaceBeforeHeading() {
        @Expect(slug("   ## Getting Started"), "getting-started")
    }

    @TestCase
    func testSlugWithLeadingAndTrailingHyphens() {
        @Expect(slug("---Leading and Trailing---"), "leading-and-trailing")
    }

    @TestCase
    func testSlugWithMixedCase() {
        @Expect(slug("Mixed-Case_and spaces"), "mixed-case-and-spaces")
    }

    @TestCase
    func testSlugWithNumbers() {
        @Expect(slug("Version 2.0 Release"), "version-2-0-release")
    }

    @TestCase
    func testSlugWithEmptyString() {
        @Expect(slug(""), "")
    }

    @TestCase
    func testSlugWithOnlySpecialCharacters() {
        @Expect(slug("@#$%^&*()"), "")
    }

    @TestCase
    func testSlugWithOnlySpaces() {
        @Expect(slug("   "), "")
    }

    @TestCase
    func testSlugWithComplexHtml() {
        @Expect(slug("<h1>Title</h1> with <strong>bold</strong> text"), "title-with-bold-text")
    }

    @TestCase
    func testSlugWithHtmlWrappedHeading() {
        @Expect(slug("<span>## Fast Start</span>"), "fast-start")
    }

    @TestCase
    func testSlugWithChineseCharacters() {
        @Expect(slug("Bundle基础概念"), "bundle基础概念")
    }

    @TestCase
    func testSlugWithChineseHeading() {
        @Expect(slug("## 什么是Bundle"), "什么是bundle")
    }

    @TestCase
    func testSlugWithMixedChineseEnglish() {
        @Expect(slug("创建简单Bundle"), "创建简单bundle")
    }

    @TestCase
    func testSlugWithLatinSupplementCharacters() {
        @Expect(slug("émojis naïve café"), "émojis-naïve-café")
    }

    @TestCase
    func testSlugWithChineseAndSpaces() {
        @Expect(slug("Bundle 最佳实践"), "bundle-最佳实践")
    }

    @TestCase
    func testSlugWithChineseAndSpecialChars() {
        @Expect(slug("调试和测试：重要步骤"), "调试和测试-重要步骤")
    }

    @TestCase
    func testSlugWithChineseMarkdownHeading() {
        @Expect(slug("### API文档Bundle"), "api文档bundle")
    }

    @TestCase
    func testSlugWithJapaneseCharacters() {
        @Expect(slug("こんにちは世界"), "こんにちは世界")
    }

    @TestCase
    func testSlugWithKoreanCharacters() {
        @Expect(slug("안녕하세요 세계"), "안녕하세요-세계")
    }

    @TestCase
    func testSlugWithComplexChinese() {
        @Expect(slug("# 自定义Bundle指南"), "自定义bundle指南")
    }

    @TestCase
    func testSlugWithInlineCodeStyleBackticks() {
        @Expect(slug("`init` 构造函数"), "init-构造函数")
    }

    @TestCase
    func testSlugCollapsesRepeatedSeparators() {
        @Expect(slug("A---B___C..."), "a-b-c")
    }
}
