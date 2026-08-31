package markit.plugins.gfm.block.table

import std.collection.ArrayList
import markit.core.nodes.Node
import markit.core.plugin.{Plugin, PluginRegistrar}
import markit.plugins.standard.block.divider.DividerNode

public class TablePlugin <: Plugin {
    private let config: TableConfig

    public init(config!: TableConfig = TableConfig()) {
        this.config = config
    }

    public prop name: String {
        get() {
            return "TablePlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerContinuationBlockParser(TableParser())
        if (config.enableThreeLineTable) {
            registrar.registerNodeBatchProcessor(TableThreeLineProcessor())
            registrar.registerPostFinalizeProcessor({ root, _ =>
                markThreeLineTables(root)
            })
        }
        registrar.registerHtmlRenderer("Table", TableHtmlRenderer())
        registrar.registerHtmlRenderer("TableRow", TableRowHtmlRenderer())
        registrar.registerHtmlRenderer("TableCell", TableCellHtmlRenderer())
        registrar.registerMarkdownRenderer("Table", TableMarkdownRenderer())
        registrar.registerMarkdownRenderer("TableRow", TableRowMarkdownRenderer())
        registrar.registerMarkdownRenderer("TableCell", TableCellMarkdownRenderer())
        registrar.registerTypstRenderer("Table", TableTypstRenderer())
        registrar.registerTypstRenderer("TableRow", TableRowTypstRenderer())
        registrar.registerTypstRenderer("TableCell", TableCellTypstRenderer())
    }

    private static func markThreeLineTables(root: Node): Unit {
        mark(root.children)
    }

    private static func mark(nodes: ArrayList<Node>): Unit {
        var index: Int64 = 0
        while (index + 2 < nodes.size) {
            let first = nodes[index]
            let second = nodes[index + 1]
            let third = nodes[index + 2]
            if (isThreeLineDivider(first) && second.kind == "Table" && isThreeLineDivider(third)) {
                second.setString("tableStyle", "three-line")
                first.setString("render", "false")
                third.setString("render", "false")
                index += 3
                continue
            }
            index += 1
        }
        for (node in nodes) {
            if (!node.children.isEmpty()) {
                mark(node.children)
            }
        }
    }

    private static func isThreeLineDivider(node: Node): Bool {
        if (let divider: DividerNode <- node) {
            return divider.isHyphenLine()
        }
        return false
    }
}
