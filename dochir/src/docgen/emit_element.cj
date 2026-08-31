package dochir.docgen

import std.collection.ArrayList
import markit.dsl.*
import stdx.chir.*

public class EmitElement {
    public static func emitClassLike(def: ClassLikeDef, outDir: String): Unit {
        let blocks = baseBlocks(
            def.packageName,
            def.srcCodeName,
            ApiFormat.typeDeclaration(def),
            ApiFormat.description(def),
            ApiFormat.supertypes(def)
        )
        appendOptional(blocks, "Properties", EmitMembers.instanceVars(def.instanceVars))
        appendOptional(blocks, "Static Properties", EmitMembers.staticVars(def.staticVars))
        appendOptional(blocks, "Constructors", EmitMembers.constructors(def.methods))
        appendOptional(blocks, "Methods", EmitMembers.methods(def.methods))
        appendDetails(blocks, "Property Details", EmitDetails.instanceVars(def.instanceVars))
        appendDetails(blocks, "Static Property Details", EmitDetails.staticVars(def.staticVars))
        appendDetails(blocks, "Constructor Details", EmitDetails.constructors(def.methods))
        appendDetails(blocks, "Method Details", EmitDetails.methods(def.methods))
        EmitMarkdown.document(blocks.toArray()).dumpMarkdown(outDir, filename: Pathing.elementFileName(def.srcCodeName))
    }

    public static func emitStruct(def: StructDef, outDir: String): Unit {
        let blocks = baseBlocks(
            def.packageName,
            def.srcCodeName,
            ApiFormat.typeDeclaration(def),
            ApiFormat.description(def),
            ApiFormat.supertypes(def)
        )
        appendOptional(blocks, "Properties", EmitMembers.instanceVars(def.instanceVars))
        appendOptional(blocks, "Static Properties", EmitMembers.staticVars(def.staticVars))
        appendOptional(blocks, "Constructors", EmitMembers.constructors(def.methods))
        appendOptional(blocks, "Methods", EmitMembers.methods(def.methods))
        appendDetails(blocks, "Property Details", EmitDetails.instanceVars(def.instanceVars))
        appendDetails(blocks, "Static Property Details", EmitDetails.staticVars(def.staticVars))
        appendDetails(blocks, "Constructor Details", EmitDetails.constructors(def.methods))
        appendDetails(blocks, "Method Details", EmitDetails.methods(def.methods))
        EmitMarkdown.document(blocks.toArray()).dumpMarkdown(outDir, filename: Pathing.elementFileName(def.srcCodeName))
    }

    public static func emitEnum(def: EnumDef, outDir: String): Unit {
        let blocks = baseBlocks(
            def.packageName,
            def.srcCodeName,
            ApiFormat.typeDeclaration(def),
            ApiFormat.description(def),
            ApiFormat.supertypes(def)
        )
        appendOptional(blocks, "Constructors", EmitMembers.enumConstructors(def.constructors))
        appendOptional(blocks, "Properties", EmitMembers.instanceVars(def.instanceVars))
        appendOptional(blocks, "Static Properties", EmitMembers.staticVars(def.staticVars))
        appendOptional(blocks, "Methods", EmitMembers.methods(def.methods))
        appendDetails(blocks, "Constructor Details", EmitDetails.enumConstructors(def.constructors))
        appendDetails(blocks, "Property Details", EmitDetails.instanceVars(def.instanceVars))
        appendDetails(blocks, "Static Property Details", EmitDetails.staticVars(def.staticVars))
        appendDetails(blocks, "Method Details", EmitDetails.methods(def.methods))
        EmitMarkdown.document(blocks.toArray()).dumpMarkdown(outDir, filename: Pathing.elementFileName(def.srcCodeName))
    }

    public static func emitExtend(def: ExtendDef, outDir: String): Unit {
        let blocks = baseBlocks(
            def.packageName,
            def.identifier,
            ApiFormat.typeDeclaration(def),
            ApiFormat.description(def),
            ApiFormat.supertypes(def)
        )
        appendOptional(blocks, "Methods", EmitMembers.methods(def.methods))
        appendDetails(blocks, "Method Details", EmitDetails.methods(def.methods))
        EmitMarkdown.document(blocks.toArray()).dumpMarkdown(outDir, filename: Pathing.elementFileName(def.identifier))
    }

    private static func baseBlocks(
        packageName: String,
        name: String,
        declaration: String,
        description: String,
        supertypes: Array<String>
    ): ArrayList<BlockSpec> {
        let blocks = ArrayList<BlockSpec>()
        blocks.add(h1(packageName + "." + name))
        blocks.add(EmitMarkdown.declarationBlock(declaration))
        if (!description.isEmpty()) {
            blocks.add(p(description))
        }
        if (!supertypes.isEmpty()) {
            blocks.add(h2("Relationships"))
            blocks.add(relationships(supertypes))
        }
        return blocks
    }

    private static func relationships(supertypes: Array<String>): BlockSpec {
        return table(
            header("Kind", "Types"),
            [
                row(cell("Supertypes"), cell(code(String.join(supertypes, delimiter: " & "))))
            ]
        )
    }

    private static func appendOptional(
        blocks: ArrayList<BlockSpec>,
        title: String,
        block: ?BlockSpec
    ): Unit {
        if (let Some(value) <- block) {
            blocks.add(h2(title))
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
