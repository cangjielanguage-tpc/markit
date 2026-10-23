package markit.core.nodes

import std.collection.ArrayList
import markit.core.editing.{SourceVersionIdentity, SyntaxNodePayload}

// Providers live with their concrete node types. The core package deliberately
// does not import plugins or reconstruct a typed node from a kind string.
public interface TypedNodeCodec {
    prop codecName: String
    func accepts(node: Node): Bool
    func createShallow(node: Node): Node
    // Optional immutable representation owned by the concrete typed provider.
    func capturePayload(node: Node, source: SourceVersionIdentity): ?SyntaxNodePayload { return None }
    // Unknown virtual getters keep their explicit captured spelling.
    func rawContentFollowsSource(node: Node): Bool { return false }

    // References outside Node.children, e.g. a TOC's items collection.
    func additionalReferences(node: Node): Array<Node> { return [] }
    func restoreReferences(target: Node, references: Array<Node>): Unit {
        if (!references.isEmpty()) {
            throw IllegalArgumentException("Codec does not support additional node references")
        }
    }
}

public class NodeCodec {
    private let codecs = ArrayList<TypedNodeCodec>()

    public func register(codec: TypedNodeCodec): Unit {
        for (existing in codecs) {
            if (existing.codecName == codec.codecName) {
                throw IllegalArgumentException("Duplicate typed node codec: " + codec.codecName)
            }
        }
        codecs.add(codec)
    }

    public func supports(node: Node): Bool {
        return provider(node).isSome()
    }

    // A single detached record, deliberately excluding graph traversal. The
    // persistent store calls this only for a newly parsed/changed record.
    public func copyShallow(node: Node): Node {
        let codec = requiredProvider(node)
        let copy = codec.createShallow(node)
        if (refEq(node, copy) || !codec.accepts(copy) || !copy.children.isEmpty() || copy.parent.isSome()) {
            throw IllegalArgumentException("Invalid shallow reconstruction from codec " + codec.codecName)
        }
        node.copyBaseTo(copy)
        return copy
    }

    public func references(node: Node): Array<Node> {
        return requiredProvider(node).additionalReferences(node)
    }
    public func capturePayload(node: Node, source: SourceVersionIdentity): ?SyntaxNodePayload {
        return requiredProvider(node).capturePayload(node, source)
    }

    public func rawContentFollowsSource(node: Node, source: SourceVersionIdentity): Bool {
        return requiredProvider(node).rawContentFollowsSource(node) && node.rawContentIsSourceDerived(source)
    }

    public func restore(node: Node, references: Array<Node>): Unit {
        requiredProvider(node).restoreReferences(node, references)
    }

    public func clone(root: Node): Node {
        let originals = ArrayList<Node>()
        let copies = ArrayList<Node>()
        let result = cloneGraph(root, originals, copies)
        // addChild attaches inherited source/render hooks recursively. Restore
        // each node's own exact binding afterwards, including synthetic sources.
        for (i in 0..originals.size) {
            originals[i].copyBaseTo(copies[i])
            copies[i].parent = None
            if (let Some(parent) <- originals[i].parent) {
                if (let Some(index) <- referenceIndex(originals, parent)) {
                    copies[i].parent = Some(copies[index])
                }
            }
        }
        return result
    }

    private func cloneGraph(node: Node, originals: ArrayList<Node>, copies: ArrayList<Node>): Node {
        if (let Some(index) <- referenceIndex(originals, node)) { return copies[index] }
        let codec = requiredProvider(node)
        let copy = codec.createShallow(node)
        if (refEq(node, copy) || !codec.accepts(copy) || !copy.children.isEmpty() || copy.parent.isSome()) {
            throw IllegalArgumentException("Invalid shallow reconstruction from codec " + codec.codecName)
        }
        node.copyBaseTo(copy)
        originals.add(node)
        copies.add(copy)
        for (child in node.children) { copy.addChild(cloneGraph(child, originals, copies)) }
        let references = ArrayList<Node>()
        for (reference in codec.additionalReferences(node)) {
            references.add(cloneGraph(reference, originals, copies))
        }
        codec.restoreReferences(copy, references.toArray())
        return copy
    }

    private func provider(node: Node): ?TypedNodeCodec {
        var selected: ?TypedNodeCodec = None
        for (codec in codecs) {
            if (codec.accepts(node)) {
                if (selected.isSome()) {
                    throw IllegalArgumentException("Ambiguous typed node codec for " + node.name)
                }
                selected = Some(codec)
            }
        }
        return selected
    }

    private func requiredProvider(node: Node): TypedNodeCodec {
        if (let Some(codec) <- provider(node)) { return codec }
        throw IllegalArgumentException("No lossless typed node codec for " + node.name)
    }

    private func referenceIndex(nodes: ArrayList<Node>, target: Node): ?Int64 {
        for (i in 0..nodes.size) { if (refEq(nodes[i], target)) { return Some(i) } }
        return None
    }
}
