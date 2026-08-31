package markit.tests.unit.plugins.standard.block

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.StandardMarkdownBundle
import markit.core.incremental.IncrementalUpdate
import markit.plugins.standard.block.list.{OrderedListNode, UnorderedListNode}
import markit.plugins.standard.block.fenced_code_block.{FencedCodeBlockConfig, FencedCodeBlockNode, FencedCodeBlockPlugin}
import markit.tests.utils.{AstTestKit, ParseModeResult, ParseModeTestKit}

private func singleFenced(result: ParseModeResult): FencedCodeBlockNode {
    if (result.root.children.size != 1) {
        throw IllegalArgumentException("Expected exactly one fenced code block in ${result.mode}")
    }

    if (let fenced: FencedCodeBlockNode <- result.root.children[0]) {
        return fenced
    }

    throw IllegalArgumentException("Expected fenced code block node in ${result.mode}")
}

private func groupedMarkit(): Markit {
    return Markit.empty().use(
        StandardMarkdownBundle(
            fencedCodeBlockConfig: FencedCodeBlockConfig(enableGroup: true, enableCodehl: false)
        )
    )
}

@Test
@Tag[FencedCodeBlock]
class FencedCodeBlockTests {
    @TestCase
    func parsesLanguageHighlightAndI18nMetadataAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            {
                => Markit.empty().use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableCodehl: false)))
            },
            """
```typescript {1,3..=5} [1..=5:en,6..=10:zh]
const x = 1;
```""",
            { result: ParseModeResult =>
                let fenced = singleFenced(result)
                if (fenced.language != "typescript") {
                    throw IllegalArgumentException("Unexpected language in ${result.mode}: ${fenced.language}")
                }
                if (fenced.highlightLines != "1,3..=5") {
                    throw IllegalArgumentException("Unexpected highlight lines in ${result.mode}: ${fenced.highlightLines}")
                }
                if (fenced.i18nLines != "1..=5:en,6..=10:zh") {
                    throw IllegalArgumentException("Unexpected i18n lines in ${result.mode}: ${fenced.i18nLines}")
                }
                if (fenced.content() != "const x = 1;") {
                    throw IllegalArgumentException("Unexpected content in ${result.mode}: ${fenced.content()}")
                }
            }
        )
    }

    @TestCase
    func rendersMetadataAsHtmlDataAttributesAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            {
                => Markit.empty().use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableCodehl: false)))
            },
            """
```typescript {1,3..=5} [1..=5:en,6..=10:zh]
const x = 1;
```""",
            "<pre><code class=\"language-typescript\" data-highlight-lines=\"1,3..=5\" data-i18n-lines=\"1..=5:en,6..=10:zh\">const x = 1;</code></pre>"
        )
    }

    @TestCase
    func stripsOpeningIndentAndSupportsTabIndentedFenceAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            {
                => Markit.empty().use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableCodehl: false)))
            },
            """
	```javascript
	console.log("中文");
	```""",
            { result: ParseModeResult =>
                let fenced = singleFenced(result)
                if (fenced.language != "javascript") {
                    throw IllegalArgumentException("Unexpected language in ${result.mode}: ${fenced.language}")
                }
                if (fenced.content() != "console.log(\"中文\");") {
                    throw IllegalArgumentException("Unexpected content in ${result.mode}: ${fenced.content()}")
                }
            }
        )
    }

    @TestCase
    func shorterFenceInsideLongerFenceStaysInContentAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            {
                => Markit.empty().use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableCodehl: false)))
            },
            """
````
code
```
````""",
            { result: ParseModeResult =>
                let fenced = singleFenced(result)
                if (fenced.fenceLength != 4) {
                    throw IllegalArgumentException("Unexpected fence length in ${result.mode}: ${fenced.fenceLength}")
                }
                if (fenced.content() != "code\n```") {
                    throw IllegalArgumentException("Unexpected content in ${result.mode}: ${fenced.content()}")
                }
                if (result.html != "<pre><code>code\n```</code></pre>") {
                    throw IllegalArgumentException("Unexpected html in ${result.mode}: ${result.html}")
                }
            }
        )
    }

    @TestCase
    func tildeFenceSupportsChineseContentAndLongerClosingFenceAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            {
                => Markit.empty().use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableCodehl: false)))
            },
            """
~~~~ts
输出("中文");
~~~~~~""",
            { result: ParseModeResult =>
                let fenced = singleFenced(result)
                if (fenced.language != "ts") {
                    throw IllegalArgumentException("Unexpected language in ${result.mode}: ${fenced.language}")
                }
                if (fenced.fenceLength != 4) {
                    throw IllegalArgumentException("Unexpected fence length in ${result.mode}: ${fenced.fenceLength}")
                }
                if (fenced.content() != "输出(\"中文\");") {
                    throw IllegalArgumentException("Unexpected content in ${result.mode}: ${fenced.content()}")
                }
            }
        )
    }

    @TestCase
    func invalidFenceInfoFallsBackToStandardParsingAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            """
```ts {1
code
""",
            "<p>```ts {1\ncode</p>"
        )
    }

    @TestCase
    func parsesFiveCharacterFenceAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            {
                => Markit.empty().use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableCodehl: false)))
            },
            """
`````
code content
`````""",
            { result: ParseModeResult =>
                let fenced = singleFenced(result)
                if (fenced.fenceLength != 5) {
                    throw IllegalArgumentException("Unexpected fence length in ${result.mode}: ${fenced.fenceLength}")
                }
                if (fenced.content() != "code content") {
                    throw IllegalArgumentException("Unexpected content in ${result.mode}: ${fenced.content()}")
                }
            }
        )
    }

    @TestCase
    func parsesEmptyFenceAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            {
                => Markit.empty().use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableCodehl: false)))
            },
            """
```
```""",
            "<pre><code></code></pre>"
        )
    }

    @TestCase
    func parsesFenceLanguageWithExtraSpacesAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            {
                => Markit.empty().use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableCodehl: false)))
            },
            """
```  javascript  
console.log('test');
```""",
            { result: ParseModeResult =>
                let fenced = singleFenced(result)
                if (fenced.language != "javascript") {
                    throw IllegalArgumentException("Unexpected language in ${result.mode}: ${fenced.language}")
                }
                if (fenced.content() != "console.log('test');") {
                    throw IllegalArgumentException("Unexpected content in ${result.mode}: ${fenced.content()}")
                }
            }
        )
    }

    @TestCase
    func preservesSpecialCharactersAndUnicodeInsideFenceAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            {
                => Markit.empty().use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableCodehl: false)))
            },
            """
```
!@#$%^&*()_+-={}[]|\\:;"'<>,.?/
中文内容 🚀 émojis
```""",
            "<pre><code>!@#$%^&amp;*()_+-={}[]|\\:;&quot;&#39;&lt;&gt;,.?/\n中文内容 🚀 émojis</code></pre>"
        )
    }

    @TestCase
    func finalizeKeepsUnclosedFenceAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            {
                => Markit.empty().use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableCodehl: false)))
            },
            """
```
code without closing fence""",
            "<pre><code>code without closing fence</code></pre>"
        )
    }

    @TestCase
    func dividerInsideFenceStaysLiteralAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            {
                => Markit.empty().use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableCodehl: false)))
            },
            """
```markdown
---
```""",
            { result: ParseModeResult =>
                let fenced = singleFenced(result)
                if (fenced.language != "markdown") {
                    throw IllegalArgumentException("Unexpected language in ${result.mode}: ${fenced.language}")
                }
                if (fenced.content() != "---") {
                    throw IllegalArgumentException("Unexpected content in ${result.mode}: ${fenced.content()}")
                }
                if (result.html != "<pre><code class=\"language-markdown\">---</code></pre>") {
                    throw IllegalArgumentException("Unexpected html in ${result.mode}: ${result.html}")
                }
            }
        )
    }

    @TestCase
    func preservesIndentedContentBlankLinesAndMixedFenceMarkersAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            {
                => Markit.empty().use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableCodehl: false)))
            },
            """
```
    indented line 1
        indented line 2
~~~
```
""",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<pre><code>    indented line 1\n        indented line 2\n~~~</code></pre>"
                )
                let fenced = singleFenced(result)
                @Expect(fenced.language, "")
                @Expect(String.fromUtf8([fenced.fenceMarker]), "`")
                @Expect(fenced.fenceLength, 3)
                @Expect(fenced.content(), "    indented line 1\n        indented line 2\n~~~")
                AstTestKit.expectSpan(fenced, 0, 55, 0, 55)
            }
        )

        ParseModeTestKit.assertAcrossModes(
            {
                => Markit.empty().use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableCodehl: false)))
            },
            "````\n\n````",
            { result: ParseModeResult =>
                @Expect(result.html, "<pre><code></code></pre>")
                let fenced = singleFenced(result)
                @Expect(fenced.content(), "")
                @Expect(fenced.fenceLength, 4)
                AstTestKit.expectSpan(fenced, 0, 10, 0, 10)
            }
        )
    }

    @TestCase
    func standardListsAttachTabAndFourSpaceIndentedFencedCodeAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            { => groupedMarkit() },
            "1. First item\n\t```javascript\n\tconsole.log(\"hello\");\n\t```\n\n2. Second item",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<ol><li><p>First item</p><pre><code class=\"language-javascript\">console.log(&quot;hello&quot;);</code></pre></li><li>Second item</li></ol>"
                )
                let listNode = AstTestKit.child(result.root, 0, "OrderedListNode")
                if (let list: OrderedListNode <- listNode) {
                    @Expect(list.children.size, 2)
                    let firstItem = AstTestKit.child(list, 0, "OrderedListItemNode")
                    let fenced = AstTestKit.child(firstItem, 1, "FencedCodeBlockNode")
                    if (let code: FencedCodeBlockNode <- fenced) {
                        @Expect(code.language, "javascript")
                        @Expect(code.content(), "console.log(\"hello\");")
                        AstTestKit.expectSpan(code, 14, 56, 14, 56)
                    }
                }
            }
        )

        ParseModeTestKit.assertAcrossModes(
            { => groupedMarkit() },
            "- First item\n    ```javascript\n    console.log(\"hello\");\n    ```\n\n- Second item",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<ul><li><p>First item</p><pre><code class=\"language-javascript\">console.log(&quot;hello&quot;);</code></pre></li><li>Second item</li></ul>"
                )
                let listNode = AstTestKit.child(result.root, 0, "UnorderedListNode")
                if (let list: UnorderedListNode <- listNode) {
                    @Expect(list.children.size, 2)
                    let firstItem = AstTestKit.child(list, 0, "UnorderedListItemNode")
                    let fenced = AstTestKit.child(firstItem, 1, "FencedCodeBlockNode")
                    if (let code: FencedCodeBlockNode <- fenced) {
                        @Expect(code.language, "javascript")
                        @Expect(code.content(), "console.log(\"hello\");")
                        AstTestKit.expectSpan(code, 13, 64, 13, 64)
                    }
                }
            }
        )
    }

    @TestCase
    func streamingFeedBytesSealsChineseFenceWithoutRuneCopyingTheWholeInput() {
        let session = Markit.empty().use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableCodehl: false))).createSession()
        var update = IncrementalUpdate()
        for (byte in "```cj\n中文\n```\n".toArray()) {
            update = session.feedBytes([byte])
        }

        @Expect(update.sealedBlocks.size, 1)
        @Expect(update.emittedHtmlFragments.size, 1)
        @Expect(update.emittedHtmlFragments[0].html, Markit.empty().use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableCodehl: false))).parse("```cj\n中文\n```\n").toHtml())

        if (let fenced: FencedCodeBlockNode <- update.sealedBlocks[0]) {
            @Expect(fenced.sourceSpan.startByte, 0)
            @Expect(fenced.sourceSpan.endByte, 16)
            @Expect(fenced.sourceSpan.startRune, 0)
            @Expect(fenced.sourceSpan.endRune, 12)
            @Expect(fenced.content(), "中文")
        } else {
            @Assert(false)
        }
    }

    @TestCase
    func standardBundleCanEnableGroupedFenceParsingAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            groupedMarkit,
            """
```typescript
///// main.ts
const x = 1;
```""",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<div class=\"code-block-group\"><div class=\"code-tabs\"><button class=\"code-tab active\" data-tab=\"0\"><span class=\"file-icon icon-ts\"></span><span class=\"file-name\">main.ts</span></button></div><div class=\"code-panels\"><div class=\"code-panel active\" data-panel=\"0\"><pre><code class=\"language-typescript\">const x = 1;</code></pre></div></div></div>"
                )
                let fenced = singleFenced(result)
                @Expect(fenced.fileGroups.size, 1)
                @Expect(fenced.fileGroups[0].filename, "main.ts")
                @Expect(fenced.fileGroups[0].language, "typescript")
                @Expect(fenced.fileGroups[0].content, "const x = 1;")
            }
        )
    }

    @TestCase
    func groupedFenceRecognizesFiveSixAndSevenSlashSeparatorsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            groupedMarkit,
            """
```javascript
///// file1.js
console.log('file1');
////// file2.js
console.log('file2');
/////// file3.js
console.log('file3');
```""",
            { result: ParseModeResult =>
                let fenced = singleFenced(result)
                @Expect(fenced.fileGroups.size, 3)
                expectGroup(fenced, 0, "file1.js", "javascript", "console.log('file1');")
                expectGroup(fenced, 1, "file2.js", "javascript", "console.log('file2');")
                expectGroup(fenced, 2, "file3.js", "javascript", "console.log('file3');")
                @Expect(
                    result.html,
                    "<div class=\"code-block-group\"><div class=\"code-tabs\"><button class=\"code-tab active\" data-tab=\"0\"><span class=\"file-icon icon-js\"></span><span class=\"file-name\">file1.js</span></button><button class=\"code-tab\" data-tab=\"1\"><span class=\"file-icon icon-js\"></span><span class=\"file-name\">file2.js</span></button><button class=\"code-tab\" data-tab=\"2\"><span class=\"file-icon icon-js\"></span><span class=\"file-name\">file3.js</span></button></div><div class=\"code-panels\"><div class=\"code-panel active\" data-panel=\"0\"><pre><code class=\"language-javascript\">console.log(&#39;file1&#39;);</code></pre></div><div class=\"code-panel\" data-panel=\"1\"><pre><code class=\"language-javascript\">console.log(&#39;file2&#39;);</code></pre></div><div class=\"code-panel\" data-panel=\"2\"><pre><code class=\"language-javascript\">console.log(&#39;file3&#39;);</code></pre></div></div></div>"
                )
            }
        )
    }

    @TestCase
    func groupedFenceSupportsPerFileLanguageOverridesAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            groupedMarkit,
            """
```text
///// main.cj [cj]
main()
///// README.md [markdown]
# Title
```""",
            { result: ParseModeResult =>
                let fenced = singleFenced(result)
                @Expect(fenced.language, "text")
                @Expect(fenced.fileGroups.size, 2)
                expectGroup(fenced, 0, "main.cj", "cj", "main()")
                expectGroup(fenced, 1, "README.md", "markdown", "# Title")
                @Expect(
                    result.html,
                    "<div class=\"code-block-group\"><div class=\"code-tabs\"><button class=\"code-tab active\" data-tab=\"0\"><span class=\"file-icon icon-cj\"></span><span class=\"file-name\">main.cj</span></button><button class=\"code-tab\" data-tab=\"1\"><span class=\"file-icon icon-md\"></span><span class=\"file-name\">README.md</span></button></div><div class=\"code-panels\"><div class=\"code-panel active\" data-panel=\"0\"><pre><code class=\"language-cj\">main()</code></pre></div><div class=\"code-panel\" data-panel=\"1\"><pre><code class=\"language-markdown\"># Title</code></pre></div></div></div>"
                )
            }
        )
    }

    @TestCase
    func markdownFenceDoesNotTurnNestedCodeGroupExampleIntoTabsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            groupedMarkit,
            """
````markdown
```cangjie
///// main.cj [cangjie]
main(): Unit {
    println("hello")
}
///// markit.json [json]
{
  "format": "website"
}
```
````""",
            { result: ParseModeResult =>
                let fenced = singleFenced(result)
                @Expect(fenced.language, "markdown")
                @Expect(fenced.fileGroups.size, 0)
                @Expect(
                    fenced.content(),
                    "```cangjie\n///// main.cj [cangjie]\nmain(): Unit {\n    println(\"hello\")\n}\n///// markit.json [json]\n{\n  \"format\": \"website\"\n}\n```"
                )
                @Expect(
                    result.html,
                    "<pre><code class=\"language-markdown\">```cangjie\n///// main.cj [cangjie]\nmain(): Unit {\n    println(&quot;hello&quot;)\n}\n///// markit.json [json]\n{\n  &quot;format&quot;: &quot;website&quot;\n}\n```</code></pre>"
                )
            }
        )
    }

    @TestCase
    func groupedFenceDoesNotTreatEscapedSeparatorAsNewFileAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            groupedMarkit,
            #"
