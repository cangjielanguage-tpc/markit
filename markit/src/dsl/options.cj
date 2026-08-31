package markit.dsl

import markit.plugins.standard.block.heading.{HeadingNumberingConfig, HeadingSlugConfig}
import markit.plugins.standard.inline.link.LinkConfig

public class DslOptions {
    public let headingNumberingConfig: HeadingNumberingConfig
    public let headingSlugConfig: HeadingSlugConfig
    public let linkConfig: LinkConfig
    public let includeI18n: Bool
    public let includeToc: Bool

    public init(
        headingNumberingConfig!: HeadingNumberingConfig = HeadingNumberingConfig(),
        headingSlugConfig!: HeadingSlugConfig = HeadingSlugConfig(),
        linkConfig!: LinkConfig = LinkConfig(),
        includeI18n!: Bool = true,
        includeToc!: Bool = true
    ) {
        this.headingNumberingConfig = headingNumberingConfig
        this.headingSlugConfig = headingSlugConfig
        this.linkConfig = linkConfig
        this.includeI18n = includeI18n
        this.includeToc = includeToc
    }
}
