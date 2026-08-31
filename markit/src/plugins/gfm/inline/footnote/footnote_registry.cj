package markit.plugins.gfm.inline.footnote

import std.collection.{ArrayList, HashMap}
import markit.core.session.{SessionState, SessionStateSnapshot}

public class FootnoteDefinition {
    public let id: String
    public var content: String
    public var number: Int64
    public let references = ArrayList<Int64>()

    public init(id: String, content: String, number!: Int64 = 0) {
        this.id = id
        this.content = content
        this.number = number
    }
}

public class FootnoteRegistry <: SessionState {
    private let definitions = HashMap<String, FootnoteDefinition>()
    private var nextNumber: Int64 = 1

    public func addDefinition(id: String, content: String): Bool {
        if (let Some(existing) <- definitions.get(id)) {
            if (existing.content.isEmpty()) {
                existing.content = content
                return true
            }
            return false
        }
        definitions[id] = FootnoteDefinition(id, content)
        return true
    }

    public func addReference(id: String, offset: Int64): Int64 {
        if (!definitions.contains(id)) {
            definitions[id] = FootnoteDefinition(id, "")
        }
        let definition = definitions[id]
        if (definition.number == 0) {
            definition.number = nextNumber
            nextNumber += 1
        }
        definition.references.add(offset)
        return definition.number
    }

    public func getDefinition(id: String): ?FootnoteDefinition {
        return definitions.get(id)
    }

    public func reset(): Unit {
        definitions.clear()
        nextNumber = 1
    }

    public func snapshot(): SessionStateSnapshot {
        return SessionStateSnapshot("FootnoteRegistry")
    }
}
