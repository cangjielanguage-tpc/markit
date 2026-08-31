package mermaid4cj.tests

import std.unittest.*
import std.unittest.testmacro.*
import mermaid4cj.MermaidRenderer

@Test
@Tag[Mermaid4cj]
class MermaidPerformanceSmokeTests {
    @TestCase
    func repeatedSmallBlocksStayDeterministic() {
        let renderer = MermaidRenderer()
        let source = "graph TD; A[开始]-->B[结束]"
        let first = renderer.renderSvg(source).svg
        for (_ in 0..100) {
            @Expect(renderer.renderSvg(source).svg, first)
        }
    }
}
