package markit.plugins.commonmark.inline.entity_reference

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public enum EntityType {
    |Named
    |Decimal
    |Hexadecimal
}

public class EntityReferenceNode <: Node {
    public let entityType: EntityType
    public let entityValue: String
    public let entityReference: String

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        entityType: EntityType,
        entityValue: String,
        entityReference: String
    ) {
        super("EntityReference", id: id, sourceSpan: sourceSpan, literal: entityReference)
        this.entityType = entityType
        this.entityValue = entityValue
        this.entityReference = entityReference
    }

    public override prop name: String {
        get() {
            return "EntityReferenceNode"
        }
    }

    public override func toString(): String {
        return "${name} [entityType=${entityTypeName()}, entityValue=${entityValue}] (${rawContent()})"
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("entityType").value(entityTypeName())
        w.name("entityValue").value(entityValue)
        w.name("entityReference").value(entityReference)
        return w
    }

    public func entityTypeName(): String {
        match (entityType) {
            case Named => return "Named"
            case Decimal => return "Decimal"
            case Hexadecimal => return "Hexadecimal"
        }
    }

    public func isNamed(): Bool {
        match (entityType) {
            case Named => return true
            case _ => return false
        }
    }
}
