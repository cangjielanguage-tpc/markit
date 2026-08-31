package markit.core.source

public class SourceLine {
    public let text: String
    public let span: SourceSpan
    public let terminated: Bool

    public init(
        text: String,
        span: SourceSpan,
        terminated!: Bool = false
    ) {
        this.text = text
        this.span = span
        this.terminated = terminated
    }
}
