package markit.tests.unit

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.core.editing.{EditingPolicy, EditingRange, EditingTextEdit}
import markit.core.nodes.{NodeCodec, RawSyntaxNode, PersistentTextPayload}
import markit.plugins.standard.block.paragraph.*

private func paragraphEditingCodec(): NodeCodec {
    let codec = NodeCodec(); registerParagraphEditingCodecs(codec); return codec
}

@Test
@Tag[StandardParagraphEditing, StandardEditing]
class Task07ParagraphEditingTests {
    @TestCase
    func giantSingleLogicalTextEditsTwiceWithBoundedSplicesAndStableSibling() {
        let text = String.fromUtf8(Array<Byte>(262144, repeat: b'a'))
        let app = Markit(ParagraphPlugin())
        let editing = app.createEditingSession("real-paragraph", text + "\n\ntail", paragraphEditingCodec(), policy: EditingPolicy.Strict)
        let before = editing.snapshot()
        let root = (before.tree.root as RawSyntaxNode).getOrThrow()
        let paragraph = root.childAt(0); let literal = paragraph.childAt(0); let tail = root.childAt(1)
        @Expect(paragraph.childCount, 2) // literal plus the legacy terminal SoftBreak
        editing.applyEdits(0, [EditingTextEdit(EditingRange(131072, 131073), "Z")])
        let first = editing.flush(); @Expect(first.committed, true); @Expect(first.syntaxUnitsParsed, 1)
        let middle = editing.snapshot()
        let middleRoot = (middle.tree.root as RawSyntaxNode).getOrThrow()
        @Expect(middleRoot.childAt(0).identity.nodeId, paragraph.identity.nodeId)
        @Expect(refEq(tail, middleRoot.childAt(1)), true)
        @Expect(middle.tree.materializeLegacy().toHtml(), app.parse(text[..131072] + "Z" + text[131073..] + "\n\ntail").html())
        editing.applyEdits(1, [EditingTextEdit(EditingRange(131073, 131074), "Y")])
        let second = editing.flush(); @Expect(second.committed, true)
        let after = editing.snapshot()
        let current = (after.tree.root as RawSyntaxNode).getOrThrow().childAt(0)
        let payload = (current.payload as ParagraphPayload).getOrThrow()
        @Expect(payload.view.readByte(131072), b'Z'); @Expect(payload.view.readByte(131073), b'Y')
        @Expect((literal.payload as PersistentTextPayload).getOrThrow().segments(131072, 131074)[0].text, "aa")
        @Expect(refEq(tail, (after.tree.root as RawSyntaxNode).getOrThrow().childAt(1)), true)
        @Expect(before.tree.materializeLegacy().children[0].literal, text)
        @Expect(after.tree.materializeLegacy().toHtml(), app.parse(text[..131072] + "ZY" + text[131074..] + "\n\ntail").html())
        before.release(); middle.release(); after.release(); editing.close()
    }

    @TestCase
    func plainSingleLineKeepsOneTextAndEmitsSmallLogicalPatch() {
        let text = String.fromUtf8(Array<Byte>(131072, repeat: b'b'))
        let app = Markit(ParagraphPlugin())
        let editing = app.createEditingSession("plain-paragraph", text, paragraphEditingCodec(), policy: EditingPolicy.Strict)
        let before = editing.snapshot(); let old = (before.tree.root as RawSyntaxNode).getOrThrow().childAt(0)
        editing.applyEdits(0, [EditingTextEdit(EditingRange(65536, 65537), "C")])
        @Expect(editing.flush().committed, true)
        let after = editing.snapshot(); let current = (after.tree.root as RawSyntaxNode).getOrThrow().childAt(0)
        @Expect(current.childCount, 1); @Expect(current.childAt(0).identity.nodeId, old.childAt(0).identity.nodeId)
        @Expect(after.patches.size, 2) // child text delta plus its immutable parent payload update
        @Expect(after.patches[0].textSplices.size, 1)
        @Expect(after.patches[0].textSplices[0].inserted, "C")
        @Expect(before.tree.materializeLegacy().children[0].literal, text)
        @Expect(after.tree.materializeLegacy().toHtml(), app.parse(text[..65536] + "C" + text[65537..]).html())
        before.release(); after.release(); editing.close()
    }

    @TestCase
    func escapedCrLfRetainsPhysicalRawAndCancelKeepsPublishedView() {
        let app = Markit(ParagraphPlugin())
        let editing = app.createEditingSession("escaped-paragraph", "a\\\r\nb", paragraphEditingCodec(), policy: EditingPolicy.Strict)
        let before = editing.snapshot(); let original = before.tree.materializeLegacy()
        @Expect(original.toHtml(), app.parse("a\\\r\nb").html())
        @Expect(original.children[0].rawContent(), "a\\\r\nb")
        editing.applyEdits(0, [EditingTextEdit(EditingRange(0, 1), "z")])
        editing.cancelComputation()
        @Expect(before.tree.materializeLegacy().children[0].rawContent(), "a\\\r\nb")
        @Expect(editing.flush().committed, true)
        let after = editing.snapshot(); let current = after.tree.materializeLegacy()
        @Expect(current.children[0].rawContent(), "z\\\r\nb")
        @Expect(current.toHtml(), app.parse("z\\\r\nb").html())
        @Expect(current.children[0].sourceSpan.startByte, 0); @Expect(current.children[0].sourceSpan.endByte, 5)
        before.release(); after.release(); editing.close()
    }
}
