package markit.core.session

import std.collection.HashMap

public class SessionSymbolTableStore {
    private let states = HashMap<String, SessionState>()

    public func register<T>(
        key: SessionStateKey<T>,
        factory: () -> T
    ): Unit where T <: SessionState {
        registerErased(key.dynamicName, { => factory() })
    }

    public func registerErased(dynamicName: String, factory: () -> SessionState): Unit {
        if (states.contains(dynamicName)) {
            throw IllegalArgumentException("Duplicate session state: ${dynamicName}")
        }
        states[dynamicName] = factory()
    }

    public func get<T>(key: SessionStateKey<T>): T where T <: SessionState {
        let state = states.get(key.dynamicName).getOrThrow()
        return (state as T).getOrThrow()
    }

    public func get(name: String): ?SessionState {
        return states.get(name)
    }

    public operator func [](name: String): ?SessionState {
        return get(name)
    }
}
