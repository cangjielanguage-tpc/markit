package dochir.model

public class DocParam {
    public let name: String
    public let typeName: String
    public let description: String

    public init(name: String, typeName: String, description: String) {
        this.name = name
        this.typeName = typeName
        this.description = description
    }
}

public class DocTag {
    public let name: String
    public let description: String

    public init(name: String, description: String) {
        this.name = name
        this.description = description
    }
}

public class DocValue {
    public let name: String
    public let typeName: String
    public let declaration: String
    public let description: String
    public let source: String
    public let typeText: String

    public init(
        name: String,
        typeName: String,
        declaration: String,
        description: String,
        source: String,
        typeText: String
    ) {
        this.name = name
        this.typeName = typeName
        this.declaration = declaration
        this.description = description
        this.source = source
        this.typeText = typeText
    }
}

public class DocFunction {
    public let name: String
    public let title: String
    public let declaration: String
    public let returnType: String
    public let description: String
    public let source: String
    public let returns: String
    public let isConstructor: Bool
    public let params: Array<DocParam>
    public let errors: Array<DocTag>
    public let examples: Array<String>

    public init(
        name: String,
        title: String,
        declaration: String,
        returnType: String,
        description: String,
        source: String,
        returns: String,
        isConstructor: Bool,
        params: Array<DocParam>,
        errors: Array<DocTag>,
        examples: Array<String>
    ) {
        this.name = name
        this.title = title
        this.declaration = declaration
        this.returnType = returnType
        this.description = description
        this.source = source
        this.returns = returns
        this.isConstructor = isConstructor
        this.params = params
        this.errors = errors
        this.examples = examples
    }
}

public class DocEnumConstructor {
    public let name: String
    public let declaration: String
    public let returnType: String
    public let description: String
    public let params: Array<DocParam>

    public init(name: String, declaration: String, returnType: String, description: String, params: Array<DocParam>) {
        this.name = name
        this.declaration = declaration
        this.returnType = returnType
        this.description = description
        this.params = params
    }
}

public class DocType {
    public let packageName: String
    public let name: String
    public let kind: String
    public let declaration: String
    public let description: String
    public let source: String
    public let supertypes: Array<String>
    public let properties: Array<DocValue>
    public let staticProperties: Array<DocValue>
    public let constructors: Array<DocFunction>
    public let methods: Array<DocFunction>
    public let enumConstructors: Array<DocEnumConstructor>

    public init(
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
    ) {
        this.packageName = packageName
        this.name = name
        this.kind = kind
        this.declaration = declaration
        this.description = description
        this.source = source
        this.supertypes = supertypes
        this.properties = properties
        this.staticProperties = staticProperties
        this.constructors = constructors
        this.methods = methods
        this.enumConstructors = enumConstructors
    }
}

public class DocPackage {
    public let name: String
    public let types: Array<DocType>
    public let globalVars: Array<DocValue>
    public let functions: Array<DocFunction>

    public init(
        name: String,
        types: Array<DocType>,
        globalVars: Array<DocValue>,
        functions: Array<DocFunction>
    ) {
        this.name = name
        this.types = types
        this.globalVars = globalVars
        this.functions = functions
    }
}

public class DocProject {
    public let name: String
    public let packages: Array<DocPackage>

    public init(name: String, packages: Array<DocPackage>) {
        this.name = name
        this.packages = packages
    }
}
