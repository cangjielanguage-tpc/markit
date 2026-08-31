package mermaid4cj

import std.fs.{Directory, File, Path, exists}
import std.io.OutputStream
import mermaid4cj.core.{
    DiagramKind,
    MermaidHtmlOptions,
    MermaidHtmlRenderResult,
    MermaidHtmlThemeMode,
    MermaidRenderOptions,
    MermaidRenderResult,
    MermaidTheme,
    ClassParseResult,
    ErParseResult,
    FlowParseResult,
    FlowchartDiagram,
    GanttDiagram,
    GanttParseResult,
    GenericParseResult,
    MindmapParseResult,
    PieParseResult,
    StateParseResult,
    SequenceParseResult
}
import mermaid4cj.parser.{ClassDiagramParser, DiagramDetector, ErDiagramParser, FlowchartParser, GanttParser, GenericDiagramParser, MindmapParser, PieParser, SequenceParser, StateDiagramParser}
import mermaid4cj.layout.{FlowchartLayout, FlowchartLayoutResult, MindmapLayout}
import mermaid4cj.svg.{ClassSvgWriter, ErSvgWriter, ErrorSvgWriter, FlowchartSvgWriter, GanttSvgWriter, GenericSvgWriter, MindmapSvgWriter, PieSvgWriter, SequenceSvgWriter, StateSvgWriter, SvgEscaper}

public class MermaidRenderer {
    public init() {}

    public func detectDiagramKind(source: String): DiagramKind {
        return DiagramDetector.detect(source)
    }

    public func supportsDiagramKind(kind: DiagramKind): Bool {
        match (kind) {
            case DiagramKind.Flowchart => return true
            case DiagramKind.Sequence => return true
            case DiagramKind.Mindmap => return true
            case DiagramKind.Class => return true
            case DiagramKind.State => return true
            case DiagramKind.Er => return true
            case DiagramKind.Pie => return true
            case DiagramKind.Gantt => return true
            case _ => return false
        }
    }

    public func renderSvg(source: String, options!: MermaidRenderOptions = MermaidRenderOptions()): MermaidRenderResult {
        let kind = detectDiagramKind(source)
        if (!supportsDiagramKind(kind)) {
            return MermaidRenderResult(
                ErrorSvgWriter().write("Unsupported Mermaid diagram", "This Mermaid diagram kind is not currently supported by mermaid4cj.", options),
                kind: kind,
                diagnostics: ["Unsupported Mermaid diagram kind"],
                supported: false
            )
        }

        match (kind) {
            case DiagramKind.Sequence =>
                return renderSequenceSvg(parseSequence(source), options: options)
            case DiagramKind.Gantt =>
                return renderGanttSvg(parseGantt(source), options: options)
            case DiagramKind.Class =>
                return renderClassSvg(parseClassDiagram(source), options: options)
            case DiagramKind.Er =>
                return renderErSvg(parseErDiagram(source), options: options)
            case DiagramKind.Mindmap =>
                return renderMindmapSvg(parseMindmap(source), options: options)
            case DiagramKind.Pie =>
                return renderPieSvg(parsePie(source), options: options)
            case DiagramKind.State =>
                return renderStateSvg(parseStateDiagram(source), options: options)
            case _ =>
                let parsed = parseFlowchart(source)
                return renderFlowchartSvg(parsed, options: options)
        }
    }

    public func parseFlowchart(source: String): FlowParseResult {
        return FlowchartParser().parse(source)
    }

    public func parseSequence(source: String): SequenceParseResult {
        return SequenceParser().parse(source)
    }

    public func parseGantt(source: String): GanttParseResult {
        return GanttParser().parse(source)
    }

    public func parseClassDiagram(source: String): ClassParseResult {
        return ClassDiagramParser().parse(source)
    }

    public func parseErDiagram(source: String): ErParseResult {
        return ErDiagramParser().parse(source)
    }

    public func parseMindmap(source: String): MindmapParseResult {
        return MindmapParser().parse(source)
    }

    public func parsePie(source: String): PieParseResult {
        return PieParser().parse(source)
    }

    public func parseStateDiagram(source: String): StateParseResult {
        return StateDiagramParser().parse(source)
    }

    public func parseGeneric(source: String, kind: DiagramKind): GenericParseResult {
        return GenericDiagramParser().parse(source, kind)
    }

