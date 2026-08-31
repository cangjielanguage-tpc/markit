package markit.core.incremental

public class PendingTailState {
    public let summary: String
    public let openBlockKind: String
    public let pendingParagraphLineCount: Int64
    public let startByteOffset: Int64
    public let endByteOffset: Int64
    public let startRuneOffset: Int64
    public let endRuneOffset: Int64
    public let previewText: String

    public init(
        summary!: String = "",
        openBlockKind!: String = "",
        pendingParagraphLineCount!: Int64 = 0,
        startByteOffset!: Int64 = 0,
        endByteOffset!: Int64 = 0,
        startRuneOffset!: Int64 = 0,
        endRuneOffset!: Int64 = 0,
        previewText!: String = ""
    ) {
        this.summary = summary
        this.openBlockKind = openBlockKind
        this.pendingParagraphLineCount = pendingParagraphLineCount
        this.startByteOffset = startByteOffset
        this.endByteOffset = endByteOffset
        this.startRuneOffset = startRuneOffset
        this.endRuneOffset = endRuneOffset
        this.previewText = previewText
    }

    public func hasPendingContent(): Bool {
        return !openBlockKind.isEmpty() || pendingParagraphLineCount > 0 || !previewText.isEmpty()
    }
}
