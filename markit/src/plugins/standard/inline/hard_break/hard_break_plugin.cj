package markit.plugins.standard.inline.hard_break

import markit.core.plugin.{Plugin, PluginRegistrar}
import markit.core.session.SessionStateKey

public class HardBreakPlugin <: Plugin {
    public let key = SessionStateKey<HardBreakState>("HardBreakPlugin", "enabled")

    public prop name: String {
        get() {
            return "HardBreakPlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerState(key, { => HardBreakState() })
        registrar.registerInlineParser(HardBreakParser())
        registrar.registerHtmlRenderer("HardBreak", HardBreakHtmlRenderer())
        registrar.registerMarkdownRenderer("HardBreak", HardBreakMarkdownRenderer())
        registrar.registerTypstRenderer("HardBreak", HardBreakTypstRenderer())
    }
}
