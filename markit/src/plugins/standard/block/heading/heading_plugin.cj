package markit.plugins.standard.block.heading

import markit.core.plugin.{Plugin, PluginRegistrar}
import markit.core.session.SessionStateKey

public class HeadingPlugin <: Plugin {
    public static let stateKey = SessionStateKey<HeadingSessionState>("HeadingPlugin", "heading")
    private let numberingConfig: HeadingNumberingConfig
    private let closableConfig: HeadingClosableConfig
    private let slugConfig: HeadingSlugConfig

    public init(
        numberingConfig!: HeadingNumberingConfig = HeadingNumberingConfig(),
        closableConfig!: HeadingClosableConfig = HeadingClosableConfig(),
        slugConfig!: HeadingSlugConfig = HeadingSlugConfig()
    ) {
        this.numberingConfig = numberingConfig
        this.closableConfig = closableConfig
        this.slugConfig = slugConfig
    }

    public prop name: String {
        get() {
            return "HeadingPlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0-scaffold"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerState(HeadingPlugin.stateKey, {
            => HeadingSessionState(
                numberingConfig: numberingConfig,
                closableConfig: closableConfig,
                slugConfig: slugConfig
            )
        })
        registrar.registerLeafBlockParser(HeadingBlockParser(closableConfig: closableConfig))
        registrar.registerNodeBatchProcessor(HeadingNodeBatchProcessor())
        registrar.registerNodeEmissionFilter(HeadingNodeEmissionFilter())
        registrar.registerHtmlRenderer("Heading", HeadingHtmlRenderer())
        registrar.registerMarkdownRenderer("Heading", HeadingMarkdownRenderer())
        registrar.registerTypstRenderer("Heading", HeadingTypstRenderer())
    }
}
