package markit.plugins.i18n.processors

import std.collection.HashMap
import markit.core.nodes.{Node, TextNode}
import markit.plugins.i18n.config.I18nConfig
import markit.plugins.i18n.nodes.{I18nBlockNode, I18nInlineNode, UniversalBlockNode, UniversalInlineNode}
import markit.plugins.standard.block.heading.HeadingNode
import markit.utils.slug

public class I18nPostProcessor {
    private let defaultLanguage: String
    private let targetLanguage: String

    public init(defaultLanguage: String, targetLanguage: String) {
        this.defaultLanguage = defaultLanguage
        this.targetLanguage = targetLanguage
    }

    public init(config: I18nConfig) {
        this.defaultLanguage = config.defaultLanguage
        this.targetLanguage = config.targetLanguage
    }

    public func process(document: Node): Node {
        setLanguageAttributes(document, defaultLanguage)
        document.setString("i18n_target_language", targetLanguage)
        setRenderFlags(document)
        rewriteHeadingSlugs(document)
        return document
    }

    public func getDefaultLanguage(): String {
        return defaultLanguage
    }

    public func getTargetLanguage(): String {
        return targetLanguage
    }

    private func setLanguageAttributes(node: Node, inheritedLanguage: String): Unit {
        let currentLanguage = if (let inline: I18nInlineNode <- node) {
            inline.languageId
        } else if (let block: I18nBlockNode <- node) {
            block.languageId
        } else if ((node is UniversalInlineNode) || (node is UniversalBlockNode) || isUniversalBlock(node)) {
            "universal"
        } else {
            inheritedLanguage
        }

        node.setString("i18n_language", currentLanguage)
        node.setString("i18n_target_language", targetLanguage)
        for (child in node.children) {
            setLanguageAttributes(child, currentLanguage)
        }
    }

    private func setRenderFlags(node: Node): Bool {
        var childShouldRender = false
        for (child in node.children) {
            if (setRenderFlags(child)) {
                childShouldRender = true
            }
        }

        let nodeLanguage = node.string("i18n_language") ?? defaultLanguage
        let ownShouldRender = shouldRenderLanguage(nodeLanguage)
        let shouldRender = ownShouldRender || childShouldRender
        if (!shouldRender) {
            node.setString("render", "false")
        }
        return shouldRender
    }

    private func shouldRenderLanguage(language: String): Bool {
        if (language == "universal") {
            return true
        }
        if (language == targetLanguage) {
            return true
        }
        return language == defaultLanguage && targetLanguage == defaultLanguage
    }

    private func isUniversalBlock(node: Node): Bool {
        return node.kind == "FencedCodeBlock" || node.kind == "Table" || node.kind == "MathBlock" || node.kind == "Divider"
    }

    private func rewriteHeadingSlugs(document: Node): Unit {
        let slugCounts = HashMap<String, Int64>()
        rewriteHeadingSlugs(document, slugCounts)
    }

    private func rewriteHeadingSlugs(node: Node, slugCounts: HashMap<String, Int64>): Unit {
        if (node.string("render") == Some("false")) {
            return
        }

        if (let heading: HeadingNode <- node) {
            rewriteHeadingSlug(heading, slugCounts)
        }

        for (child in node.children) {
            rewriteHeadingSlugs(child, slugCounts)
        }
    }

    private func rewriteHeadingSlug(heading: HeadingNode, slugCounts: HashMap<String, Int64>): Unit {
        let text = renderableText(heading).trimAscii()
        let baseSlug = slug(text)
        if (baseSlug.isEmpty()) {
            return
        }

        let oldBaseSlug = heading.string("baseSlug") ?? heading.slug
        let oldTypstLabel = heading.string("typstLabel") ?? ""
        let seen = slugCounts.get(baseSlug) ?? 0
        let occurrence = seen + 1
        slugCounts[baseSlug] = occurrence
        let uniqueSlug = if (seen == 0) {
            baseSlug
        } else {
            "${baseSlug}-${occurrence}"
        }

        heading.slug = uniqueSlug
        heading.setString("baseSlug", baseSlug)
        heading.setInt("slugOccurrence", occurrence)
        if (!oldTypstLabel.isEmpty()) {
            heading.setString("typstLabel", rewriteTypstLabel(oldTypstLabel, oldBaseSlug, baseSlug, occurrence))
        }
    }

    private func rewriteTypstLabel(
        oldTypstLabel: String,
        oldBaseSlug: String,
        baseSlug: String,
        occurrence: Int64
    ): String {
        let suffix = if (occurrence <= 1) { baseSlug } else { "${baseSlug}-${occurrence}" }
        if (oldBaseSlug.isEmpty()) {
            return suffix
        }
        if (oldTypstLabel == oldBaseSlug) {
            return suffix
        }
        if (oldTypstLabel.endsWith("-${oldBaseSlug}")) {
            return oldTypstLabel[0..oldTypstLabel.size - oldBaseSlug.size] + suffix
        }
        return suffix
    }

    private func renderableText(node: Node): String {
        let sb = StringBuilder()
        appendRenderableText(node, sb)
        return sb.toString()
    }

    private func appendRenderableText(node: Node, sb: StringBuilder): Unit {
        if (node.string("render") == Some("false")) {
            return
        }
        if (let text: TextNode <- node) {
            sb.append(text.content)
            return
        }
        if (!node.literal.isEmpty() && node.children.isEmpty()) {
            sb.append(node.literal)
            return
        }
        for (child in node.children) {
            appendRenderableText(child, sb)
        }
    }
}
