package dochir.model

import std.collection.ArrayList

class FunctionBuild {
    let owner: String
    let name: String
    let title: String
    let declaration: String
    let returnType: String
    let description: String
    let source: String
    let returns: String
    let isConstructor: Bool
    let params: ArrayList<DocParam>
    let errors: ArrayList<DocTag>
    let examples: ArrayList<String>

    init(fields: Array<String>) {
        this.owner = fields[1]
        this.name = fields[2]
        this.title = fields[3]
        this.declaration = fields[4]
        this.returnType = fields[5]
        this.description = fields[6]
        this.source = fields[7]
        this.returns = fields[8]
        this.isConstructor = fields[9] == "true"
        this.params = ArrayList<DocParam>()
        this.errors = ArrayList<DocTag>()
        this.examples = ArrayList<String>()
    }

    func build(): DocFunction {
        return DocFunction(
            name,
            title,
            declaration,
            returnType,
            description,
            source,
            returns,
            isConstructor,
            params.toArray(),
            errors.toArray(),
            examples.toArray()
        )
    }
}

class EnumCtorBuild {
    let name: String
    let declaration: String
    let returnType: String
    let description: String
    let params: ArrayList<DocParam>

    init(fields: Array<String>) {
        this.name = fields[1]
        this.declaration = fields[2]
        this.returnType = fields[3]
        this.description = if (fields.size >= 5) { fields[4] } else { "" }
        this.params = ArrayList<DocParam>()
    }

    func build(): DocEnumConstructor {
        return DocEnumConstructor(name, declaration, returnType, description, params.toArray())
    }
}

class TypeBuild {
    let packageName: String
    let name: String
    let kind: String
    let declaration: String
    let description: String
    let source: String
    let supertypes: Array<String>
    let properties: ArrayList<DocValue>
    let staticProperties: ArrayList<DocValue>
    let constructors: ArrayList<DocFunction>
    let methods: ArrayList<DocFunction>
    let enumConstructors: ArrayList<DocEnumConstructor>

    init(fields: Array<String>) {
        this.packageName = fields[1]
        this.name = fields[2]
        this.kind = fields[3]
        this.declaration = fields[4]
        this.description = fields[5]
        this.source = fields[6]
        this.supertypes = DocCodec.decodeList(fields[7])
        this.properties = ArrayList<DocValue>()
        this.staticProperties = ArrayList<DocValue>()
        this.constructors = ArrayList<DocFunction>()
        this.methods = ArrayList<DocFunction>()
        this.enumConstructors = ArrayList<DocEnumConstructor>()
    }

    func build(): DocType {
        return DocType(
            packageName,
            name,
            kind,
            declaration,
            description,
            source,
            supertypes,
            properties.toArray(),
            staticProperties.toArray(),
            constructors.toArray(),
            methods.toArray(),
            enumConstructors.toArray()
        )
    }
}

public class DocCodec {
    private static let version = "dochir-model-v1"

    public static func encodePackage(pkg: DocPackage): String {
        let lines = ArrayList<String>()
        lines.add(version)
        lines.add(record("package", [pkg.name]))

        for (ty in pkg.types) {
            lines.add(record("type", [
                ty.packageName,
                ty.name,
                ty.kind,
                ty.declaration,
                ty.description,
                ty.source,
                joinList(ty.supertypes)
            ]))
            for (value in ty.properties) {
                lines.add(valueRecord("value", "property", value))
            }
            for (value in ty.staticProperties) {
                lines.add(valueRecord("value", "staticProperty", value))
            }
            for (fn in ty.constructors) {
                appendFunction(lines, "constructor", fn)
            }
            for (fn in ty.methods) {
                appendFunction(lines, "method", fn)
            }
            for (ctor in ty.enumConstructors) {
                lines.add(record("enumCtor", [ctor.name, ctor.declaration, ctor.returnType, ctor.description]))
                for (param in ctor.params) {
                    lines.add(record("param", [param.name, param.typeName, param.description]))
                }
                lines.add("endEnumCtor")
            }
            lines.add("endType")
        }

        for (value in pkg.globalVars) {
            lines.add(valueRecord("value", "globalVar", value))
        }
        for (fn in pkg.functions) {
            appendFunction(lines, "function", fn)
        }

        lines.add("endPackage")
        return String.join(lines.toArray(), delimiter: "\n") + "\n"
    }

