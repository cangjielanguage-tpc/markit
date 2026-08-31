package markit.core.source

public class TextView {
    public let source: SourceBuffer
    public let span: SourceSpan

    public init(source: SourceBuffer, span: SourceSpan) {
        this.source = source
        this.span = span
    }

    public prop byteSize: Int64 {
        get() {
            return span.endByte - span.startByte
        }
    }

    public prop runeSize: Int64 {
        get() {
            return span.endRune - span.startRune
        }
    }

    public func isEmpty(): Bool {
        return byteSize == 0
    }

    public func cursor(): Cursor {
        return Cursor(this)
    }

    public func slice(startByteDelta: Int64, endByteDelta: Int64, startRuneDelta!: Int64 = 0, endRuneDelta!: Int64 = 0): TextView {
        return TextView(source, span.slice(startByteDelta, endByteDelta, startRuneDelta, endRuneDelta))
    }

    public func toString(): String {
        return source.slice(span.startByte, span.endByte)
    }
}
