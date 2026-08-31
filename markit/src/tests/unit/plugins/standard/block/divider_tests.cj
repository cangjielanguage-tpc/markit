package markit.tests.unit.plugins.standard.block

import std.unittest.*
import std.unittest.testmacro.*
import markit.Markit
import markit.plugins.standard.block.divider.DividerNode
import markit.tests.utils.AstTestKit
import markit.tests.utils.ParseModeTestKit

@Test
class DividerTests {
    @TestCase
    func rendersDifferentDividerMarkers() {
        ParseModeTestKit.assertAcrossModes(
            { => Markit() },
            "---\n",
            { result =>
                @Expect(result.html, "<hr />")
                let divider = AstTestKit.child(result.root, 0, "DividerNode")
                if (let node: DividerNode <- divider) {
                    @Expect(node.marker, b'-')
                    @Expect(node.markerCount, 3)
                    @Expect(node.isHyphenLine(), true)
                    AstTestKit.expectSpan(node, 0, 3, 0, 3)
                }
            }
        )
        ParseModeTestKit.assertAcrossModes(
            { => Markit() },
            "***\n",
            { result =>
                @Expect(result.html, "<hr />")
                let divider = AstTestKit.child(result.root, 0, "DividerNode")
                if (let node: DividerNode <- divider) {
                    @Expect(node.marker, b'*')
                    @Expect(node.markerCount, 3)
                    @Expect(node.isHyphenLine(), false)
                }
            }
        )
        ParseModeTestKit.assertAcrossModes(
            { => Markit() },
            "___\n",
            { result =>
                @Expect(result.html, "<hr />")
                let divider = AstTestKit.child(result.root, 0, "DividerNode")
                if (let node: DividerNode <- divider) {
                    @Expect(node.marker, b'_')
                    @Expect(node.markerCount, 3)
                    @Expect(node.isHyphenLine(), false)
                }
            }
        )
    }

    @TestCase
    func dividerAllowsLeadingTrailingWhitespaceAndTabs() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "  * * *  \n",
            "<hr />"
        )
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "\t---\t\n",
            "<hr />"
        )
    }

    @TestCase
    func longerDividerMarkersStillRenderHr() {
        ParseModeTestKit.assertAcrossModes(
            { => Markit() },
            "----------\n",
            { result =>
                @Expect(result.html, "<hr />")
                let divider = AstTestKit.child(result.root, 0, "DividerNode")
                if (let node: DividerNode <- divider) {
                    @Expect(node.marker, b'-')
                    @Expect(node.markerCount, 10)
                    @Expect(node.isHyphenLine(), true)
                }
            }
        )
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "_____ \n",
            "<hr />"
        )
    }

    @TestCase
    func shortMarkerFallsBackToParagraph() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "--\n",
            "<p>--</p>"
        )
    }

    @TestCase
    func nonDividerContentWithMarkerFallsBackToParagraph() {
        ParseModeTestKit.assertHtmlAcrossModes(
            { => Markit() },
            "--- not a divider\n",
            "<p>--- not a divider</p>"
        )
    }
}