    public static func decodePackage(content: String): ?DocPackage {
        let lines = content.replace("\r\n", "\n").replace("\r", "\n").split("\n")
        if (lines.isEmpty() || lines[0] != version) {
            return None
        }

        var packageName = ""
        let types = ArrayList<DocType>()
        let globalVars = ArrayList<DocValue>()
        let functions = ArrayList<DocFunction>()
        var currentType: ?TypeBuild = None
        var currentFunction: ?FunctionBuild = None
        var currentEnumCtor: ?EnumCtorBuild = None

        for (i in 1..lines.size) {
            let raw = lines[i]
            if (raw.trimAscii().isEmpty()) {
                continue
            }
            let fields = decodeFields(raw)
            if (fields.isEmpty()) {
                continue
            }
            let tag = fields[0]

            if (tag == "package" && fields.size >= 2) {
                packageName = fields[1]
            } else if (tag == "type" && fields.size >= 8) {
                currentType = Some(TypeBuild(fields))
            } else if (tag == "endType") {
                if (let Some(ty) <- currentType) {
                    types.add(ty.build())
                }
                currentType = None
            } else if (tag == "value" && fields.size >= 8) {
                let owner = fields[1]
                let value = DocValue(fields[2], fields[3], fields[4], fields[5], fields[6], fields[7])
                if (owner == "globalVar") {
                    globalVars.add(value)
                } else if (let Some(ty) <- currentType) {
                    if (owner == "staticProperty") {
                        ty.staticProperties.add(value)
                    } else {
                        ty.properties.add(value)
                    }
                }
            } else if (tag == "function" && fields.size >= 10) {
                currentFunction = Some(FunctionBuild(fields))
            } else if (tag == "param" && fields.size >= 4) {
                let param = DocParam(fields[1], fields[2], fields[3])
                if (let Some(fn) <- currentFunction) {
                    fn.params.add(param)
                } else if (let Some(ctor) <- currentEnumCtor) {
                    ctor.params.add(param)
                }
            } else if (tag == "error" && fields.size >= 3) {
                if (let Some(fn) <- currentFunction) {
                    fn.errors.add(DocTag(fields[1], fields[2]))
                }
            } else if (tag == "example" && fields.size >= 2) {
                if (let Some(fn) <- currentFunction) {
                    fn.examples.add(fields[1])
                }
            } else if (tag == "endFunction") {
                if (let Some(fn) <- currentFunction) {
                    let built = fn.build()
                    if (fn.owner == "function") {
                        functions.add(built)
                    } else if (let Some(ty) <- currentType) {
                        if (fn.owner == "constructor") {
                            ty.constructors.add(built)
                        } else {
                            ty.methods.add(built)
                        }
                    }
                }
                currentFunction = None
            } else if (tag == "enumCtor" && fields.size >= 4) {
                currentEnumCtor = Some(EnumCtorBuild(fields))
            } else if (tag == "endEnumCtor") {
                if (let Some(ctor) <- currentEnumCtor) {
                    if (let Some(ty) <- currentType) {
                        ty.enumConstructors.add(ctor.build())
                    }
                }
                currentEnumCtor = None
            }
        }

        if (packageName.isEmpty()) {
            return None
        }
        return Some(DocPackage(packageName, types.toArray(), globalVars.toArray(), functions.toArray()))
    }

    private static func appendFunction(lines: ArrayList<String>, owner: String, fn: DocFunction): Unit {
        lines.add(record("function", [
            owner,
            fn.name,
            fn.title,
            fn.declaration,
            fn.returnType,
            fn.description,
            fn.source,
            fn.returns,
            if (fn.isConstructor) { "true" } else { "false" }
        ]))
        for (param in fn.params) {
            lines.add(record("param", [param.name, param.typeName, param.description]))
        }
        for (error in fn.errors) {
            lines.add(record("error", [error.name, error.description]))
        }
        for (example in fn.examples) {
            lines.add(record("example", [example]))
        }
        lines.add("endFunction")
    }

