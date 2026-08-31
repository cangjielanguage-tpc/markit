package markit.plugins.i18n

import markit.core.nodes.Node
import markit.core.plugin.{Plugin, PluginRegistrar}
import markit.core.session.{ParseSession, SessionStateKey, SessionSymbolTableStore}
import markit.plugins.i18n.block.{I18nBlockHtmlRenderer, I18nBlockMarkdownRenderer, I18nBlockParser, I18nBlockTypstRenderer}
import markit.plugins.i18n.config.I18nConfig
import markit.plugins.i18n.inline.{I18nInlineHtmlRenderer, I18nInlineMarkdownRenderer, I18nInlineParser, I18nInlineTypstRenderer}
import markit.plugins.i18n.processors.I18nPostProcessor

public class I18nPlugin <: Plugin {
    public static let stateKey = SessionStateKey<I18nSessionState>("I18nPlugin", "i18n")
    public let config: I18nConfig
    private let postProcessor: I18nPostProcessor

    public init(config!: I18nConfig = I18nConfig()) {
        this.config = config
        this.postProcessor = I18nPostProcessor(config)
    }

    public prop name: String {
        get() {
            return "I18nPlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerState(I18nPlugin.stateKey, { => I18nSessionState(config) })
        registrar.registerInlineParser(I18nInlineParser())
        registrar.registerContinuationBlockParser(I18nBlockParser())
        registrar.registerNodeEmissionFilter(I18nEmissionFilter())
        registrar.registerSessionFinalizeProcessor({
            session: ParseSession =>
            session.symbolTables.get(I18nPlugin.stateKey).beforeSessionFinalize(session)
        })
        registrar.registerPostFinalizeProcessor({
            root: Node,
            _: SessionSymbolTableStore =>
            postProcessor.process(root)
        })

        registrar.registerHtmlRenderer("I18nInline", I18nInlineHtmlRenderer())
        registrar.registerHtmlRenderer("UniversalInline", I18nInlineHtmlRenderer())
        registrar.registerHtmlRenderer("I18nBlock", I18nBlockHtmlRenderer())
        registrar.registerHtmlRenderer("UniversalBlock", I18nBlockHtmlRenderer())

        registrar.registerMarkdownRenderer("I18nInline", I18nInlineMarkdownRenderer())
        registrar.registerMarkdownRenderer("UniversalInline", I18nInlineMarkdownRenderer())
        registrar.registerMarkdownRenderer("I18nBlock", I18nBlockMarkdownRenderer())
        registrar.registerMarkdownRenderer("UniversalBlock", I18nBlockMarkdownRenderer())

        registrar.registerTypstRenderer("I18nInline", I18nInlineTypstRenderer())
        registrar.registerTypstRenderer("UniversalInline", I18nInlineTypstRenderer())
        registrar.registerTypstRenderer("I18nBlock", I18nBlockTypstRenderer())
        registrar.registerTypstRenderer("UniversalBlock", I18nBlockTypstRenderer())
    }
}
