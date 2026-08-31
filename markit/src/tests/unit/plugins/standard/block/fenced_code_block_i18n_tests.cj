package markit.tests.unit.plugins.standard.block

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.plugins.standard.block.fenced_code_block.{FencedCodeBlockLineRuleUtils, FencedCodeBlockNode, FencedCodeBlockPlugin, FencedCodeBlockConfig}
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

private func singleGroupedFence(result: ParseModeResult): FencedCodeBlockNode {
    if (result.root.children.size != 1) {
        throw IllegalArgumentException("Expected exactly one grouped fenced code block in ${result.mode}")
    }

    if (let fenced: FencedCodeBlockNode <- result.root.children[0]) {
        return fenced
    }

    throw IllegalArgumentException("Expected fenced code block node in ${result.mode}")
}

@Test
class FencedCodeBlockI18nTests {
    @TestCase
    func convertsGlobalHighlightLinesToLocalRanges() {
        @Expect(
            FencedCodeBlockLineRuleUtils.convertGlobalHighlightLinesToLocal("3..=4,8", 2, 3),
            "2..=3"
        )
        @Expect(
            FencedCodeBlockLineRuleUtils.convertGlobalHighlightLinesToLocal("3..=4,8", 6, 3),
            "3"
        )
    }

    @TestCase
    func convertsGlobalI18nLinesToLocalRanges() {
        @Expect(
            FencedCodeBlockLineRuleUtils.convertGlobalI18nLinesToLocal("2..=4:zh,6..=8:en", 2, 3),
            "1..=3:zh"
        )
        @Expect(
            FencedCodeBlockLineRuleUtils.convertGlobalI18nLinesToLocal("2..=4:zh,6..=8:en", 6, 3),
            "1..=3:en"
        )
    }

    @TestCase
    func collectsI18nLinesForGroupedSyntax() {
        let selectedZh = FencedCodeBlockLineRuleUtils.collectI18nLineNumbers("4,6:en,5,7:zh", "zh", 7)
        @Expect(selectedZh.size, 5)
        @Expect(selectedZh[0], 1)
        @Expect(selectedZh[1], 2)
        @Expect(selectedZh[2], 3)
        @Expect(selectedZh[3], 5)
        @Expect(selectedZh[4], 7)

        let selectedEn = FencedCodeBlockLineRuleUtils.collectI18nLineNumbers("4,6:en,5,7:zh", "en", 7)
        @Expect(selectedEn.size, 5)
        @Expect(selectedEn[0], 1)
        @Expect(selectedEn[1], 2)
        @Expect(selectedEn[2], 3)
        @Expect(selectedEn[3], 4)
        @Expect(selectedEn[4], 6)
    }