    public func renderFlowchartSvg(parsed: FlowParseResult, options!: MermaidRenderOptions = MermaidRenderOptions()): MermaidRenderResult {
        if (!parsed.diagnostics.isEmpty()) {
            return MermaidRenderResult(
                ErrorSvgWriter().write("Mermaid parse error", parsed.diagnostics[0], options),
                kind: DiagramKind.Flowchart,
                diagnostics: parsed.diagnostics,
                supported: false
            )
        }

        let layout = FlowchartLayout(textMeasurer: options.textMeasurer).layout(parsed.diagram)
        return renderFlowchartSvgWithLayout(parsed.diagram, layout, options)
    }

    private func renderFlowchartSvgWithLayout(diagram: FlowchartDiagram, layout: FlowchartLayoutResult, options: MermaidRenderOptions): MermaidRenderResult {
        return MermaidRenderResult(
            FlowchartSvgWriter(textMeasurer: options.textMeasurer).write(diagram, layout, options),
            kind: DiagramKind.Flowchart,
            diagnostics: [],
            supported: true
        )
    }

    public func renderSequenceSvg(parsed: SequenceParseResult, options!: MermaidRenderOptions = MermaidRenderOptions()): MermaidRenderResult {
        if (!parsed.diagnostics.isEmpty()) {
            return MermaidRenderResult(
                ErrorSvgWriter().write("Mermaid parse error", parsed.diagnostics[0], options),
                kind: DiagramKind.Sequence,
                diagnostics: parsed.diagnostics,
                supported: false
            )
        }
        return MermaidRenderResult(
            SequenceSvgWriter().write(parsed.diagram, options),
            kind: DiagramKind.Sequence,
            diagnostics: [],
            supported: true
        )
    }

    public func renderGanttSvg(parsed: GanttParseResult, options!: MermaidRenderOptions = MermaidRenderOptions()): MermaidRenderResult {
        if (!parsed.diagnostics.isEmpty()) {
            return MermaidRenderResult(
                ErrorSvgWriter().write("Mermaid parse error", parsed.diagnostics[0], options),
                kind: DiagramKind.Gantt,
                diagnostics: parsed.diagnostics,
                supported: false
            )
        }
        return MermaidRenderResult(
            GanttSvgWriter().write(parsed.diagram, options),
            kind: DiagramKind.Gantt,
            diagnostics: [],
            supported: true
        )
    }

    public func renderClassSvg(parsed: ClassParseResult, options!: MermaidRenderOptions = MermaidRenderOptions()): MermaidRenderResult {
        if (!parsed.diagnostics.isEmpty()) {
            return MermaidRenderResult(
                ErrorSvgWriter().write("Mermaid parse error", parsed.diagnostics[0], options),
                kind: DiagramKind.Class,
                diagnostics: parsed.diagnostics,
                supported: false
            )
        }
        return MermaidRenderResult(
            ClassSvgWriter().write(parsed.diagram, options),
            kind: DiagramKind.Class,
            diagnostics: [],
            supported: true
        )
    }

    public func renderErSvg(parsed: ErParseResult, options!: MermaidRenderOptions = MermaidRenderOptions()): MermaidRenderResult {
        if (!parsed.diagnostics.isEmpty()) {
            return MermaidRenderResult(
                ErrorSvgWriter().write("Mermaid parse error", parsed.diagnostics[0], options),
                kind: DiagramKind.Er,
                diagnostics: parsed.diagnostics,
                supported: false
            )
        }
        return MermaidRenderResult(
            ErSvgWriter().write(parsed.diagram, options),
            kind: DiagramKind.Er,
            diagnostics: [],
            supported: true
        )
    }

    public func renderMindmapSvg(parsed: MindmapParseResult, options!: MermaidRenderOptions = MermaidRenderOptions()): MermaidRenderResult {
        if (!parsed.diagnostics.isEmpty()) {
            return MermaidRenderResult(ErrorSvgWriter().write("Mermaid parse error", parsed.diagnostics[0], options), kind: DiagramKind.Mindmap, diagnostics: parsed.diagnostics, supported: false)
        }
        let layout = MindmapLayout().layout(parsed.diagram, options)
        return MermaidRenderResult(MindmapSvgWriter().write(parsed.diagram, layout, options), kind: DiagramKind.Mindmap, diagnostics: [], supported: true)
    }

