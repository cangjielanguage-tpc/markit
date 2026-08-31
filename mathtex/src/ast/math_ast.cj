package mathtex.ast

import std.collection.ArrayList

public class MathSourceSpan {
    public let startByte: Int64
    public let endByte: Int64
    public let startRune: Int64
    public let endRune: Int64

    public init(startByte!: Int64 = 0, endByte!: Int64 = 0, startRune!: Int64 = 0, endRune!: Int64 = 0) {
        this.startByte = startByte
        this.endByte = endByte
        this.startRune = startRune
        this.endRune = endRune
    }
}

public open class MathNode {
    public let kind: String
    public let sourceSpan: MathSourceSpan
    public let literal: String
    public let children: Array<MathNode>

    public init(
        kind: String,
        sourceSpan!: MathSourceSpan = MathSourceSpan(),
        literal!: String = "",
        children!: Array<MathNode> = []
    ) {
        this.kind = kind
        this.sourceSpan = sourceSpan
        this.literal = literal
        this.children = children
    }
}

public class MathSequenceNode <: MathNode {
    public init(sourceSpan: MathSourceSpan, children: Array<MathNode>) {
        super("Sequence", sourceSpan: sourceSpan, children: children)
    }
}

public class MathSymbolNode <: MathNode {
    public let value: String
    public let family: String

    public init(value: String, sourceSpan: MathSourceSpan, literal!: String = "", family!: String = "ord") {
        super("Symbol", sourceSpan: sourceSpan, literal: if (literal.isEmpty()) { value } else { literal })
        this.value = value
        this.family = family
    }
}

public class MathTextNode <: MathNode {
    public let text: String

    public init(text: String, sourceSpan: MathSourceSpan, literal!: String = "") {
        super("Text", sourceSpan: sourceSpan, literal: if (literal.isEmpty()) { text } else { literal })
        this.text = text
    }
}

public class MathGroupNode <: MathNode {
    public init(sourceSpan: MathSourceSpan, children: Array<MathNode>) {
        super("Group", sourceSpan: sourceSpan, children: children)
    }
}

public class MathCommandNode <: MathNode {
    public let name: String

    public init(name: String, sourceSpan: MathSourceSpan, literal: String, children!: Array<MathNode> = []) {
        super("Command", sourceSpan: sourceSpan, literal: literal, children: children)
        this.name = name
    }
}

public class MathEnvironmentNode <: MathNode {
    public let name: String
    public let rows: Array<Array<MathNode>>
    public let columnAlignments: Array<String>
    public let columnSeparatorCounts: Array<Int64>

    public init(
        name: String,
        rows: Array<Array<MathNode>>,
        sourceSpan: MathSourceSpan,
        literal: String,
        columnAlignments!: Array<String> = [],
        columnSeparatorCounts!: Array<Int64> = []
    ) {
        super("Environment", sourceSpan: sourceSpan, literal: literal, children: flattenRows(rows))
        this.name = name
        this.rows = rows
        this.columnAlignments = columnAlignments
        this.columnSeparatorCounts = columnSeparatorCounts
    }

    private static func flattenRows(rows: Array<Array<MathNode>>): Array<MathNode> {
        let nodes = ArrayList<MathNode>()
        for (row in rows) {
            for (cell in row) {
                nodes.add(cell)
            }
        }
        return nodes.toArray()
    }
}

public class MathDelimitedNode <: MathNode {
    public let left: MathNode
    public let body: MathNode
    public let right: MathNode

    public init(left: MathNode, body: MathNode, right: MathNode, sourceSpan: MathSourceSpan, literal: String) {
        super("Delimited", sourceSpan: sourceSpan, literal: literal, children: [left, body, right])
        this.left = left
        this.body = body
        this.right = right
    }
}

public class MathSizingNode <: MathNode {
    public let size: String
    public let body: MathNode

    public init(size: String, body: MathNode, sourceSpan: MathSourceSpan, literal: String) {
        super("Sizing", sourceSpan: sourceSpan, literal: literal, children: [body])
        this.size = size
        this.body = body
    }
}

public class MathColorNode <: MathNode {
    public let color: String
    public let body: MathNode

    public init(color: String, body: MathNode, sourceSpan: MathSourceSpan, literal: String) {
        super("Color", sourceSpan: sourceSpan, literal: literal, children: [body])
        this.color = color
        this.body = body
    }
}

public class MathSupSubNode <: MathNode {
    public let base: MathNode
    public let sup: ?MathNode
    public let sub: ?MathNode

    public init(base: MathNode, sourceSpan: MathSourceSpan, sup!: ?MathNode = None, sub!: ?MathNode = None) {
        super("SupSub", sourceSpan: sourceSpan, children: childrenOf(base, sup, sub))
        this.base = base
        this.sup = sup
        this.sub = sub
    }

    private static func childrenOf(base: MathNode, sup: ?MathNode, sub: ?MathNode): Array<MathNode> {
        let nodes = ArrayList<MathNode>()
        nodes.add(base)
        if (let Some(node) <- sup) {
            nodes.add(node)
        }
        if (let Some(node) <- sub) {
            nodes.add(node)
        }
        return nodes.toArray()
    }
}

public class MathLimitsNode <: MathNode {
    public let base: MathNode
    public let mode: String

    public init(base: MathNode, mode: String, sourceSpan: MathSourceSpan, literal: String) {
        super("Limits", sourceSpan: sourceSpan, literal: literal, children: [base])
        this.base = base
        this.mode = mode
    }
}

public class MathFractionNode <: MathNode {
    public let numerator: MathNode
    public let denominator: MathNode

    public init(numerator: MathNode, denominator: MathNode, sourceSpan: MathSourceSpan) {
        super("Fraction", sourceSpan: sourceSpan, literal: "\\frac", children: [numerator, denominator])
        this.numerator = numerator
        this.denominator = denominator
    }
}

public class MathSqrtNode <: MathNode {
    public let radicand: MathNode
    public let index: ?MathNode

    public init(radicand: MathNode, sourceSpan: MathSourceSpan, index!: ?MathNode = None) {
        super("Sqrt", sourceSpan: sourceSpan, literal: "\\sqrt", children: childrenOf(radicand, index))
        this.radicand = radicand
        this.index = index
    }

    private static func childrenOf(radicand: MathNode, index: ?MathNode): Array<MathNode> {
        let nodes = ArrayList<MathNode>()
        nodes.add(radicand)
        if (let Some(node) <- index) {
            nodes.add(node)
        }
        return nodes.toArray()
    }
}

public class MathErrorNode <: MathNode {
    public let message: String

    public init(message: String, sourceSpan: MathSourceSpan, literal: String) {
        super("Error", sourceSpan: sourceSpan, literal: literal)
        this.message = message
    }
}

public class MathExpression {
    public let root: MathNode
    public let source: String
    public let displayMode: Bool

    public init(root: MathNode, source: String, displayMode!: Bool = false) {
        this.root = root
        this.source = source
        this.displayMode = displayMode
    }
}
