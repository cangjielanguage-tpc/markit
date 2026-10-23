package markit.tests.utils

import std.collection.ArrayList
import markit.Markit
import markit.bundles.{CommonMarkBundle, GFMBundle, StandardMarkdownBundle}
import markit.core.block.LeafBlockParser
import markit.core.nodes.Node
import markit.core.plugin.{Plugin, PluginRegistrar}
import markit.core.session.ParseSession
import markit.core.source.SourceSpan
import markit.plugins.i18n.I18nPlugin
import markit.plugins.i18n.config.I18nConfig
import markit.plugins.toc.TocPlugin

// Frozen legacy extension source: deliberately uses only the pre-edit API.
// Task 02 must prove compatibility without changing this class or its parsers.
public class EditingLegacyNoticePlugin <: Plugin {
    public prop name: String { get() { return "EditingLegacyNoticePlugin" } }
    public prop version: String { get() { return "1.0.0" } }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerLeafBlockParser(EditingLegacyNoticeParser("~note ", b'~', "isolated-candidate"))
        registrar.registerLeafBlockParser(EditingLegacyNoticeParser("!note ", b'!', "unknown-effects-candidate"))
    }
}

private class EditingLegacyNoticeParser <: LeafBlockParser {
    private let marker: String
    private let firstByte: Byte
    private let parserName: String

    public init(marker: String, firstByte: Byte, parserName: String) {
        this.marker = marker
        this.firstByte = firstByte
        this.parserName = parserName
    }

    public prop name: String { get() { return parserName } }
    public prop ownerPlugin: String { get() { return "EditingLegacyNoticePlugin" } }
    public prop priority: Int64 { get() { return 1 } }
    public prop startBytes: Array<Byte> { get() { return [firstByte] } }
    public prop acceptsAnyNonBlank: Bool { get() { return false } }

    public func tryParse(session: ParseSession, line: String): ?Node {
        if (!line.startsWith(marker)) { return None }
        let content = line[marker.size..]
        let span = session.currentLineSpan()
        var contentRunes: Int64 = 0
        for (_ in content.runes()) { contentRunes += 1 }
        return Some(session.createTextNode(content, SourceSpan(
            span.startByte + marker.size, span.startByte + line.size,
            span.startRune + marker.size, span.startRune + marker.size + contentRunes
        )))
    }
}

public class EditingLegacyFixture {
    public let plugin: String
    public let bundle: String
    public let markdown: String

    public init(plugin: String, bundle: String, markdown: String) {
        this.plugin = plugin
        this.bundle = bundle
        this.markdown = markdown
    }

    public func createMarkit(): Markit {
        if (bundle == "CommonMark.default") { return Markit(CommonMarkBundle()) }
        if (bundle == "GFM.default") { return Markit(GFMBundle()) }
        if (bundle == "Standard.blockAutoAnchor") {
            return Markit(StandardMarkdownBundle(blockAutoAnchor: true))
        }
        if (bundle == "GFM.i18n.zh-to-en") {
            return Markit(GFMBundle()).use(I18nPlugin(
                config: I18nConfig(defaultLanguage: "zh", targetLanguage: "en")
            ))
        }
        if (bundle == "Standard.toc") { return Markit().use(TocPlugin()) }
        return Markit()
    }

