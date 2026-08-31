package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[KatexMigration, KatexParser, KatexSymbols]
class KatexSymbolsTests {
    @TestCase
    func migratedKatexParserBatchOperatorsAndSymbolsShouldParse() {
        // Sources:
        // - describe("An op symbol builder") / should not fail
        // - describe("Unicode") / big operators, relations, arrows, binary operators, common ords, delimiters
        // - describe("Symbols") / spacing functions in math or text mode
        assertParsesAll([
            "\\sum_{n=1}^{10} n",
            "\\prod_{n=1}^{10} n",
            "\\coprod A",
            "\\int_0^1 x dx",
            "\\iint_D f dx dy",
            "\\iiint_D f dx dy dz",
            "\\oint_C f dz",
            "\\lim_{x\\to 0} x",
            "\\limsup_{x \\rightarrow \\infty}",
            "\\liminf_{x \\rightarrow \\infty}",
            "\\sin x + \\cos x + \\tan x",
            "\\log x + \\ln x",
            "\\max x + \\min y",
            "\\alpha\\beta\\gamma\\delta\\epsilon\\varepsilon",
            "\\zeta\\eta\\theta\\vartheta\\iota\\kappa",
            "\\lambda\\mu\\nu\\xi\\rho\\varrho",
            "\\sigma\\varsigma\\tau\\upsilon\\phi\\varphi\\chi",
            "\\pi\\psi\\omega",
            "\\Gamma\\Delta\\Theta\\Lambda\\Xi\\Pi\\Sigma\\Upsilon\\Phi\\Psi\\Omega",
            "\\le \\ge \\ne \\equiv \\approx \\sim \\cong \\propto",
            "\\in \\notin \\subset \\subseteq \\supset \\supseteq",
            "\\to \\rightarrow \\leftarrow \\Rightarrow \\Leftarrow \\leftrightarrow \\Leftrightarrow",
            "\\infty \\partial \\nabla \\forall \\exists \\emptyset",
            "\\cdot \\cdotp \\times \\pm \\mp \\div \\oplus \\otimes \\cup \\cap",
            "\\langle x \\rangle",
            "\\lbrace x \\rbrace",
            "\\lvert x \\rvert",
            "\\vert x \\mid y",
            "a b\\, \\; \\! \\: \\> ~ \\thinspace \\medspace \\quad \\ ",
            "\\enspace \\thickspace \\qquad \\space \\nobreakspace"
        ])
    }
    @TestCase
    func migratedKatexParserBatchTexvcAndAliasesShouldParse() {
        // Sources:
        // - describe("A texvc builder") / should not fail
        // - describe("Symbols") / support AMS symbols
        assertParsesAll([
            "\\lang\\N\\darr\\R\\dArr\\Z\\Darr\\alef\\rang",
            "\\alefsym\\uarr\\Alpha\\uArr\\Beta\\Uarr\\Chi",
            "\\clubs\\diamonds\\hearts\\spades\\cnums\\Complex",
            "\\Dagger\\empty\\harr\\Epsilon\\hArr\\Eta\\Harr\\exist",
            "\\image\\larr\\infin\\lArr\\Iota\\Larr\\isin\\Kappa",
            "\\Mu\\lrarr\\natnums\\lrArr\\Nu\\Lrarr\\Omicron",
            "\\real\\rarr\\plusmn\\rArr\\reals\\Rarr\\Reals\\Rho",
            "\\text{\\sect}\\sdot\\sub\\sube\\supe",
            "\\Tau\\thetasym\\weierp\\Zeta"
        ])
    }
    @TestCase
    func migratedKatexParserBatchMoreKnownCommandsShouldParse() {
        // Sources:
        // - describe("The \\mathchoice function")
        // - describe("Newlines via \\\\ and \\newline")
        // - describe("\\relax")
        // - describe("\\emph")
        assertParsesAll([
            "\\mathchoice{D}{T}{S}{SS}",
            "a \\\\ b",
            "a \\newline b",
            "\\begin{matrix}a\\\\b\\end{matrix}",
            "x^\\relax 2",
            "x_\\relax 2",
            "\\relax x",
            "\\emph{hello}",
            "\\text{\\emph{hello}}",
            "\\textup{\\emph{hello}}",
            "\\textit{\\emph{hello}}"
        ])
    }
}
