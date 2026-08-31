package markit.tests.unit.plugins.toc

import std.unittest.*
import std.unittest.testmacro.*
import std.collection.ArrayList
import markit.Markit
import markit.bundles.GFMBundle
import markit.plugins.toc.{Toc, TocItem}

@Test
class TocPropertyTests {
    @TestCase
    func generatedHeadingCountsMatchTocItemsForManyInputs() {
        let samples = [
            "# A\n## B\n### C\n",
            "# 中文\n## English 中文\n",
            "# A\n# A\n# A\n",
            "### Deep\n#### Deeper\n# Root\n",
            "# Café\n## русский\n### 日本語\n"
        ]

        for (markdown in samples) {
            let out = Markit(GFMBundle()).parse(markdown)
            let headings = Toc.extractHeadingList(out.root())
            let detailed = Toc.extractDetailedHeadingList(out.root())
            let tocNode = Toc.parse(out.root())
            @Expect(headings.size, detailed.size)
            @Expect(countTocItems(tocNode.items), headings.size)
            @Expect(tocNode.name, "TocNode")
        }
    }

    @TestCase
    func generatedDuplicateHeadingsHaveUniqueAnchors() {
        let markdown = "# 重复\n# 重复\n# 重复\n# Repeat\n# Repeat\n"
        let tocNode = Toc.parse(Markit(GFMBundle()).parse(markdown).root())

        @Expect(tocNode.items.size, 5)
        @Expect(tocNode.items[0].anchorId, "重复")
        @Expect(tocNode.items[1].anchorId, "重复-2")
        @Expect(tocNode.items[2].anchorId, "重复-3")
        @Expect(tocNode.items[3].anchorId, "repeat")
        @Expect(tocNode.items[4].anchorId, "repeat-2")
    }

    private func countTocItems(items: ArrayList<TocItem>): Int64 {
        var count: Int64 = 0
        for (item in items) {
            count += countTocItem(item)
        }
        return count
    }

    private func countTocItem(item: TocItem): Int64 {
        var count: Int64 = 1
        for (child in item.children) {
            if (let tocChild: TocItem <- child) {
                count += countTocItem(tocChild)
            }
        }
        return count
    }
}
