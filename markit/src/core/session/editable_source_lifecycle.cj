package markit.core.session

import std.collection.HashMap
import markit.core.editing.SourceVersionIdentity
import markit.core.source.{EditableRopeStore, EditableSourceLease}

// Bridge lives above source so the source package never depends on session.
// Each current/snapshot/cache count group owns one real source epoch lease.
public class EditableSourceLifecycle {
    public let store: EditableRopeStore
    public let retention: SourceVersionRetention
    private let epochs: HashMap<Int64, EditableSourceLease>

    public init(store: EditableRopeStore) {
        this.store = store
        let epochPins = HashMap<Int64, EditableSourceLease>()
        this.epochs = epochPins
        retention = SourceVersionRetention(store.current.identity.documentId,
            onRetain: { source: SourceVersionIdentity =>
                epochPins[source.version] = store.retainVersion(source.version)
            },
            onRelease: { source: SourceVersionIdentity =>
                let lease = epochPins.get(source.version).getOrThrow()
                lease.release()
                epochPins.remove(source.version)
            })
        retention.setCurrent(store.current.identity.version)
    }

    // Invoke after the engine has installed leases for every active raw birth
    // epoch and released its previous transaction/snapshot roots.
    public func pruneHistory(): Int64 { return store.pruneHistory() }
}
