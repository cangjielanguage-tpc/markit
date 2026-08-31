package markit.tests.unit.plugins.toc

import std.unittest.*
import std.unittest.testmacro.*
import markit.plugins.toc.TocItem

@Test
class TocItemTests {
    @TestCase
    func createsItemWithNumber() {
        let item = TocItem("Test Heading", 2, "test-heading", number: "1.1")

        @Expect(item.text, "Test Heading")
        @Expect(item.level, 2)
        @Expect(item.anchorId, "test-heading")
        @Expect(item.number, "1.1")
        @Expect(item.children.size, 0)
        @Expect(item.toJson(), "{\"type\":\"TocItem\",\"startOffset\":0,\"endOffset\":0,\"startByteOffset\":0,\"endByteOffset\":0,\"text\":\"Test Heading\",\"level\":2,\"id\":\"test-heading\",\"number\":\"1.1\",\"children\":[]}")
    }

    @TestCase
    func supportsNestedChildren() {
        let parent = TocItem("Parent", 1, "parent")
        let child = TocItem("Child", 2, "child")

        parent.addChild(child)

        @Expect(parent.children.size, 1)
        if (let tocChild: TocItem <- parent.children[0]) {
            @Expect(tocChild.text, "Child")
            @Expect(tocChild.anchorId, "child")
        } else {
            @Expect(true, false)
        }
    }
}