    public static func builtinInventory(): Array<EditingLegacyFixture> {
        return [
            EditingLegacyFixture("BlockquotePlugin", "Standard.default", "> quoted\n"),
            EditingLegacyFixture("HeadingPlugin", "Standard.default", "# 标题😀\n"),
            EditingLegacyFixture("DividerPlugin", "Standard.default", "---\n"),
            EditingLegacyFixture("FencedCodeBlockPlugin", "Standard.default", "```text\ncode\n```\n"),
            EditingLegacyFixture("ListPlugin", "Standard.default", "- parent\n  - child\n"),
            EditingLegacyFixture("ParagraphPlugin", "Standard.default", "first\nsecond"),
            EditingLegacyFixture("InlineCodePlugin", "Standard.default", "`code`\n"),
            EditingLegacyFixture("LinkPlugin", "Standard.default", "[link](https://example.test)\n"),
            EditingLegacyFixture("ImagePlugin", "Standard.default", "![alt](image.png)\n"),
            EditingLegacyFixture("ReferenceLinkPlugin", "Standard.default", "[name][id]\n\n[id]: /target\n"),
            EditingLegacyFixture("BoldPlugin", "Standard.default", "**bold**\n"),
            EditingLegacyFixture("ItalicPlugin", "Standard.default", "*italic*\n"),
            EditingLegacyFixture("HardBreakPlugin", "Standard.default", "first  \nsecond\n"),
            EditingLegacyFixture("SetextHeadingPlugin", "CommonMark.default", "heading\n=======\n"),
            EditingLegacyFixture("HTMLBlockPlugin", "CommonMark.default", "<div>block</div>\n"),
            EditingLegacyFixture("CommonMarkAutolinkPlugin", "CommonMark.default", "<https://example.test>\n"),
            EditingLegacyFixture("HTMLInlinePlugin", "CommonMark.default", "a <span>inline</span> b\n"),
            EditingLegacyFixture("EntityReferencePlugin", "CommonMark.default", "&amp; &#x1F600;\n"),
            EditingLegacyFixture("AlphabeticListPlugin", "GFM.default", "a. alpha\nb. beta\n"),
            EditingLegacyFixture("MathBlockPlugin", "GFM.default", "$$\nx+1\n$$\n"),
            EditingLegacyFixture("TablePlugin", "GFM.default", "| a | b |\n|---|---|\n| 1 | 2 |\n"),
            EditingLegacyFixture("TaskListPlugin", "GFM.default", "- [x] done\n- [ ] todo\n"),
            EditingLegacyFixture("AutolinkPlugin", "GFM.default", "https://example.test\n"),
            EditingLegacyFixture("FootnotePlugin", "GFM.default", "note[^a]\n\n[^a]: body\n"),
            EditingLegacyFixture("InlineMathPlugin", "GFM.default", "value $x+1$\n"),
            EditingLegacyFixture("RelaxedEmphasisPlugin", "GFM.default", "_italic_ and __bold__\n"),
            EditingLegacyFixture("StrikethroughPlugin", "GFM.default", "~~deleted~~\n"),
            EditingLegacyFixture("AutoAnchorPlugin", "Standard.blockAutoAnchor", "# section\n\nparagraph\n"),
            EditingLegacyFixture("I18nPlugin", "GFM.i18n.zh-to-en", "中文\n\n:::en\nEnglish\n:::\n"),
            EditingLegacyFixture("TocPlugin", "Standard.toc", "# Intro\n\n## Child\n")
        ]
    }
}

public class EditingLegacyInvariants {
    // Use for a fixture leaf whose literal is known to be unchanged source text.
    // This is deliberately opt-in: entities/synthetic text need provenance rules.
    public static func literalSliceMatches(node: Node, markdown: String): Bool {
        let span = node.sourceSpan
        if (span.startByte < 0 || span.endByte < span.startByte || span.endByte > markdown.size) {
            return false
        }
        return markdown[span.startByte..span.endByte] == node.literal
    }

    public static func duplicateIds(root: Node): ArrayList<Int64> {
        let seen = ArrayList<Int64>()
        let duplicates = ArrayList<Int64>()
        visitIds(root, seen, duplicates)
        return duplicates
    }

    private static func visitIds(node: Node, seen: ArrayList<Int64>, duplicates: ArrayList<Int64>): Unit {
        if (seen.contains(node.id)) { duplicates.add(node.id) } else { seen.add(node.id) }
        for (child in node.children) { visitIds(child, seen, duplicates) }
    }

    // Independent coordinate check, including the scanner's CRLF normalization.
    public static func invalidCoordinates(root: Node, markdown: String): ArrayList<String> {
        let failures = ArrayList<String>()
        visitCoordinates(root, markdown, failures)
        return failures
    }

    private static func visitCoordinates(node: Node, markdown: String, failures: ArrayList<String>): Unit {
        let span = node.sourceSpan
        if (span.startByte < 0 || span.endByte < span.startByte || span.endByte > markdown.size) {
            failures.add("${node.name}#${node.id}: byte bounds ${span.startByte}..${span.endByte}")
        } else {
            var expectedStart: Int64 = 0
            var expectedEnd: Int64 = 0
            for (_ in markdown[0..span.startByte].replace("\r\n", "\n").runes()) { expectedStart += 1 }
            for (_ in markdown[0..span.endByte].replace("\r\n", "\n").runes()) { expectedEnd += 1 }
            if (span.startRune != expectedStart || span.endRune != expectedEnd) {
                failures.add("${node.name}#${node.id}: runes ${span.startRune}..${span.endRune}, expected ${expectedStart}..${expectedEnd}")
            }
        }
        for (child in node.children) { visitCoordinates(child, markdown, failures) }
    }
}
