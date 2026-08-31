package dochir.docgen

import markit.dsl.*
import std.collection.ArrayList
import stdx.chir.*

public class EmitDetails {
    public static func instanceVars(vars: Array<MemberVar>): Array<BlockSpec> {
        let blocks = ArrayList<BlockSpec>()
        for (value in vars) {
            if (!ApiFormat.isDocumentable(value)) {
                continue
            }
            let doc = SourceComments.sourceDocForLocation(value.location)
            blocks.add(h3(value.name))
            blocks.add(EmitMarkdown.declarationBlock(ApiFormat.memberDeclaration(value)))
            addSummary(blocks, doc)
            blocks.add(typeTable(ApiFormat.typeName(value.ty), doc.typeText))
        }
        return blocks.toArray()
    }

    public static func staticVars(vars: Array<GlobalVar>): Array<BlockSpec> {
        let blocks = ArrayList<BlockSpec>()
        for (value in vars) {
            if (!ApiFormat.isDocumentable(value)) {
                continue
            }
            let doc = SourceComments.sourceDocForText(value.toString(), value.packageName)
            blocks.add(h3(ApiFormat.sourceName(value)))
            blocks.add(EmitMarkdown.declarationBlock(ApiFormat.globalVarDeclaration(value)))
            addSummary(blocks, doc)
            blocks.add(typeTable(ApiFormat.typeName(value.ty), doc.typeText))
        }
        return blocks.toArray()
    }

    public static func globalVars(vars: Array<GlobalVar>): Array<BlockSpec> {
        return staticVars(vars)
    }

    public static func globalVars(vars: Array<GlobalVar>, packageName: String): Array<BlockSpec> {
        let blocks = ArrayList<BlockSpec>()
        for (value in vars) {
            if (!ApiFormat.isDocumentable(value, packageName)) {
                continue
            }
            let doc = SourceComments.sourceDocForText(value.toString(), value.packageName)
            blocks.add(h3(ApiFormat.sourceName(value)))
            blocks.add(EmitMarkdown.declarationBlock(ApiFormat.globalVarDeclaration(value)))
            addSummary(blocks, doc)
            blocks.add(typeTable(ApiFormat.typeName(value.ty), doc.typeText))
        }
        return blocks.toArray()
    }

    public static func constructors(functions: Array<Function>): Array<BlockSpec> {
        return functionDetails(functions, true)
    }

    public static func methods(functions: Array<Function>): Array<BlockSpec> {
        return functionDetails(functions, false)
    }

    public static func functions(functions: Array<Function>): Array<BlockSpec> {
        let blocks = ArrayList<BlockSpec>()
        for (value in functions) {
            if (!ApiFormat.isDocumentable(value) || value.isMemberMethod()) {
                continue
            }
            addFunctionDetail(blocks, value, ApiFormat.functionDeclaration(value), ApiFormat.sourceName(value))
        }
        return blocks.toArray()
    }

    public static func functions(functions: Array<Function>, packageName: String): Array<BlockSpec> {
        let blocks = ArrayList<BlockSpec>()
        for (value in functions) {
            if (!ApiFormat.isDocumentable(value, packageName) || value.isMemberMethod()) {
                continue
            }
            addFunctionDetail(blocks, value, ApiFormat.functionDeclaration(value), ApiFormat.sourceName(value))
        }
        return blocks.toArray()
    }

    public static func enumConstructors(ctors: Array<EnumCtorInfo>): Array<BlockSpec> {
        let blocks = ArrayList<BlockSpec>()
        for (value in ctors) {
            blocks.add(h3(value.srcCodeName))
            blocks.add(EmitMarkdown.declarationBlock(ApiFormat.enumConstructorDeclaration(value)))
            let paramTypes = value.funcType.paramTypes
            if (!paramTypes.isEmpty()) {
                let rows = Array<TableRowSpec>(paramTypes.size) { i =>
                    row(
                        cell("p" + i.toString()),
                        cell(code(ApiFormat.typeName(paramTypes[i]))),
                        cell("")
                    )
                }
                blocks.add(h4("Parameters"))
                blocks.add(table(header("Name", "Type", "Description"), rows))
            }
            blocks.add(h4("Return Type"))
            blocks.add(p([code(ApiFormat.typeName(value.funcType.returnType))]))
        }
        return blocks.toArray()
    }

