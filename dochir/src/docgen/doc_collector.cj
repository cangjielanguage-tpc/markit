package dochir.docgen

import dochir.model.*
import std.collection.ArrayList
import stdx.chir.*

public class DocCollector {
    public static func configure(language!: String = "en", defaultLang!: String = "en"): Unit {
        SourceComments.configure(language: language, defaultLang: defaultLang)
    }

    public static func collectPackage(pkg: Package): DocPackage {
        let types = ArrayList<DocType>()
        let globalVars = ArrayList<DocValue>()
        let functions = ArrayList<DocFunction>()

        for (d in pkg.classDefs) {
            if (ApiFormat.isDocumentable(d, pkg.name)) {
                types.add(classLike(d))
            }
        }
        for (d in pkg.structDefs) {
            if (ApiFormat.isDocumentable(d, pkg.name)) {
                types.add(structDef(d))
            }
        }
        for (d in pkg.enumDefs) {
            if (ApiFormat.isDocumentable(d, pkg.name)) {
                types.add(enumDef(d))
            }
        }
        for (d in pkg.extendDefs) {
            if (ApiFormat.isDocumentable(d, pkg.name)) {
                types.add(extendDef(d))
            }
        }
        for (value in pkg.globalVars) {
            if (ApiFormat.isDocumentable(value, pkg.name)) {
                globalVars.add(globalValue(value))
            }
        }
        for (fn in pkg.functions) {
            if (ApiFormat.isDocumentable(fn, pkg.name) && !fn.isMemberMethod()) {
                functions.add(functionValue(fn))
            }
        }

        return DocPackage(pkg.name, types.toArray(), globalVars.toArray(), functions.toArray())
    }

    private static func classLike(def: ClassLikeDef): DocType {
        return customType(
            def.packageName,
            def.srcCodeName,
            ApiFormat.kind(def),
            ApiFormat.typeDeclaration(def),
            ApiFormat.description(def),
            SourceComments.locationLabelForText(def.toString()),
            ApiFormat.supertypes(def),
            memberValues(def.instanceVars),
            globalValues(def.staticVars),
            constructorValues(def.methods),
            methodValues(def.methods),
            []
        )
    }

    private static func structDef(def: StructDef): DocType {
        return customType(
            def.packageName,
            def.srcCodeName,
            ApiFormat.kind(def),
            ApiFormat.typeDeclaration(def),
            ApiFormat.description(def),
            SourceComments.locationLabelForText(def.toString()),
            ApiFormat.supertypes(def),
            memberValues(def.instanceVars),
            globalValues(def.staticVars),
            constructorValues(def.methods),
            methodValues(def.methods),
            []
        )
    }

    private static func enumDef(def: EnumDef): DocType {
        return customType(
            def.packageName,
            def.srcCodeName,
            ApiFormat.kind(def),
            ApiFormat.typeDeclaration(def),
            ApiFormat.description(def),
            SourceComments.locationLabelForText(def.toString()),
            ApiFormat.supertypes(def),
            memberValues(def.instanceVars),
            globalValues(def.staticVars),
            constructorValues(def.methods),
            methodValues(def.methods),
            enumConstructors(def.packageName, def.srcCodeName, def.constructors)
        )
    }

    private static func extendDef(def: ExtendDef): DocType {
        return customType(
            def.packageName,
            def.identifier,
            ApiFormat.kind(def),
            ApiFormat.typeDeclaration(def),
            ApiFormat.description(def),
            SourceComments.locationLabelForText(def.toString()),
            ApiFormat.supertypes(def),
            [],
            [],
            [],
            methodValues(def.methods),
            []
        )
    }

    private static func customType(
        packageName: String,
        name: String,
        kind: String,
        declaration: String,
        description: String,
        source: String,
        supertypes: Array<String>,
        properties: Array<DocValue>,
        staticProperties: Array<DocValue>,
        constructors: Array<DocFunction>,
        methods: Array<DocFunction>,
        enumConstructors: Array<DocEnumConstructor>
    ): DocType {
        return DocType(
            packageName,
            name,
            kind,
            declaration,
            description,
            source,
            supertypes,
            properties,
            staticProperties,
            constructors,
            methods,
            enumConstructors
        )
    }

    private static func memberValues(values: Array<MemberVar>): Array<DocValue> {
        let out = ArrayList<DocValue>()
        for (value in values) {
            if (ApiFormat.isDocumentable(value)) {
                out.add(memberValue(value))
            }
        }
        return out.toArray()
    }