    public func renderPieSvg(parsed: PieParseResult, options!: MermaidRenderOptions = MermaidRenderOptions()): MermaidRenderResult {
        if (!parsed.diagnostics.isEmpty()) {
            return MermaidRenderResult(ErrorSvgWriter().write("Mermaid parse error", parsed.diagnostics[0], options), kind: DiagramKind.Pie, diagnostics: parsed.diagnostics, supported: false)
        }
        return MermaidRenderResult(PieSvgWriter().write(parsed.diagram, options), kind: DiagramKind.Pie, diagnostics: [], supported: true)
    }

    public func renderStateSvg(parsed: StateParseResult, options!: MermaidRenderOptions = MermaidRenderOptions()): MermaidRenderResult {
        if (!parsed.diagnostics.isEmpty()) {
            return MermaidRenderResult(ErrorSvgWriter().write("Mermaid parse error", parsed.diagnostics[0], options), kind: DiagramKind.State, diagnostics: parsed.diagnostics, supported: false)
        }
        return MermaidRenderResult(StateSvgWriter().write(parsed.diagram, options), kind: DiagramKind.State, diagnostics: [], supported: true)
    }

    public func renderGenericSvg(parsed: GenericParseResult, options!: MermaidRenderOptions = MermaidRenderOptions()): MermaidRenderResult {
        if (!parsed.diagnostics.isEmpty()) {
            return MermaidRenderResult(
                ErrorSvgWriter().write("Mermaid parse error", parsed.diagnostics[0], options),
                kind: parsed.diagram.kind,
                diagnostics: parsed.diagnostics,
                supported: false
            )
        }
        return MermaidRenderResult(
            GenericSvgWriter().write(parsed.diagram, options),
            kind: parsed.diagram.kind,
            diagnostics: [],
            supported: true
        )
    }

    public func renderSvgWithTheme(source: String, theme: String, options!: MermaidRenderOptions = MermaidRenderOptions()): MermaidRenderResult {
        return renderSvg(
            source,
            options: MermaidRenderOptions(
                theme: normalizeThemeName(theme),
                classPrefix: options.classPrefix,
                idPrefix: options.idPrefix,
                title: options.title,
                errorSvg: options.errorSvg,
                textMeasurer: options.textMeasurer
            )
        )
    }

    public func renderSvgToStream(source: String, out: OutputStream, options!: MermaidRenderOptions = MermaidRenderOptions()): MermaidRenderResult {
        let result = renderSvg(source, options: options)
        out.write(result.svg.toArray())
        out.flush()
        return result
    }

    public func renderSvgFile(source: String, outputPath: Path, options!: MermaidRenderOptions = MermaidRenderOptions()): MermaidRenderResult {
        let result = renderSvg(source, options: options)
        let parent = outputPath.parent
        if (!parent.isEmpty() && !exists(parent)) {
            Directory.create(parent, recursive: true)
        }
        File.writeTo(outputPath, result.svg.toArray())
        return result
    }

    public func renderSvgFileWithTheme(source: String, outputPath: Path, theme: String, options!: MermaidRenderOptions = MermaidRenderOptions()): MermaidRenderResult {
        return renderSvgFile(
            source,
            outputPath,
            options: MermaidRenderOptions(
                theme: normalizeThemeName(theme),
                classPrefix: options.classPrefix,
                idPrefix: options.idPrefix,
                title: options.title,
                errorSvg: options.errorSvg,
                textMeasurer: options.textMeasurer
            )
        )
    }

