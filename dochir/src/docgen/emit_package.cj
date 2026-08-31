package dochir.docgen

import std.collection.ArrayList
import markit.dsl.*
import stdx.chir.*

public class EmitPackage {
    public static func emitIndex(
        pkg: Package,
        outDir: String,
        subpackages: Array<Package>
    ): Unit {
        let blocks = ArrayList<BlockSpec>()
        blocks.add(h1(pkg.name))
        blocks.add(divider())

        if (!subpackages.isEmpty()) {
            blocks.add(subpackagesTable(subpackages))
        }

        appendOptional(blocks, classLikeGroup("Classes", pkg.classDefs, true, pkg.name))
        appendOptional(blocks, classLikeGroup("Interfaces", pkg.classDefs, false, pkg.name))
        appendOptional(blocks, structGroup(pkg.structDefs, pkg.name))
        appendOptional(blocks, enumGroup(pkg.enumDefs, pkg.name))
        appendOptional(blocks, typeGroupFromExtends(pkg.extendDefs, pkg.name))
        appendOptional(blocks, globalVarGroup(pkg.globalVars, pkg.name))
        appendOptional(blocks, functionGroup(pkg.functions, pkg.name))
        appendDetails(blocks, "Global Variable Details", EmitDetails.globalVars(pkg.globalVars, pkg.name))
        appendDetails(blocks, "Function Details", EmitDetails.functions(pkg.functions, pkg.name))

        EmitMarkdown.document(blocks.toArray()).dumpMarkdown(outDir, filename: Pathing.packageIndexFile())
    }

    private static func subpackagesTable(subpackages: Array<Package>): BlockSpec {
        let rows = Array<TableRowSpec>(subpackages.size) { i =>
            let sp = subpackages[i]
            row(
                cell(sp.name),
                cell(link("../" + Pathing.packageNameToPath(sp.name) + "/" + Pathing.packageIndexFile(), "index"))
            )
        }
        return table(
            header("Name", "Link"),
            rows
        )
    }

    private static func classLikeGroup(
        title: String,
        defs: Array<ClassLikeDef>,
        wantClass: Bool,
        packageName: String
    ): ?BlockSpec {
        let filtered = ArrayList<ClassLikeDef>()
        for (d in defs) {
            if (d.isClass() == wantClass && ApiFormat.isDocumentable(d, packageName)) {
                filtered.add(d)
            }
        }
        if (filtered.isEmpty()) {
            return None
        }

        let rows = Array<TableRowSpec>(filtered.size) { i =>
            let d = filtered[i]
            let name = d.srcCodeName
            let decl = ApiFormat.typeDeclaration(d)
            row(
                cell(link(Pathing.elementFileName(name), name)),
                EmitMarkdown.declarationCell(decl),
                cell(ApiFormat.description(d))
            )
        }
        return Some(group(title, rows))
    }

    private static func structGroup(defs: Array<StructDef>, packageName: String): ?BlockSpec {
        if (defs.isEmpty()) {
            return None
        }
        let filtered = ArrayList<StructDef>()
        for (d in defs) {
            if (ApiFormat.isDocumentable(d, packageName)) {
                filtered.add(d)
            }
        }
        if (filtered.isEmpty()) {
            return None
        }
        let rows = Array<TableRowSpec>(filtered.size) { i =>
            let d = filtered[i]
            let name = d.srcCodeName
            let decl = ApiFormat.typeDeclaration(d)
            row(
                cell(link(Pathing.elementFileName(name), name)),
                EmitMarkdown.declarationCell(decl),
                cell(ApiFormat.description(d))
            )
        }
        return Some(group("Structs", rows))
    }

    private static func enumGroup(defs: Array<EnumDef>, packageName: String): ?BlockSpec {
        if (defs.isEmpty()) {
            return None
        }
        let filtered = ArrayList<EnumDef>()
        for (d in defs) {
            if (ApiFormat.isDocumentable(d, packageName)) {
                filtered.add(d)
            }
        }
        if (filtered.isEmpty()) {
            return None
        }
        let rows = Array<TableRowSpec>(filtered.size) { i =>
            let d = filtered[i]
            let name = d.srcCodeName
            let decl = ApiFormat.typeDeclaration(d)
            row(
                cell(link(Pathing.elementFileName(name), name)),
                EmitMarkdown.declarationCell(decl),
                cell(ApiFormat.description(d))
            )
        }
        return Some(group("Enums", rows))
    }

    private static func typeGroupFromExtends(defs: Array<ExtendDef>, packageName: String): ?BlockSpec {
        if (defs.isEmpty()) {
            return None
        }
        let filtered = ArrayList<ExtendDef>()
        for (d in defs) {
            if (ApiFormat.isDocumentable(d, packageName)) {
                filtered.add(d)
            }
        }
        if (filtered.isEmpty()) {
            return None
        }
        let rows = Array<TableRowSpec>(filtered.size) { i =>
            let d = filtered[i]
            let name = d.identifier
            let decl = ApiFormat.typeDeclaration(d)
            row(
                cell(link(Pathing.elementFileName(name), name)),
                EmitMarkdown.declarationCell(decl),
                cell(ApiFormat.description(d))
            )
        }
        return Some(group("Types", rows))
    }

    private static func globalVarGroup(defs: Array<GlobalVar>, packageName: String): ?BlockSpec {
        let filtered = ArrayList<GlobalVar>()
        for (d in defs) {
            if (ApiFormat.isDocumentable(d, packageName)) {
                filtered.add(d)
            }
        }
        if (filtered.isEmpty()) {
            return None
        }
        let rows = Array<TableRowSpec>(filtered.size) { i =>
            let d = filtered[i]
            row(
                cell(ApiFormat.sourceName(d)),
                EmitMarkdown.declarationCell(ApiFormat.globalVarDeclaration(d)),
                cell(ApiFormat.description(d))
            )
        }
        return Some(group("Global Variables", rows))
    }

    private static func functionGroup(defs: Array<Function>, packageName: String): ?BlockSpec {
        let filtered = ArrayList<Function>()
        for (d in defs) {
            if (ApiFormat.isDocumentable(d, packageName) && !d.isMemberMethod()) {
                filtered.add(d)
            }
        }
        if (filtered.isEmpty()) {
            return None
        }
        let rows = Array<TableRowSpec>(filtered.size) { i =>
            let d = filtered[i]
            row(
                cell(ApiFormat.sourceName(d)),
                EmitMarkdown.declarationCell(ApiFormat.functionDeclaration(d)),
                cell(ApiFormat.description(d))
            )
        }
        return Some(group("Functions", rows))
    }

    private static func group(title: String, rows: Array<TableRowSpec>): BlockSpec {
        return universalBlock(
            h2(title),
            table(
                header("Name", "Declaration", "Description"),
                rows
            )
        )
    }

    private static func appendOptional(blocks: ArrayList<BlockSpec>, block: ?BlockSpec): Unit {
        if (let Some(value) <- block) {
            blocks.add(value)
        }
    }

    private static func appendDetails(
        blocks: ArrayList<BlockSpec>,
        title: String,
        details: Array<BlockSpec>
    ): Unit {
        if (details.isEmpty()) {
            return
        }
        blocks.add(h2(title))
        for (block in details) {
            blocks.add(block)
        }
    }
}
