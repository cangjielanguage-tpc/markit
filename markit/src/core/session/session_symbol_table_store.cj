package markit.core.session

import std.collection.{ArrayList, HashMap}

public class SessionSymbolTableCheckpoint {
    internal SessionSymbolTableCheckpoint(internal let owner: SessionSymbolTableStore, internal let names: Array<String>, internal let payloads: Array<SessionStateSnapshot>) {}
}

// An active sandbox keeps the original instances untouched. Restoring its root
// does not invoke provider code and cannot fail halfway through the state set.
public class SessionSymbolTableSandbox {
    internal let owner: SessionSymbolTableStore
    internal let previous: HashMap<String, SessionState>
    internal let depth: Int64
    internal var active: Bool = true
    internal SessionSymbolTableSandbox(owner: SessionSymbolTableStore, previous: HashMap<String, SessionState>, depth: Int64) {
        this.owner = owner
        this.previous = previous
        this.depth = depth
    }
}

public class SessionSymbolTableStore {
    private var states = HashMap<String, SessionState>()
    private let factories: ?HashMap<String, () -> SessionState>
    private var sandboxDepth: Int64 = 0
    private let sandboxes: ?ArrayList<SessionSymbolTableSandbox>
    private prop scopeStack: ArrayList<SessionSymbolTableSandbox> { get() { return sandboxes.getOrThrow() } }

    public SessionSymbolTableStore(checkpointEnabled!: Bool = false) {
        factories = if (checkpointEnabled) { Some(HashMap<String, () -> SessionState>()) } else { None }
        sandboxes = if (checkpointEnabled) { Some(ArrayList<SessionSymbolTableSandbox>()) } else { None }
    }

    public func register<T>(
        key: SessionStateKey<T>,
        factory: () -> T
    ): Unit where T <: SessionState {
        registerErased(key.dynamicName, { => factory() })
    }

    public func registerErased(dynamicName: String, factory: () -> SessionState): Unit {
        if (sandboxDepth > 0) { throw IllegalArgumentException("Cannot register state inside a sandbox") }
        if (states.contains(dynamicName)) {
            throw IllegalArgumentException("Duplicate session state: ${dynamicName}")
        }
        let state = factory()
        states[dynamicName] = state
        if (let Some(enabled) <- factories) { enabled[dynamicName] = factory }
    }

    public func get<T>(key: SessionStateKey<T>): T where T <: SessionState {
        let state = get(key.dynamicName).getOrThrow()
        return (state as T).getOrThrow()
    }

    public func get(name: String): ?SessionState {
        if (let Some(state) <- states.get(name)) { return Some(state) }
        if (sandboxDepth > 0) {
            if (let Some(original) <- visibleState(name)) {
                let factory = factories.getOrThrow().get(name).getOrThrow()
                let state = factory()
                if (!state.supportsStateRestore || !state.restoreSnapshot(freezeSnapshot(name, original))) {
                    throw IllegalArgumentException("Session state refused sandbox restore: " + name)
                }
                states[name] = state
                return Some(state)
            }
        }
        return None
    }

    public operator func [](name: String): ?SessionState {
        return get(name)
    }

    public prop supportsCheckpoint: Bool {
        get() {
            if (factories.isNone()) { return false }
            for ((name, _) in factories.getOrThrow()) {
                if (!visibleState(name).getOrThrow().supportsStateRestore) { return false }
            }
            return true
        }
    }

    public func checkpoint(): SessionSymbolTableCheckpoint {
        if (factories.isNone()) { throw IllegalArgumentException("Session checkpoints were not enabled") }
        let names = ArrayList<String>()
        let payloads = ArrayList<SessionStateSnapshot>()
        for ((name, _) in factories.getOrThrow()) {
            let state = visibleState(name).getOrThrow()
            names.add(name)
            payloads.add(freezeSnapshot(name, state))
        }
        return SessionSymbolTableCheckpoint(this, names.toArray(), payloads.toArray())
    }

    public func restore(checkpoint: SessionSymbolTableCheckpoint): Bool {
        if (let Some(restored) <- prepare(checkpoint)) {
            states = restored
            return true
        }
        return false
    }

    public func beginSandbox(checkpoint: SessionSymbolTableCheckpoint): SessionSymbolTableSandbox {
        let restored = prepare(checkpoint).getOrThrow()
        sandboxDepth += 1
        let sandbox = SessionSymbolTableSandbox(this, states, sandboxDepth)
        states = restored
        scopeStack.add(sandbox)
        return sandbox
    }

    // Candidate attempts clone only states actually requested through get().
    // Untouched tables remain behind the previous immutable scope root.
    public func beginLazySandbox(): SessionSymbolTableSandbox {
        if (!supportsCheckpoint) { throw IllegalArgumentException("Session states do not support transactional probes") }
        sandboxDepth += 1
        let sandbox = SessionSymbolTableSandbox(this, states, sandboxDepth)
        states = HashMap<String, SessionState>()
        scopeStack.add(sandbox)
        return sandbox
    }

    public func endSandbox(sandbox: SessionSymbolTableSandbox): Unit {
        if (!refEq(sandbox.owner, this) || !sandbox.active || sandbox.depth != sandboxDepth) {
            throw IllegalArgumentException("Invalid or closed session state sandbox")
        }
        states = sandbox.previous
        sandbox.active = false
        sandboxDepth -= 1
        scopeStack.remove(at: scopeStack.size - 1)
    }

    public func commitSandbox(sandbox: SessionSymbolTableSandbox): Unit {
        if (!refEq(sandbox.owner, this) || !sandbox.active || sandbox.depth != sandboxDepth) {
            throw IllegalArgumentException("Invalid or closed session state sandbox")
        }
        for ((name, state) in states) { sandbox.previous[name] = state }
        states = sandbox.previous
        sandbox.active = false
        sandboxDepth -= 1
        scopeStack.remove(at: scopeStack.size - 1)
    }

    private func visibleState(name: String): ?SessionState {
        if (let Some(state) <- states.get(name)) { return Some(state) }
        var index = scopeStack.size
        while (index > 0) {
            index -= 1
            if (let Some(state) <- scopeStack[index].previous.get(name)) { return Some(state) }
        }
        return None
    }

    private func freezeSnapshot(name: String, state: SessionState): SessionStateSnapshot {
        if (!state.supportsStateRestore) { throw IllegalArgumentException("Session state has no restore codec: " + name) }
        let snapshot = state.snapshot()
        if (snapshot.dynamicName != name || !snapshot.hasRestorablePayload) {
            throw IllegalArgumentException("Session state returned an incomplete checkpoint: " + name)
        }
        let payload = snapshot.payloadCopy().getOrThrow()
        return RestorableSessionStateSnapshot(name, snapshot.sourceVersion, snapshot.contextFingerprint, payload)
    }

    private func prepare(checkpoint: SessionSymbolTableCheckpoint): ?HashMap<String, SessionState> {
        if (!refEq(checkpoint.owner, this)) { return None }
        let enabled = factories.getOrThrow()
        if (checkpoint.names.size != enabled.size) { return None }
        let restored = HashMap<String, SessionState>()
        for (i in 0..checkpoint.names.size) {
            let name = checkpoint.names[i]
            if (let Some(factory) <- enabled.get(name)) {
                let state = factory()
                if (!state.supportsStateRestore || !state.restoreSnapshot(checkpoint.payloads[i])) { return None }
                restored[name] = state
            } else { return None }
        }
        return Some(restored)
    }
}