    private static func functionDetails(functions: Array<Function>, constructorOnly: Bool): Array<BlockSpec> {
        let blocks = ArrayList<BlockSpec>()
        for (value in functions) {
            let declaration = ApiFormat.functionDeclaration(value)
            let isConstructor = declaration.startsWith("init(")
            if (!ApiFormat.isDocumentable(value) || isConstructor != constructorOnly) {
                continue
            }
            let title = if (isConstructor) { declaration } else { ApiFormat.sourceName(value) }
            addFunctionDetail(blocks, value, declaration, title)
        }
        return blocks.toArray()
    }

    private static func addFunctionDetail(
        blocks: ArrayList<BlockSpec>,
        value: Function,
        declaration: String,
        title: String
    ): Unit {
        let doc = SourceComments.sourceDocForText(value.toString(), value.packageName)
        blocks.add(h3(title))
        blocks.add(EmitMarkdown.declarationBlock(declaration))
        addSummary(blocks, doc)
        addParameterTable(blocks, value, doc)
        addReturn(blocks, value, doc)
        addErrors(blocks, doc)
        addExamples(blocks, doc)
    }

    private static func addSummary(blocks: ArrayList<BlockSpec>, doc: SourceDoc): Unit {
        if (!doc.summary.isEmpty()) {
            blocks.add(p(doc.summary))
        }
    }

    private static func typeTable(actualType: String, docType: String): BlockSpec {
        let typeText = if (docType.isEmpty()) { actualType } else { docType }
        return table(
            header("Item", "Value"),
            [
                row(cell("Type"), cell(code(typeText)))
            ]
        )
    }

    private static func addParameterTable(blocks: ArrayList<BlockSpec>, value: Function, doc: SourceDoc): Unit {
        let rows = parameterRows(value, doc)
        if (rows.isEmpty()) {
            return
        }
        blocks.add(h4("Parameters"))
        blocks.add(table(
            header("Name", "Type", "Description"),
            rows
        ))
    }

    private static func parameterRows(value: Function, doc: SourceDoc): Array<TableRowSpec> {
        let params = value.parameters
        let types = value.funcSrcCodeType.paramTypes
        let start = if (value.isInstanceMemberMethod() && !params.isEmpty()) { 1 } else { 0 }
        let rows = ArrayList<TableRowSpec>()
        for (i in start..params.size) {
            let typeIndex = i - start
            if (typeIndex >= types.size) {
                continue
            }
            let param = params[i]
            let name = if (!param.srcCodeName.isEmpty()) { param.srcCodeName } else { "p" + typeIndex.toString() }
            rows.add(row(
                cell(name),
                cell(code(ApiFormat.typeName(types[typeIndex]))),
                cell(paramDescription(doc, name))
            ))
        }
        return rows.toArray()
    }

    private static func paramDescription(doc: SourceDoc, name: String): String {
        for ((paramName, text) in doc.params) {
            if (paramName == name) {
                return text
            }
        }
        return ""
    }

    private static func addReturn(blocks: ArrayList<BlockSpec>, value: Function, doc: SourceDoc): Unit {
        let returnType = ApiFormat.typeName(value.funcSrcCodeType.returnType)
        if (returnType == "Unit" && doc.returns.isEmpty()) {
            return
        }
        blocks.add(h4("Return Type"))
        if (doc.returns.isEmpty()) {
            blocks.add(p([code(returnType)]))
        } else {
            blocks.add(p([code(returnType), text(" - " + doc.returns)]))
        }
    }

    private static func addErrors(blocks: ArrayList<BlockSpec>, doc: SourceDoc): Unit {
        if (doc.errors.isEmpty()) {
            return
        }
        let rows = Array<TableRowSpec>(doc.errors.size) { i =>
            let (name, text) = doc.errors[i]
            row(cell(code(name)), cell(text))
        }
        blocks.add(h4("Throws"))
        blocks.add(table(header("Type", "Description"), rows))
    }

    private static func addExamples(blocks: ArrayList<BlockSpec>, doc: SourceDoc): Unit {
        if (doc.examples.isEmpty()) {
            return
        }
        blocks.add(h4("Examples"))
        for (example in doc.examples) {
            blocks.add(codeBlock("cangjie", example))
        }
    }
}
