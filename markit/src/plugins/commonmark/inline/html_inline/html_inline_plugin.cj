package markit.plugins.commonmark.inline.html_inline

import std.collection.ArrayList
import markit.core.nodes.Node
import markit.core.plugin.{Plugin, PluginRegistrar}
import markit.core.session.SessionSymbolTableStore
import markit.core.source.SourceSpan

public class HTMLInlinePlugin <: Plugin {
    private let config: HtmlInlineTagPairingConfig

    public init(config!: HtmlInlineTagPairingConfig = HtmlInlineTagPairingConfig()) {
        this.config = config
    }

    public prop name: String {
        get() {
            return "HTMLInlinePlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerInlineParser(HTMLInlineParser())
        registrar.registerHtmlRenderer("HTMLInline", HTMLInlineHtmlRenderer())
        registrar.registerMarkdownRenderer("HTMLInline", HTMLInlineMarkdownRenderer())
        registrar.registerTypstRenderer("HTMLInline", HTMLInlineTypstRenderer())
        registrar.registerPostFinalizeProcessor({
            root: Node,
            _: SessionSymbolTableStore =>
            if (config.enabled) {
                pairTags(root)
            }
            extractHtmlInlineFromHtmlBlocks(root)
        })
    }

    private static func pairTags(node: Node): Unit {
        for (child in node.children) {
            pairTags(child)
        }
        if (node.children.size < 2) {
            return
        }

        let result = ArrayList<Node>()
        var index: Int64 = 0
        var changed = false
        while (index < node.children.size) {
            if (let opening: HTMLInlineNode <- node.children[index]) {
                if (opening.isOpeningTag()) {
                    let closeIndex = findMatchingClose(node.children, index, opening.tagName)
                    if (closeIndex.isSome()) {
                        let closePos = closeIndex.getOrThrow()
                        if (let closing: HTMLInlineNode <- node.children[closePos]) {
                            let container = HTMLInlineNode(
                                opening.id,
                                opening.sourceSpan.merge(closing.sourceSpan),
                                opening.tagName,
                                Container,
                                buildRaw(node.children, index, closePos),
                                isContentProtected: opening.isContentProtected,
                                attributes: opening.attributes,
                                attributesStr: opening.attributesStr
                            )
                            if (opening.isContentProtected) {
                                let literal = buildRaw(node.children, index + 1, closePos - 1)
                                if (!literal.isEmpty()) {
                                    container.addChild(Node(
                                        "Text",
                                        id: opening.id,
                                        sourceSpan: SourceSpanForChildren(node.children, index + 1, closePos - 1),
                                        literal: literal
                                    ))
                                }
                            } else {
                                for (i in index + 1..closePos) {
                                    container.addChild(node.children[i])
                                }
                                pairTags(container)
                            }
                            result.add(container)
                            index = closePos + 1
                            changed = true
                            continue
                        }
                    }
                }
            }
            result.add(node.children[index])
            index += 1
        }

        if (changed) {
            node.children.clear()
            for (child in result) {
                node.addChild(child)
            }
        }
    }

    private static func findMatchingClose(children: ArrayList<Node>, start: Int64, tagName: String): ?Int64 {
        var depth: Int64 = 0
        for (i in start + 1..children.size) {
            if (let html: HTMLInlineNode <- children[i]) {
                if (html.tagName == tagName) {
                    if (html.isOpeningTag()) {
                        depth += 1
                    } else if (html.isClosingTag()) {
                        if (depth == 0) {
                            return Some(i)
                        }
                        depth -= 1
                    }
                }
            }
        }
        return None
    }

    private static func buildRaw(children: ArrayList<Node>, start: Int64, end: Int64): String {
        if (end < start || start < 0 || end >= children.size) {
            return ""
        }
        let raw = StringBuilder()
        for (i in start..end + 1) {
            raw.append(children[i].rawContent())
        }
        return raw.toString()
    }

    private static func SourceSpanForChildren(children: ArrayList<Node>, start: Int64, end: Int64): SourceSpan {
        if (end < start || start < 0 || end >= children.size) {
            return SourceSpan.empty()
        }
        var span = children[start].sourceSpan
        for (i in start + 1..end + 1) {
            span = span.merge(children[i].sourceSpan)
        }
        return span
    }

    private static func extractHtmlInlineFromHtmlBlocks(node: Node): Unit {
        for (child in node.children) {
            extractHtmlInlineFromHtmlBlocks(child)
        }
        if (node.kind != "HTMLBlock") {
            return
        }

        let result = ArrayList<Node>()
        for (child in node.children) {
            if (child.kind == "Paragraph") {
                let paragraphRest = ArrayList<Node>()
                for (grandChild in child.children) {
                    if (grandChild.kind == "HTMLInline") {
                        result.add(grandChild)
                    } else {
                        paragraphRest.add(grandChild)
                    }
                }
                let normalizedRest = trimSoftBreakEdges(paragraphRest)
                var hasContent = false
                for (rest in normalizedRest) {
                    if (rest.kind != "SoftBreak") {
                        hasContent = true
                        break
                    }
                }
                if (hasContent) {
                    child.children.clear()
                    for (rest in normalizedRest) {
                        child.addChild(rest)
                    }
                    result.add(child)
                }
            } else {
                result.add(child)
            }
        }
        node.children.clear()
        for (child in result) {
            node.addChild(child)
        }
    }

    private static func trimSoftBreakEdges(children: ArrayList<Node>): ArrayList<Node> {
        let result = ArrayList<Node>()
        if (children.isEmpty()) {
            return result
        }

        var start: Int64 = 0
        var end: Int64 = children.size
        while (start < end && children[start].kind == "SoftBreak") {
            start += 1
        }
        while (end > start && children[end - 1].kind == "SoftBreak") {
            end -= 1
        }
        for (i in start..end) {
            result.add(children[i])
        }
        return result
    }
}
