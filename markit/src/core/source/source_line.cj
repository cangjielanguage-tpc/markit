package markit.core.source

public class SourceLine {
    public SourceLine(
        public let text: String,
        public let span: SourceSpan,
        public let terminated!: Bool = false
    ) {}
}