    @TestCase
    func parsesGroupedFilesWithInheritedAndExplicitLanguagesAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            {
                => Markit.empty().use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableGroup: true, enableCodehl: false)))
            },
            """
```typescript
///// 基础.ts
const a = 1;
///// second.js [javascript]
const b = 2;
```""",
            { result: ParseModeResult =>
                let fenced = singleGroupedFence(result)
                if (fenced.fileGroups.size != 2) {
                    throw IllegalArgumentException("Expected two file groups in ${result.mode}")
                }
                if (fenced.fileGroups[0].filename != "基础.ts" ||
                    fenced.fileGroups[0].language != "typescript" ||
                    fenced.fileGroups[0].content != "const a = 1;") {
                    throw IllegalArgumentException("Unexpected first group in ${result.mode}")
                }
                if (fenced.fileGroups[1].filename != "second.js" ||
                    fenced.fileGroups[1].language != "javascript" ||
                    fenced.fileGroups[1].content != "const b = 2;") {
                    throw IllegalArgumentException("Unexpected second group in ${result.mode}")
                }
            }
        )
    }

    @TestCase
    func projectsHighlightAndI18nRulesIntoEachGroupedFileAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            {
                => Markit.empty().use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableGroup: true, enableCodehl: false)))
            },
            """
```cangjie {3..=4,8} [2..=4:zh,6..=8:en]
///// 基础.cj
// 注释
let a = 1
let b = 2
///// second.cj
let c = 3
let d = 4
let e = 5
```""",
            { result: ParseModeResult =>
                let fenced = singleGroupedFence(result)
                if (fenced.fileGroups.size != 2) {
                    throw IllegalArgumentException("Expected two file groups in ${result.mode}")
                }
                if (fenced.fileGroups[0].filename != "基础.cj" ||
                    fenced.fileGroups[0].highlightLines != "2..=3" ||
                    fenced.fileGroups[0].i18nLines != "1..=3:zh") {
                    throw IllegalArgumentException("Unexpected first projection in ${result.mode}")
                }
                if (fenced.fileGroups[1].filename != "second.cj" ||
                    fenced.fileGroups[1].highlightLines != "3" ||
                    fenced.fileGroups[1].i18nLines != "1..=3:en") {
                    throw IllegalArgumentException("Unexpected second projection in ${result.mode}")
                }
            }
        )
    }

    @TestCase
    func backslashEscapedSeparatorIsIgnoredAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            {
                => Markit.empty().use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableGroup: true, enableCodehl: false)))
            },
            """
```javascript
///// 不是分组 \\
console.log('same group');
///// file2.js
console.log('file2');
```""",
            { result: ParseModeResult =>
                let fenced = singleGroupedFence(result)
                if (fenced.fileGroups.size != 2) {
                    throw IllegalArgumentException("Expected two file groups in ${result.mode}")
                }
                if (fenced.fileGroups[0].filename != "" ||
                    fenced.fileGroups[0].content != "///// 不是分组 \\\nconsole.log('same group');") {
                    throw IllegalArgumentException("Unexpected escaped group handling in ${result.mode}")
                }
                if (fenced.fileGroups[1].filename != "file2.js" ||
                    fenced.fileGroups[1].content != "console.log('file2');") {
                    throw IllegalArgumentException("Unexpected second group content in ${result.mode}")
                }
            }
        )
    }

    @TestCase
    func groupedHtmlRendersTabsPanelsAndChineseFileNamesAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            {
                => Markit.empty().use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableGroup: true, enableCodehl: false)))
            },
            """
```typescript
///// 基础.ts
const a = 1;
```""",
            { result: ParseModeResult =>
                @Expect(
                    result.html,
                    "<div class=\"code-block-group\"><div class=\"code-tabs\"><button class=\"code-tab active\" data-tab=\"0\"><span class=\"file-icon icon-ts\"></span><span class=\"file-name\">基础.ts</span></button></div><div class=\"code-panels\"><div class=\"code-panel active\" data-panel=\"0\"><pre><code class=\"language-typescript\">const a = 1;</code></pre></div></div></div>"
                )
                let fenced = singleGroupedFence(result)
                @Expect(fenced.fileGroups.size, 1)
                @Expect(fenced.fileGroups[0].filename, "基础.ts")
                @Expect(fenced.fileGroups[0].language, "typescript")
                @Expect(fenced.fileGroups[0].content, "const a = 1;")
            }
        )
    }

    @TestCase
    func sixAndSevenSlashSeparatorsAreRecognizedAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            {
                => Markit.empty().use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableGroup: true, enableCodehl: false)))
            },
            """
```javascript
////// file1.js
console.log('file1');
/////// file2.js
console.log('file2');
```""",
            { result: ParseModeResult =>
                let fenced = singleGroupedFence(result)
                if (fenced.fileGroups.size != 2) {
                    throw IllegalArgumentException("Expected two file groups in ${result.mode}")
                }
                if (fenced.fileGroups[0].filename != "file1.js" ||
                    fenced.fileGroups[0].content != "console.log('file1');") {
                    throw IllegalArgumentException("Unexpected first slash-count group in ${result.mode}")
                }
                if (fenced.fileGroups[1].filename != "file2.js" ||
                    fenced.fileGroups[1].content != "console.log('file2');") {
                    throw IllegalArgumentException("Unexpected second slash-count group in ${result.mode}")
                }
            }
        )
    }

    @TestCase
    func fourSlashesDoNotStartAFileGroupAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            {
                => Markit.empty().use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableGroup: true, enableCodehl: false)))
            },
            """
```javascript
//// file1.js
console.log('file1');
///// file2.js
console.log('file2');
```""",
            { result: ParseModeResult =>
                let fenced = singleGroupedFence(result)
                if (fenced.fileGroups.size != 2) {
                    throw IllegalArgumentException("Expected two file groups in ${result.mode}")
                }
                if (fenced.fileGroups[0].filename != "" ||
                    fenced.fileGroups[0].content != "//// file1.js\nconsole.log('file1');") {
                    throw IllegalArgumentException("Unexpected non-separator preservation in ${result.mode}")
                }
                if (fenced.fileGroups[1].filename != "file2.js" ||
                    fenced.fileGroups[1].content != "console.log('file2');") {
                    throw IllegalArgumentException("Unexpected file2 group in ${result.mode}")
                }
            }
        )
    }

    @TestCase
    func backslashEscapeWithTrailingSpacesIsIgnoredAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            {
                => Markit.empty().use(FencedCodeBlockPlugin(config: FencedCodeBlockConfig(enableGroup: true, enableCodehl: false)))
            },
            """
```javascript
///// Not a separator \\   
console.log('same group');
///// file2.js
console.log('file2');
```""",
            { result: ParseModeResult =>
                let fenced = singleGroupedFence(result)
                if (fenced.fileGroups.size != 2) {
                    throw IllegalArgumentException("Expected two file groups in ${result.mode}")
                }
                if (fenced.fileGroups[0].filename != "" ||
                    fenced.fileGroups[0].content != "///// Not a separator \\   \nconsole.log('same group');") {
                    throw IllegalArgumentException("Unexpected spaced backslash preservation in ${result.mode}")
                }
                if (fenced.fileGroups[1].filename != "file2.js") {
                    throw IllegalArgumentException("Unexpected trailing group filename in ${result.mode}")
                }
            }
        )
    }
}