```javascript
///// This is not a separator because it ends with backslash\
console.log('this should be in the same group');
///// file2.js
console.log('file2');
```"#,
            { result: ParseModeResult =>
                let fenced = singleFenced(result)
                @Expect(fenced.fileGroups.size, 2)
                expectGroup(
                    fenced,
                    0,
                    "",
                    "javascript",
                    "///// This is not a separator because it ends with backslash\\\nconsole.log('this should be in the same group');"
                )
                expectGroup(fenced, 1, "file2.js", "javascript", "console.log('file2');")
            }
        )
    }

    @TestCase
    func groupedFenceDoesNotTreatFourSlashesAsSeparatorAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            groupedMarkit,
            """
```javascript
//// file1.js
console.log('file1');
///// file2.js
console.log('file2');
```""",
            { result: ParseModeResult =>
                let fenced = singleFenced(result)
                @Expect(fenced.fileGroups.size, 2)
                expectGroup(fenced, 0, "", "javascript", "//// file1.js\nconsole.log('file1');")
                expectGroup(fenced, 1, "file2.js", "javascript", "console.log('file2');")
            }
        )
    }

    @TestCase
    func groupedFenceBackslashEscapeStillWorksBeforeTrailingSpacesAcrossModes() {
        let input = "```javascript\n" +
            "///// Not a separator \\" + "   \n" +
            "console.log('same group');\n" +
            "///// file2.js\n" +
            "console.log('file2');\n" +
            "```"
        ParseModeTestKit.assertAcrossModes(
            groupedMarkit,
            input,
            { result: ParseModeResult =>
                let fenced = singleFenced(result)
                @Expect(fenced.fileGroups.size, 2)
                expectGroup(
                    fenced,
                    0,
                    "",
                    "javascript",
                    "///// Not a separator \\   \nconsole.log('same group');"
                )
                expectGroup(fenced, 1, "file2.js", "javascript", "console.log('file2');")
            }
        )
    }

    private func expectGroup(
        fenced: FencedCodeBlockNode,
        index: Int64,
        filename: String,
        language: String,
        content: String
    ): Unit {
        let group = fenced.fileGroups[index]
        @Expect(group.filename, filename)
        @Expect(group.language, language)
        @Expect(group.content, content)
    }
}
