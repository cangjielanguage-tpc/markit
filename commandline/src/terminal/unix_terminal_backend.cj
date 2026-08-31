package commandline.terminal

import std.collection.ArrayList
import std.sync.Mutex

@When[os != "Windows"]
@C
struct UnixTermios {
    var c_iflag: UInt32 = 0
    var c_oflag: UInt32 = 0
    var c_cflag: UInt32 = 0
    var c_lflag: UInt32 = 0
    var c_line: UInt8 = 0
    var c_cc: VArray<UInt8, $32> = VArray<UInt8, $32>({ _ => 0 })
    var c_ispeed: UInt32 = 0
    var c_ospeed: UInt32 = 0
}

@When[os != "Windows"]
foreign {
    func isatty(fd: Int32): Int32
    func tcgetattr(fd: Int32, termios: CPointer<UnixTermios>): Int32
    func tcsetattr(fd: Int32, action: Int32, termios: CPointer<UnixTermios>): Int32
    func read(fd: Int32, buffer: CPointer<UInt8>, count: UIntNative): IntNative
}

@When[os != "Windows"]
public class NativeTerminalBackend <: TerminalBackend {
    private static let stdinFd: Int32 = 0
    private static let escapeCode: UInt8 = 27
    private static let lineFeedCode: UInt8 = 10
    private static let carriageReturnCode: UInt8 = 13
    private static let backspaceCode: UInt8 = 8
    private static let deleteCode: UInt8 = 127
    private static let spaceCode: UInt8 = 32
    private static let openBracketCode: UInt8 = 91
    private static let leftCode: UInt8 = 68
    private static let rightCode: UInt8 = 67
    private static let upCode: UInt8 = 65
    private static let downCode: UInt8 = 66
    private static let upperACode: UInt8 = 65
    private static let lowerACode: UInt8 = 97
    private static let upperCCode: UInt8 = 67
    private static let lowerCCode: UInt8 = 99
    private static let upperZCode: UInt8 = 90
    private static let lowerZCode: UInt8 = 122
    private static let uppercaseOffset: UInt8 = 32
    private static let canonicalFlag: UInt32 = 2
    private static let echoFlag: UInt32 = 8
    private static let vtimeIndex: Int = 5
    private static let vminIndex: Int = 6
    private static let tcsetNow: Int32 = 0
    private let testKeyQueue: ArrayList<TerminalKey>
    private let mutex: Mutex
    private var originalMode: ?UnixTermios = None
    private var usesQueuedKeys: Bool = false

    public init(testKeyQueue: ArrayList<TerminalKey>, mutex: Mutex) {
        this.testKeyQueue = testKeyQueue
        this.mutex = mutex
    }

    public func supportsKeyNavigation(): Bool {
        if (hasQueuedKeyInput()) {
            return true
        }
        return unsafe { isatty(NativeTerminalBackend.stdinFd) == 1 }
    }

    public func enterKeyMode(): Bool {
        if (hasQueuedKeyInput()) {
            usesQueuedKeys = true
            originalMode = None
            return true
        }

        var mode = UnixTermios()
        if (unsafe { tcgetattr(NativeTerminalBackend.stdinFd, inout mode) } != 0) {
            return false
        }

        var rawMode = mode
        rawMode.c_lflag = clearFlag(rawMode.c_lflag, NativeTerminalBackend.canonicalFlag)
        rawMode.c_lflag = clearFlag(rawMode.c_lflag, NativeTerminalBackend.echoFlag)
        rawMode.c_cc[NativeTerminalBackend.vminIndex] = 0
        rawMode.c_cc[NativeTerminalBackend.vtimeIndex] = 1

        if (unsafe { tcsetattr(NativeTerminalBackend.stdinFd, NativeTerminalBackend.tcsetNow, inout rawMode) } != 0) {
            return false
        }

        originalMode = Some(mode)
        usesQueuedKeys = false
        return true
    }

