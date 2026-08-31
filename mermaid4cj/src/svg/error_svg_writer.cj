package mermaid4cj.svg

import mermaid4cj.core.MermaidRenderOptions

public class ErrorSvgWriter {
    public init() {}

    public func write(title: String, message: String, options: MermaidRenderOptions): String {
        let theme = SvgTheme.resolve(options.theme)
        let out = StringBuilder(title.size + message.size + 512)
        out.append("<svg xmlns=\"http://www.w3.org/2000/svg\" class=\"")
        SvgEscaper.appendAttribute(out, options.classPrefix)
        out.append(" mermaid4cj-error\" role=\"img\" viewBox=\"0 0 520 120\" width=\"520\" height=\"120\">")
        out.append("<title>")
        SvgEscaper.appendText(out, title)
        out.append("</title><rect width=\"520\" height=\"120\" rx=\"6\" fill=\"")
        out.append(theme.errorFill)
        out.append("\" stroke=\"")
        out.append(theme.errorStroke)
        out.append("\"/><text x=\"24\" y=\"42\" font-family=\"Arial, sans-serif\" font-size=\"16\" font-weight=\"700\" fill=\"")
        out.append(theme.text)
        out.append("\">")
        SvgEscaper.appendText(out, title)
        out.append("</text><text x=\"24\" y=\"74\" font-family=\"Arial, sans-serif\" font-size=\"13\" fill=\"")
        out.append(theme.text)
        out.append("\">")
        SvgEscaper.appendText(out, message)
        out.append("</text></svg>")
        return out.toString()
    }
}