    public func renderMarkitHtml(source: String, options!: MermaidHtmlOptions = MermaidHtmlOptions()): MermaidHtmlRenderResult {
        let kind = detectDiagramKind(source)
        if (!supportsDiagramKind(kind)) {
            let light = MermaidRenderResult(
                ErrorSvgWriter().write("Unsupported Mermaid diagram", "This Mermaid diagram kind is not currently supported by mermaid4cj.", svgOptions(options, MermaidTheme.Default, "light")),
                kind: kind,
                diagnostics: ["Unsupported Mermaid diagram kind"],
                supported: false
            )
            let dark = MermaidRenderResult(
                ErrorSvgWriter().write("Unsupported Mermaid diagram", "This Mermaid diagram kind is not currently supported by mermaid4cj.", svgOptions(options, MermaidTheme.Dark, "dark")),
                kind: kind,
                diagnostics: ["Unsupported Mermaid diagram kind"],
                supported: false
            )
            return MermaidHtmlRenderResult(
                dualThemeHtml(source, light, dark, options),
                light: Some(light),
                dark: Some(dark),
                diagnostics: ["Unsupported Mermaid diagram kind"],
                supported: false
            )
        }
        match (options.themeMode) {
            case MermaidHtmlThemeMode.Light =>
                let light = renderKindSvg(source, kind, svgOptions(options, MermaidTheme.Default, "light"))
                return MermaidHtmlRenderResult(
                    singleThemeHtml(source, light, options, "light"),
                    light: Some(light),
                    diagnostics: light.diagnostics,
                    supported: light.supported
                )
            case MermaidHtmlThemeMode.Dark =>
                let dark = renderKindSvg(source, kind, svgOptions(options, MermaidTheme.Dark, "dark"))
                return MermaidHtmlRenderResult(
                    singleThemeHtml(source, dark, options, "dark"),
                    dark: Some(dark),
                    diagnostics: dark.diagnostics,
                    supported: dark.supported
                )
            case MermaidHtmlThemeMode.Dual =>
                match (kind) {
                    case DiagramKind.Sequence | DiagramKind.Mindmap | DiagramKind.Class | DiagramKind.State | DiagramKind.Er | DiagramKind.Pie | DiagramKind.Gantt =>
                        let light = renderKindSvg(source, kind, svgOptions(options, MermaidTheme.Default, "light"))
                        let dark = renderKindSvg(source, kind, svgOptions(options, MermaidTheme.Dark, "dark"))
                        let diagnostics = mergeDiagnostics(light, dark)
                        return MermaidHtmlRenderResult(
                            dualThemeHtml(source, light, dark, options),
                            light: Some(light),
                            dark: Some(dark),
                            diagnostics: diagnostics,
                            supported: light.supported && dark.supported
                        )
                    case _ => ()
                }
                let parsed = parseFlowchart(source)
                if (!parsed.diagnostics.isEmpty()) {
                    let light = renderFlowchartSvg(parsed, options: svgOptions(options, MermaidTheme.Default, "light"))
                    let dark = renderFlowchartSvg(parsed, options: svgOptions(options, MermaidTheme.Dark, "dark"))
                    let diagnostics = mergeDiagnostics(light, dark)
                    return MermaidHtmlRenderResult(
                        dualThemeHtml(source, light, dark, options),
                        light: Some(light),
                        dark: Some(dark),
                        diagnostics: diagnostics,
                        supported: false
                    )
                }
                let layout = FlowchartLayout(textMeasurer: svgOptions(options, MermaidTheme.Default, "light").textMeasurer).layout(parsed.diagram)
                let light = renderFlowchartSvgWithLayout(parsed.diagram, layout, svgOptions(options, MermaidTheme.Default, "light"))
                let dark = renderFlowchartSvgWithLayout(parsed.diagram, layout, svgOptions(options, MermaidTheme.Dark, "dark"))
                let diagnostics = mergeDiagnostics(light, dark)
                return MermaidHtmlRenderResult(
                    dualThemeHtml(source, light, dark, options),
                    light: Some(light),
                    dark: Some(dark),
                    diagnostics: diagnostics,
                    supported: light.supported && dark.supported
                )
        }
    }

    private func renderKindSvg(source: String, kind: DiagramKind, options: MermaidRenderOptions): MermaidRenderResult {
        match (kind) {
            case DiagramKind.Sequence => return renderSequenceSvg(parseSequence(source), options: options)
            case DiagramKind.Gantt => return renderGanttSvg(parseGantt(source), options: options)
            case DiagramKind.Class => return renderClassSvg(parseClassDiagram(source), options: options)
            case DiagramKind.Er => return renderErSvg(parseErDiagram(source), options: options)
            case DiagramKind.Mindmap => return renderMindmapSvg(parseMindmap(source), options: options)
            case DiagramKind.Pie => return renderPieSvg(parsePie(source), options: options)
            case DiagramKind.State => return renderStateSvg(parseStateDiagram(source), options: options)
            case _ => return renderFlowchartSvg(parseFlowchart(source), options: options)
        }
    }

    public func renderMarkitHtmlToStream(source: String, out: OutputStream, options!: MermaidHtmlOptions = MermaidHtmlOptions()): MermaidHtmlRenderResult {
        let result = renderMarkitHtml(source, options: options)
        out.write(result.html.toArray())
        out.flush()
        return result
    }

    public static func themeFromName(theme: String): MermaidTheme {
        return normalizeThemeName(theme)
    }

