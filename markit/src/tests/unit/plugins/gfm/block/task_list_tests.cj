package markit.tests.unit.plugins.gfm.block

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.bundles.GFMBundle
import markit.core.nodes.{Node, TextNode}
import markit.plugins.gfm.block.task_list.{TaskListItemNode, TaskListNode}
import markit.plugins.standard.block.fenced_code_block.FencedCodeBlockConfig
import markit.tests.utils.{AstTestKit, ParseModeResult, ParseModeTestKit}

private func gfm(): Markit {
    return Markit(GFMBundle(fencedCodeBlockConfig: FencedCodeBlockConfig(enableCodehl: false)))
}

@Test
class TaskListTests {
    @TestCase
    func rendersCheckedAndUncheckedItemsAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "- [ ] Unchecked task\n- [x] Checked task\n- [X] Uppercase checked\n",
            { result: ParseModeResult =>
                @Expect(result.html, "<ul class=\"task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" /> Unchecked task</li><li class=\"task-list-item\"><input type=\"checkbox\" checked=\"checked\" /> Checked task</li><li class=\"task-list-item\"><input type=\"checkbox\" checked=\"checked\" /> Uppercase checked</li></ul>")
                expectTaskList(result.root, ["Unchecked task", "Checked task", "Uppercase checked"], [false, true, true])
            }
        )
    }

    @TestCase
    func supportsDifferentMarkersAndChineseContentAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            gfm,
            "- [ ] 中文任务\n* [x] émojis 🚀\n+ [ ] symbols !@#\n",
            "<ul class=\"task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" /> 中文任务</li><li class=\"task-list-item\"><input type=\"checkbox\" checked=\"checked\" /> émojis 🚀</li><li class=\"task-list-item\"><input type=\"checkbox\" /> symbols !@#</li></ul>"
        )
    }

    @TestCase
    func parsesInlineContentInsideTaskItemsAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            gfm,
            "- [x] **bold** and `code`\n",
            "<ul class=\"task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" checked=\"checked\" /> <strong>bold</strong> and <code>code</code></li></ul>"
        )
    }

    @TestCase
    func invalidTaskSyntaxFallsBackToStandardListAcrossModes() {
        ParseModeTestKit.assertAcrossModes(
            gfm,
            "- [y] not a task\n",
            { result: ParseModeResult =>
                AstTestKit.expectNoNode(result.root, "TaskListNode")
                @Expect(result.html, "<ul><li>[y] not a task</li></ul>")
            }
        )
    }

    @TestCase
    func keepsFencedCodeBlockInsideTaskItemAcrossModes() {
        let markdown = """
- [ ] First task
  ```javascript
  console.log("hello");
  ```

- [x] Done
"""

        ParseModeTestKit.assertHtmlAcrossModes(
            gfm,
            markdown,
            "<ul class=\"task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" /> First task<pre><code class=\"language-javascript\">console.log(&quot;hello&quot;);</code></pre></li><li class=\"task-list-item\"><input type=\"checkbox\" checked=\"checked\" /> Done</li></ul>"
        )
    }

    @TestCase
    func keepsTabIndentedFencedCodeBlockInsideTaskItemAcrossModes() {
        ParseModeTestKit.assertHtmlAcrossModes(
            gfm,
            "- [ ] First task\n\t```javascript\n\tconsole.log(\"hello\");\n\t```\n\n- [ ] Second task\n",
            "<ul class=\"task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" /> First task<pre><code class=\"language-javascript\">console.log(&quot;hello&quot;);</code></pre></li><li class=\"task-list-item\"><input type=\"checkbox\" /> Second task</li></ul>"
        )
    }

    private func expectTaskList(root: Node, contents: Array<String>, checked: Array<Bool>): Unit {
        AstTestKit.expectRoot(root, 1)
        @Expect(contents.size, checked.size)
        let listNode = AstTestKit.child(root, 0, "TaskListNode")
        if (let list: TaskListNode <- listNode) {
            @Expect(list.tight, true)
            @Expect(list.baseIndent, 0)
            @Expect(list.children.size, contents.size)
            for (i in 0..contents.size) {
                let itemNode = AstTestKit.child(list, i, "TaskListItemNode")
                if (let item: TaskListItemNode <- itemNode) {
                    @Expect(item.content, contents[i])
                    @Expect(item.checked, checked[i])
                    @Expect(item.indentLevel, 0)
                    @Expect(String.fromUtf8([item.marker]), "-")
                    @Expect(item.children.size, 1)
                    let textNode = AstTestKit.child(item, 0, "TextNode")
                    if (let text: TextNode <- textNode) {
                        @Expect(text.content, contents[i])
                    }
                }
            }
        }
    }
}
