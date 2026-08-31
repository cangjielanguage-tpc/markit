package markit.plugins.standard.block.heading

public struct HeadingSlugConfig {
    public let currentPagePath: String
    public let enablePathLabels: Bool

    public init(
        currentPagePath!: String = "",
        enablePathLabels!: Bool = false
    ) {
        this.currentPagePath = currentPagePath
        this.enablePathLabels = enablePathLabels
    }
}
