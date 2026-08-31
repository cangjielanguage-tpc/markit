package mermaid4cj.svg

import mermaid4cj.core.MermaidTheme

public class SvgTheme {
    public let background: String
    public let nodeFill: String
    public let nodeStroke: String
    public let text: String
    public let edge: String
    public let edgeLabelBackground: String
    public let errorFill: String
    public let errorStroke: String

    public init(
        background: String,
        nodeFill: String,
        nodeStroke: String,
        text: String,
        edge: String,
        edgeLabelBackground: String,
        errorFill: String,
        errorStroke: String
    ) {
        this.background = background
        this.nodeFill = nodeFill
        this.nodeStroke = nodeStroke
        this.text = text
        this.edge = edge
        this.edgeLabelBackground = edgeLabelBackground
        this.errorFill = errorFill
        this.errorStroke = errorStroke
    }

    public static func resolve(theme: MermaidTheme): SvgTheme {
        match (theme) {
            case MermaidTheme.Dark => return SvgTheme("#1f2937", "#374151", "#93c5fd", "#f9fafb", "#d1d5db", "#374151", "#3f1f1f", "#f87171")
            case _ => return SvgTheme("transparent", "#ECECFF", "#9370DB", "#333333", "#333333", "#e8e8e8", "#fff1f2", "#e11d48")
        }
    }
}
