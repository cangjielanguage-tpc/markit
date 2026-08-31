package markit.tests.unit

import std.io.ByteBuffer
import std.unittest.*
import std.unittest.testmacro.*
import markit.{Markit, ParseCallbacks}
import markit.core.incremental.IncrementalUpdate
import markit.core.plugin.{Plugin, PluginRegistrar}
import markit.core.session.{SessionState, SessionStateKey, SessionStateSnapshot}

class TestState <: SessionState {
    public func reset(): Unit {}

    public func snapshot(): SessionStateSnapshot {
        return SessionStateSnapshot("TestPlugin.state")
    }
}

class TestPlugin <: Plugin {
    public let key = SessionStateKey<TestState>("TestPlugin", "state")

    public prop name: String {
        get() {
            return "TestPlugin"
        }
    }

    public prop version: String {
        get() {
            return "1.0.0"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerState(key, { => TestState() })
    }
}

class CallbackProbe {
    public var updateCount: Int64 = 0
    public var finalized: Bool = false
}

@Test
class ApiTests {
    @TestCase
    func parseStringReturnsParseOutput() {
        let out = Markit().parse("# title")
        @Expect(out.finalUpdate.isFinal, true)
        @Expect(out.finalUpdate.bytesCommitted, 7)
        @Expect(out.root().kind, "Document")
        @Expect(out.html(), "<h1 id=\"title\">title</h1>")
    }

    @TestCase
    func renderHtmlMatchesParseOutputHtml() {
        let markdown = "# title\n\nThis is **strong** and `code`."
        let parser = Markit()
        @Expect(parser.renderHtml(markdown), parser.parse(markdown).html())
    }

    @TestCase
    func callbacksReceiveUpdatesAndFinalize() {
        let probe = CallbackProbe()
        let callbacks = ParseCallbacks(
            onUpdate: { _: IncrementalUpdate =>
                probe.updateCount += 1
            },
            onFinalize: { _ =>
                probe.finalized = true
            }
        )

        Markit().parseWithCallbacks("abc", callbacks)

        @Expect(probe.updateCount, 2)
        @Expect(probe.finalized, true)
    }

    @TestCase
    func inputStreamFeedsBytes() {
        let input = ByteBuffer([b'a', b'b', b'c'])
        let out = Markit().parse(input)
        @Expect(out.finalUpdate.bytesCommitted, 3)
    }

    @TestCase
    func feedBytesAcceptsChineseSplitAtEveryByte() {
        let session = Markit().createSession()
        var update = IncrementalUpdate()

        for (byte in "# 中文标题\n") {
            update = session.feedBytes([byte])
        }

        @Expect(update.sealedBlocks.size, 1)
        @Expect(update.emittedHtmlFragments[0].html, "<h1 id=\"中文标题\">中文标题</h1>")
        @Expect(update.sealedBlocks[0].sourceSpan.startByte, 0)
        @Expect(update.sealedBlocks[0].sourceSpan.endByte, 14)
        @Expect(update.sealedBlocks[0].sourceSpan.startRune, 0)
        @Expect(update.sealedBlocks[0].sourceSpan.endRune, 6)
    }

    @TestCase
    func feedBytesBuffersIncompleteChineseRune() {
        let session = Markit().createSession()
        let bytes = "中\n\n".toArray()

        let first = session.feedBytes(bytes[0..1])
        let second = session.feedBytes(bytes[1..2])
        let third = session.feedBytes(bytes[2..])

        @Expect(first.sealedBlocks.size, 0)
        @Expect(second.sealedBlocks.size, 0)
        @Expect(third.sealedBlocks.size, 1)
        @Expect(third.emittedHtmlFragments[0].html, "<p>中</p>")
    }

    @TestCase
    func chineseCrLfLineSpansUseBytesAndRunesSeparately() {
        let update = Markit().createSession().feed("# 中文\r\n# 第二行\r\n")

        @Expect(update.sealedBlocks.size, 2)
        @Expect(update.sealedBlocks[0].sourceSpan.startByte, 0)
        @Expect(update.sealedBlocks[0].sourceSpan.endByte, 8)
        @Expect(update.sealedBlocks[0].sourceSpan.startRune, 0)
        @Expect(update.sealedBlocks[0].sourceSpan.endRune, 4)
        @Expect(update.sealedBlocks[1].sourceSpan.startByte, 10)
        @Expect(update.sealedBlocks[1].sourceSpan.endByte, 21)
        @Expect(update.sealedBlocks[1].sourceSpan.startRune, 5)
        @Expect(update.sealedBlocks[1].sourceSpan.endRune, 10)
    }

    @TestCase
    func chineseParagraphSpanCoversParagraphLines() {
        let session = Markit().createSession()
        var update = IncrementalUpdate()

        for (byte in "中文\n段落\n\n") {
            update = session.feedBytes([byte])
        }

        @Expect(update.sealedBlocks.size, 1)
        @Expect(update.emittedHtmlFragments[0].html, "<p>中文\n段落</p>")
        @Expect(update.sealedBlocks[0].sourceSpan.startByte, 0)
        @Expect(update.sealedBlocks[0].sourceSpan.endByte, 13)
        @Expect(update.sealedBlocks[0].sourceSpan.startRune, 0)
        @Expect(update.sealedBlocks[0].sourceSpan.endRune, 5)
    }

