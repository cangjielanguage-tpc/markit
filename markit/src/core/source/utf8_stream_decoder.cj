package markit.core.source

import std.collection.ArrayList

public class Utf8StreamDecoder {
    private let pendingBytes = ArrayList<Byte>()

    public prop pendingByteSize: Int64 {
        get() {
            return pendingBytes.size
        }
    }

    public func feed(chunk: Array<Byte>): String {
        let totalSize = pendingBytes.size + chunk.size
        if (totalSize == 0) {
            return ""
        }

        let combined = Array<Byte>(totalSize, repeat: 0)
        var cursor: Int64 = 0
        for (b in pendingBytes) {
            combined[cursor] = b
            cursor += 1
        }
        for (b in chunk) {
            combined[cursor] = b
            cursor += 1
        }
        pendingBytes.clear()

        let complete = completePrefixLength(combined)
        if (complete < combined.size) {
            for (i in complete..combined.size) {
                pendingBytes.add(combined[i])
            }
        }

        if (complete == 0) {
            return ""
        }
        return String.fromUtf8(combined[0..complete])
    }

    public func finalize(): Unit {
        if (!pendingBytes.isEmpty()) {
            throw IllegalArgumentException("Invalid utf8 byte sequence in Utf8StreamDecoder.")
        }
    }

    private func completePrefixLength(bytes: Array<Byte>): Int64 {
        var index: Int64 = 0
        while (index < bytes.size) {
            let byte = bytes[index]
            if (byte < 0x80) {
                index += 1
            } else if (byte >= 0xC2 && byte <= 0xDF) {
                if (index + 2 > bytes.size) {
                    return index
                }
                requireContinuation(bytes[index + 1])
                index += 2
            } else if (byte == 0xE0) {
                if (index + 3 > bytes.size) {
                    return index
                }
                requireRange(bytes[index + 1], 0xA0, 0xBF)
                requireContinuation(bytes[index + 2])
                index += 3
            } else if (byte >= 0xE1 && byte <= 0xEC) {
                if (index + 3 > bytes.size) {
                    return index
                }
                requireContinuation(bytes[index + 1])
                requireContinuation(bytes[index + 2])
                index += 3
            } else if (byte == 0xED) {
                if (index + 3 > bytes.size) {
                    return index
                }
                requireRange(bytes[index + 1], 0x80, 0x9F)
                requireContinuation(bytes[index + 2])
                index += 3
            } else if (byte >= 0xEE && byte <= 0xEF) {
                if (index + 3 > bytes.size) {
                    return index
                }
                requireContinuation(bytes[index + 1])
                requireContinuation(bytes[index + 2])
                index += 3
            } else if (byte == 0xF0) {
                if (index + 4 > bytes.size) {
                    return index
                }
                requireRange(bytes[index + 1], 0x90, 0xBF)
                requireContinuation(bytes[index + 2])
                requireContinuation(bytes[index + 3])
                index += 4
            } else if (byte >= 0xF1 && byte <= 0xF3) {
                if (index + 4 > bytes.size) {
                    return index
                }
                requireContinuation(bytes[index + 1])
                requireContinuation(bytes[index + 2])
                requireContinuation(bytes[index + 3])
                index += 4
            } else if (byte == 0xF4) {
                if (index + 4 > bytes.size) {
                    return index
                }
                requireRange(bytes[index + 1], 0x80, 0x8F)
                requireContinuation(bytes[index + 2])
                requireContinuation(bytes[index + 3])
                index += 4
            } else {
                throw IllegalArgumentException("Invalid utf8 byte sequence in Utf8StreamDecoder.")
            }
        }
        return index
    }

    private func requireContinuation(byte: Byte): Unit {
        requireRange(byte, 0x80, 0xBF)
    }

    private func requireRange(byte: Byte, min: Byte, max: Byte): Unit {
        if (byte < min || byte > max) {
            throw IllegalArgumentException("Invalid utf8 byte sequence in Utf8StreamDecoder.")
        }
    }
}
