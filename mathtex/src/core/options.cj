package mathtex.core

public enum MathOutputMode {
    | Html
    | MathMl
    | HtmlAndMathMl
    | Typst
}

public class MathRenderOptions {
    public let displayMode: Bool
    public let classPrefix: String
    public let throwOnError: Bool
    public let errorColor: String

    public init(
        displayMode!: Bool = false,
        classPrefix!: String = "katex",
        throwOnError!: Bool = false,
        errorColor!: String = "#cc0000"
    ) {
        this.displayMode = displayMode
        this.classPrefix = if (classPrefix.isEmpty()) { "katex" } else { classPrefix }
        this.throwOnError = throwOnError
        this.errorColor = errorColor
    }
}