    @TestCase
    func symbolTablesSupportTypedAndDynamicLookup() {
        let plugin = TestPlugin()
        let out = Markit.empty().use(plugin).parse("")
        let typed = out.symbolTables().get(plugin.key)
        let dynamic = out.symbolTables()["TestPlugin.state"]

        @Expect(typed.snapshot().dynamicName, "TestPlugin.state")
        @Expect(dynamic.isSome(), true)
    }

    @TestCase
    func streamingHeadingSealsAfterNewline() {
        let session = Markit().createSession()
        let first = session.feed("# title")
        let second = session.feed("\n")

        @Expect(first.sealedBlocks.size, 0)
        @Expect(second.sealedBlocks.size, 1)
        @Expect(second.emittedHtmlFragments[0].html, "<h1 id=\"title\">title</h1>")
    }

    @TestCase
    func paragraphSealsOnBlankLine() {
        let session = Markit().createSession()
        let update = session.feed("hello\nworld\n\n")

        @Expect(update.sealedBlocks.size, 1)
        @Expect(update.emittedHtmlFragments[0].html, "<p>hello\nworld</p>")
    }

    @TestCase
    func headingTerminatesOpenParagraph() {
        let session = Markit().createSession()
        let update = session.feed("hello\n# title\n")

        @Expect(update.sealedBlocks.size, 2)
        @Expect(update.emittedHtmlFragments[0].html, "<p>hello</p>")
        @Expect(update.emittedHtmlFragments[1].html, "<h1 id=\"title\">title</h1>")
    }

    @TestCase
    func finalizeSealsPendingParagraph() {
        let session = Markit().createSession()
        session.feed("hello")
        let update = session.finalize()

        @Expect(update.sealedBlocks.size, 1)
        @Expect(update.emittedHtmlFragments[0].html, "<p>hello</p>")
    }

    @TestCase
    func headingSlugIsSessionUnique() {
        let out = Markit().parse("# Title\n# Title\n")

        @Expect(out.html(), "<h1 id=\"title\">Title</h1><h1 id=\"title-2\">Title</h1>")
    }

    @TestCase
    func dividerIsRegisteredBlockPlugin() {
        let out = Markit().parse("---\n")

        @Expect(out.html(), "<hr />")
    }

    @TestCase
    func dividerTerminatesOpenParagraph() {
        let out = Markit().parse("hello\n---\n")

        @Expect(out.html(), "<p>hello</p><hr />")
    }

    @TestCase
    func unorderedListRendersChineseItems() {
        let out = Markit().parse("- 中文\n- 第二项\n")

        @Expect(out.html(), "<ul><li>中文</li><li>第二项</li></ul>")
    }

    @TestCase
    func orderedListKeepsChineseAndStartNumber() {
        let out = Markit().parse("3. 第三项\n4. 第四项\n")

        @Expect(out.html(), "<ol start=\"3\"><li>第三项</li><li>第四项</li></ol>")
    }

    @TestCase
    func listCloseReprocessesFollowingHeading() {
        let out = Markit().parse("- 项目\n# 标题\n")

        @Expect(out.html(), "<ul><li>项目</li></ul><h1 id=\"标题\">标题</h1>")
    }

    @TestCase
    func chineseListSpanUsesByteOffsets() {
        let update = Markit().createSession().feed("- 中文\n- 第二项\n")

        @Expect(update.sealedBlocks.size, 0)
        let finalUpdate = Markit().parse("- 中文\n- 第二项\n").finalUpdate
        @Expect(finalUpdate.sealedBlocks[0].sourceSpan.startByte, 0)
        @Expect(finalUpdate.sealedBlocks[0].sourceSpan.endByte, 20)
    }

    @TestCase
    func fencedCodeSealsOnClosingFence() {
        let session = Markit().createSession()
        let first = session.feed("```cj\nlet x = 1")
        let second = session.feed("\n```\n")

        @Expect(first.sealedBlocks.size, 0)
        @Expect(second.sealedBlocks.size, 1)
        @Expect(second.emittedHtmlFragments[0].html, Markit().parse("```cj\nlet x = 1\n```\n").toHtml())
    }

    @TestCase
    func fencedCodeProtectsMarkdownMarkers() {
        let out = Markit().parse("```\n# not heading\n---\n```\n")

        @Expect(out.html(), "<pre><code># not heading\n---</code></pre>")
    }

    @TestCase
    func finalizeSealsUnclosedFencedCode() {
        let session = Markit().createSession()
        session.feed("```\nopen")
        let update = session.finalize()

        @Expect(update.sealedBlocks.size, 1)
        @Expect(update.emittedHtmlFragments[0].html, "<pre><code>open</code></pre>")
    }
}
