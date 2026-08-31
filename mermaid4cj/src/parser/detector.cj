package mermaid4cj.parser

import mermaid4cj.core.DiagramKind

public class DiagramDetector {
    public static func detect(source: String): DiagramKind {
        for (line in source.lines()) {
            let trimmed = line.trimAscii()
            if (trimmed.isEmpty() || trimmed.startsWith("%%")) {
                continue
            }
            let lower = trimmed.toAsciiLower()
            if (lower.startsWith("graph ") || lower == "graph" ||
                lower.startsWith("flowchart ") || lower == "flowchart" ||
                lower.startsWith("flowchart-v2 ") || lower == "flowchart-v2" ||
                lower.startsWith("flowchart-elk ") || lower == "flowchart-elk") {
                return DiagramKind.Flowchart
            }
            if (lower.startsWith("sequencediagram")) {
                return DiagramKind.Sequence
            }
            if (lower.startsWith("mindmap")) {
                return DiagramKind.Mindmap
            }
            if (lower.startsWith("classdiagram")) {
                return DiagramKind.Class
            }
            if (lower.startsWith("statediagram")) {
                return DiagramKind.State
            }
            if (lower.startsWith("erdiagram")) {
                return DiagramKind.Er
            }
            if (lower.startsWith("pie")) {
                return DiagramKind.Pie
            }
            if (lower.startsWith("gantt")) {
                return DiagramKind.Gantt
            }
            return DiagramKind.Unsupported
        }
        return DiagramKind.Unsupported
    }
}
