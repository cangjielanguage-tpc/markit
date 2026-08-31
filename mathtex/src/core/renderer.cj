package mathtex.core

import mathtex.html.HtmlMathWriter
import mathtex.mathml.MathMlWriter
import mathtex.ast.{MathErrorNode, MathNode}
import mathtex.parser.{MathTex, TexCommandRegistry}
import mathtex.typst.MathTypstWriter

public class MathRenderer {
    public init() {}

    public func renderHtmlAndMathMl(tex: String, options!: MathRenderOptions = MathRenderOptions()): MathRenderResult {
        return render(tex, MathOutputMode.HtmlAndMathMl, options)
    }

    public func renderHtml(tex: String, options!: MathRenderOptions = MathRenderOptions()): MathRenderResult {
        return render(tex, MathOutputMode.Html, options)
    }

    public func renderMathMl(tex: String, options!: MathRenderOptions = MathRenderOptions()): MathRenderResult {
        return render(tex, MathOutputMode.MathMl, options)
    }

    public func renderTypst(tex: String, options!: MathRenderOptions = MathRenderOptions()): MathRenderResult {
        return render(tex, MathOutputMode.Typst, options)
    }

    public func supportsCommand(_name: String): Bool {
        return TexCommandRegistry.supports(_name)
    }

    public func render(tex: String, mode: MathOutputMode, options: MathRenderOptions): MathRenderResult {
        let expression = MathTex().parse(tex, displayMode: options.displayMode).expression
        let supported = !hasError(expression.root)
        let diagnostics: Array<String> = if (supported) { [] } else { ["Unsupported TeX expression"] }
        if (!supported && options.throwOnError) {
            throw IllegalArgumentException("Unsupported TeX expression: ${tex}")
        }
        match (mode) {
            case MathOutputMode.Html => return MathRenderResult(
                HtmlMathWriter().writeHtml(expression, options.classPrefix, options.errorColor),
                diagnostics: diagnostics,
                supported: supported
            )
            case MathOutputMode.MathMl => return MathRenderResult(
                MathMlWriter().write(expression),
                diagnostics: diagnostics,
                supported: supported
            )
            case MathOutputMode.HtmlAndMathMl => return MathRenderResult(
                HtmlMathWriter().writeHtmlAndMathMl(expression, options.classPrefix, options.errorColor),
                diagnostics: diagnostics,
                supported: supported
            )
            case MathOutputMode.Typst => return MathRenderResult(
                if (options.displayMode) {
                    MathTypstWriter().writeBlock(expression)
                } else {
                    MathTypstWriter().writeInline(expression)
                },
                diagnostics: diagnostics,
                supported: supported
            )
        }
    }

    private func hasError(node: MathNode): Bool {
        if (let _: MathErrorNode <- node) {
            return true
        }
        for (child in node.children) {
            if (hasError(child)) {
                return true
            }
        }
        return false
    }

}