    public func leaveKeyMode(): Unit {
        if (usesQueuedKeys) {
            usesQueuedKeys = false
            originalMode = None
            return
        }

        match (originalMode) {
            case Some(mode) =>
                var restoreMode = mode
                _ = unsafe { tcsetattr(NativeTerminalBackend.stdinFd, NativeTerminalBackend.tcsetNow, inout restoreMode) }
            case None => ()
        }
        originalMode = None
    }

    public func readKey(): TerminalKey {
        match (popQueuedKey()) {
            case Some(value) => return value
            case None => ()
        }

        match (readByte(true)) {
            case Some(byte) => return decodeKey(byte)
            case None => return TerminalKey.Eof
        }
    }

    private func decodeKey(byte: UInt8): TerminalKey {
        if (byte == NativeTerminalBackend.carriageReturnCode || byte == NativeTerminalBackend.lineFeedCode) {
            return TerminalKey.Enter
        }
        if (byte == NativeTerminalBackend.backspaceCode || byte == NativeTerminalBackend.deleteCode) {
            return TerminalKey.Backspace
        }
        if (byte == NativeTerminalBackend.spaceCode) {
            return TerminalKey.Space
        }
        if (byte == NativeTerminalBackend.escapeCode) {
            return decodeEscapeSequence()
        }
        if (byte == NativeTerminalBackend.upperACode || byte == NativeTerminalBackend.lowerACode) {
            return TerminalKey.SelectAll
        }
        if (byte == NativeTerminalBackend.upperCCode || byte == NativeTerminalBackend.lowerCCode) {
            return TerminalKey.Clear
        }
        return TerminalKey.Char(asciiString(lowercaseAscii(byte)))
    }

    private func decodeEscapeSequence(): TerminalKey {
        match (readByte(false)) {
            case Some(next1) =>
                if (next1 != NativeTerminalBackend.openBracketCode) {
                    return TerminalKey.Escape
                }
                match (readByte(false)) {
                    case Some(next2) =>
                        if (next2 == NativeTerminalBackend.upCode) {
                            return TerminalKey.Up
                        }
                        if (next2 == NativeTerminalBackend.downCode) {
                            return TerminalKey.Down
                        }
                        if (next2 == NativeTerminalBackend.leftCode) {
                            return TerminalKey.Left
                        }
                        if (next2 == NativeTerminalBackend.rightCode) {
                            return TerminalKey.Right
                        }
                        return TerminalKey.Escape
                    case None => return TerminalKey.Escape
                }
            case None => return TerminalKey.Escape
        }
    }

    private func readByte(waitForInput: Bool): ?UInt8 {
        while (true) {
            var buffer: UInt8 = 0
            let result = unsafe { read(NativeTerminalBackend.stdinFd, inout buffer, 1) }
            if (result > 0) {
                return Some(buffer)
            }
            if (result < 0) {
                return None<UInt8>
            }
            if (!waitForInput) {
                return None<UInt8>
            }
        }
        throw Exception("unreachable")
    }

    private func lowercaseAscii(byte: UInt8): UInt8 {
        if (byte >= NativeTerminalBackend.upperACode && byte <= NativeTerminalBackend.upperZCode) {
            return byte + NativeTerminalBackend.uppercaseOffset
        }
        return byte
    }

    private func clearFlag(value: UInt32, flag: UInt32): UInt32 {
        if ((value & flag) != 0) {
            return value - flag
        }
        return value
    }

    private func asciiString(byte: UInt8): String {
        return String.fromUtf8([byte])
    }

    private func hasQueuedKeyInput(): Bool {
        mutex.lock()
        let result = testKeyQueue.size > 0
        mutex.unlock()
        return result
    }

    private func popQueuedKey(): ?TerminalKey {
        mutex.lock()
        if (testKeyQueue.size > 0) {
            let value = testKeyQueue[0]
            testKeyQueue.remove(0..1)
            mutex.unlock()
            return Some(value)
        }
        mutex.unlock()
        return None<TerminalKey>
    }
}
