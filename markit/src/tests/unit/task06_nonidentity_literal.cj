package markit.tests.unit

import std.collection.ArrayList
import markit.core.block.BlockEditingContext
import markit.core.editing.SourceAnchor
import markit.core.inline.{InlineTextView, InlineLiteralFacet, InlineRecoveryContext, InlineRecoveryWindow, InlineLiteralSplice}
import markit.core.nodes.PersistentTextPayload

// A concrete non-identity test decoder, deliberately confined to test facets.
// Raw coordinates remain raw coordinates; decoded offsets have no identity proof.
class Task06EscapedLiteralFacet <: InlineLiteralFacet {
    private let identity = Task06LiteralFacet()
    public prop grammarVersion: String { get() { return "task06-escaped-literal-v1" } }
    public func recoverWindow(context: InlineRecoveryContext): ?InlineRecoveryWindow {
        if (let Some(window) <- identity.recoverWindow(context)) {
            return Some(InlineRecoveryWindow(window.startByte, window.oldEndByte, window.newEndByte,
                "test escaped literal boundary", grammarVersion))
        }
        return None
    }
    public func projectRaw(view: InlineTextView, anchor: SourceAnchor, context: BlockEditingContext): ?Int64 {
        return identity.projectRaw(view, anchor, context)
    }
    public func decode(view: InlineTextView, startByte: Int64, endByte: Int64): String {
        let bytes = ArrayList<Byte>()
        var cursor = startByte
        while (cursor < endByte) {
            var byte = view.readByte(cursor)
            if (byte == 92 && cursor + 1 < endByte) { cursor += 1; byte = view.readByte(cursor) }
            bytes.add(byte); cursor += 1
        }
        return String.fromUtf8(bytes.toArray())
    }
    public func payload(view: InlineTextView, startByte: Int64, endByte: Int64, _: BlockEditingContext): ?PersistentTextPayload {
        return Some(PersistentTextPayload.withRawSpelling(decode(view, startByte, endByte), view.sliceBytes(startByte, endByte)))
    }
    public func splice(_: PersistentTextPayload, _: InlineRecoveryContext): ?InlineLiteralSplice { return None }
}
