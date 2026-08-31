package mathtex.parser

import std.collection.ArrayList
import mathtex.ast.MathExpression

public class MathTex {
    public init() {}

    public func createSession(displayMode!: Bool = false): MathParseSession {
        return MathParseSession(displayMode: displayMode)
    }

    public func parse(tex: String, displayMode!: Bool = false): MathParseOutput {
        let session = createSession(displayMode: displayMode)
        session.feed(tex)
        return session.finalize()
    }
}

public class MathParseSession {
    private let chunks = ArrayList<String>()
    private let byteChunks = ArrayList<Byte>()
    private let displayMode: Bool
    private var finalized: Bool = false

    public init(displayMode!: Bool = false) {
        this.displayMode = displayMode
    }

    public func feed(chunk: String): MathParseUpdate {
        ensureOpen()
        chunks.add(chunk)
        return MathParseUpdate(
            bytesAccepted: chunk.size,
            pendingByteSize: totalPendingBytes(),
            isFinal: false
        )
    }

    public func feedBytes(chunk: Array<Byte>): MathParseUpdate {
        ensureOpen()
        for (byte in chunk) {
            byteChunks.add(byte)
        }
        return MathParseUpdate(
            bytesAccepted: Int64(chunk.size),
            pendingByteSize: totalPendingBytes(),
            isFinal: false
        )
    }

    public func finalize(): MathParseOutput {
        ensureOpen()
        finalized = true

        let source = sourceText()
        let expression = parseCompleteSource(source)
        return MathParseOutput(
            expression,
            MathParseUpdate(
                bytesCommitted: source.size,
                pendingByteSize: 0,
                isFinal: true
            )
        )
    }

    public func snapshot(): MathExpression {
        let source = sourceText()
        return parseCompleteSource(source)
    }

    private func parseCompleteSource(source: String): MathExpression {
        return TexParser(source, displayMode).parse()
    }

    private func sourceText(): String {
        let capacity = totalPendingBytes()
        let out = StringBuilder(if (capacity > 0) { capacity } else { 1 })
        for (chunk in chunks) {
            out.append(chunk)
        }
        if (!byteChunks.isEmpty()) {
            out.append(String.fromUtf8(byteChunks.toArray()))
        }
        return out.toString()
    }

    private func totalPendingBytes(): Int64 {
        var total: Int64 = 0
        for (chunk in chunks) {
            total += chunk.size
        }
        total += byteChunks.size
        return total
    }

    private func ensureOpen(): Unit {
        if (finalized) {
            throw IllegalArgumentException("Cannot feed after finalize")
        }
    }
}

public class MathParseUpdate {
    public let bytesAccepted: Int64
    public let bytesCommitted: Int64
    public let pendingByteSize: Int64
    public let isFinal: Bool

    public init(
        bytesAccepted!: Int64 = 0,
        bytesCommitted!: Int64 = 0,
        pendingByteSize!: Int64 = 0,
        isFinal!: Bool = false
    ) {
        this.bytesAccepted = bytesAccepted
        this.bytesCommitted = bytesCommitted
        this.pendingByteSize = pendingByteSize
        this.isFinal = isFinal
    }
}

public class MathParseOutput {
    public let expression: MathExpression
    public let finalUpdate: MathParseUpdate

    public init(expression: MathExpression, finalUpdate: MathParseUpdate) {
        this.expression = expression
        this.finalUpdate = finalUpdate
    }
}
