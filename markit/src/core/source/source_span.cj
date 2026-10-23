package markit.core.source

public struct SourceSpan {
    public SourceSpan(
        public let startByte: Int64,
        public let endByte: Int64,
        public let startRune: Int64,
        public let endRune: Int64
    ) {}

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
