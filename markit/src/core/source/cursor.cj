package markit.core.source

public struct CursorCheckpoint {
    public let bytePos: Int64
    public let runePos: Int64

    public init(bytePos: Int64, runePos: Int64) {
        this.bytePos = bytePos
        this.runePos = runePos
    }
}

public class Cursor {
    private let view: TextView
    private var bytePos: Int64
    private var runePos: Int64

    public init(view: TextView) {
        this.view = view
        this.bytePos = view.span.startByte
        this.runePos = view.span.startRune
    }

    public func bytePosition(): Int64 {
        return bytePos
    }

    public func runePosition(): Int64 {
        return runePos
    }

    public func atEnd(): Bool {
        return bytePos >= view.span.endByte
    }

    public func checkpoint(): CursorCheckpoint {
        return CursorCheckpoint(bytePos, runePos)
    }

    public func restore(checkpoint: CursorCheckpoint): Unit {
        if (checkpoint.bytePos < view.span.startByte || checkpoint.bytePos > view.span.endByte) {
            throw IllegalArgumentException("Cursor checkpoint is outside this view")
        }
        bytePos = checkpoint.bytePos
        runePos = checkpoint.runePos
    }

    public func peekByte(): ?Byte {
        if (atEnd()) {
            return None
        }
        return Some(view.source.byteAt(bytePos))
    }

    public func advanceByte(): ?Byte {
        if (atEnd()) {
            return None
        }
        let b = view.source.byteAt(bytePos)
        bytePos += 1
        return Some(b)
    }

    public func peekRune(): ?Rune {
        if (atEnd()) {
            return None
        }
        return Some(decodeRuneAt(bytePos)[0])
    }

    public func advanceRune(): ?Rune {
        if (atEnd()) {
            return None
        }
        let decoded = decodeRuneAt(bytePos)
        bytePos += decoded[1]
        runePos += 1
        return Some(decoded[0])
    }

    private func decodeRuneAt(pos: Int64): (Rune, Int64) {
        let first = view.source.byteAt(pos)
        let width = utf8Width(first)
        if (pos + width > view.span.endByte) {
            throw IllegalArgumentException("Incomplete utf8 rune inside TextView")
        }

        let bytes = Array<Byte>(width, repeat: 0)
        for (i in 0..width) {
            bytes[i] = view.source.byteAt(pos + i)
        }
        return Rune.fromUtf8(bytes, 0)
    }

    private func utf8Width(byte: Byte): Int64 {
        if (byte < 0x80) {
            return 1
        }
        if (byte >= 0xC2 && byte <= 0xDF) {
            return 2
        }
        if (byte >= 0xE0 && byte <= 0xEF) {
            return 3
        }
        if (byte >= 0xF0 && byte <= 0xF4) {
            return 4
        }
        throw IllegalArgumentException("Invalid utf8 byte sequence in Cursor.")
    }
}
