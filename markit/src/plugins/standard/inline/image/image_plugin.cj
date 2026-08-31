package markit.plugins.standard.inline.image

import markit.core.plugin.{Plugin, PluginRegistrar}

public class ImagePlugin <: Plugin {
    public prop name: String {
        get() {
            return "ImagePlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerInlineParser(ImageParser())
        registrar.registerHtmlRenderer("Image", ImageHtmlRenderer())
        registrar.registerMarkdownRenderer("Image", ImageMarkdownRenderer())
        registrar.registerTypstRenderer("Image", ImageTypstRenderer())
    }
}