    private static func valueRecord(tag: String, owner: String, value: DocValue): String {
        return record(tag, [
            owner,
            value.name,
            value.typeName,
            value.declaration,
            value.description,
            value.source,
            value.typeText
        ])
    }

    private static func record(tag: String, fields: Array<String>): String {
        let out = ArrayList<String>()
        out.add(tag)
        for (field in fields) {
            out.add(escapeField(field))
        }
        return String.join(out.toArray(), delimiter: "\t")
    }

    private static func decodeFields(line: String): Array<String> {
        let parts = line.split("\t")
        let out = ArrayList<String>()
        for (part in parts) {
            out.add(unescapeField(part))
        }
        return out.toArray()
    }

    private static func joinList(items: Array<String>): String {
        let escaped = ArrayList<String>()
        for (item in items) {
            escaped.add(escapeListItem(item))
        }
        return String.join(escaped.toArray(), delimiter: ",")
    }

    static func decodeList(text: String): Array<String> {
        if (text.isEmpty()) {
            return []
        }
        let parts = splitEscapedList(text)
        let out = ArrayList<String>()
        for (part in parts) {
            out.add(unescapeListItem(part))
        }
        return out.toArray()
    }

    private static func escapeListItem(text: String): String {
        return text.replace("\\", "\\\\").replace(",", "\\c")
    }

    private static func unescapeListItem(text: String): String {
        let out = StringBuilder()
        var index: Int64 = 0
        while (index < text.size) {
            let byte = text[index]
            if (byte != b'\\' || index + 1 >= text.size) {
                let width = utf8Width(byte)
                out.append(text[index..index + width])
                index += width
                continue
            }

            let next = text[index + 1]
            if (next == b'c') {
                out.append(",")
            } else if (next == b'\\') {
                out.append("\\")
            } else {
                out.append("\\")
                out.append(text[index + 1..index + 2])
            }
            index += 2
        }
        return out.toString()
    }

    private static func splitEscapedList(text: String): Array<String> {
        let parts = ArrayList<String>()
        var current = StringBuilder()
        var index: Int64 = 0
        while (index < text.size) {
            let byte = text[index]
            if (byte == b'\\' && index + 1 < text.size) {
                current.append(text[index..index + 2])
                index += 2
            } else if (byte == b',') {
                parts.add(current.toString())
                current = StringBuilder()
                index += 1
            } else {
                let width = utf8Width(byte)
                current.append(text[index..index + width])
                index += width
            }
        }
        parts.add(current.toString())
        return parts.toArray()
    }

    private static func escapeField(text: String): String {
        let out = StringBuilder()
        var index: Int64 = 0
        while (index < text.size) {
            let byte = text[index]
            if (byte == b'\\') {
                out.append("\\\\")
                index += 1
            } else if (byte == b'\t') {
                out.append("\\t")
                index += 1
            } else if (byte == b'\n') {
                out.append("\\n")
                index += 1
            } else if (byte == b'\r') {
                out.append("\\r")
                index += 1
            } else {
                let width = utf8Width(byte)
                out.append(text[index..index + width])
                index += width
            }
        }
        return out.toString()
    }

    private static func unescapeField(text: String): String {
        let out = StringBuilder()
        var index: Int64 = 0
        while (index < text.size) {
            let byte = text[index]
            if (byte != b'\\' || index + 1 >= text.size) {
                let width = utf8Width(byte)
                out.append(text[index..index + width])
                index += width
                continue
            }

            let next = text[index + 1]
            if (next == b'\\') {
                out.append("\\")
            } else if (next == b't') {
                out.append("\t")
            } else if (next == b'n') {
                out.append("\n")
            } else if (next == b'r') {
                out.append("\r")
            } else {
                out.append("\\")
                out.append(text[index + 1..index + 2])
            }
            index += 2
        }
        return out.toString()
    }

    private static func utf8Width(first: Byte): Int64 {
        if (first < 0x80) {
            return 1
        }
        if ((first & 0xE0) == 0xC0) {
            return 2
        }
        if ((first & 0xF0) == 0xE0) {
            return 3
        }
        if ((first & 0xF8) == 0xF0) {
            return 4
        }
        return 1
    }
}