    public static func markitThemeCss(classPrefix!: String = "mmd"): String {
        let prefix = SvgEscaper.attribute(classPrefix)
        let out = StringBuilder(512)
        out.append(".")
        out.append(prefix)
        out.append("-diagram.")
        out.append(prefix)
        out.append("-theme-dark{display:none}")
        out.append("html[data-theme=\"dark\"] .")
        out.append(prefix)
        out.append("-diagram.")
        out.append(prefix)
        out.append("-theme-light{display:none}")
        out.append("html[data-theme=\"dark\"] .")
        out.append(prefix)
        out.append("-diagram.")
        out.append(prefix)
        out.append("-theme-dark{display:block}")
        out.append("html[data-theme=\"light\"] .")
        out.append(prefix)
        out.append("-diagram.")
        out.append(prefix)
        out.append("-theme-light{display:block}")
        out.append("html[data-theme=\"light\"] .")
        out.append(prefix)
        out.append("-diagram.")
        out.append(prefix)
        out.append("-theme-dark{display:none}")
        return out.toString()
    }

    private func svgOptions(options: MermaidHtmlOptions, theme: MermaidTheme, suffix: String): MermaidRenderOptions {
        return MermaidRenderOptions(
            theme: theme,
            classPrefix: options.classPrefix,
            idPrefix: "${options.idPrefix}-${suffix}",
            title: options.title,
            textMeasurer: options.textMeasurer
        )
    }

    private func singleThemeHtml(source: String, result: MermaidRenderResult, options: MermaidHtmlOptions, themeName: String): String {
        let out = StringBuilder(result.svg.size + source.size + 256)
        out.append("<div class=\"")
        SvgEscaper.appendAttribute(out, options.classPrefix)
        out.append("-container mermaid4cj-container\" data-mermaid4cj=\"native\" data-mermaid4cj-theme=\"")
        out.append(themeName)
        out.append("\"><div class=\"")
        SvgEscaper.appendAttribute(out, options.classPrefix)
        out.append("-diagram ")
        SvgEscaper.appendAttribute(out, options.classPrefix)
        out.append("-theme-")
        out.append(themeName)
        out.append("\">")
        out.append(result.svg)
        out.append("</div>")
        appendSourceIfRequested(out, source, options)
        out.append("</div>")
        return out.toString()
    }

    private func dualThemeHtml(source: String, light: MermaidRenderResult, dark: MermaidRenderResult, options: MermaidHtmlOptions): String {
        let out = StringBuilder(light.svg.size + dark.svg.size + source.size + 384)
        out.append("<div class=\"")
        SvgEscaper.appendAttribute(out, options.classPrefix)
        out.append("-container mermaid4cj-container\" data-mermaid4cj=\"native\" data-mermaid4cj-theme=\"dual\"><div class=\"")
        SvgEscaper.appendAttribute(out, options.classPrefix)
        out.append("-diagram ")
        SvgEscaper.appendAttribute(out, options.classPrefix)
        out.append("-theme-light\">")
        out.append(light.svg)
        out.append("</div><div class=\"")
        SvgEscaper.appendAttribute(out, options.classPrefix)
        out.append("-diagram ")
        SvgEscaper.appendAttribute(out, options.classPrefix)
        out.append("-theme-dark\">")
        out.append(dark.svg)
        out.append("</div>")
        appendSourceIfRequested(out, source, options)
        out.append("</div>")
        return out.toString()
    }

    private func appendSourceIfRequested(out: StringBuilder, source: String, options: MermaidHtmlOptions): Unit {
        if (!options.includeSource) {
            return
        }
        out.append("<pre class=\"")
        SvgEscaper.appendAttribute(out, options.classPrefix)
        out.append("-source\"><code class=\"language-mermaid\">")
        SvgEscaper.appendText(out, source)
        out.append("</code></pre>")
    }

    private func mergeDiagnostics(light: MermaidRenderResult, dark: MermaidRenderResult): Array<String> {
        let out = Array<String>(light.diagnostics.size + dark.diagnostics.size, { i =>
            if (i < light.diagnostics.size) {
                light.diagnostics[i]
            } else {
                dark.diagnostics[i - light.diagnostics.size]
            }
        })
        return out
    }
}

private func normalizeThemeName(theme: String): MermaidTheme {
    match (theme.toAsciiLower()) {
        case "dark" | "dark-plus" | "night" => return MermaidTheme.Dark
        case _ => return MermaidTheme.Default
    }
}
