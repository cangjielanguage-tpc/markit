package markit.tests.unit.utils

import std.collection.HashMap
import std.unittest.*
import std.unittest.testmacro.*
import markit.utils.HtmlPropertyHelper

@Test
class HtmlPropertyHelperTests {
    @TestCase
    func extractsNamedAttributesFromCompleteTagsExactly() {
        let html = "<a href=\"/page.html\" class=\"link primary\" target=\"_blank\" data-id=\"中文\">Link</a>"

        @Expect(HtmlPropertyHelper.extractHref(html), "/page.html")
        @Expect(HtmlPropertyHelper.extractClass(html), "link primary")
        @Expect(HtmlPropertyHelper.extractAttribute(html, "target"), "_blank")
        @Expect(HtmlPropertyHelper.extractAttribute(html, "data-id"), "中文")
        @Expect(HtmlPropertyHelper.extractAttribute(html, "missing"), "")
    }

    @TestCase
    func parsesQuotedUnquotedAndBooleanAttributesExactly() {
        let parsed = HtmlPropertyHelper.parseAttributesString(
            "disabled checked class=\"form-control\" data-x='中文 value' id=main"
        )

        @Expect(parsed.size, 5)
        @Expect(parsed.get("disabled"), Some(""))
        @Expect(parsed.get("checked"), Some(""))
        @Expect(parsed.get("class"), Some("form-control"))
        @Expect(parsed.get("data-x"), Some("中文 value"))
        @Expect(parsed.get("id"), Some("main"))
    }

    @TestCase
    func extractsAllAttributesFromSelfClosingAndPlainTextInputs() {
        let image = HtmlPropertyHelper.extractAllAttributes("<img src=\"/logo.png\" alt=\"Logo 中文\" />")
        @Expect(image.size, 2)
        @Expect(image.get("src"), Some("/logo.png"))
        @Expect(image.get("alt"), Some("Logo 中文"))

        let plain = HtmlPropertyHelper.extractAllAttributes("Just plain text")
        @Expect(plain.size, 0)
    }

    @TestCase
    func buildsAttributesInStableEscapedKeyOrder() {
        let attributes = HashMap<String, String>()
        attributes["data-value"] = "中文 & <tag>"
        attributes["class"] = "btn primary"
        attributes["id"] = "main"

        @Expect(
            HtmlPropertyHelper.buildAttributesString(attributes),
            "class=\"btn primary\" data-value=\"中文 &amp; &lt;tag&gt;\" id=\"main\""
        )
        @Expect(
            HtmlPropertyHelper.buildAttributesString(attributes, includeLeadingSpace: true),
            " class=\"btn primary\" data-value=\"中文 &amp; &lt;tag&gt;\" id=\"main\""
        )
    }

    @TestCase
    func roundTripParseBuildParsePreservesAttributeMap() {
        let original = "class=\"content\" id=\"main\" data-value=\"test 中文\" checked"
        let parsed = HtmlPropertyHelper.parseAttributesString(original)
        let rebuilt = HtmlPropertyHelper.buildAttributesString(parsed)
        let reparsed = HtmlPropertyHelper.parseAttributesString(rebuilt)

        @Expect(reparsed.size, parsed.size)
        @Expect(reparsed.get("class"), parsed.get("class"))
        @Expect(reparsed.get("id"), parsed.get("id"))
        @Expect(reparsed.get("data-value"), parsed.get("data-value"))
        @Expect(reparsed.get("checked"), parsed.get("checked"))
    }
}
