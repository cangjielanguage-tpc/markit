package markit.core.session

import markit.core.source.SourceRetentionMode

public class ParseOptions {
    public let inputChunkSize: Int64
    public let sourceRetentionMode: SourceRetentionMode
    public let emitHtmlFragments: Bool
    public let emitPreview: Bool

    public init(
        inputChunkSize!: Int64 = 8192,
        sourceRetentionMode!: SourceRetentionMode = SourceRetentionMode.Essential,
        emitHtmlFragments!: Bool = true,
        emitPreview!: Bool = true
    ) {
        this.inputChunkSize = inputChunkSize
        this.sourceRetentionMode = sourceRetentionMode
        this.emitHtmlFragments = emitHtmlFragments
        this.emitPreview = emitPreview
    }
}
