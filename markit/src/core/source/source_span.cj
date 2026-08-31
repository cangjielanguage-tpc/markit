package markit.core.source

public struct SourceSpan {
    public let startByte: Int64
    public let endByte: Int64
    public let startRune: Int64
    public let endRune: Int64

    public init(
        startByte: Int64,
        endByte: Int64,
        startRune: Int64,
        endRune: Int64
    ) {
        this.startByte = startByte
        this.endByte = endByte
        this.startRune = startRune
        this.endRune = endRune
    }

    public static func empty(): SourceSpan {
        return SourceSpan(0, 0, 0, 0)
    }

    public func merge(other: SourceSpan): SourceSpan {
        return SourceSpan(
            if (startByte < other.startByte) { startByte } else { other.startByte },
            if (endByte > other.endByte) { endByte } else { other.endByte },
            if (startRune < other.startRune) { startRune } else { other.startRune },
            if (endRune > other.endRune) { endRune } else { other.endRune }
        )
    }

    public func slice(
        startByteDelta: Int64,
        endByteDelta: Int64,
        startRuneDelta: Int64,
        endRuneDelta: Int64
    ): SourceSpan {
        return SourceSpan(
            startByte + startByteDelta,
            startByte + endByteDelta,
            startRune + startRuneDelta,
            startRune + endRuneDelta
        )
    }
}
