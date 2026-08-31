package markit.tests.unit

import std.unittest.*
import std.unittest.testmacro.*
import markit.core.block.{
    BlockDispatchTable,
    BlockFrame,
    BlockState,
    ContinuationBlockDispatchTable,
    ContinuationBlockParser,
    ContinueResult,
    LeafBlockParser
}
import markit.core.inline.{InlineDispatchTable, InlineParseResult, InlineParser}
import markit.core.nodes.{Node, TextNode}
import markit.core.plugin.{Plugin, PluginRegistrar, PluginRegistry}
import markit.core.session.ParseSession
import markit.core.source.SourceSpan

@Test
class RegistryDispatchTests {
    @TestCase
    func leafBlockDispatchBucketsByFirstNonSpaceByteAndPriority() {
        let table = BlockDispatchTable()
        table.register(TestLeafParser("low-bang", 90, [b'!'], false))
        table.register(TestLeafParser("high-bang", 10, [b'!'], false))
        table.register(TestLeafParser("fallback", 5, [], true))

        let bang = table.candidatesFor("  !note")
        @Expect(bang.size, 3)
        @Expect(bang[0].name, "high-bang")
        @Expect(bang[1].name, "low-bang")
        @Expect(bang[2].name, "fallback")

        let word = table.candidatesFor("plain text")
        @Expect(word.size, 1)
        @Expect(word[0].name, "fallback")

        @Expect(table.candidatesFor(" \t ").size, 0)
    }

    @TestCase
    func continuationDispatchBucketsByFirstNonSpaceByteAndPriority() {
        let table = ContinuationBlockDispatchTable()
        table.register(TestContinuationParser("low-dollar", 90, [b'$']))
        table.register(TestContinuationParser("high-dollar", 10, [b'$']))
        table.register(TestContinuationParser("quote", 50, [b'>']))

        let dollar = table.candidatesFor("  $$")
        @Expect(dollar.size, 2)
        @Expect(dollar[0].name, "high-dollar")
        @Expect(dollar[1].name, "low-dollar")

        let quoteCandidates = table.candidatesFor("\t> quoted")
        @Expect(quoteCandidates.size, 1)
        @Expect(quoteCandidates[0].name, "quote")

        @Expect(table.candidatesFor("plain").size, 0)
    }

    @TestCase
    func inlineDispatchBucketsByStartByteAndPriority() {
        let table = InlineDispatchTable()
        table.register(TestInlineParser("low-star", 90, [b'*', b'_']))
        table.register(TestInlineParser("high-star", 10, [b'*']))
        table.register(TestInlineParser("bang", 30, [b'!']))

        let star = table.candidatesFor(b'*')
        @Expect(star.size, 2)
        @Expect(star[0].name, "high-star")
        @Expect(star[1].name, "low-star")

        let underscore = table.candidatesFor(b'_')
        @Expect(underscore.size, 1)
        @Expect(underscore[0].name, "low-star")

        let bang = table.candidatesFor(b'!')
        @Expect(bang.size, 1)
        @Expect(bang[0].name, "bang")

        @Expect(table.candidatesFor(b'x').size, 0)
    }

    @TestCase
    func pluginRegistryFreezesAfterCreatingRuntimeTables() {
        let registry = PluginRegistry()
        registry.register(RegistryDispatchPlugin())

        let inline = registry.createInlineDispatchTable()
        @Expect(inline.candidatesFor(b'*')[0].name, "plugin-inline")

        var threw = false
        try {
            registry.register(EmptyPlugin())
        } catch (e: IllegalArgumentException) {
            threw = true
        }
        @Expect(threw, true)
    }
}

private class TestLeafParser <: LeafBlockParser {
    private let parserName: String
    private let priorityValue: Int64
    private let startByteValues: Array<Byte>
    private let anyNonBlank: Bool

    public init(parserName: String, priorityValue: Int64, startByteValues: Array<Byte>, anyNonBlank: Bool) {
        this.parserName = parserName
        this.priorityValue = priorityValue
        this.startByteValues = startByteValues
        this.anyNonBlank = anyNonBlank
    }

    public prop name: String {
        get() { return parserName }
    }

    public prop ownerPlugin: String {
        get() { return "RegistryDispatchTests" }
    }

    public prop priority: Int64 {
        get() { return priorityValue }
    }

    public prop startBytes: Array<Byte> {
        get() { return startByteValues }
    }

    public prop acceptsAnyNonBlank: Bool {
        get() { return anyNonBlank }
    }

    public func tryParse(_: ParseSession, _: String): ?Node {
        return None
    }
}

private class TestContinuationState <: BlockState {}

private class TestContinuationParser <: ContinuationBlockParser {
    private let parserName: String
    private let priorityValue: Int64
    private let startByteValues: Array<Byte>

    public init(parserName: String, priorityValue: Int64, startByteValues: Array<Byte>) {
        this.parserName = parserName
        this.priorityValue = priorityValue
        this.startByteValues = startByteValues
    }

    public prop name: String {
        get() { return parserName }
    }

    public prop ownerPlugin: String {
        get() { return "RegistryDispatchTests" }
    }

    public prop priority: Int64 {
        get() { return priorityValue }
    }

    public prop startBytes: Array<Byte> {
        get() { return startByteValues }
    }

    public func tryStart(_: ParseSession, _: String): ?BlockFrame {
        return Some(BlockFrame(TestContinuationState()))
    }

    public func continueBlock(_: ParseSession, _: BlockFrame, _: String): ContinueResult {
        return Open
    }

    public func finalize(_: ParseSession, _: BlockFrame): Node {
        return TextNode(0, SourceSpan.empty(), parserName)
    }
}

private class TestInlineParser <: InlineParser {
    private let parserName: String
    private let priorityValue: Int64
    private let startByteValues: Array<Byte>

    public init(parserName: String, priorityValue: Int64, startByteValues: Array<Byte>) {
        this.parserName = parserName
        this.priorityValue = priorityValue
        this.startByteValues = startByteValues
    }

    public prop name: String {
        get() { return parserName }
    }

    public prop ownerPlugin: String {
        get() { return "RegistryDispatchTests" }
    }

    public prop priority: Int64 {
        get() { return priorityValue }
    }

    public prop startBytes: Array<Byte> {
        get() { return startByteValues }
    }

    public func tryParse(_: ParseSession, _: String, _: Int64, _: Int64, _: SourceSpan): ?InlineParseResult {
        return None
    }
}

private class RegistryDispatchPlugin <: Plugin {
    public prop name: String {
        get() { return "RegistryDispatchPlugin" }
    }

    public prop version: String {
        get() { return "1.0.0" }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerLeafBlockParser(TestLeafParser("plugin-leaf", 20, [b'#'], false))
        registrar.registerContinuationBlockParser(TestContinuationParser("plugin-continuation", 20, [b'~']))
        registrar.registerInlineParser(TestInlineParser("plugin-inline", 20, [b'*']))
    }
}

private class EmptyPlugin <: Plugin {
    public prop name: String {
        get() { return "EmptyPlugin" }
    }

    public prop version: String {
        get() { return "1.0.0" }
    }

    public func register(_: PluginRegistrar): Unit {}
}
