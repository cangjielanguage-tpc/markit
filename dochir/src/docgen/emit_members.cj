package dochir.docgen

import markit.dsl.*
import std.collection.ArrayList
import stdx.chir.*

public class EmitMembers {
    public static func instanceVars(vars: Array<MemberVar>): ?BlockSpec {
        let filtered = ArrayList<MemberVar>()
        for (value in vars) {
            if (ApiFormat.isDocumentable(value)) {
                filtered.add(value)
            }
        }
        if (filtered.isEmpty()) {
            return None
        }

        let rows = Array<TableRowSpec>(filtered.size) { i =>
            let value = filtered[i]
            row(
                cell(value.name),
                cell(ApiFormat.typeName(value.ty)),
                EmitMarkdown.declarationCell(ApiFormat.memberDeclaration(value)),
                cell(ApiFormat.description(value))
            )
        }
        return Some(table(
            header("Name", "Type", "Declaration", "Description"),
            rows
        ))
    }

    public static func staticVars(vars: Array<GlobalVar>): ?BlockSpec {
        let filtered = ArrayList<GlobalVar>()
        for (value in vars) {
            if (ApiFormat.isDocumentable(value)) {
                filtered.add(value)
            }
        }
        if (filtered.isEmpty()) {
            return None
        }

        let rows = Array<TableRowSpec>(filtered.size) { i =>
            let value = filtered[i]
            row(
                cell(ApiFormat.sourceName(value)),
                cell(ApiFormat.typeName(value.ty)),
                EmitMarkdown.declarationCell(ApiFormat.globalVarDeclaration(value)),
                cell(ApiFormat.description(value))
            )
        }
        return Some(table(
            header("Name", "Type", "Declaration", "Description"),
            rows
        ))
    }

    public static func constructors(functions: Array<Function>): ?BlockSpec {
        let filtered = ArrayList<Function>()
        for (value in functions) {
            if (ApiFormat.isDocumentable(value) && ApiFormat.functionDeclaration(value).startsWith("init(")) {
                filtered.add(value)
            }
        }
        if (filtered.isEmpty()) {
            return None
        }

        let rows = Array<TableRowSpec>(filtered.size) { i =>
            let value = filtered[i]
            row(
                EmitMarkdown.declarationCell(ApiFormat.functionDeclaration(value)),
                cell(ApiFormat.description(value))
            )
        }
        return Some(table(header("Declaration", "Description"), rows))
    }

    public static func methods(functions: Array<Function>): ?BlockSpec {
        let filtered = ArrayList<Function>()
        for (value in functions) {
            if (ApiFormat.isDocumentable(value) && !ApiFormat.functionDeclaration(value).startsWith("init(")) {
                filtered.add(value)
            }
        }
        if (filtered.isEmpty()) {
            return None
        }

        let rows = Array<TableRowSpec>(filtered.size) { i =>
            let value = filtered[i]
            row(
                cell(ApiFormat.sourceName(value)),
                EmitMarkdown.declarationCell(ApiFormat.functionDeclaration(value)),
                cell(ApiFormat.typeName(value.funcSrcCodeType.returnType)),
                cell(ApiFormat.description(value))
            )
        }
        return Some(table(
            header("Name", "Declaration", "Return Type", "Description"),
            rows
        ))
    }

    public static func enumConstructors(ctors: Array<EnumCtorInfo>): ?BlockSpec {
        if (ctors.isEmpty()) {
            return None
        }

        let rows = Array<TableRowSpec>(ctors.size) { i =>
            let value = ctors[i]
            row(
                cell(value.srcCodeName),
                EmitMarkdown.declarationCell(ApiFormat.enumConstructorDeclaration(value))
            )
        }
        return Some(table(
            header("Name", "Declaration"),
            rows
        ))
    }
}
