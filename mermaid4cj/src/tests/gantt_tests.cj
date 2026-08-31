package mermaid4cj.tests

import std.fs.{Path, exists, remove}
import std.unittest.*
import std.unittest.testmacro.*
import mermaid4cj.{MermaidHtmlOptions, MermaidRenderOptions, MermaidRenderer}

@Test
@Tag[Mermaid4cj]
class MermaidGanttTests {
    @TestCase
    func migratesUpstreamDocsCoreTaskMetadata() {
        let parsed = MermaidRenderer().parseGantt("""
gantt
dateFormat YYYY-MM-DD
title Adding GANTT diagram functionality to mermaid
excludes weekends
section A section
Completed task            :done,    des1, 2014-01-06,2014-01-08
Active task               :active,  des2, 2014-01-09, 3d
Future task               :         des3, after des2, 5d
Future task2              :         des4, after des3, 5d
section Critical tasks
Completed task in critical line :crit, done, 2014-01-06,24h
Functionality added             :milestone, isadded, 2014-01-25, 0d
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        @Expect(parsed.diagram.title.getOrThrow(), "Adding GANTT diagram functionality to mermaid")
        @Expect(parsed.diagram.dateFormat, "YYYY-MM-DD")
        @Expect(parsed.diagram.excludes[0], "weekends")
        @Expect(parsed.diagram.sections.size, 2)
        @Expect(parsed.diagram.tasks.size, 6)
        @Expect(parsed.diagram.tasks[0].id, "des1")
        @Expect(parsed.diagram.tasks[0].label, "Completed task")
        @Expect(parsed.diagram.tasks[0].done, true)
        @Expect(parsed.diagram.tasks[1].active, true)
        @Expect(parsed.diagram.tasks[2].start, parsed.diagram.tasks[1].end)
        @Expect(parsed.diagram.tasks[3].start, parsed.diagram.tasks[2].end)
        @Expect(parsed.diagram.tasks[4].crit, true)
        @Expect(parsed.diagram.tasks[4].done, true)
        @Expect(parsed.diagram.tasks[5].milestone, true)
    }

    @TestCase
    func migratesUpstreamAfterAndUntilTaskReferences() {
        let parsed = MermaidRenderer().parseGantt("""
gantt
dateFormat YYYY-MM-DD
section Documentation
task A: a, 2024-01-27, 2024-01-28
task B: b, after a, 2024-01-30
task C: c, 2024-01-20, until a
task D: d, after c, until b
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        let tasks = parsed.diagram.tasks
        @Expect(tasks.size, 4)
        @Expect(tasks[1].start, tasks[0].end)
        @Expect(tasks[2].end, tasks[0].start)
        @Expect(tasks[3].start, tasks[2].end)
        @Expect(tasks[3].end, tasks[1].start)
    }

    @TestCase
    func migratesUpstreamMultipleAfterAndUntilReferences() {
        let parsed = MermaidRenderer().parseGantt("""
gantt
dateFormat YYYY-MM-DD
section sec1
task1 : id1, after id2 id3 id4, 1d
task2 : id2, 2013-01-01, 1d
task3 : id3, 2013-02-01, 3d
task4 : id4, 2013-02-01, 2d
task5 : id5, 2013-01-01, until id2 id3 id4
""")
        @Expect(parsed.diagnostics.isEmpty(), true)
        let tasks = parsed.diagram.tasks
        @Expect(tasks[0].start, 0)
        @Expect(tasks[4].end, tasks[1].start)
    }

    @TestCase
    func rendersGanttWithDedicatedSvgStructureAndPrefix() {
        let result = MermaidRenderer().renderSvg("""
gantt
title Release Plan
dateFormat YYYY-MM-DD
todayMarker stroke-width:5px,stroke:#0f0,opacity:0.5
section Build
Design      :done, des1, 2026-01-01, 2026-01-03
Implement   :active, impl1, after des1, 3d
Ship        :crit, milestone, ship1, after impl1, 0d
""", options: MermaidRenderOptions(idPrefix: "g1", classPrefix: "mk"))
        @Expect(result.supported, true)
        @Expect(result.svg.contains("id=\"g1\""), true)
        @Expect(result.svg.contains("class=\"mk-gantt mermaid4cj-gantt\""), true)
        @Expect(result.svg.contains("gantt-grid"), true)
        @Expect(result.svg.contains("gantt-today"), true)
        @Expect(result.svg.contains("data-id=\"impl1\""), true)
        @Expect(result.svg.contains("gantt-task-active"), true)
        @Expect(result.svg.contains("gantt-task-milestone"), true)
    }

    @TestCase
    func markitHtmlAndSvgFileSupportGantt() {
        let source = "gantt\ntitle Plan\nsection A\nTask : t1, 2026-01-01, 1d"
        let html = MermaidRenderer().renderMarkitHtml(source, options: MermaidHtmlOptions(classPrefix: "mk-mermaid", idPrefix: "gt"))
        @Expect(html.supported, true)
        @Expect(html.html.contains("data-mermaid4cj-theme=\"dual\""), true)
        @Expect(html.html.contains("gt-light"), true)
        @Expect(html.html.contains("gt-dark"), true)

        let path = Path("build/mermaid4cj-gantt-test.svg")
        let result = MermaidRenderer().renderSvgFile(source, path, options: MermaidRenderOptions(idPrefix: "gantt-file"))
        @Expect(result.supported, true)
        @Expect(exists(path), true)
        remove(path)
    }
}
