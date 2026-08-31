package mathtex.core

public class MathRenderResult {
    public let output: String
    public let diagnostics: Array<String>
    public let supported: Bool

    public init(output: String, diagnostics!: Array<String> = [], supported!: Bool = false) {
        this.output = output
        this.diagnostics = diagnostics
        this.supported = supported
    }
}
