package mermaid4cj.core

import std.collection.ArrayList

public class MermaidRenderContext {
    public let diagnostics: ArrayList<String>

    public init() {
        diagnostics = ArrayList<String>()
    }

    public func reset(): Unit {
        while (!diagnostics.isEmpty()) {
            diagnostics.remove(at: diagnostics.size - 1)
        }
    }
}
