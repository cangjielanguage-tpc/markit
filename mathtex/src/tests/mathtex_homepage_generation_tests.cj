package mathtex.tests

import std.fs.{Directory, File, OpenMode, Path, exists}
import std.unittest.*
import std.unittest.testmacro.*
import mathtex.{MathRenderOptions, MathRenderer}
import mathtex.util.HtmlEscaper

@Test
@Tag[MathTex, MathTexHtml, MathTexDemo]
class MathtexHomepageGenerationTests {
    @TestCase
    func homepageShouldShowSourceAndRenderedMathUsingMarkitCliAssets() {
        let outputDir = Path("target").join("mathtex-home")
        let outputPath = outputDir.join("index.html")
        if (!exists(outputDir)) {
            Directory.create(outputDir.toString(), recursive: true)
        }

        let html = buildHomepageHtml()
        let file = File(outputPath.toString(), OpenMode.Write)
        file.write(html.toArray())
        file.close()

        @Expect(exists(outputPath), true)
        let written = String.fromUtf8(File.readFrom(outputPath))
        @Expect(written.contains("../../../markit-cli/assets/css/katex.min.css"), true)
        @Expect(written.contains("../../../markit-cli/assets/themes/arctic/styles.css"), true)
        @Expect(written.contains("../../../markit-cli/assets/themes/arctic/fonts.css"), true)
        @Expect(written.contains("../../../markit-cli/assets/js/markit.bundle.js"), true)
        @Expect(written.contains("data-tex=\"E = mc^2\""), true)
        @Expect(written.contains("class=\"katex mathtex\""), true)
        @Expect(written.contains("data-tex=\"E = mc^2\""), true)
        @Expect(written.contains("class=\"katex mathtex katex-display\""), true)
        @Expect(written.contains("<span class=\"katex-mathml\">"), true)
        @Expect(written.contains("<span class=\"katex-html\" aria-hidden=\"true\">"), true)
    }

