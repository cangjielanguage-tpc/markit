package commandline.terminal

import std.collection.ArrayList
import std.sync.Mutex

@When[os == "Windows"]
public class NativeTerminalBackend <: TerminalBackend {
    private let testKeyQueue: ArrayList<TerminalKey>
    private let mutex: Mutex
    private var usesQueuedKeys: Bool = false

    public init(testKeyQueue: ArrayList<TerminalKey>, mutex: Mutex) {
        this.testKeyQueue = testKeyQueue
        this.mutex = mutex
    }

    public func supportsKeyNavigation(): Bool {
        return hasQueuedKeyInput()
    }

    public func enterKeyMode(): Bool {
        if (hasQueuedKeyInput()) {
            usesQueuedKeys = true
            return true
        }
        return false
    }

    public func leaveKeyMode(): Unit {
        usesQueuedKeys = false
    }

    public func readKey(): TerminalKey {
        match (popQueuedKey()) {
            case Some(value) => return value
            case None => return TerminalKey.Eof
        }
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
