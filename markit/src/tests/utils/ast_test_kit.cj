package markit.tests.utils

import markit.core.nodes.Node

public class AstTestKit {
    public static func expectRoot(root: Node, childCount: Int64): Unit {
        if (root.name != "DocumentNode") {
            throw IllegalArgumentException("Expected DocumentNode, actual ${root.name}")
        }
        if (root.children.size != childCount) {
            throw IllegalArgumentException(
                "Expected DocumentNode child count ${childCount}, actual ${root.children.size}"
            )
        }
    }

    public static func child(parent: Node, index: Int64, expectedName: String): Node {
        if (index < 0 || index >= parent.children.size) {
            throw IllegalArgumentException(
                "Missing child ${index} on ${parent.name}; child count ${parent.children.size}"
            )
        }

        let actual = parent.children[index]
        if (actual.name != expectedName) {
            throw IllegalArgumentException(
                "Expected child ${index} of ${parent.name} to be ${expectedName}, actual ${actual.name}"
            )
        }
        return actual
    }

    public static func expectSpan(
        node: Node,
        startByte: Int64,
        endByte: Int64,
        startRune: Int64,
        endRune: Int64
    ): Unit {
        if (node.sourceSpan.startByte != startByte || node.sourceSpan.endByte != endByte ||
            node.sourceSpan.startRune != startRune || node.sourceSpan.endRune != endRune) {
            throw IllegalArgumentException(
                "Expected ${node.name} span b=${startByte}..${endByte} r=${startRune}..${endRune}, " +
                "actual b=${node.sourceSpan.startByte}..${node.sourceSpan.endByte} " +
                "r=${node.sourceSpan.startRune}..${node.sourceSpan.endRune}"
            )
        }
    }

    public static func expectLeaf(node: Node): Unit {
        if (!node.children.isEmpty()) {
            throw IllegalArgumentException(
                "Expected ${node.name} to be a leaf, actual child count ${node.children.size}"
            )
        }
    }

    public static func expectExactJson(root: Node, expected: String): Unit {
        let actual = root.toJson()
        if (actual != expected) {
            throw IllegalArgumentException(
                "AST JSON mismatch.\nExpected:\n${expected}\nActual:\n${actual}"
            )
        }
    }

    public static func expectNoNode(root: Node, nodeName: String): Unit {
        let actual = countNodes(root, nodeName)
        if (actual != 0) {
            throw IllegalArgumentException(
                "Expected no ${nodeName} nodes, actual ${actual}"
            )
        }
    }

    public static func expectNodeCount(root: Node, nodeName: String, expected: Int64): Unit {
        let actual = countNodes(root, nodeName)
        if (actual != expected) {
            throw IllegalArgumentException(
                "Expected ${expected} ${nodeName} node(s), actual ${actual}"
            )
        }
    }

    public static func countNodes(root: Node, nodeName: String): Int64 {
        var count: Int64 = if (root.name == nodeName) { 1 } else { 0 }
        for (child in root.children) {
            count += countNodes(child, nodeName)
        }
        return count
    }
}