    private func buildHomepageHtml(): String {
        let renderer = MathRenderer()
        let formulas = [
            "E = mc^2",
            "x_i^2 + y_{n+1}",
            "\\frac{a}{b} + \\sqrt{x^2 + y^2}",
            "\\displaystyle{\\frac{a}{b}} + x \\quad x^{\\frac{a}{b}}",
            "\\sqrt[3]{2} + \\frac{1}{n}\\sum_{i=1}^n x_i",
            "\\prod_{k=1}^n k \\quad \\coprod_{j=1}^m A_j",
            "\\sum\\limits_{i=1}^n x_i + \\int\\nolimits_0^1 f(x) dx",
            "\\displaystyle{\\sum_{i=1}^n x_i} \\quad \\textstyle{\\sum_{i=1}^n x_i}",
            "\\sin(x) + \\log_2 n \\le \\infty",
            "\\operatorname{rank}(A) + \\lim_{x\\to\\infty} f(x)",
            "\\alpha + \\beta \\rightarrow \\gamma",
            "p \\implies q \\iff r \\Leftarrow s",
            "\\left(\\frac{x}{y}\\right) + \\left\\lVert v \\right\\rVert",
            "\\left\\langle x,y \\right\\rangle + \\left\\lfloor n \\right\\rfloor",
            "\\begin{matrix}a&b\\\\c&d\\end{matrix}",
            "\\begin{pmatrix}a&b\\\\c&d\\end{pmatrix}",
            "\\begin{bmatrix}1&0\\\\0&1\\end{bmatrix} + \\begin{Bmatrix}a&b\\\\c&d\\end{Bmatrix}",
            "\\begin{Vmatrix}a&b\\\\c&d\\end{Vmatrix}",
            "\\begin{array}{cc}a+b&c-d\\\\e/f&g^2\\end{array}",
            "\\begin{cases}a&\\text{if }b\\\\c&\\text{otherwise}\\end{cases}",
            "\\begin{aligned}a&=b+c\\\\d&=e+f\\end{aligned}",
            "\\begin{gathered}x+y=1\\\\x-y=0\\end{gathered}",
            "\\newcommand\\sq[1]{#1^2}\\sq{x}+\\sq{y}",
            "\\gdef\\pair#1#2{(#1,#2)}\\pair{x}{y}+\\pair{a}{b}",
            "\\mathrm{d}x + \\mathbb{R} + \\mathcal{F}",
            "\\mathsf{ABC} + \\mathtt{code} + \\mathfrak{g}",
            "\\textcolor{red}{x} + \\color{blue}{y}",
            "\\colorbox{yellow}{x} + \\fcolorbox{blue}{yellow}{y}",
            "\\overline{x} + \\underline{y} + \\hat{z}",
            "\\widehat{AB} + \\widetilde{xyz} + \\overrightarrow{PQ}",
            "\\overleftarrow{AB} + \\overleftrightarrow{CD} + \\underleftrightarrow{EF}",
            "\\xleftarrow{n} + \\xrightarrow[under]{over} + \\xleftrightarrow{A}",
            "\\xlongequal{def} + \\xrightarrow{f} + \\xleftarrow{g}",
            "\\xhookleftarrow{abc} + \\xmapsto{abc} + \\xtwoheadrightarrow{abc}",
            "\\xrightleftharpoons{abc} + \\xtofrom{abc} + \\xrightleftarrows{abc}",
            "\\overbracket{AB}^{n} + \\underbracket{CD}_{m} + \\overgroup{EF}",
            "\\overlinesegment{AB} + \\underlinesegment{CD} + \\undergroup{EF}",
            "\\overbrace{x+x+x}^{n} + \\underbrace{1+1+1}_{n}",
            "\\boxed{y} + \\cancel{z} + \\bcancel{x} + \\xcancel{w}"
        ]

        let out = StringBuilder(32000)
        out.append("<!doctype html>\n")
        out.append("<html lang=\"zh-CN\">\n")
        out.append("<head>\n")
        out.append("  <meta charset=\"utf-8\">\n")
        out.append("  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n")
        out.append("  <title>mathtex render check</title>\n")
        out.append("  <link rel=\"stylesheet\" href=\"../../../markit-cli/assets/themes/arctic/fonts.css\">\n")
        out.append("  <link rel=\"stylesheet\" href=\"../../../markit-cli/assets/themes/arctic/styles.css\">\n")
        out.append("  <link rel=\"stylesheet\" href=\"../../../markit-cli/assets/css/katex.min.css\">\n")
        out.append("  <style>\n")
        out.append("    body { margin: 0; padding: 32px; font-family: system-ui, sans-serif; background: #f6f7f9; color: #1f2328; }\n")
        out.append("    main { max-width: 1280px; margin: 0 auto; }\n")
        out.append("    h1 { margin: 0 0 6px; font-size: 28px; }\n")
        out.append("    .meta { margin: 0 0 20px; color: #57606a; font-size: 14px; }\n")
        out.append("    .formula-grid { display: grid; gap: 16px; }\n")
        out.append("    .formula-row { display: grid; grid-template-columns: minmax(220px, 0.8fr) minmax(260px, 1fr) minmax(260px, 1fr); gap: 16px; padding: 16px; border: 1px solid #d0d7de; border-radius: 8px; background: white; }\n")
        out.append("    .source, .rendered, .official { min-width: 0; }\n")
        out.append("    .label { margin: 0 0 8px; font-size: 12px; color: #57606a; text-transform: uppercase; }\n")
        out.append("    pre { margin: 0; padding: 12px 14px; border-radius: 8px; background: #f6f8fa; white-space: pre-wrap; overflow-wrap: anywhere; font: 13px/1.5 ui-monospace, SFMono-Regular, Consolas, monospace; }\n")
        out.append("    .rendered, .official { font-size: 1.15rem; overflow-x: auto; padding: 4px 0; }\n")
        out.append("    .rendered .katex-display, .official .katex-display { margin: 0.35em 0; }\n")
        out.append("    @media (max-width: 980px) { .formula-row { grid-template-columns: 1fr; } body { padding: 18px; } }\n")
        out.append("  </style>\n")
        out.append("</head>\n")
        out.append("<body>\n")
        out.append("  <main>\n")
        out.append("    <h1>mathtex render check</h1>\n")
        out.append("    <p class=\"meta\">TeX on the left; mathtex static HTML + MathML in the middle; official KaTeX runtime output on the right. CSS/fonts/js are referenced from markit-cli assets.</p>\n")
        out.append("    <section class=\"formula-grid\">\n")
        for (i in 0..formulas.size) {
            let tex = formulas[i]
            let displayMode = tex.contains("\\begin")
            let rendered = renderer.renderHtmlAndMathMl(tex, options: MathRenderOptions(displayMode: displayMode)).output
            out.append("      <article class=\"formula-row\" data-tex=\"")
            out.append(HtmlEscaper.escapeAttribute(tex))
            out.append("\">\n")
            out.append("        <div class=\"source\"><p class=\"label\">Original TeX</p><pre>")
            out.append(HtmlEscaper.escapeText(tex))
            out.append("</pre></div>\n")
            out.append("        <div class=\"rendered\"><p class=\"label\">mathtex HTML + MathML</p>")
            out.append(rendered)
            out.append("</div>\n")
            out.append("        <div class=\"official\"><p class=\"label\">official KaTeX</p><div class=\"official-katex\" data-display=\"")
            out.append(if (displayMode) { "true" } else { "false" })
            out.append("\"></div></div>\n")
            out.append("      </article>\n")
        }
        out.append("    </section>\n")
        out.append("  </main>\n")
        out.append("  <script src=\"../../../markit-cli/ts-render/node_modules/katex/dist/katex.min.js\"></script>\n")
        out.append("  <script>\n")
        out.append("    document.querySelectorAll('.formula-row').forEach(function(row) {\n")
        out.append("      var target = row.querySelector('.official-katex');\n")
        out.append("      if (!target || !window.katex) return;\n")
        out.append("      katex.render(row.getAttribute('data-tex') || '', target, { throwOnError: false, displayMode: target.getAttribute('data-display') === 'true' });\n")
        out.append("    });\n")
        out.append("  </script>\n")
        out.append("  <script src=\"../../../markit-cli/assets/js/markit.bundle.js\"></script>\n")
        out.append("</body>\n")
        out.append("</html>\n")
        return out.toString()
    }
}
