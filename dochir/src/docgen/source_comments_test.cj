package dochir.docgen

@Test
func parseSlashSlashDocImmediatelyBeforeDeclaration(): Unit {
    let doc = SourceComments.docForTesting([
        "// A documented class.",
        "public class Demo {}"
    ], 2)

    @Expect(doc.summary, "A documented class.")
    @Expect(doc.params.isEmpty())
    @Expect(doc.returns, "")
    @Expect(doc.typeText, "")
}

@Test
func ignoreTripleSlashDoc(): Unit {
    let doc = SourceComments.docForTesting([
        "/// Not a dochir doc comment.",
        "public class Demo {}"
    ], 2)

    @Expect(doc.summary, "")
    @Expect(doc.params.isEmpty())
    @Expect(doc.returns, "")
    @Expect(doc.typeText, "")
}

@Test
func parseContiguousLineDocBlock(): Unit {
    let doc = SourceComments.docForTesting([
        "// First sentence.",
        "// Second sentence.",
        "public func demo(): Unit {}"
    ], 3)

    @Expect(doc.summary, "First sentence. Second sentence.")
}

@Test
func stopLineDocAtTripleSlash(): Unit {
    let doc = SourceComments.docForTesting([
        "// Real declaration doc.",
        "/// Ignored separator.",
        "public class Demo {}"
    ], 3)

    @Expect(doc.summary, "")
    @Expect(doc.params.isEmpty())
}

@Test
func parseSlashSlashDocWithTags(): Unit {
    let doc = SourceComments.docForTesting([
        "// Runs the operation.",
        "// @param value Value to process.",
        "// @return Processed value.",
        "public func run(value: Int64): Int64 { return value }"
    ], 4)

    @Expect(doc.summary, "Runs the operation.")
    @Expect(doc.params.size, 1)
    @Expect(doc.params[0][0], "value")
    @Expect(doc.params[0][1], "Value to process.")
    @Expect(doc.returns, "Processed value.")
}

@Test
func parseSingleLineBlockDoc(): Unit {
    let doc = SourceComments.docForTesting([
        "/** A compact block doc. */",
        "public class Demo {}"
    ], 2)

    @Expect(doc.summary, "A compact block doc.")
}

@Test
func parseStdStyleBlockDocWithTags(): Unit {
    let doc = SourceComments.docForTesting([
        "/**",
        " * Builds a signature view from a display name, function type, and generic parameters.",
        " * @param name Logical name of the symbol.",
        " * @param ty Function type (parameters and return).",
        " * @param genericTypeParams Generic type parameters in declaration order.",
        " * @return Single-line textual form of this signature.",
        " * @type { FuncType }",
        " */",
        "public func toString(): String { return \"\" }"
    ], 9)

    @Expect(doc.summary, "Builds a signature view from a display name, function type, and generic parameters.")
    @Expect(doc.params.size, 3)
    @Expect(doc.params[0][0], "name")
    @Expect(doc.params[0][1], "Logical name of the symbol.")
    @Expect(doc.params[1][0], "ty")
    @Expect(doc.params[1][1], "Function type (parameters and return).")
    @Expect(doc.params[2][0], "genericTypeParams")
    @Expect(doc.params[2][1], "Generic type parameters in declaration order.")
    @Expect(doc.returns, "Single-line textual form of this signature.")
    @Expect(doc.typeText, "FuncType")
}

@Test
func parseTagContinuationLines(): Unit {
    let doc = SourceComments.docForTesting([
        "/**",
        " * Runs the operation.",
        " * @param value First line",
        " *   second line",
        " * @return First result line",
        " *   second result line",
        " */",
        "public func run(value: Int64): Int64 { return value }"
    ], 8)

    @Expect(doc.summary, "Runs the operation.")
    @Expect(doc.params.size, 1)
    @Expect(doc.params[0][0], "value")
    @Expect(doc.params[0][1], "First line second line")
    @Expect(doc.returns, "First result line second result line")
}

@Test
func ignoreBlankDocLinesInSummary(): Unit {
    let doc = SourceComments.docForTesting([
        "/**",
        " * First paragraph.",
        " *",
        " * Second paragraph.",
        " */",
        "public class Demo {}"
    ], 6)

    @Expect(doc.summary, "First paragraph. Second paragraph.")
}

@Test
func allowBlankLineBetweenDocAndDeclaration(): Unit {
    let doc = SourceComments.docForTesting([
        "// Description survives one blank separator.",
        "",
        "public class Demo {}"
    ], 3)

    @Expect(doc.summary, "Description survives one blank separator.")
}

@Test
func allowAnnotationBetweenDocAndDeclaration(): Unit {
    let doc = SourceComments.docForTesting([
        "// Describes an annotated enum.",
        "@Derive[Equatable]",
        "public enum Demo { A }"
    ], 3)

    @Expect(doc.summary, "Describes an annotated enum.")
}

@Test
func returnEmptyDocWithoutLeadingComment(): Unit {
    let doc = SourceComments.docForTesting([
        "let value = 1",
        "public class Demo {}"
    ], 2)

    @Expect(doc.summary, "")
    @Expect(doc.params.isEmpty())
    @Expect(doc.returns, "")
    @Expect(doc.typeText, "")
}

@Test
func parseThrowsAndExampleTags(): Unit {
    let doc = SourceComments.docForTesting([
        "// Builds an item.",
        "// @throws CHIRException when the source value is invalid.",
        "// @example",
        "// let item = builder.createAllocate(IntType.getInt32())",
        "// println(item.ty)",
        "public func build(): Unit {}"
    ], 6)

    @Expect(doc.summary, "Builds an item.")
    @Expect(doc.errors.size, 1)
    @Expect(doc.errors[0][0], "CHIRException")
    @Expect(doc.errors[0][1], "when the source value is invalid.")
    @Expect(doc.examples.size, 1)
    @Expect(doc.examples[0], "let item = builder.createAllocate(IntType.getInt32())\nprintln(item.ty)")
}

