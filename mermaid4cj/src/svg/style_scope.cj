package mermaid4cj.svg

public func appendSvgStyleScope(out: StringBuilder, idPrefix: String): Unit {
    out.append("#")
    SvgEscaper.appendText(out, idPrefix)
}

public func appendSvgStyleScopeSelector(out: StringBuilder, idPrefix: String, selector: String): Unit {
    appendSvgStyleScope(out, idPrefix)
    if (!selector.isEmpty()) {
        out.append(" ")
        out.append(selector)
    }
}
