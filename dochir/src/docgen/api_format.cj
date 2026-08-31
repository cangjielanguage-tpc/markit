package dochir.docgen

import std.collection.ArrayList
import stdx.chir.*

public class ApiFormat {
    public static func typeDeclaration(def: ClassLikeDef): String {
        let parts = ArrayList<String>()
        addAccess(parts, def)
        if (def.isSealed()) {
            parts.add("sealed")
        }
        if (def.isAbstract() && def.isClass()) {
            parts.add("abstract")
        } else if (def.isOpen() && def.isClass()) {
            parts.add("open")
        }
        parts.add(if (def.isClass()) { "class" } else { "interface" })
        parts.add(typeTitle(def))

        let supers = ArrayList<String>()
        if (let Some(superClass) <- def.superClass) {
            if (!isImplicitObject(superClass)) {
                supers.add(typeName(superClass))
            }
        }
        for (it in def.implementedInterfaceTypes) {
            supers.add(typeName(it))
        }
        let decl = String.join(parts.toArray(), delimiter: " ")
        if (supers.isEmpty()) {
            return decl + genericConstraints(def.genericTypeParams)
        }
        return decl + " <: " + String.join(supers.toArray(), delimiter: " & ") +
            genericConstraints(def.genericTypeParams)
    }

    public static func typeDeclaration(def: StructDef): String {
        let parts = ArrayList<String>()
        addAccess(parts, def)
        parts.add("struct")
        parts.add(typeTitle(def))
        return String.join(parts.toArray(), delimiter: " ") + genericConstraints(def.genericTypeParams)
    }

    public static func typeDeclaration(def: EnumDef): String {
        let parts = ArrayList<String>()
        addAccess(parts, def)
        parts.add("enum")
        parts.add(typeTitle(def))
        return String.join(parts.toArray(), delimiter: " ") + genericConstraints(def.genericTypeParams)
    }

    public static func typeDeclaration(def: ExtendDef): String {
        let parts = ArrayList<String>()
        addAccess(parts, def)
        parts.add("extend")
        parts.add(typeParams(def.genericTypeParams))
        parts.add(typeName(def.extendedType))
        let decl = compactJoin(parts)
        if (def.implementedInterfaceTypes.isEmpty()) {
            return decl + genericConstraints(def.genericTypeParams)
        }
        let interfaces = ArrayList<String>()
        for (it in def.implementedInterfaceTypes) {
            interfaces.add(typeName(it))
        }
        return decl + " <: " + String.join(interfaces.toArray(), delimiter: " & ") +
            genericConstraints(def.genericTypeParams)
    }

    public static func memberDeclaration(value: MemberVar): String {
        let parts = ArrayList<String>()
        addAccess(parts, value)
        parts.add(if (value.isReadOnly()) { "let" } else { "var" })
        parts.add(value.name + ": " + typeName(value.ty))
        return String.join(parts.toArray(), delimiter: " ")
    }

    public static func globalVarDeclaration(value: GlobalVar): String {
        let parts = ArrayList<String>()
        addAccess(parts, value)
        if (value.isStatic()) {
            parts.add("static")
        }
        if (value.isConst()) {
            parts.add("const")
        }
        parts.add(if (value.isReadOnly()) { "let" } else { "var" })
        parts.add(sourceName(value) + ": " + typeName(value.ty))
        return String.join(parts.toArray(), delimiter: " ")
    }

    public static func functionDeclaration(value: Function): String {
        let name = sourceName(value)
        let constructor = isConstructor(value)
        let parts = ArrayList<String>()
        if (!constructor) {
            addAccess(parts, value)
            if (value.isStaticMemberMethod()) {
                parts.add("static")
            }
            if (value.isAbstract()) {
                parts.add("abstract")
            } else if (value.isOpen()) {
                parts.add("open")
            }
            parts.add("func")
        }

        let title = if (constructor) { "init" } else { name }
        let params = parameterList(value)
        let generics = typeParams(value.genericTypeParams)
        let returnType = value.funcSrcCodeType.returnType
        let signature = title + generics + "(" + params + ")"
        if (constructor) {
            return signature + genericConstraints(value.genericTypeParams)
        }
        return String.join(parts.toArray(), delimiter: " ") + " " + signature +
            ": " + typeName(returnType) + genericConstraints(value.genericTypeParams)
    }

    public static func enumConstructorDeclaration(value: EnumCtorInfo): String {
        let paramTypes = value.funcType.paramTypes
        let params = ArrayList<String>()
        for (i in 0..paramTypes.size) {
            params.add(typeName(paramTypes[i]))
        }
        if (params.isEmpty()) {
            return value.srcCodeName
        }
        return value.srcCodeName + "(" + String.join(params.toArray(), delimiter: ", ") + ")"
    }