@Test
func selectsLocalizedThrowsByLanguage(): Unit {
    SourceComments.configure(language: "zh", defaultLang: "en")
    let doc = SourceComments.docForTesting([
        "/**",
        " * @description Builds an item.",
        " * @description-zh 构建一个条目。",
        " * @throws CHIRException when the source value is invalid.",
        " * @throws-zh CHIRException 当源值无效时抛出。",
        " * @exception ParseException when parsing fails.",
        " * @exception-zh ParseException 当解析失败时抛出。",
        " */",
        "public func build(): Unit {}"
    ], 9)

    @Expect(doc.errors.size, 2)
    @Expect(doc.errors[0][0], "CHIRException")
    @Expect(doc.errors[0][1], "当源值无效时抛出。")
    @Expect(doc.errors[1][0], "ParseException")
    @Expect(doc.errors[1][1], "当解析失败时抛出。")
    SourceComments.configure(language: "en", defaultLang: "en")
}

@Test
func selectsLocalizedDescriptionByLanguage(): Unit {
    SourceComments.configure(language: "zh", defaultLang: "en")
    let doc = SourceComments.docForTesting([
        "/**",
        " * @description Add two numbers.",
        " * @description-zh 两个数字相加",
        " * @description-ja 二つの数値を加算する",
        " */",
        "public func add(a: Int64, b: Int64): Int64 { return a + b }"
    ], 6)

    @Expect(doc.summary, "两个数字相加")
    SourceComments.configure(language: "en", defaultLang: "en")
}

@Test
func selectsLocalizedParamAndReturnByLanguage(): Unit {
    SourceComments.configure(language: "zh", defaultLang: "en")
    let doc = SourceComments.docForTesting([
        "/**",
        " * @description Run a plugin.",
        " * @description-zh 执行插件。",
        " * @param pkg Package to inspect or transform.",
        " * @param-zh pkg 要检查或转换的包。",
        " * @return true when plugin execution succeeds.",
        " * @return-zh 插件执行成功时返回 true。",
        " */",
        "public func run(pkg: Package): Bool { return true }"
    ], 9)

    @Expect(doc.summary, "执行插件。")
    @Expect(doc.params.size, 1)
    @Expect(doc.params[0][0], "pkg")
    @Expect(doc.params[0][1], "要检查或转换的包。")
    @Expect(doc.returns, "插件执行成功时返回 true。")
    SourceComments.configure(language: "en", defaultLang: "en")
}

@Test
func fallsBackToDefaultParamAndReturnLanguage(): Unit {
    SourceComments.configure(language: "ja", defaultLang: "en")
    let doc = SourceComments.docForTesting([
        "/**",
        " * @description Run a plugin.",
        " * @description-zh 执行插件。",
        " * @param pkg Package to inspect or transform.",
        " * @param-zh pkg 要检查或转换的包。",
        " * @return true when plugin execution succeeds.",
        " * @return-zh 插件执行成功时返回 true。",
        " */",
        "public func run(pkg: Package): Bool { return true }"
    ], 9)

    @Expect(doc.params.size, 1)
    @Expect(doc.params[0][1], "Package to inspect or transform.")
    @Expect(doc.returns, "true when plugin execution succeeds.")
    SourceComments.configure(language: "en", defaultLang: "en")
}

@Test
func bareDescriptionUsesDefaultLanguage(): Unit {
    SourceComments.configure(language: "zh", defaultLang: "zh")
    let doc = SourceComments.docForTesting([
        "/**",
        " * @description 两个数字相加",
        " * @description-en Add two numbers.",
        " */",
        "public func add(a: Int64, b: Int64): Int64 { return a + b }"
    ], 5)

    @Expect(doc.summary, "两个数字相加")
    SourceComments.configure(language: "en", defaultLang: "en")
}

@Test
func parsesStdxStyleTagsWithLocalizedDescription(): Unit {
    let doc = SourceComments.docForTesting([
        "/**",
        " * @param a Left input.",
        " * @param b Right input.",
        " * @return Sum of both inputs.",
        " * @decription-en Add two numbers.",
        " */",
        "public func add(a: Int64, b: Int64): Int64 { return a + b }"
    ], 7)

    @Expect(doc.summary, "Add two numbers.")
    @Expect(doc.params.size, 2)
    @Expect(doc.params[0][0], "a")
    @Expect(doc.params[0][1], "Left input.")
    @Expect(doc.params[1][0], "b")
    @Expect(doc.params[1][1], "Right input.")
    @Expect(doc.returns, "Sum of both inputs.")
}

@Test
func findsLocalizedEnumConstructorDescription(): Unit {
    SourceComments.configure(language: "zh", defaultLang: "en")
    let doc = SourceComments.enumConstructorDocForTesting([
        "/**",
        " * @description Describes binary operation kinds.",
        " * @description-zh 描述二元操作类型。",
        " */",
        "public enum BinaryExprKind <: ToString {",
        "    /**",
        "     * @description Addition operation.",
        "     * @description-zh 加法操作。",
        "     */",
        "    | Add",
        "    /**",
        "     * @description Subtraction operation.",
        "     * @description-zh 减法操作。",
        "     */",
        "    | Sub",
        "}",
    ], "BinaryExprKind", "Add")

    @Expect(doc.summary, "加法操作。")
    SourceComments.configure(language: "en", defaultLang: "en")
}
