# mathtex

`mathtex` is a Cangjie build-time TeX math renderer for Markit.

Its primary goal is to let Markit render inline and block math during build, emit static KaTeX-compatible HTML plus MathML, and avoid requiring browser-side KaTeX JavaScript for supported formulas. It also provides a Typst writer so Markit's Typst path can use the same parsed math AST instead of a separate weak string translator.

`mathtex` is not a full KaTeX clone yet. It intentionally follows KaTeX output shape, class names, MathML accessibility model, and behavior tests for the supported subset, while keeping its own typed AST, parser session, and writer implementation.

## Public API

The package re-exports the main API from `mathtex.cj`:

```cangjie
import mathtex.{MathRenderOptions, MathRenderer, MathTex}

let renderer = MathRenderer()

let html = renderer.renderHtmlAndMathMl(
    "\\sum\\limits_{i=1}^n x_i",
    options: MathRenderOptions(displayMode: true)
)

let typst = renderer.renderTypst("\\frac{a}{b}")

let parser = MathTex().createSession(displayMode: false)
parser.feed("E = ")
parser.feed("mc^2")
let parsed = parser.finalize()
```

Important types:

- `MathRenderer`: one-shot render facade.
- `MathRenderOptions`: `displayMode`, `classPrefix`, `throwOnError`, and `errorColor`.
- `MathRenderResult`: rendered `output`, `supported`, and `diagnostics`.
- `MathTex`: parser facade.
- `MathParseSession`: chunked parser session with `feed`, `feedBytes`, `snapshot`, and `finalize`.
- `MathExpression` / `MathNode`: typed math AST root and nodes.

Supported output modes:

- HTML only.
- MathML only.
- HTML plus MathML.
- Typst math.

## Output Contract

HTML output is KaTeX-compatible by default:

- root class uses `katex` and also adds `mathtex`;
- display math adds `katex-display`;
- accessible output includes `katex-mathml` and `katex-html` containers;
- source TeX is preserved through `data-tex` and MathML annotation for copyability;
- common KaTeX atom/layout classes are emitted, including `mord`, `mbin`, `mrel`, `mopen`, `mclose`, `mpunct`, `mop`, `mfrac`, `msupsub`, `vlist`, `pstrut`, `arraycolsep`, and stretchy SVG layout spans where KaTeX uses them.

CSS and fonts are intentionally not bundled in this package. Markit or markit-cli should resolve KaTeX CSS and KaTeX font assets through the package/assets pipeline. The generated DOM keeps KaTeX class names so those assets can style the output.

## Implemented Coverage

Current KaTeX migration test status:

- upstream `it(...)` estimate: 727;
- passing migrated `KatexMigration` cases: 602;
- skipped migrated cases: 15;
- passing migrated test-entry coverage: about 82.8%;
- migrated-and-tagged entry coverage: about 84.9%;
- full local verification: `cjpm test --show-tags` passes 617/617.

Implemented parser and writer areas include:

- symbols, groups, source spans, scripts, Unicode superscripts/subscripts;
- fractions, `\genfrac`, infix forms such as `\over`, roots and indexed roots;
- Greek letters, common operators, binary operators, relations, arrows, delimiter commands, and Unicode math symbols;
- text commands, text ligatures, font commands, color commands, sizing commands, and style switches;
- `\left...\right` and covered `\middle` cases;
- matrix, matrix-star, cases, aligned, gathered, split, equation, array-like, `smallmatrix`, and `subarray` environments;
- `array`, `subarray`, and `matrix*` preambles for covered `l/c/r` alignment and `|` / `:` vertical separator metadata;
- operator limits and explicit `\limits` / `\nolimits` across HTML, MathML, and Typst;
- accents, wide accents, over/under braces, brackets, groups, line segments, extensible arrows, cancel/box/enclosure commands;
- simple macro definitions and expansion for `\def`, `\gdef`, `\edef`, `\xdef`, `\newcommand`, `\renewcommand`, and `\providecommand`;
- comments, spacing commands, `\rule`, `\kern`, `\hskip`, lap/smash/phantom-like layout commands;
- graceful error rendering with `throwOnError: false`, and exception behavior with `throwOnError: true`;
- chunked parser input for Markit-style incremental parsing.

## Markit Integration Boundary

`mathtex` is intended to replace these weak or runtime-oriented paths for supported formulas:

- browser-side KaTeX rendering in generated website pages;
- Markit's older simplified math-to-Typst translation logic.

For unsupported formulas, callers should either keep graceful fallback output or route through a compatibility path. `MathRenderResult.supported` and `diagnostics` are the integration boundary for that decision.

## Known Boundaries

The following are not complete yet:

- full KaTeX visual and DOM parity across the entire command surface;
- exact font metrics for every long-tail layout construct;
- exact array preamble behavior for `@{...}`, `!{...}`, `>{...}`, and `<{...}` spacing/modifier forms;
- full TeX macro expansion, especially delimited parameters, optional default macro arguments, and complex expansion edge cases;
- every KaTeX strict-mode, trust-mode, HTML extension, URL/security, and error-message option;
- every stretchy SVG path table entry and every exact SVG metric;
- complete visual regression coverage against upstream KaTeX;
- complete support for every Unicode/script/text edge case accepted by KaTeX.

When adding support for a new command, prefer migrating the related KaTeX test case first, then implement parser/AST/writer behavior, and finally add exact AST/HTML/MathML/Typst assertions where the output is renderer-visible.

## Verification

Run from `mathtex/`:

```powershell
cjpm test --show-tags
cjpm test --include-tags KatexMigration --show-tags
cjpm test --include-tags MathTexDemo --show-tags
```

`MathTexDemo` regenerates the local comparison page at:

```text
target/mathtex-home/index.html
```