    private static func globalValues(values: Array<GlobalVar>): Array<DocValue> {
        let out = ArrayList<DocValue>()
        for (value in values) {
            if (ApiFormat.isDocumentable(value)) {
                out.add(globalValue(value))
            }
        }
        return out.toArray()
    }

    private static func memberValue(value: MemberVar): DocValue {
        let doc = SourceComments.sourceDocForLocation(value.location)
        let typeText = if (doc.typeText.isEmpty()) { ApiFormat.typeName(value.ty) } else { doc.typeText }
        return DocValue(
            value.name,
            ApiFormat.typeName(value.ty),
            ApiFormat.memberDeclaration(value),
            doc.summary,
            SourceComments.locationLabelForLocation(value.location),
            typeText
        )
    }

    private static func globalValue(value: GlobalVar): DocValue {
        let doc = SourceComments.sourceDocForText(value.toString(), value.packageName)
        let typeText = if (doc.typeText.isEmpty()) { ApiFormat.typeName(value.ty) } else { doc.typeText }
        return DocValue(
            ApiFormat.sourceName(value),
            ApiFormat.typeName(value.ty),
            ApiFormat.globalVarDeclaration(value),
            doc.summary,
            SourceComments.locationLabelForText(value.toString()),
            typeText
        )
    }

    private static func constructorValues(functions: Array<Function>): Array<DocFunction> {
        let out = ArrayList<DocFunction>()
        for (value in functions) {
            let declaration = ApiFormat.functionDeclaration(value)
            if (ApiFormat.isDocumentable(value) && declaration.startsWith("init(")) {
                out.add(functionValue(value))
            }
        }
        return out.toArray()
    }

    private static func methodValues(functions: Array<Function>): Array<DocFunction> {
        let out = ArrayList<DocFunction>()
        for (value in functions) {
            let declaration = ApiFormat.functionDeclaration(value)
            if (ApiFormat.isDocumentable(value) && !declaration.startsWith("init(")) {
                out.add(functionValue(value))
            }
        }
        return out.toArray()
    }

    private static func functionValue(value: Function): DocFunction {
        let declaration = ApiFormat.functionDeclaration(value)
        let isConstructor = declaration.startsWith("init(")
        let doc = SourceComments.sourceDocForText(value.toString(), value.packageName)
        let title = if (isConstructor) { declaration } else { ApiFormat.sourceName(value) }
        return DocFunction(
            ApiFormat.sourceName(value),
            title,
            declaration,
            ApiFormat.typeName(value.funcSrcCodeType.returnType),
            doc.summary,
            SourceComments.locationLabelForText(value.toString()),
            doc.returns,
            isConstructor,
            params(value, doc),
            errors(doc),
            doc.examples
        )
    }

    private static func params(value: Function, doc: SourceDoc): Array<DocParam> {
        let params = value.parameters
        let types = value.funcSrcCodeType.paramTypes
        let start = if (value.isInstanceMemberMethod() && !params.isEmpty()) { 1 } else { 0 }
        let rows = ArrayList<DocParam>()
        for (i in start..params.size) {
            let typeIndex = i - start
            if (typeIndex >= types.size) {
                continue
            }
            let param = params[i]
            let name = if (!param.srcCodeName.isEmpty()) { param.srcCodeName } else { "p" + typeIndex.toString() }
            rows.add(DocParam(name, ApiFormat.typeName(types[typeIndex]), paramDescription(doc, name)))
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

    private static func errors(doc: SourceDoc): Array<DocTag> {
        let out = ArrayList<DocTag>()
        for ((name, text) in doc.errors) {
            out.add(DocTag(name, text))
        }
        return out.toArray()
    }

    private static func enumConstructors(
        packageName: String,
        enumName: String,
        ctors: Array<EnumCtorInfo>
    ): Array<DocEnumConstructor> {
        let out = ArrayList<DocEnumConstructor>()
        for (value in ctors) {
            let paramTypes = value.funcType.paramTypes
            let params = ArrayList<DocParam>()
            for (i in 0..paramTypes.size) {
                params.add(DocParam("p" + i.toString(), ApiFormat.typeName(paramTypes[i]), ""))
            }
            out.add(DocEnumConstructor(
                value.srcCodeName,
                ApiFormat.enumConstructorDeclaration(value),
                ApiFormat.typeName(value.funcType.returnType),
                SourceComments.descriptionForEnumConstructor(packageName, enumName, value.srcCodeName),
                params.toArray()
            ))
        }
        return out.toArray()
    }
}
