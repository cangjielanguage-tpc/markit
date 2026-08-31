package dochir.docgen

import markit.dsl.*
import markit.plugins.standard.inline.link.LinkConfig
import stdx.chir.*

public class EmitMarkdown {
    private static let options = DslOptions(linkConfig: LinkConfig(outputExtension: "md"))

    public static func document(blocks: Array<BlockSpec>): DslDocument {
        return md(options, blocks)
    }

    public static func declarationBlock(declaration: String): BlockSpec {
        return codeBlock("cangjie", declaration)
    }

    public static func declarationCell(declaration: String): TableCellSpec {
        return cell(code(declaration))
    }

    public static func dumpPackageIndex(pkg: Package, outDir: String): Unit {
        EmitPackage.emitIndex(pkg, outDir, [])
    }
}
