package dochir.model

public class DocParam {
    public DocParam(public let name: String, public let typeName: String, public let description: String) {}
}

public class DocTag {
    public DocTag(public let name: String, public let description: String) {}
}

public class DocValue {
    public DocValue(
        public let name: String,
        public let typeName: String,
        public let declaration: String,
        public let description: String,
        public let source: String,
        public let typeText: String
    ) {}
}

public class DocFunction {
    public DocFunction(
        public let name: String,
        public let title: String,
        public let declaration: String,
        public let returnType: String,
        public let description: String,
        public let source: String,
        public let returns: String,
        public let isConstructor: Bool,
        public let params: Array<DocParam>,
        public let errors: Array<DocTag>,
        public let examples: Array<String>
    ) {}
}

public class DocEnumConstructor {
    public DocEnumConstructor(public let name: String, public let declaration: String, public let returnType: String, public let description: String, public let params: Array<DocParam>) {}
}

public class DocType {
    public DocType(
        public let packageName: String,
        public let name: String,
        public let kind: String,
        public let declaration: String,
        public let description: String,
        public let source: String,
        public let supertypes: Array<String>,
        public let properties: Array<DocValue>,
        public let staticProperties: Array<DocValue>,
        public let constructors: Array<DocFunction>,
        public let methods: Array<DocFunction>,
        public let enumConstructors: Array<DocEnumConstructor>
    ) {}
}

public class DocPackage {
    public DocPackage(
        public let name: String,
        public let types: Array<DocType>,
        public let globalVars: Array<DocValue>,
        public let functions: Array<DocFunction>
    ) {}
}

public class DocProject {
    public DocProject(public let name: String, public let packages: Array<DocPackage>) {}
}