    public static func kind(def: ClassLikeDef): String {
        return if (def.isClass()) { "Class" } else { "Interface" }
    }

    public static func kind(def: StructDef): String {
        return if (def.isStruct()) { "Struct" } else { "Struct" }
    }

    public static func kind(def: EnumDef): String {
        return if (def.isEnum()) { "Enum" } else { "Enum" }
    }

    public static func kind(def: ExtendDef): String {
        return if (def.isExtend()) { "Extend" } else { "Extend" }
    }

    public static func supertypes(def: ClassLikeDef): Array<String> {
        return supertypesFromCustom(def)
    }

    public static func supertypes(def: StructDef): Array<String> {
        return supertypesFromCustom(def)
    }

    public static func supertypes(def: EnumDef): Array<String> {
        return supertypesFromCustom(def)
    }

    public static func supertypes(def: ExtendDef): Array<String> {
        let result = ArrayList<String>()
        result.add(typeName(def.extendedType))
        for (it in def.implementedInterfaceTypes) {
            result.add(typeName(it))
        }
        return result.toArray()
    }

    public static func description(value: ClassLikeDef): String {
        return SourceComments.descriptionForText(value.toString(), value.packageName)
    }

    public static func description(value: StructDef): String {
        return SourceComments.descriptionForText(value.toString(), value.packageName)
    }

    public static func description(value: EnumDef): String {
        return SourceComments.descriptionForText(value.toString(), value.packageName)
    }

    public static func description(value: ExtendDef): String {
        return SourceComments.descriptionForText(value.toString(), value.packageName)
    }

    public static func description(value: MemberVar): String {
        return SourceComments.descriptionForLocation(value.location)
    }

    public static func description(value: GlobalVar): String {
        return SourceComments.descriptionForText(value.toString(), value.packageName)
    }

    public static func description(value: Function): String {
        return SourceComments.descriptionForText(value.toString(), value.packageName)
    }

    public static func typeName(ty: Type): String {
        if (let Some(t) <- (ty as RefType)) {
            return typeName(t.baseType)
        }
        if (let Some(t) <- (ty as BoxType)) {
            return "Box<" + typeName(t.baseType) + ">"
        }
        if (let Some(t) <- (ty as CPointerType)) {
            return "CPointer<" + typeName(t.elementType) + ">"
        }
        if (let Some(t) <- (ty as RawArrayType)) {
            return "RawArray<" + typeName(t.elementType) + ">"
        }
        if (let Some(t) <- (ty as VArrayType)) {
            return "VArray<" + typeName(t.elementType) + ", " + t.size.toString() + ">"
        }
        if (let Some(t) <- (ty as TupleType)) {
            let items = ArrayList<String>()
            for (it in t.elementTypes) {
                items.add(typeName(it))
            }
            return "(" + String.join(items.toArray(), delimiter: ", ") + ")"
        }
        if (let Some(t) <- (ty as FuncType)) {
            let items = ArrayList<String>()
            for (it in t.paramTypes) {
                items.add(typeName(it))
            }
            let prefix = if (t.isCFunc) { "CFunc<" } else { "" }
            let suffix = if (t.isCFunc) { ">" } else { "" }
            return prefix + "(" + String.join(items.toArray(), delimiter: ", ") + ") -> " +
                typeName(t.returnType) + suffix
        }
        if (let Some(t) <- (ty as GenericType)) {
            return t.srcCodeName
        }
        if (let Some(t) <- (ty as CustomType)) {
            return customTypeName(t)
        }
        return ty.qualifiedName
    }

    public static func sourceName(value: GlobalValue): String {
        if (!value.srcCodeName.isEmpty()) {
            return normalizeSourceName(value.srcCodeName)
        }
        return value.identifierWithoutPrefix
    }

    public static func isDocumentable(value: GlobalValue): Bool {
        return value.isPublic() && !value.isImported() && !value.isCompilerAdd() && isUserFacingName(sourceName(value))
    }

    public static func isDocumentable(value: CustomTypeDef): Bool {
        return value.isPublic() && !value.isImported() && isUserFacingName(fallbackTypeName(value))
    }

    public static func isDocumentable(value: GlobalValue, packageName: String): Bool {
        return isDocumentable(value) && belongsToPackage(value.packageName, packageName)
    }

    public static func isDocumentable(value: CustomTypeDef, packageName: String): Bool {
        return isDocumentable(value) && belongsToPackage(value.packageName, packageName)
    }

    public static func isDocumentable(value: MemberVar): Bool {
        return value.isPublic() && !value.name.isEmpty()
    }

    private static func typeTitle(def: CustomTypeDef): String {
        return def.srcCodeName + typeParams(def.genericTypeParams)
    }

