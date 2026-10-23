package markit.tests.unit

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.core.block.LeafBlockParser
import markit.core.editing.{IncrementalCheckpoint, IncrementalParserContext, IncrementalParserFacet, IncrementalReadDependency}
import markit.core.nodes.Node
import markit.core.plugin.{Plugin, PluginRegistrar}
import markit.core.session.ParseSession
import markit.plugins.standard.block.blockquote.BlockquotePlugin
import markit.plugins.standard.block.heading.HeadingPlugin
import markit.plugins.standard.block.paragraph.ParagraphPlugin
import markit.plugins.standard.inline.bold.BoldPlugin
import markit.tests.utils.{EditingLegacyNoticePlugin, ParseModeTestKit}

// These tiny test parsers exercise declarations, not a second editing engine.
private class CapabilityDeclarationLeaf <: LeafBlockParser {
    private let parserName: String
    private let marker: String
    private let enabled: Bool
    private let facet: ?IncrementalParserFacet

    public init(parserName: String, marker: String, enabled: Bool,
        facet!: ?IncrementalParserFacet = None) {
        this.parserName = parserName
        this.marker = marker
        this.enabled = enabled
        this.facet = facet
    }

    public prop name: String { get() { return parserName } }
    public prop ownerPlugin: String { get() { return "MixedCapabilityDeclarationPlugin" } }
    public prop priority: Int64 { get() { return 1 } }
    public prop startBytes: Array<Byte> { get() { return [marker[0]] } }
    public prop acceptsAnyNonBlank: Bool { get() { return false } }
    public prop supportsIncremental: Bool { get() { return enabled } }
    public prop incrementalFacet: ?IncrementalParserFacet { get() { return facet } }

    public func tryParse(session: ParseSession, line: String): ?Node {
        if (!line.startsWith(marker)) { return None }
        return Some(session.createTextNode(line[marker.size..], session.currentLineSpan()))
    }
}

private class MixedCapabilityDeclarationPlugin <: Plugin {
    public prop name: String { get() { return "MixedCapabilityDeclarationPlugin" } }
    public prop version: String { get() { return "1.0.0" } }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerLeafBlockParser(CapabilityDeclarationLeaf("legacy", "~legacy ", false))
        registrar.registerLeafBlockParser(CapabilityDeclarationLeaf("flag-only", "~declared ", true))
    }
}

// Explicitly incomplete provider: refusing methods cannot claim a successful
// empty checkpoint, restoration, equivalence, or effect rollback.
private class DecliningCapabilityFacet <: IncrementalParserFacet {
    public prop owner: String { get() { return "MixedCapabilityDeclarationPlugin" } }
    public prop hasStateCodec: Bool { get() { return false } }
    public prop hasEffectRollback: Bool { get() { return false } }
    public prop hasReadEvidence: Bool { get() { return false } }
    public prop hasNodeCodec: Bool { get() { return false } }
    public func checkpoint(_: IncrementalParserContext): ?IncrementalCheckpoint { return None }
    public func restore(_: IncrementalParserContext, _: IncrementalCheckpoint): Bool { return false }
    public func rollbackEffects(_: IncrementalParserContext, _: IncrementalCheckpoint): Bool { return false }
    public func syntaxEquivalent(_: IncrementalCheckpoint, _: IncrementalCheckpoint): Bool { return false }
    public func readDependencies(): ArrayList<IncrementalReadDependency> {
        return ArrayList<IncrementalReadDependency>()
    }
}

@Test
@Tag[EditingContracts]
class EditingParserCapabilityTests {
    @TestCase
    func fourExistingParserCategoriesInheritSafeDefaults() {
        let registrar = PluginRegistrar()
        HeadingPlugin().register(registrar)
        BlockquotePlugin().register(registrar)
        ParagraphPlugin().register(registrar)
        BoldPlugin().register(registrar)
        @Expect(registrar.leafBlockParsers.size, 1)
        @Expect(registrar.continuationBlockParsers.size, 1)
        @Expect(registrar.paragraphBlockParsers.size, 1)
        @Expect(registrar.inlineParsers.size > 0, true)
        for (parser in registrar.leafBlockParsers) {
            @Expect(parser.supportsIncremental, false)
            @Expect(parser.incrementalFacet.isNone(), true)
            @Expect(parser.incrementalIsolation.isNone(), true)
        }
        for (parser in registrar.continuationBlockParsers) {
            @Expect(parser.supportsIncremental, false)
            @Expect(parser.incrementalFacet.isNone(), true)
            @Expect(parser.incrementalIsolation.isNone(), true)
        }
        for (parser in registrar.paragraphBlockParsers) {
            @Expect(parser.supportsIncremental, false)
            @Expect(parser.incrementalFacet.isNone(), true)
            @Expect(parser.incrementalIsolation.isNone(), true)
        }
        for (parser in registrar.inlineParsers) {
            @Expect(parser.supportsIncremental, false)
            @Expect(parser.incrementalFacet.isNone(), true)
            @Expect(parser.incrementalIsolation.isNone(), true)
        }
    }

    @TestCase
    func onePluginCanDeclareDifferentCapabilitiesForItsActualParsers() {
        let registrar = PluginRegistrar()
        MixedCapabilityDeclarationPlugin().register(registrar)
        @Expect(registrar.leafBlockParsers.size, 2)
        @Expect(registrar.leafBlockParsers[0].supportsIncremental, false)
        @Expect(registrar.leafBlockParsers[1].supportsIncremental, true)
        // A true flag does not manufacture a provider or isolation evidence.
        @Expect(registrar.leafBlockParsers[1].incrementalFacet.isNone(), true)
        @Expect(registrar.leafBlockParsers[1].incrementalIsolation.isNone(), true)
        for (result in ParseModeTestKit.collect(
            { => Markit().use(MixedCapabilityDeclarationPlugin()) },
            "~legacy old\n~declared new"
        )) {
            @Expect(result.html, "oldnew")
        }
    }

    @TestCase
    func incompleteFacetDoesNotPretendToProvideMissingOperations() {
        let parser = CapabilityDeclarationLeaf("partial", "~partial ", true,
            facet: Some(DecliningCapabilityFacet()))
        @Expect(parser.supportsIncremental, true)
        let facet = parser.incrementalFacet.getOrThrow()
        @Expect(facet.hasStateCodec, false)
        @Expect(facet.hasEffectRollback, false)
        @Expect(facet.hasReadEvidence, false)
        @Expect(facet.hasNodeCodec, false)
        @Expect(parser.incrementalIsolation.isNone(), true)
    }

    @TestCase
    func frozenLegacyThirdPartySourceStillParsesAndAppendsUnchanged() {
        for (result in ParseModeTestKit.collect(
            { => Markit().use(EditingLegacyNoticePlugin()) },
            "~note 甲😀\r\n!note second"
        )) {
            @Expect(result.html, "甲😀second")
            @Expect(result.root.children.size, 2)
        }
        let registrar = PluginRegistrar()
        EditingLegacyNoticePlugin().register(registrar)
        for (parser in registrar.leafBlockParsers) {
            @Expect(parser.supportsIncremental, false)
            @Expect(parser.incrementalFacet.isNone(), true)
            @Expect(parser.incrementalIsolation.isNone(), true)
        }
    }
}
