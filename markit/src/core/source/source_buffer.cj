package markit.core.source

import std.collection.ArrayList

public class SourceBuffer {
    private let segments = ArrayList<SourceSegment>()
    private var acceptedBytes: Int64 = 0
    private var materializedText: ?String = None
    public let retentionMode: SourceRetentionMode

    public init(retentionMode!: SourceRetentionMode = SourceRetentionMode.Essential) {
        this.retentionMode = retentionMode
    }

    public prop byteSize: Int64 {
        get() {
            return acceptedBytes
        }
    }

    public func append(chunk: String): Int64 {
        segments.add(SourceSegment(text: chunk))
        let accepted = Int64(chunk.size)
        acceptedBytes += accepted
        materializedText = None
        return accepted
    }

    public func appendBytes(chunk: Array<Byte>): Int64 {
        let acceptedChunk = chunk.clone()
        segments.add(SourceSegment(bytes: acceptedChunk, isByteSegment: true))
        let accepted = acceptedChunk.size
        acceptedBytes += accepted
        materializedText = None
        return accepted
    }

    public func isEmpty(): Bool {
        return acceptedBytes == 0
    }

    public func stringSegmentCount(): Int64 {
        var count: Int64 = 0
        for (segment in segments) {
            if (!segment.isByteSegment) {
                count += 1
            }
        }
        return count
    }

    public func byteSegmentCount(): Int64 {
        var count: Int64 = 0
        for (segment in segments) {
            if (segment.isByteSegment) {
                count += 1
            }
        }
        return count
    }

    public func retainsFullSource(): Bool {
        return retentionMode == SourceRetentionMode.Full
    }

    public func hasRetainedSource(): Bool {
        return !segments.isEmpty()
    }

    public func view(span: SourceSpan): TextView {
        return TextView(this, span)
    }

    public func view(startByte: Int64, endByte: Int64, startRune!: Int64 = 0, endRune!: Int64 = 0): TextView {
        return TextView(this, SourceSpan(startByte, endByte, startRune, endRune))
    }

    public func cursor(span: SourceSpan): Cursor {
        return Cursor(view(span))
    }

    public func byteAt(byteOffset: Int64): Byte {
        if (byteOffset < 0 || byteOffset >= acceptedBytes) {
            throw IllegalArgumentException("Invalid source byte offset: ${byteOffset}")
        }

        var base: Int64 = 0
        for (segment in segments) {
            let size = segment.byteSize()
            if (byteOffset < base + size) {
                let local = byteOffset - base
                if (segment.isByteSegment) {
                    return segment.bytes[local]
                }
                return segment.text[local]
            }
            base += size
        }
        throw IllegalArgumentException("Invalid source byte offset: ${byteOffset}")
    }

    public func slice(startByte: Int64, endByte: Int64): String {
        if (startByte < 0 || endByte < startByte || endByte > acceptedBytes) {
            throw IllegalArgumentException("Invalid source slice range: ${startByte}..${endByte}")
        }
        if (startByte == endByte) {
            return ""
        }
        if (segments.isEmpty()) {
            return ""
        }
        if (let Some(text) <- materializedText) {
            return textBytesToString(text, startByte, endByte)
        }

        var base: Int64 = 0
        for (segment in segments) {
            let size = segment.byteSize()
            let segmentEnd = base + size
            if (startByte >= base && endByte <= segmentEnd) {
                let localStart = startByte - base
                let localEnd = endByte - base
                if (!segment.isByteSegment) {
                    return textBytesToString(segment.text, localStart, localEnd)
                }
                return bytesToString(segment.bytes, localStart, localEnd)
            }
            base = segmentEnd
        }

        let sliceSize = endByte - startByte
        let bytes = Array<Byte>(sliceSize, repeat: 0)
        var cursor: Int64 = 0
        base = 0
        for (segment in segments) {
            let size = segment.byteSize()
            let segmentEnd = base + size
            if (segmentEnd <= startByte) {
                base = segmentEnd
                continue
            }
            if (base >= endByte) {
                break
            }

            let localStart = if (startByte > base) { startByte - base } else { 0 }
            let localEnd = if (endByte < segmentEnd) { endByte - base } else { size }
            if (segment.isByteSegment) {
                for (i in localStart..localEnd) {
                    bytes[cursor] = segment.bytes[i]
                    cursor += 1
                }
            } else {
                for (i in localStart..localEnd) {
                    bytes[cursor] = segment.text[i]
                    cursor += 1
                }
            }
            base = segmentEnd
        }
        return String.fromUtf8(bytes)
    }

    public func materialize(): String {
        if (let Some(cached) <- materializedText) {
            return cached
        }

        if (acceptedBytes == 0) {
            materializedText = Some("")
            return ""
        }

        let allBytes = Array<Byte>(acceptedBytes, repeat: 0)
        var cursor: Int64 = 0
        for (segment in segments) {
            if (segment.isByteSegment) {
                for (b in segment.bytes) {
                    allBytes[cursor] = b
                    cursor += 1
                }
            } else {
                for (b in segment.text) {
                    allBytes[cursor] = b
                    cursor += 1
                }
            }
        }
        let text = String.fromUtf8(allBytes)
        materializedText = Some(text)
        return text
    }

    public func releaseRetainedSource(): Unit {
        if (retainsFullSource()) {
            return
        }
        segments.clear()
        materializedText = None
    }

    public func toDebugString(): String {
        if (!retainsFullSource()) {
            return ""
        }
        return materialize()
    }

    private func bytesToString(bytes: Array<Byte>, start: Int64, end: Int64): String {
        let sliceSize = end - start
        let slice = Array<Byte>(sliceSize, repeat: 0)
        var cursor: Int64 = 0
        for (i in start..end) {
            slice[cursor] = bytes[i]
            cursor += 1
        }
        return String.fromUtf8(slice)
    }

    private func textBytesToString(text: String, start: Int64, end: Int64): String {
        let sliceSize = end - start
        let slice = Array<Byte>(sliceSize, repeat: 0)
        var cursor: Int64 = 0
        var byteOffset: Int64 = 0
        for (b in text) {
            if (byteOffset >= end) {
                break
            }
            if (byteOffset >= start) {
                slice[cursor] = b
                cursor += 1
            }
            byteOffset += 1
        }
        return String.fromUtf8(slice)
    }
}

private class SourceSegment {
    public let text: String
    public let bytes: Array<Byte>
    public let isByteSegment: Bool

    public init(
        text!: String = "",
        bytes!: Array<Byte> = [],
        isByteSegment!: Bool = false
    ) {
        this.text = text
        this.bytes = bytes
        this.isByteSegment = isByteSegment
    }

    public func byteSize(): Int64 {
        return if (isByteSegment) { bytes.size } else { text.size }
    }
}
