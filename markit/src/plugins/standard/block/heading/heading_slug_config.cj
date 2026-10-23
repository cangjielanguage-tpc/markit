package markit.plugins.standard.block.heading

public struct HeadingSlugConfig {
    public HeadingSlugConfig(
        public let currentPagePath!: String = "",
        public let enablePathLabels!: Bool = false
    ) {}
}