    private static func customTypeName(ty: CustomType): String {
        let args = ty.genericTypeArgs
        if (args.isEmpty()) {
            return fallbackTypeName(ty.def)
        }
        let items = ArrayList<String>()
        for (arg in args) {
            items.add(typeName(arg))
        }
        return fallbackTypeName(ty.def) + "<" + String.join(items.toArray(), delimiter: ", ") + ">"
    }

    private static func fallbackTypeName(def: CustomTypeDef): String {
        if (!def.srcCodeName.isEmpty()) {
            return def.srcCodeName
        }
        return def.identifier
    }

    private static func belongsToPackage(actual: String, expected: String): Bool {
        return actual == expected
    }

    private static func isUserFacingName(name: String): Bool {
        return !name.isEmpty() && !name.startsWith("@") && !name.contains("$")
    }

    private static func typeParams(params: Array<GenericType>): String {
        if (params.isEmpty()) {
            return ""
        }
        let names = ArrayList<String>()
        for (p in params) {
            names.add(typeName(p))
        }
        return "<" + String.join(names.toArray(), delimiter: ", ") + ">"
    }

    private static func genericConstraints(params: Array<GenericType>): String {
        let constraints = ArrayList<String>()
        for (p in params) {
            if (p.upperBounds.isEmpty()) {
                continue
            }
            let bounds = ArrayList<String>()
            for (bound in p.upperBounds) {
                if (isImplicitObject(bound)) {
                    continue
                }
                bounds.add(typeName(bound))
            }
            if (!bounds.isEmpty()) {
                constraints.add(typeName(p) + " <: " + String.join(bounds.toArray(), delimiter: " & "))
            }
        }
        if (constraints.isEmpty()) {
            return ""
        }
        return " where " + String.join(constraints.toArray(), delimiter: ", ")
    }

    private static func parameterList(value: Function): String {
        let params = value.parameters
        let types = value.funcSrcCodeType.paramTypes
        let start = if (value.isInstanceMemberMethod() && !params.isEmpty()) { 1 } else { 0 }
        let result = ArrayList<String>()
        for (i in start..params.size) {
            let typeIndex = i - start
            if (typeIndex >= types.size) {
                continue
            }
            let p = params[i]
            let name = if (!p.srcCodeName.isEmpty()) { p.srcCodeName } else { "p" + typeIndex.toString() }
            result.add(name + ": " + typeName(types[typeIndex]))
        }
        return String.join(result.toArray(), delimiter: ", ")
    }

    private static func isConstructor(value: Function): Bool {
        let name = value.srcCodeName
        return name == "init" || name == "<init>" || value.identifier.contains("<init>")
    }

    private static func normalizeSourceName(name: String): String {
        if (name == "<init>") {
            return "init"
        }
        return name
    }

    private static func isImplicitObject(ty: Type): Bool {
        if (let Some(t) <- (ty.stripAllRefs() as ClassLikeType)) {
            return t.classLikeDef.srcCodeName == "Object"
        }
        return false
    }

    private static func supertypesFromCustom(def: CustomTypeDef): Array<String> {
        let result = ArrayList<String>()
        if (let Some(classLike) <- (def as ClassLikeDef)) {
            if (let Some(superClass) <- classLike.superClass) {
                if (!isImplicitObject(superClass)) {
                    result.add(typeName(superClass))
                }
            }
        }
        for (it in def.implementedInterfaceTypes) {
            result.add(typeName(it))
        }
        return result.toArray()
    }

    private static func addAccess(parts: ArrayList<String>, value: CustomTypeDef): Unit {
        if (value.isPublic()) {
            parts.add("public")
        } else if (value.isProtected()) {
            parts.add("protected")
        } else if (value.isPrivate()) {
            parts.add("private")
        } else if (value.isInternal()) {
            parts.add("internal")
        }
    }

    private static func addAccess(parts: ArrayList<String>, value: GlobalValue): Unit {
        if (value.isPublic()) {
            parts.add("public")
        } else if (value.isProtected()) {
            parts.add("protected")
        } else if (value.isPrivate()) {
            parts.add("private")
        } else if (value.isInternal()) {
            parts.add("internal")
        }
    }

    private static func addAccess(parts: ArrayList<String>, value: MemberVar): Unit {
        if (value.isPublic()) {
            parts.add("public")
        } else if (value.isProtected()) {
            parts.add("protected")
        } else if (value.isPrivate()) {
            parts.add("private")
        } else if (value.isInternal()) {
            parts.add("internal")
        }
    }

    private static func compactJoin(parts: ArrayList<String>): String {
        let nonEmpty = ArrayList<String>()
        for (part in parts) {
            if (!part.isEmpty()) {
                nonEmpty.add(part)
            }
        }
        return String.join(nonEmpty.toArray(), delimiter: " ")
    }
}
