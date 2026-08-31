package markit.plugins.standard.inline.reference_link

import std.collection.ArrayList
import std.collection.HashMap
import markit.core.nodes.Node
import markit.core.session.SessionState
import markit.core.session.SessionStateSnapshot

public class LinkDefinition {
    public let url: String
    public let title: String

    public init(url: String, title: String) {
        this.url = url
        this.title = title
    }
}

public class ReferenceLinkRegistry <: SessionState {
    private let definitions = HashMap<String, LinkDefinition>()
    private let pendingRefs = ArrayList<Node>()
    private let pendingImages = ArrayList<Node>()

    public func addDefinition(label: String, url: String, title: String): Bool {
        let key = toLowerCase(label)
        if (definitions.contains(key)) {
            return false
        }
        definitions[key] = LinkDefinition(url, title)
        return true
    }

    public func getDefinition(label: String): ?LinkDefinition {
        return definitions.get(toLowerCase(label))
    }

    public func hasDefinition(label: String): Bool {
        return definitions.contains(toLowerCase(label))
    }

    public func addUnresolvedRef(node: Node): Unit {
        pendingRefs.add(node)
    }

    public func addUnresolvedImage(node: Node): Unit {
        pendingImages.add(node)
    }

    public func getUnresolvedRefs(): ArrayList<Node> {
        return pendingRefs
    }

    public func getUnresolvedImages(): ArrayList<Node> {
        return pendingImages
    }

    public func definitionCount(): Int64 {
        return definitions.size
    }

    public func reset(): Unit {
        definitions.clear()
        pendingRefs.clear()
        pendingImages.clear()
    }

    public func snapshot(): SessionStateSnapshot {
        return SessionStateSnapshot("ReferenceLinkRegistry")
    }

    private static func toLowerCase(s: String): String {
        var needsConversion = false
        for (rune in s.runes()) {
            if (rune.isAsciiUpperCase()) {
                needsConversion = true
                break
            }
        }
        if (!needsConversion) {
            return s
        }
        let builder = StringBuilder(s.size)
        for (rune in s.runes()) {
            if (rune.isAsciiUpperCase()) {
                builder.append(rune.toAsciiLowerCase())
            } else {
                builder.append(rune)
            }
        }
        return builder.toString()
    }
}
