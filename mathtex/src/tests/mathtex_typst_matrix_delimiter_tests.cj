package mathtex.tests

import std.unittest.*
import std.unittest.testmacro.*

@Test
@Tag[MathTex, MathTexTypst, KatexMigration, KatexEnvironment]
class MathTexTypstMatrixDelimiterTests {
    @TestCase
    func migratedKatexDelimitedMatricesShouldPreserveTypstDelimiter() {
        // Source: test/katex-spec.ts / matrix environment build cases.
        assertTypstEquals("\\begin{pmatrix}a&b\\\\c&d\\end{pmatrix}", "$mat(delim: \"(\", a, b; c, d)$")
        assertTypstEquals("\\begin{bmatrix}a&b\\\\c&d\\end{bmatrix}", "$mat(delim: \"[\", a, b; c, d)$")
        assertTypstEquals("\\begin{Vmatrix}a&b\\\\c&d\\end{Vmatrix}", "$mat(delim: \"∥\", a, b; c, d)$")
    }
}
