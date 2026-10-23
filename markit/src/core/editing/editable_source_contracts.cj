package markit.core.editing

public enum EditingCoordinate <: Equatable<EditingCoordinate> {
    | Utf8Byte
    | UnicodeRune
    | Utf16

    public operator func ==(right: EditingCoordinate): Bool {
        match ((this, right)) { case (Utf8Byte, Utf8Byte) | (UnicodeRune, UnicodeRune) | (Utf16, Utf16) => true; case _ => false }
    }
}

public enum AnchorAffinity <: Equatable<AnchorAffinity> {
    | Before
    | After

    public operator func ==(right: AnchorAffinity): Bool {
        match ((this, right)) { case (Before, Before) | (After, After) => true; case _ => false }
    }
}

public struct SourceVersionIdentity {

    public SourceVersionIdentity(public let documentId: String, public let version: Int64) {
        if (documentId.isEmpty() || version < 0) {
            throw IllegalArgumentException("Invalid source identity")
        }
    }
}

public struct EditingRange {

    public EditingRange(public let start: Int64, public let end: Int64, public let coordinate!: EditingCoordinate = EditingCoordinate.Utf8Byte) {
        if (start < 0 || end < start) {
            throw IllegalArgumentException("Invalid half-open edit range")
        }
    }
}

public struct EditingTextEdit {
    public EditingTextEdit(public let range: EditingRange, public let text: String) {}
}

public struct SourceAnchor {

    public SourceAnchor(public let source: SourceVersionIdentity, public let byteOffset: Int64,
        public let affinity!: AnchorAffinity = AnchorAffinity.After) {
        if (byteOffset < 0) { throw IllegalArgumentException("Negative anchor") }
    }
}

public struct SourceCoordinate {
    // line and utf16Column are -1 when raw offsets are valid but no editor position exists
    // (the position between CR and LF). Other coordinates remain meaningful.

    public SourceCoordinate(public let byteOffset: Int64, public let runeOffset: Int64, public let utf16Offset: Int64,
        public let line: Int64, public let utf16Column: Int64) {}
}

public struct EditingSourceLine {
    public EditingSourceLine(public let index: Int64, public let startByte: Int64, public let content: String, public let lineEnding: String) {}
}

public interface EditableSourceVersion {
    prop identity: SourceVersionIdentity
    prop byteLength: Int64
    prop runeLength: Int64
    prop utf16Length: Int64
    prop lineCount: Int64
    func sliceBytes(start: Int64, end: Int64): String
    func coordinateAtByte(byteOffset: Int64): ?SourceCoordinate
    func byteAtCoordinate(offset: Int64, coordinate: EditingCoordinate): ?Int64
    func byteAtLineColumn(line: Int64, utf16Column: Int64): ?Int64
    func lineAt(index: Int64): ?EditingSourceLine
}

public interface EditableSourceStore {
    prop current: EditableSourceVersion
    // Edits use original-version coordinates, ascending non-overlapping ranges.
    // Byte/rune/linear UTF-16 edits may delete CR or LF independently; only
    // partial UTF-8 scalars/UTF-16 surrogate pairs and stale versions reject.
    // Line/column positions cannot address the middle of a CRLF pair.
    // Equal-position zero-length insertions preserve their input array order.
    // An empty batch is a no-op and keeps the current version.
    func applyEdits(expectedVersion: Int64, edits: Array<EditingTextEdit>): EditableSourceVersion
    func resolve(anchor: SourceAnchor, targetVersion: Int64): ?Int64
}

public struct SourceMappingSegment {

    public SourceMappingSegment(public let viewStart: Int64, public let viewEnd: Int64, public let rawStart: Int64, public let rawEnd: Int64,
        public let source: SourceVersionIdentity, public let synthetic!: Bool = false) {
        if (viewStart < 0 || viewEnd < viewStart || rawStart < 0 || rawEnd < rawStart) {
            throw IllegalArgumentException("Invalid source mapping segment")
        }
    }
}

public interface ComposableSourceMap {
    func mapByte(viewOffset: Int64, affinity: AnchorAffinity): ?SourceAnchor
    func segments(start: Int64, end: Int64): Array<SourceMappingSegment>
    func compose(parent: ComposableSourceMap): ComposableSourceMap
}
