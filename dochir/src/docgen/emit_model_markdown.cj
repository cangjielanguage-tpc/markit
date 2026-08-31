package dochir.docgen

import dochir.model.*
import markit.dsl.*
import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists, remove}

class SourceTarget {
    let file: String
    let line: String

    init(file: String, line: String) {
        this.file = file
        this.line = line
    }
}

class SourceLinkConfig {
    let projectName: String
    let sourceRoot: String
    let sourceRepository: String
    let sourceBranch: String

    init(projectName: String, sourceRoot: String, sourceRepository: String, sourceBranch: String) {
        this.projectName = projectName
        this.sourceRoot = sourceRoot
        this.sourceRepository = sourceRepository
        this.sourceBranch = sourceBranch
    }

    func sourceUrl(packageName: String, source: String): ?String {
        if (sourceRepository.trimAscii().isEmpty() || sourceBranch.trimAscii().isEmpty() || source.trimAscii().isEmpty()) {
            return None
        }
        let repo = normalizedRepository()
        if (repo.isEmpty()) {
            return None
        }
        let target = parseSource(source)
        let path = sourcePath(packageName, target.file)
        if (path.isEmpty()) {
            return None
        }
        let anchor = if (target.line.isEmpty()) { "" } else { "#L" + target.line }
        return Some(repo + "/blob/" + sourceBranch.trimAscii() + "/" + path + anchor)
    }

    private func normalizedRepository(): String {
        var repo = sourceRepository.trimAscii()
        while (repo.endsWith("/")) {
            repo = repo[0..(repo.size - 1)]
        }
        if (repo.endsWith(".git")) {
            repo = repo[0..(repo.size - 4)]
        }
        return repo
    }

    private func sourcePath(packageName: String, file: String): String {
        let normalizedFile = file.replace("\\", "/").trimAscii()
        if (normalizedFile.isEmpty()) {
            return ""
        }
        let root = trimPathSlashes(sourceRoot.trimAscii().replace("\\", "/"))
        if (root.isEmpty()) {
            return normalizedFile
        }
        if (normalizedFile == root || normalizedFile.startsWith(root + "/")) {
            return normalizedFile
        }
        if (normalizedFile.contains("/")) {
            return joinPath(root, normalizedFile)
        }
        let packagePath = packageSourcePath(packageName)
        if (packagePath.isEmpty()) {
            return joinPath(root, normalizedFile)
        }
        return joinPath(root, packagePath + "/" + normalizedFile)
    }

    private func packageSourcePath(packageName: String): String {
        if (packageName.isEmpty() || packageName == projectName) {
            return ""
        }
        let prefix = projectName + "."
        if (!projectName.isEmpty() && packageName.startsWith(prefix)) {
            return packageName[prefix.size..packageName.size].replace(".", "/")
        }
        return packageName.replace(".", "/")
    }

    private func parseSource(source: String): SourceTarget {
        let trimmed = source.trimAscii()
        if (let Some(colon) <- trimmed.lastIndexOf(":")) {
            let file = trimmed[0..colon].trimAscii()
            let line = trimmed[(colon + 1)..trimmed.size].trimAscii()
            if (!file.isEmpty() && isDigits(line)) {
                return SourceTarget(file, line)
            }
        }
        return SourceTarget(trimmed, "")
    }

    private func trimPathSlashes(value: String): String {
        var result = value
        while (result.startsWith("/")) {
            result = result[1..result.size]
        }
        while (result.endsWith("/")) {
            result = result[0..(result.size - 1)]
        }
        return result
    }

    private func joinPath(left: String, right: String): String {
        if (left.isEmpty()) {
            return right
        }
        if (right.isEmpty()) {
            return left
        }
        return left + "/" + right
    }

    private func isDigits(value: String): Bool {
        if (value.isEmpty()) {
            return false
        }
        var index: Int64 = 0
        while (index < value.size) {
            let byte = value[index]
            if (byte < b'0' || byte > b'9') {
                return false
            }
            index += 1
        }
        return true
    }
}

class DocTemplate {
    private let zh: Bool

    init(language: String) {
        this.zh = language.toAsciiLower().startsWith("zh")
    }

    static func forLanguage(language: String): DocTemplate {
        return DocTemplate(language)
    }

    func apiReferenceTitle(projectName: String): String {
        return projectName + (if (zh) { " api文档" } else { " API Reference" })
    }

    func projectIntro(): String {
        return if (zh) { "此项目公开的包、类型、函数和属性。" } else {
            "Public packages, types, functions, and properties exposed by this project."
        }
    }

    func allPackagesIntro(): String {
        return if (zh) { "此项目中记录的所有公开包。" } else { "All public packages documented in this project." }
    }

    func packageIntro(packageName: String): Array<InlineSpec> {
        if (zh) {
            return [text("包 "), code(packageName), text(" 的公开 API。")]
        }
        return [text("Public API surface for package "), code(packageName), text(".")]
    }

    func projectHomeIntro(): String {
        return if (zh) { "此项目的包、类型、函数、属性和枚举构造器 API 文档。" } else {
            "Public API documentation for packages, types, functions, properties, and enum constructors."
        }
    }

    func overview(): String { return if (zh) { "概览" } else { "Overview" } }
    func item(): String { return if (zh) { "项目" } else { "Item" } }
    func count(): String { return if (zh) { "数量" } else { "Count" } }
    func packages(): String { return if (zh) { "包" } else { "Packages" } }
    func allPackages(): String { return if (zh) { "全部包" } else { "All Packages" } }
    func packageLabel(): String { return if (zh) { "包" } else { "Package" } }
    func types(): String { return if (zh) { "类型" } else { "Types" } }
    func typeLabel(): String { return if (zh) { "类型" } else { "Type" } }
    func functions(): String { return if (zh) { "函数" } else { "Functions" } }
    func globalVariables(): String { return if (zh) { "全局变量" } else { "Global Variables" } }
    func properties(): String { return if (zh) { "属性" } else { "Properties" } }
    func staticProperties(): String { return if (zh) { "静态属性" } else { "Static Properties" } }
    func constructors(): String { return if (zh) { "构造函数" } else { "Constructors" } }
    func enumConstructors(): String { return if (zh) { "枚举构造器" } else { "Enum Constructors" } }
    func methods(): String { return if (zh) { "方法" } else { "Methods" } }
    func extensions(): String { return if (zh) { "扩展" } else { "Extensions" } }
    func subpackages(): String { return if (zh) { "子包" } else { "Subpackages" } }
    func packageLevelDeclarations(): String { return if (zh) { "包级声明" } else { "Package-level declarations" } }
    func relationships(): String { return if (zh) { "关系" } else { "Relationships" } }
    func typeIndex(): String { return if (zh) { "类型索引" } else { "Type Index" } }
    func inheritance(): String { return if (zh) { "继承关系" } else { "Inheritance" } }
    func name(): String { return if (zh) { "名称" } else { "Name" } }
    func kind(): String { return if (zh) { "种类" } else { "Kind" } }
    func declaration(): String { return if (zh) { "声明" } else { "Declaration" } }
    func description(): String { return if (zh) { "说明" } else { "Description" } }
    func members(): String { return if (zh) { "成员" } else { "Members" } }
    func returns(): String { return if (zh) { "返回类型" } else { "Return Type" } }
    func parameters(): String { return if (zh) { "参数" } else { "Parameters" } }
    func throwsLabel(): String { return if (zh) { "抛出" } else { "Throws" } }
    func examples(): String { return if (zh) { "示例" } else { "Examples" } }
    func linkLabel(): String { return if (zh) { "链接" } else { "Link" } }
    func source(): String { return if (zh) { "源码" } else { "Source" } }
    func noPackages(): String { return if (zh) { "没有记录任何公开包。" } else { "No public packages were documented." } }
    func noDeclarations(): String { return if (zh) { "此包没有公开声明。" } else { "No public declarations in this package." } }
    func supertypesInterfaces(): String { return if (zh) { "父类型" } else { "Supertypes" } }
    func knownSubtypes(): String { return if (zh) { "子类型" } else { "Subtypes" } }
    func extendedType(): String { return if (zh) { "被扩展类型" } else { "Extended Type" } }
    func implementedInterfaces(): String { return if (zh) { "实现的接口" } else { "Implemented Interfaces" } }
    func extensionLabel(): String { return if (zh) { "扩展" } else { "Extension" } }
    func propertyKind(): String { return if (zh) { "属性" } else { "Property" } }
    func staticPropertyKind(): String { return if (zh) { "静态属性" } else { "Static Property" } }
    func constructorKind(): String { return if (zh) { "构造函数" } else { "Constructor" } }
    func enumConstructorKind(): String { return if (zh) { "枚举构造器" } else { "Enum Constructor" } }
    func methodKind(): String { return if (zh) { "方法" } else { "Method" } }
    func functionKind(): String { return if (zh) { "函数" } else { "Function" } }
    func globalVariableKind(): String { return if (zh) { "全局变量" } else { "Global Variable" } }

    func memberContextPrefix(kind: String): String {
        return if (zh) { kind + "位于 " } else { kind + " in " }
    }

    func extendsPrefix(): String {
        return if (zh) { "扩展 " } else { "Extends " }
    }

    func implementsSeparator(): String {
        return if (zh) { "；实现 " } else { "; implements " }
    }

    func kindName(kind: String): String {
        if (!zh) {
            return kind
        }
        match (kind) {
            case "Class" => "类"
            case "Interface" => "接口"
            case "Struct" => "结构体"
            case "Enum" => "枚举"
            case "Extend" => "扩展"
            case _ => kind
        }
    }

    func packageSymbolDescription(packageName: String): String {
        return if (zh) { "包 " + packageName } else { "Package " + packageName }
    }
}

public class DocMarkdownEmitter {
    private static var template = DocTemplate.forLanguage("en")
    private static var currentLanguage = "en"

    public static func emit(
        project: DocProject,
        outRoot: String,
        sourceRoot!: String = "src",
        sourceRepository!: String = "",
        sourceBranch!: String = "",
        language!: String = "en"
    ): Unit {
        currentLanguage = language
        template = DocTemplate.forLanguage(language)
        clean(outRoot)
        let sourceLinks = SourceLinkConfig(project.name, sourceRoot, sourceRepository, sourceBranch)

        for (pkg in project.packages) {
            emitPackage(project, pkg, packageDir(outRoot, pkg.name), sourceRoot, sourceLinks)
        }

        emitPackagesIndex(project, outRoot)
        emitProjectIndex(project, outRoot)
        emitSummary(project, outRoot)
        emitSymbolIndex(project, outRoot)
    }

    private static func emitProjectIndex(project: DocProject, outRoot: String): Unit {
        let blocks = ArrayList<BlockSpec>()
        let packageRows = ArrayList<TableRowSpec>()

        for (pkg in project.packages) {
            packageRows.add(row(
                cell(codeLink(packageLink(pkg.name), pkg.name)),
                cell(countTypes(pkg).toString()),
                cell(countPackageFunctions(pkg).toString())
            ))
        }

        blocks.add(h1(template.apiReferenceTitle(project.name)))
        blocks.add(p(template.projectIntro()))
        blocks.add(divider())
        appendOptional(blocks, projectOverview(project))
        blocks.add(h2(template.packages()))
        if (packageRows.isEmpty()) {
            blocks.add(p(template.noPackages()))
        } else {
            blocks.add(table(
                header(template.packageLabel(), template.types(), template.functions()),
                packageRows.toArray()
            ))
        }

        EmitMarkdown.document(blocks.toArray()).dumpMarkdown(outRoot, filename: Pathing.packageIndexFile())
    }

    private static func emitPackagesIndex(project: DocProject, outRoot: String): Unit {
        let blocks = ArrayList<BlockSpec>()
        let packageRows = ArrayList<TableRowSpec>()

        for (pkg in project.packages) {
            packageRows.add(row(
                cell(codeLink(packageLinkFromPackagesRoot(pkg.name), pkg.name)),
                cell(countTypes(pkg).toString()),
                cell(countPackageFunctions(pkg).toString())
            ))
        }

        blocks.add(h1(template.packages()))
        blocks.add(p(template.allPackagesIntro()))
        blocks.add(divider())
        if (packageRows.isEmpty()) {
            blocks.add(p(template.noPackages()))
        } else {
            blocks.add(table(
                header(template.packageLabel(), template.types(), template.functions()),
                packageRows.toArray()
            ))
        }

        EmitMarkdown.document(blocks.toArray()).dumpMarkdown(
            Path(outRoot).join("packages").normalize().toString(),
            filename: Pathing.packageIndexFile()
        )
    }

    private static func emitPackage(
        project: DocProject,
        pkg: DocPackage,
        outDir: String,
        sourceRoot: String,
        sourceLinks: SourceLinkConfig
    ): Unit {
        let homepage = PackageHomepage.read(pkg.name, project.name, sourceRoot, language: currentLanguage)
        let blocks = ArrayList<BlockSpec>()
        if (homepage.isEmpty()) {
            blocks.add(p(template.packageIntro(pkg.name)))
        }
        appendOptional(blocks, packageOverview(pkg))

        let subpackages = directSubpackages(project, pkg.name)
        if (!subpackages.isEmpty()) {
            blocks.add(h2(template.subpackages()))
            blocks.add(subpackagesTable(pkg.name, subpackages))
        }

        blocks.add(h2(template.packageLevelDeclarations()))
        if (hasPackageDeclarations(pkg)) {
            appendOptional(blocks, typeDeclarationsGroup(template.types(), pkg.types, headingLevel: 3))
            appendOptional(blocks, valueGroup(project, pkg.name, template.globalVariables(), pkg.globalVars, "", headingLevel: 3))
            appendOptional(blocks, functionGroup(project, pkg.name, template.functions(), pkg.functions, "", headingLevel: 3))
        } else {
            blocks.add(p(template.noDeclarations()))
        }
        appendOptional(blocks, typeIndex(project, pkg))
        appendOptional(blocks, inheritanceGroup(project, pkg))
        appendOptional(blocks, extensionsGroup(project, pkg))

        writePackageIndex(pkg.name, homepage, blocks.toArray(), outDir)

        for (value in pkg.globalVars) {
            emitValuePage(pkg.name, "", template.globalVariableKind(), value, outDir, Pathing.topLevelValueFileName(value.name), sourceLinks)
        }
        for (fn in pkg.functions) {
            emitFunctionPage(pkg.name, "", template.functionKind(), fn, outDir, Pathing.topLevelFunctionFileName(fn.declaration), sourceLinks, project)
        }
        for (ty in pkg.types) {
            emitType(project, ty, outDir, sourceLinks)
        }
    }

    private static func emitType(project: DocProject, ty: DocType, outDir: String, sourceLinks: SourceLinkConfig): Unit {
        let blocks = ArrayList<BlockSpec>()
        blocks.add(h1(ty.name))
        blocks.add(EmitMarkdown.declarationBlock(ty.declaration))
        if (!ty.description.isEmpty()) {
            blocks.add(p(ty.description))
        }
        appendOptional(blocks, sourceParagraph(sourceLinks, ty.packageName, ty.source))
        if (let Some(relationships) <- typeRelationships(project, ty)) {
            blocks.add(h2(template.relationships()))
            blocks.add(relationships)
        }

        appendOptional(blocks, valueGroup(project, ty.packageName, template.properties(), ty.properties, ty.name))
        appendOptional(blocks, valueGroup(project, ty.packageName, template.staticProperties(), ty.staticProperties, ty.name))
        appendOptional(blocks, functionGroup(project, ty.packageName, template.constructors(), ty.constructors, ty.name))
        appendOptional(blocks, enumConstructorGroup(template.enumConstructors(), ty.enumConstructors, ty.name))
        appendOptional(blocks, functionGroup(project, ty.packageName, template.methods(), ty.methods, ty.name))

        EmitMarkdown.document(blocks.toArray()).dumpMarkdown(outDir, filename: Pathing.elementFileName(ty.name))

        for (value in ty.properties) {
            emitValuePage(
                ty.packageName,
                ty.name,
                template.propertyKind(),
                value,
                outDir,
                Pathing.typePropertyFileName(ty.name, value.name),
                sourceLinks
            )
        }
        for (value in ty.staticProperties) {
            emitValuePage(
                ty.packageName,
                ty.name,
                template.staticPropertyKind(),
                value,
                outDir,
                Pathing.typeStaticPropertyFileName(ty.name, value.name),
                sourceLinks
            )
        }
        for (fn in ty.constructors) {
            emitFunctionPage(
                ty.packageName,
                ty.name,
                template.constructorKind(),
                fn,
                outDir,
                Pathing.typeConstructorFileName(ty.name, fn.declaration),
                sourceLinks,
                project
            )
        }
        for (ctor in ty.enumConstructors) {
            emitEnumConstructorPage(
                ty.packageName,
                ty.name,
                ctor,
                outDir,
                Pathing.enumConstructorFileName(ty.name, ctor.declaration),
                sourceLinks,
                project
            )
        }
        for (fn in ty.methods) {
            emitFunctionPage(
                ty.packageName,
                ty.name,
                template.methodKind(),
                fn,
                outDir,
                Pathing.typeMethodFileName(ty.name, fn.declaration),
                sourceLinks,
                project
            )
        }
    }

    private static func projectOverview(project: DocProject): ?BlockSpec {
        let rows = ArrayList<TableRowSpec>()
        addCountRow(rows, template.packages(), project.packages.size)
        addCountRow(rows, template.types(), countProjectTypes(project))
        addCountRow(rows, template.functions(), countProjectFunctions(project))
        return overviewGroup(rows)
    }

    private static func packageOverview(pkg: DocPackage): ?BlockSpec {
        let rows = ArrayList<TableRowSpec>()
        addCountRow(rows, template.types(), nonExtensionTypes(pkg).size)
        addCountRow(rows, template.extensions(), extensionTypes(pkg).size)
        addCountRow(rows, template.globalVariables(), pkg.globalVars.size)
        addCountRow(rows, template.functions(), countPackageFunctions(pkg))
        addCountRow(rows, template.properties(), countPackageProperties(pkg))
        return overviewGroup(rows)
    }

    private static func overviewGroup(rows: ArrayList<TableRowSpec>): ?BlockSpec {
        if (rows.isEmpty()) {
            return None
        }
        return Some(group(
            template.overview(),
            header([template.item(), template.count()]),
            rows.toArray()
        ))
    }

    private static func addCountRow(rows: ArrayList<TableRowSpec>, label: String, count: Int64): Unit {
        if (count > 0) {
            rows.add(row([cell(label), cell(count.toString())]))
        }
    }

    private static func typeIndex(project: DocProject, pkg: DocPackage): ?BlockSpec {
        if (pkg.types.isEmpty()) {
            return None
        }

        let rows = ArrayList<TableRowSpec>()
        for (ty in pkg.types) {
            rows.add(row([
                cell(codeLink(Pathing.elementFileName(ty.name), ty.name)),
                cell(template.kindName(ty.kind)),
                typeRelationshipSummaryCell(project, pkg.name, ty),
                cell(typeMemberCount(ty).toString()),
                cell(ty.description)
            ]))
        }

        return Some(universalBlock(
            h2(template.typeIndex()),
            table(header([template.name(), template.kind(), template.relationships(), template.members(), template.description()]), rows.toArray())
        ))
    }

    private static func inheritanceGroup(project: DocProject, pkg: DocPackage): ?BlockSpec {
        let rows = ArrayList<TableRowSpec>()
        for (ty in pkg.types) {
            if (ty.kind == "Extend") {
                continue
            }
            let subtypes = knownSubtypes(project, ty)
            let supertypes = effectiveSupertypes(project, ty)
            if (supertypes.isEmpty() && subtypes.isEmpty()) {
                continue
            }
            rows.add(row([
                cell(codeLink(Pathing.elementFileName(ty.name), ty.name)),
                typeRefsCell(project, pkg.name, supertypes),
                typeLinksCell(pkg.name, subtypes)
            ]))
        }

        if (rows.isEmpty()) {
            return None
        }
        return Some(universalBlock(
            h2(template.inheritance()),
            table(header([template.typeLabel(), template.supertypesInterfaces(), template.knownSubtypes()]), rows.toArray())
        ))
    }

    private static func extensionsGroup(project: DocProject, pkg: DocPackage): ?BlockSpec {
        let extensions = extensionTypes(pkg)
        if (extensions.isEmpty()) {
            return None
        }

        let rows = ArrayList<TableRowSpec>()
        for (ty in extensions) {
            rows.add(row([
                cell(codeLink(Pathing.elementFileName(ty.name), ty.name)),
                extendedTypeCell(project, pkg.name, ty),
                implementedInterfacesCell(project, pkg.name, ty),
                cell(ty.methods.size.toString()),
                cell(ty.description)
            ]))
        }

        return Some(universalBlock(
            h2(template.extensions()),
            table(header([template.extensionLabel(), template.extendedType(), template.implementedInterfaces(), template.methods(), template.description()]), rows.toArray())
        ))
    }

    private static func typeRelationships(project: DocProject, ty: DocType): ?BlockSpec {
        let rows = ArrayList<TableRowSpec>()

        if (ty.kind == "Extend") {
            rows.add(row([cell(template.extendedType()), extendedTypeCell(project, ty.packageName, ty)]))
            let interfaces = implementedInterfaces(ty)
            if (!interfaces.isEmpty()) {
                rows.add(row([cell(template.implementedInterfaces()), typeRefsCell(project, ty.packageName, interfaces)]))
            }
        } else {
            let supertypes = effectiveSupertypes(project, ty)
            if (!supertypes.isEmpty()) {
                rows.add(row([cell(template.supertypesInterfaces()), typeRefsCell(project, ty.packageName, supertypes)]))
            }
        }

        let subtypes = knownSubtypes(project, ty)
        if (!subtypes.isEmpty()) {
            rows.add(row([cell(template.knownSubtypes()), typeLinksCell(ty.packageName, subtypes)]))
        }

        let extensions = extensionsForType(project, ty)
        if (!extensions.isEmpty()) {
            rows.add(row([cell(template.extensions()), typeLinksCell(ty.packageName, extensions)]))
        }

        if (rows.isEmpty()) {
            return None
        }
        return Some(table(header([template.kind(), template.types()]), rows.toArray()))
    }

    private static func typeRelationshipSummaryCell(
        project: DocProject,
        currentPackageName: String,
        ty: DocType
    ): TableCellSpec {
        if (ty.kind == "Extend") {
            let inlines = ArrayList<InlineSpec>()
            inlines.add(text(template.extendsPrefix()))
            for (item in cellInlines(extendedTypeCell(project, currentPackageName, ty))) {
                inlines.add(item)
            }
            let interfaces = implementedInterfaces(ty)
            if (!interfaces.isEmpty()) {
                inlines.add(text(template.implementsSeparator()))
                appendTypeRefs(inlines, project, currentPackageName, interfaces)
            }
            return cell(inlines.toArray())
        }

        let supertypes = effectiveSupertypes(project, ty)
        if (supertypes.isEmpty()) {
            return cell("")
        }
        return typeRefsCell(project, currentPackageName, supertypes)
    }

    private static func extendedTypeCell(project: DocProject, currentPackageName: String, ty: DocType): TableCellSpec {
        if (ty.supertypes.isEmpty()) {
            return cell("")
        }
        return typeRefCell(project, currentPackageName, ty.supertypes[0])
    }

    private static func implementedInterfacesCell(
        project: DocProject,
        currentPackageName: String,
        ty: DocType
    ): TableCellSpec {
        return typeRefsCell(project, currentPackageName, implementedInterfaces(ty))
    }

    private static func typeRefCell(project: DocProject, currentPackageName: String, ref: String): TableCellSpec {
        let inlines = ArrayList<InlineSpec>()
        appendTypeRef(inlines, project, currentPackageName, ref)
        return cell(inlines.toArray())
    }

    private static func typeRefsCell(project: DocProject, currentPackageName: String, refs: Array<String>): TableCellSpec {
        if (refs.isEmpty()) {
            return cell("")
        }
        let inlines = ArrayList<InlineSpec>()
        appendTypeRefs(inlines, project, currentPackageName, refs)
        return cell(inlines.toArray())
    }

    private static func typeLinksCell(currentPackageName: String, types: Array<DocType>): TableCellSpec {
        if (types.isEmpty()) {
            return cell("")
        }

        let inlines = ArrayList<InlineSpec>()
        for (i in 0..types.size) {
            if (i > 0) {
                inlines.add(text(", "))
            }
            let ty = types[i]
            inlines.add(codeLink(typeLinkFromPackage(currentPackageName, ty), ty.name))
        }
        return cell(inlines.toArray())
    }

    private static func appendTypeRefs(
        inlines: ArrayList<InlineSpec>,
        project: DocProject,
        currentPackageName: String,
        refs: Array<String>
    ): Unit {
        for (i in 0..refs.size) {
            if (i > 0) {
                inlines.add(text(", "))
            }
            appendTypeRef(inlines, project, currentPackageName, refs[i])
        }
    }

    private static func appendTypeRef(
        inlines: ArrayList<InlineSpec>,
        project: DocProject,
        currentPackageName: String,
        ref: String
    ): Unit {
        appendTypeNameInlines(inlines, project, currentPackageName, ref)
    }

    private static func cellInlines(cellSpec: TableCellSpec): Array<InlineSpec> {
        match (cellSpec) {
            case TableCell(items, _) => return items
        }
    }

    private static func findType(project: DocProject, currentPackageName: String, ref: String): ?DocType {
        let name = baseTypeName(ref)

        if (let Some(pkg) <- packageByName(project, currentPackageName)) {
            for (ty in pkg.types) {
                if (matchesTypeReference(name, ty)) {
                    return Some(ty)
                }
            }
        }

        for (pkg in project.packages) {
            for (ty in pkg.types) {
                if (qualifiedTypeName(ty) == name) {
                    return Some(ty)
                }
            }
        }

        for (pkg in project.packages) {
            for (ty in pkg.types) {
                if (ty.name == name) {
                    return Some(ty)
                }
            }
        }

        return None
    }

    private static func packageByName(project: DocProject, packageName: String): ?DocPackage {
        for (pkg in project.packages) {
            if (pkg.name == packageName) {
                return Some(pkg)
            }
        }
        return None
    }

    private static func matchesTypeReference(ref: String, ty: DocType): Bool {
        return ref == ty.name || ref == qualifiedTypeName(ty)
    }

    private static func matchesTypeReference(ref: String, target: DocType, candidate: DocType): Bool {
        let name = baseTypeName(ref)
        return matchesTypeReference(name, target) && !sameType(target, candidate)
    }

    private static func qualifiedTypeName(ty: DocType): String {
        return ty.packageName + "." + ty.name
    }

    private static func sameType(a: DocType, b: DocType): Bool {
        return a.packageName == b.packageName && a.name == b.name
    }

    private static func baseTypeName(ref: String): String {
        var value = ref.trimAscii()
        if (value.startsWith("?")) {
            value = value[1..value.size].trimAscii()
        }
        if (let Some(index) <- value.indexOf("<")) {
            value = value[0..index].trimAscii()
        }
        return value
    }

    private static func typeLinkFromPackage(currentPackageName: String, target: DocType): String {
        return typeLinkFromContext(currentPackageName, "", target)
    }

    private static func typeLinkFromContext(
        currentPackageName: String,
        samePackagePrefix: String,
        target: DocType
    ): String {
        if (target.packageName == currentPackageName) {
            return samePackagePrefix + Pathing.elementFileName(target.name)
        }
        return samePackagePrefix + packagesRootPrefix(currentPackageName) + "/" + target.packageName.replace(".", "/") + "/" +
            Pathing.elementFileName(target.name)
    }

    private static func packagesRootPrefix(packageName: String): String {
        let depth = packageName.split(".").size
        let parts = ArrayList<String>()
        for (_ in 0..depth) {
            parts.add("..")
        }
        return String.join(parts.toArray(), delimiter: "/")
    }

    private static func knownSubtypes(project: DocProject, target: DocType): Array<DocType> {
        let result = ArrayList<DocType>()
        for (pkg in project.packages) {
            for (candidate in pkg.types) {
                if (candidate.kind == "Extend") {
                    continue
                }
                for (ref in effectiveSupertypes(project, candidate)) {
                    if (matchesTypeReference(ref, target, candidate)) {
                        addTypeIfMissing(result, candidate)
                    }
                }
            }
        }
        return result.toArray()
    }

    private static func effectiveSupertypes(project: DocProject, ty: DocType): Array<String> {
        if (ty.kind == "Extend") {
            return ty.supertypes
        }

        let result = ArrayList<String>()
        let visited = ArrayList<String>()
        collectEffectiveSupertypeRefs(project, ty, result, visited)
        return result.toArray()
    }

    private static func collectEffectiveSupertypeRefs(
        project: DocProject,
        ty: DocType,
        result: ArrayList<String>,
        visited: ArrayList<String>
    ): Unit {
        if (!markVisited(visited, ty)) {
            return
        }

        for (ref in ty.supertypes) {
            addRefIfMissing(result, ref)
            if (let Some(superType) <- findType(project, ty.packageName, ref)) {
                if (!sameType(superType, ty)) {
                    collectEffectiveSupertypeRefs(project, superType, result, visited)
                }
            }
        }

        for (extension in extensionsForType(project, ty)) {
            for (ref in implementedInterfaces(extension)) {
                addRefIfMissing(result, ref)
                if (let Some(interfaceType) <- findType(project, ty.packageName, ref)) {
                    collectEffectiveSupertypeRefs(project, interfaceType, result, visited)
                }
            }
        }
    }

    private static func markVisited(visited: ArrayList<String>, ty: DocType): Bool {
        let key = qualifiedTypeName(ty)
        for (value in visited) {
            if (value == key) {
                return false
            }
        }
        visited.add(key)
        return true
    }

    private static func addRefIfMissing(refs: ArrayList<String>, ref: String): Unit {
        if (ref.trimAscii().isEmpty()) {
            return
        }
        for (existing in refs) {
            if (baseTypeName(existing) == baseTypeName(ref)) {
                return
            }
        }
        refs.add(ref)
    }

    private static func extensionsForType(project: DocProject, target: DocType): Array<DocType> {
        let result = ArrayList<DocType>()
        for (pkg in project.packages) {
            for (candidate in pkg.types) {
                if (candidate.kind != "Extend" || candidate.supertypes.isEmpty()) {
                    continue
                }
                if (matchesTypeReference(candidate.supertypes[0], target, candidate)) {
                    addTypeIfMissing(result, candidate)
                }
            }
        }
        return result.toArray()
    }

    private static func addTypeIfMissing(types: ArrayList<DocType>, value: DocType): Unit {
        for (existing in types) {
            if (sameType(existing, value)) {
                return
            }
        }
        types.add(value)
    }

    private static func implementedInterfaces(ty: DocType): Array<String> {
        if (ty.kind != "Extend" || ty.supertypes.size <= 1) {
            return []
        }

        let result = ArrayList<String>()
        for (i in 1..ty.supertypes.size) {
            result.add(ty.supertypes[i])
        }
        return result.toArray()
    }

    private static func nonExtensionTypes(pkg: DocPackage): Array<DocType> {
        let result = ArrayList<DocType>()
        for (ty in pkg.types) {
            if (ty.kind != "Extend") {
                result.add(ty)
            }
        }
        return result.toArray()
    }

    private static func extensionTypes(pkg: DocPackage): Array<DocType> {
        let result = ArrayList<DocType>()
        for (ty in pkg.types) {
            if (ty.kind == "Extend") {
                result.add(ty)
            }
        }
        return result.toArray()
    }

    private static func typeMemberCount(ty: DocType): Int64 {
        return Int64(
            ty.properties.size +
            ty.staticProperties.size +
            ty.constructors.size +
            ty.methods.size +
            ty.enumConstructors.size
        )
    }

    private static func typeDeclarationsGroup(
        title: String,
        types: Array<DocType>,
        headingLevel!: Int64 = 2
    ): ?BlockSpec {
        if (types.isEmpty()) {
            return None
        }

        let includeDescription = hasTypeDescriptions(types)
        let rows = Array<TableRowSpec>(types.size) { i =>
            let ty = types[i]
            if (includeDescription) {
                row(
                    cell(codeLink(Pathing.elementFileName(ty.name), ty.name)),
                    cell(template.kindName(ty.kind)),
                    EmitMarkdown.declarationCell(ty.declaration),
                    cell(ty.description)
                )
            } else {
                row(
                    cell(codeLink(Pathing.elementFileName(ty.name), ty.name)),
                    cell(template.kindName(ty.kind)),
                    EmitMarkdown.declarationCell(ty.declaration)
                )
            }
        }
        if (includeDescription) {
            return Some(group(title, header(template.name(), template.kind(), template.declaration(), template.description()), rows, headingLevel: headingLevel))
        }
        return Some(group(title, header(template.name(), template.kind(), template.declaration()), rows, headingLevel: headingLevel))
    }

    private static func valueGroup(
        project: DocProject,
        currentPackageName: String,
        title: String,
        values: Array<DocValue>,
        ownerTypeName: String,
        headingLevel!: Int64 = 2
    ): ?BlockSpec {
        if (values.isEmpty()) {
            return None
        }
        let includeDescription = hasValueDescriptions(values)
        let rows = Array<TableRowSpec>(values.size) { i =>
            let value = values[i]
            if (includeDescription) {
                row(
                    cell(codeLink(valuePageLink(title, ownerTypeName, value), value.name)),
                    typeNameCell(project, currentPackageName, value.typeName),
                    EmitMarkdown.declarationCell(value.declaration),
                    cell(value.description)
                )
            } else {
                row(
                    cell(codeLink(valuePageLink(title, ownerTypeName, value), value.name)),
                    typeNameCell(project, currentPackageName, value.typeName),
                    EmitMarkdown.declarationCell(value.declaration)
                )
            }
        }
        if (includeDescription) {
            return Some(group(title, header(template.name(), template.typeLabel(), template.declaration(), template.description()), rows, headingLevel: headingLevel))
        }
        return Some(group(title, header(template.name(), template.typeLabel(), template.declaration()), rows, headingLevel: headingLevel))
    }

    private static func functionGroup(
        project: DocProject,
        currentPackageName: String,
        title: String,
        values: Array<DocFunction>,
        ownerTypeName: String,
        headingLevel!: Int64 = 2
    ): ?BlockSpec {
        if (values.isEmpty()) {
            return None
        }
        let includeDescription = hasFunctionDescriptions(values)
        let rows = Array<TableRowSpec>(values.size) { i =>
            let value = values[i]
            if (value.isConstructor) {
                if (includeDescription) {
                    row(
                        cell(codeLink(functionPageLink(ownerTypeName, value), value.declaration)),
                        cell(value.description)
                    )
                } else {
                    row(cell(codeLink(functionPageLink(ownerTypeName, value), value.declaration)))
                }
            } else {
                if (includeDescription) {
                    row(
                        cell(codeLink(functionPageLink(ownerTypeName, value), value.name)),
                        EmitMarkdown.declarationCell(value.declaration),
                        typeNameCell(project, currentPackageName, value.returnType),
                        cell(value.description)
                    )
                } else {
                    row(
                        cell(codeLink(functionPageLink(ownerTypeName, value), value.name)),
                        EmitMarkdown.declarationCell(value.declaration),
                        typeNameCell(project, currentPackageName, value.returnType)
                    )
                }
            }
        }
        if (values[0].isConstructor) {
            if (includeDescription) {
                return Some(group(title, header(template.declaration(), template.description()), rows, headingLevel: headingLevel))
            }
            return Some(group(title, header(template.declaration()), rows, headingLevel: headingLevel))
        }
        if (includeDescription) {
            return Some(group(title, header(template.name(), template.declaration(), template.returns(), template.description()), rows, headingLevel: headingLevel))
        }
        return Some(group(title, header(template.name(), template.declaration(), template.returns()), rows, headingLevel: headingLevel))
    }

    private static func enumConstructorGroup(
        title: String,
        values: Array<DocEnumConstructor>,
        ownerTypeName: String
    ): ?BlockSpec {
        if (values.isEmpty()) {
            return None
        }
        let includeDescription = hasEnumConstructorDescriptions(values)
        let rows = Array<TableRowSpec>(values.size) { i =>
            let value = values[i]
            if (includeDescription) {
                row(
                    cell(codeLink(Pathing.enumConstructorFileName(ownerTypeName, value.declaration), value.name)),
                    EmitMarkdown.declarationCell(value.declaration),
                    cell(value.description)
                )
            } else {
                row(
                    cell(codeLink(Pathing.enumConstructorFileName(ownerTypeName, value.declaration), value.name)),
                    EmitMarkdown.declarationCell(value.declaration)
                )
            }
        }
        if (includeDescription) {
            return Some(group(title, header(template.name(), template.declaration(), template.description()), rows))
        }
        return Some(group(title, header(template.name(), template.declaration()), rows))
    }

    private static func hasTypeDescriptions(values: Array<DocType>): Bool {
        for (value in values) {
            if (!value.description.isEmpty()) {
                return true
            }
        }
        return false
    }

    private static func hasValueDescriptions(values: Array<DocValue>): Bool {
        for (value in values) {
            if (!value.description.isEmpty()) {
                return true
            }
        }
        return false
    }

    private static func hasFunctionDescriptions(values: Array<DocFunction>): Bool {
        for (value in values) {
            if (!value.description.isEmpty()) {
                return true
            }
        }
        return false
    }

    private static func hasEnumConstructorDescriptions(values: Array<DocEnumConstructor>): Bool {
        for (value in values) {
            if (!value.description.isEmpty()) {
                return true
            }
        }
        return false
    }

    private static func valuePageLink(title: String, ownerTypeName: String, value: DocValue): String {
        if (ownerTypeName.isEmpty()) {
            return Pathing.topLevelValueFileName(value.name)
        }
        if (title == template.staticProperties()) {
            return Pathing.typeStaticPropertyFileName(ownerTypeName, value.name)
        }
        return Pathing.typePropertyFileName(ownerTypeName, value.name)
    }

    private static func functionPageLink(ownerTypeName: String, value: DocFunction): String {
        if (ownerTypeName.isEmpty()) {
            return Pathing.topLevelFunctionFileName(value.declaration)
        }
        if (value.isConstructor) {
            return Pathing.typeConstructorFileName(ownerTypeName, value.declaration)
        }
        return Pathing.typeMethodFileName(ownerTypeName, value.declaration)
    }

    private static func emitValuePage(
        packageName: String,
        ownerTypeName: String,
        kind: String,
        value: DocValue,
        outDir: String,
        filename: String,
        sourceLinks: SourceLinkConfig
    ): Unit {
        let blocks = ArrayList<BlockSpec>()
        blocks.add(h1(value.name))
        blocks.add(EmitMarkdown.declarationBlock(value.declaration))
        if (!value.description.isEmpty()) {
            blocks.add(p(value.description))
        }
        appendOptional(blocks, memberContextParagraph(packageName, ownerTypeName, kind, value.source, sourceLinks))
        writeDocument(outDir, filename, blocks.toArray())
    }

    private static func emitFunctionPage(
        packageName: String,
        ownerTypeName: String,
        kind: String,
        value: DocFunction,
        outDir: String,
        filename: String,
        sourceLinks: SourceLinkConfig,
        project: DocProject
    ): Unit {
        let blocks = ArrayList<BlockSpec>()
        blocks.add(h1(value.title))
        blocks.add(EmitMarkdown.declarationBlock(value.declaration))
        if (!value.description.isEmpty()) {
            blocks.add(p(value.description))
        }
        appendOptional(blocks, memberContextParagraph(packageName, ownerTypeName, kind, value.source, sourceLinks))
        let samePackagePrefix = memberTypeLinkPrefix(ownerTypeName)
        addParameterSection(blocks, project, packageName, value.params, samePackagePrefix: samePackagePrefix)
        addReturnSection(blocks, project, packageName, value, samePackagePrefix: samePackagePrefix)
        addErrorSection(blocks, project, packageName, value.errors, samePackagePrefix: samePackagePrefix)
        addExampleSection(blocks, value.examples)
        writeDocument(outDir, filename, blocks.toArray())
    }

    private static func emitEnumConstructorPage(
        packageName: String,
        ownerTypeName: String,
        value: DocEnumConstructor,
        outDir: String,
        filename: String,
        sourceLinks: SourceLinkConfig,
        project: DocProject
    ): Unit {
        let blocks = ArrayList<BlockSpec>()
        blocks.add(h1(value.name))
        blocks.add(EmitMarkdown.declarationBlock(value.declaration))
        if (!value.description.isEmpty()) {
            blocks.add(p(value.description))
        }
        appendOptional(blocks, memberContextParagraph(packageName, ownerTypeName, template.enumConstructorKind(), "", sourceLinks))
        addParameterSection(blocks, project, packageName, value.params, samePackagePrefix: memberTypeLinkPrefix(ownerTypeName))
        writeDocument(outDir, filename, blocks.toArray())
    }

    private static func sourceParagraph(
        sourceLinks: SourceLinkConfig,
        packageName: String,
        source: String
    ): ?BlockSpec {
        if (let Some(url) <- sourceLinks.sourceUrl(packageName, source)) {
            return Some(p([link(url, template.source())]))
        }
        return None
    }

    private static func typeNameCell(
        project: DocProject,
        currentPackageName: String,
        typeName: String,
        samePackagePrefix!: String = ""
    ): TableCellSpec {
        return cell(typeNameInlines(project, currentPackageName, typeName, samePackagePrefix: samePackagePrefix))
    }

    private static func typeNameInlines(
        project: DocProject,
        currentPackageName: String,
        typeName: String,
        samePackagePrefix!: String = ""
    ): Array<InlineSpec> {
        let inlines = ArrayList<InlineSpec>()
        appendTypeNameInlines(inlines, project, currentPackageName, typeName, samePackagePrefix: samePackagePrefix)
        return inlines.toArray()
    }

    private static func appendTypeNameInlines(
        inlines: ArrayList<InlineSpec>,
        project: DocProject,
        currentPackageName: String,
        typeName: String,
        samePackagePrefix!: String = ""
    ): Unit {
        if (typeName.isEmpty()) {
            return
        }

        var literalStart: Int64 = 0
        var index: Int64 = 0
        while (index < typeName.size) {
            let ch = typeName[index]
            if (!isTypeIdentifierStart(ch)) {
                index += 1
                continue
            }

            var tokenEnd = index + 1
            while (tokenEnd < typeName.size && isTypeIdentifierPart(typeName[tokenEnd])) {
                tokenEnd += 1
            }

            let token = trimTrailingDots(typeName[index..tokenEnd])
            if (!token.isEmpty()) {
                if (let Some(ty) <- findType(project, currentPackageName, token)) {
                    if (literalStart < index) {
                        inlines.add(code(typeName[literalStart..index]))
                    }
                    inlines.add(codeLink(typeLinkFromContext(currentPackageName, samePackagePrefix, ty), token))
                    literalStart = index + token.size
                }
            }
            index = tokenEnd
        }

        if (literalStart < typeName.size) {
            inlines.add(code(typeName[literalStart..typeName.size]))
        }
    }

    private static func isTypeIdentifierStart(ch: Byte): Bool {
        return (ch >= b'a' && ch <= b'z') || (ch >= b'A' && ch <= b'Z') || ch == b'_'
    }

    private static func isTypeIdentifierPart(ch: Byte): Bool {
        return isTypeIdentifierStart(ch) || (ch >= b'0' && ch <= b'9') || ch == b'.'
    }

    private static func trimTrailingDots(value: String): String {
        var out = value
        while (out.endsWith(".")) {
            out = out[0..(out.size - 1)]
        }
        return out
    }

    private static func memberContextParagraph(
        packageName: String,
        ownerTypeName: String,
        kind: String,
        source: String,
        sourceLinks: SourceLinkConfig
    ): ?BlockSpec {
        let inlines = ArrayList<InlineSpec>()
        inlines.add(text(template.memberContextPrefix(kind)))
        if (!ownerTypeName.isEmpty()) {
            inlines.add(codeLink(typeOwnerLink(ownerTypeName), ownerTypeName))
        } else {
            inlines.add(codeLink(packageOwnerLink(ownerTypeName), packageName))
        }

        if (let Some(url) <- sourceLinks.sourceUrl(packageName, source)) {
            inlines.add(text(" · "))
            inlines.add(link(url, template.source()))
        }
        return Some(p(inlines.toArray()))
    }

    private static func typeOwnerLink(ownerTypeName: String): String {
        return "../../" + Pathing.elementFileName(ownerTypeName)
    }

    private static func packageOwnerLink(ownerTypeName: String): String {
        if (ownerTypeName.isEmpty()) {
            return "../" + Pathing.packageIndexFile()
        }
        return "../../" + Pathing.packageIndexFile()
    }

    private static func memberTypeLinkPrefix(ownerTypeName: String): String {
        if (ownerTypeName.isEmpty()) {
            return "../"
        }
        return "../../"
    }

    private static func addParameterSection(
        blocks: ArrayList<BlockSpec>,
        project: DocProject,
        currentPackageName: String,
        params: Array<DocParam>,
        samePackagePrefix!: String = ""
    ): Unit {
        if (params.isEmpty()) {
            return
        }
        let rows = Array<TableRowSpec>(params.size) { i =>
            let param = params[i]
            row(
                cell(code(param.name)),
                typeNameCell(project, currentPackageName, param.typeName, samePackagePrefix: samePackagePrefix),
                cell(param.description)
            )
        }
        blocks.add(h2(template.parameters()))
        blocks.add(table(header(template.name(), template.typeLabel(), template.description()), rows))
    }

    private static func addReturnSection(
        blocks: ArrayList<BlockSpec>,
        project: DocProject,
        currentPackageName: String,
        value: DocFunction,
        samePackagePrefix!: String = ""
    ): Unit {
        if (value.isConstructor || (value.returnType == "Unit" && value.returns.isEmpty())) {
            return
        }
        blocks.add(h2(template.returns()))
        if (value.returns.isEmpty()) {
            blocks.add(p(typeNameInlines(project, currentPackageName, value.returnType, samePackagePrefix: samePackagePrefix)))
        } else {
            let inlines = ArrayList<InlineSpec>()
            appendTypeNameInlines(inlines, project, currentPackageName, value.returnType, samePackagePrefix: samePackagePrefix)
            inlines.add(text(" - " + value.returns))
            blocks.add(p(inlines.toArray()))
        }
    }

    private static func addErrorSection(
        blocks: ArrayList<BlockSpec>,
        project: DocProject,
        currentPackageName: String,
        errors: Array<DocTag>,
        samePackagePrefix!: String = ""
    ): Unit {
        if (errors.isEmpty()) {
            return
        }
        let rows = Array<TableRowSpec>(errors.size) { i =>
            let error = errors[i]
            row(cell(typeNameInlines(project, currentPackageName, error.name, samePackagePrefix: samePackagePrefix)), cell(error.description))
        }
        blocks.add(h2(template.throwsLabel()))
        blocks.add(table(header(template.typeLabel(), template.description()), rows))
    }

    private static func addExampleSection(blocks: ArrayList<BlockSpec>, examples: Array<String>): Unit {
        if (examples.isEmpty()) {
            return
        }
        blocks.add(h2(template.examples()))
        for (example in examples) {
            blocks.add(codeBlock("cangjie", example))
        }
    }

    private static func writeDocument(outDir: String, filename: String, blocks: Array<BlockSpec>): Unit {
        let file = Path(outDir).join(filename).normalize()
        let parent = file.parent
        if (!parent.isEmpty() && !exists(parent)) {
            Directory.create(parent.toString(), recursive: true)
        }
        File.writeTo(file, (EmitMarkdown.document(blocks).toMarkdown().trimAsciiEnd() + "\n").toArray())
    }

    private static func group(
        title: String,
        headings: TableRowSpec,
        rows: Array<TableRowSpec>,
        headingLevel!: Int64 = 2
    ): BlockSpec {
        return universalBlock(
            h(headingLevel, title),
            table(headings, rows)
        )
    }

    private static func writePackageIndex(
        packageName: String,
        homepage: String,
        blocks: Array<BlockSpec>,
        outDir: String
    ): Unit {
        let dir = Path(outDir)
        if (!exists(dir)) {
            Directory.create(outDir, recursive: true)
        }

        let heading = EmitMarkdown.document([h1(packageName)]).toMarkdown().trimAsciiEnd()
        let body = EmitMarkdown.document(blocks).toMarkdown().trimAscii()
        let content = if (homepage.isEmpty()) {
            heading + "\n\n" + body + "\n"
        } else {
            heading + "\n\n" + homepage.trimAscii() + "\n\n" + body + "\n"
        }
        File.writeTo(dir.join(Pathing.packageIndexFile()), content.toArray())
    }

    private static func subpackagesTable(packageName: String, subpackages: Array<DocPackage>): BlockSpec {
        let prefix = packageName + "."
        let rows = Array<TableRowSpec>(subpackages.size) { i =>
            let sp = subpackages[i]
            let rest = if (sp.name.startsWith(prefix)) { sp.name[prefix.size..sp.name.size] } else { sp.name }
            row(
                cell(code(sp.name)),
                cell(codeLink(rest.replace(".", "/") + "/" + Pathing.packageIndexFile(), sp.name))
            )
        }
        return table(header(template.name(), template.linkLabel()), rows)
    }

    private static func directSubpackages(project: DocProject, packageName: String): Array<DocPackage> {
        let out = ArrayList<DocPackage>()
        let prefix = packageName + "."
        for (pkg in project.packages) {
            if (!pkg.name.startsWith(prefix)) {
                continue
            }
            let rest = pkg.name[prefix.size..pkg.name.size]
            if (!rest.contains(".")) {
                out.add(pkg)
            }
        }
        return out.toArray()
    }

    private static func emitSummary(project: DocProject, outRoot: String): Unit {
        let blocks = ArrayList<BlockSpec>()
        blocks.add(h1(template.packages()))

        let packageItems = ArrayList<ListItemSpec>()
        packageItems.add(linkListItem("packages/index.md", template.allPackages(), icon: "package"))
        for (pkg in project.packages) {
            let children = ArrayList<ListItemSpec>()
            for (value in pkg.globalVars) {
                children.add(linkListItem(
                    packageDirRelative(pkg.name) + "/" + Pathing.topLevelValueFileName(value.name),
                    value.name,
                    icon: "global-variable"
                ))
            }
            for (fn in pkg.functions) {
                children.add(linkListItem(
                    packageDirRelative(pkg.name) + "/" + Pathing.topLevelFunctionFileName(fn.declaration),
                    fn.name,
                    icon: "function"
                ))
            }
            for (ty in pkg.types) {
                children.add(linkListItem(
                    packageDirRelative(pkg.name) + "/" + Pathing.elementFileName(ty.name),
                    ty.name,
                    icon: typeNavIcon(ty),
                    children: typeMemberNavItems(pkg.name, ty)
                ))
            }
            packageItems.add(linkListItem(packageLink(pkg.name), pkg.name, icon: "package", children: children.toArray()))
        }

        blocks.add(ul(packageItems.toArray()))
        blocks.add(htmlBlock("<!-- homepage -->"))
        blocks.add(h1(template.apiReferenceTitle(project.name)))
        blocks.add(p(template.projectHomeIntro()))
        appendOptional(blocks, projectOverview(project))
        blocks.add(h2(template.packages()))

        let homepagePackageItems = ArrayList<ListItemSpec>()
        for (pkg in project.packages) {
            homepagePackageItems.add(linkListItem(packageLink(pkg.name), pkg.name, icon: "package"))
        }
        blocks.add(ul(homepagePackageItems.toArray()))

        File.writeTo(
            Path(outRoot).join("markit.md"),
            (EmitMarkdown.document(blocks.toArray()).toMarkdown().trimAsciiEnd() + "\n").toArray()
        )
    }

    private static func typeMemberNavItems(packageName: String, ty: DocType): Array<ListItemSpec> {
        let items = ArrayList<ListItemSpec>()
        let base = packageDirRelative(packageName) + "/"
        for (value in ty.properties) {
            items.add(linkListItem(base + Pathing.typePropertyFileName(ty.name, value.name), value.name, icon: "property"))
        }
        for (value in ty.staticProperties) {
            items.add(linkListItem(
                base + Pathing.typeStaticPropertyFileName(ty.name, value.name),
                value.name,
                icon: "static-property"
            ))
        }
        for (fn in ty.constructors) {
            items.add(linkListItem(
                base + Pathing.typeConstructorFileName(ty.name, fn.declaration),
                fn.title,
                icon: "constructor"
            ))
        }
        for (ctor in ty.enumConstructors) {
            items.add(linkListItem(
                base + Pathing.enumConstructorFileName(ty.name, ctor.declaration),
                ctor.name,
                icon: "enum-case"
            ))
        }
        for (fn in ty.methods) {
            items.add(linkListItem(base + Pathing.typeMethodFileName(ty.name, fn.declaration), fn.name, icon: "method"))
        }
        return items.toArray()
    }

    private static func typeNavIcon(ty: DocType): String {
        match (ty.kind) {
            case "Class" => return if (ty.declaration.contains("abstract class")) { "abstract-class" } else { "class" }
            case "Interface" => return "interface"
            case "Struct" => return "struct"
            case "Enum" => return "enum"
            case "Extend" => return "extension"
            case _ => return "type"
        }
    }

    private static func linkListItem(
        url: String,
        label: String,
        icon!: String = "",
        children!: Array<ListItemSpec> = []
    ): ListItemSpec {
        let blocks = ArrayList<BlockSpec>()
        blocks.add(p([link(url, label, title: navIconTitle(icon))]))
        if (!children.isEmpty()) {
            blocks.add(ul(children))
        }
        return item(blocks.toArray())
    }

    private static func navIconTitle(icon: String): String {
        if (icon.trimAscii().isEmpty()) {
            return ""
        }
        return "nav-icon:" + icon.trimAscii()
    }

    private static func emitSymbolIndex(project: DocProject, outRoot: String): Unit {
        let entries = ArrayList<String>()
        entries.add(symbolEntry(
            project.name,
            template.apiReferenceTitle(project.name),
            "index.md",
            [project.name, template.apiReferenceTitle(project.name)]
        ))

        for (pkg in project.packages) {
            let pkgDir = packageDirRelative(pkg.name)
            entries.add(symbolEntry(
                pkg.name,
                template.packageSymbolDescription(pkg.name),
                pkgDir + "/" + Pathing.packageIndexFile(),
                [pkg.name, template.packageSymbolDescription(pkg.name)]
            ))
            for (value in pkg.globalVars) {
                entries.add(symbolEntry(
                    value.name,
                    pkg.name + "." + value.name,
                    pkgDir + "/" + Pathing.topLevelValueFileName(value.name),
                    [value.name, value.declaration, pkg.name + "." + value.name]
                ))
            }
            for (fn in pkg.functions) {
                entries.add(symbolEntry(
                    fn.name,
                    pkg.name + "." + fn.name,
                    pkgDir + "/" + Pathing.topLevelFunctionFileName(fn.declaration),
                    [fn.name, fn.declaration, pkg.name + "." + fn.name]
                ))
            }
            for (ty in pkg.types) {
                let typeQualified = qualifiedTypeName(ty)
                entries.add(symbolEntry(
                    ty.name,
                    typeQualified,
                    pkgDir + "/" + Pathing.elementFileName(ty.name),
                    [ty.name, ty.declaration, typeQualified]
                ))
                appendTypeSymbolEntries(entries, pkgDir, ty)
            }
        }

        let content = "[\n" + String.join(entries.toArray(), delimiter: ",\n") + "\n]\n"
        File.writeTo(Path(outRoot).join("pages.json"), content.toArray())
    }

    private static func appendTypeSymbolEntries(entries: ArrayList<String>, pkgDir: String, ty: DocType): Unit {
        let typeQualified = qualifiedTypeName(ty)
        for (value in ty.properties) {
            entries.add(symbolEntry(
                value.name,
                typeQualified + "." + value.name,
                pkgDir + "/" + Pathing.typePropertyFileName(ty.name, value.name),
                [value.name, value.declaration, typeQualified + "." + value.name]
            ))
        }
        for (value in ty.staticProperties) {
            entries.add(symbolEntry(
                value.name,
                typeQualified + "." + value.name,
                pkgDir + "/" + Pathing.typeStaticPropertyFileName(ty.name, value.name),
                [value.name, value.declaration, typeQualified + "." + value.name]
            ))
        }
        for (fn in ty.constructors) {
            entries.add(symbolEntry(
                fn.title,
                typeQualified + ".init",
                pkgDir + "/" + Pathing.typeConstructorFileName(ty.name, fn.declaration),
                [fn.title, fn.declaration, typeQualified + ".init"]
            ))
        }
        for (ctor in ty.enumConstructors) {
            entries.add(symbolEntry(
                ctor.name,
                typeQualified + "." + ctor.name,
                pkgDir + "/" + Pathing.enumConstructorFileName(ty.name, ctor.declaration),
                [ctor.name, ctor.declaration, typeQualified + "." + ctor.name]
            ))
        }
        for (fn in ty.methods) {
            entries.add(symbolEntry(
                fn.name,
                typeQualified + "." + fn.name,
                pkgDir + "/" + Pathing.typeMethodFileName(ty.name, fn.declaration),
                [fn.name, fn.declaration, typeQualified + "." + fn.name]
            ))
        }
    }

    private static func symbolEntry(
        name: String,
        description: String,
        location: String,
        searchKeys: Array<String>
    ): String {
        return "  {\"name\":" + jsonString(name) +
            ",\"description\":" + jsonString(description) +
            ",\"location\":" + jsonString(location) +
            ",\"searchKeys\":" + jsonStringArray(searchKeys) + "}"
    }

    private static func jsonStringArray(values: Array<String>): String {
        let items = Array<String>(values.size) { i => jsonString(values[i]) }
        return "[" + String.join(items, delimiter: ",") + "]"
    }

    private static func jsonString(value: String): String {
        var escaped = value.replace("\\", "\\\\")
        escaped = escaped.replace("\"", "\\\"")
        escaped = escaped.replace("\r", "\\r")
        escaped = escaped.replace("\n", "\\n")
        escaped = escaped.replace("\t", "\\t")
        return "\"" + escaped + "\""
    }

    private static func packageDir(outRoot: String, packageName: String): String {
        return Path(outRoot).join(packageDirRelative(packageName)).normalize().toString()
    }

    private static func packageDirRelative(packageName: String): String {
        return "packages/" + packageName.replace(".", "/")
    }

    private static func packageLink(packageName: String): String {
        return packageDirRelative(packageName) + "/" + Pathing.packageIndexFile()
    }

    private static func packageLinkFromPackagesRoot(packageName: String): String {
        return packageName.replace(".", "/") + "/" + Pathing.packageIndexFile()
    }

    private static func clean(outRoot: String): Unit {
        let path = Path(outRoot)
        try {
            if (exists(path)) {
                remove(path, recursive: true)
            }
        } catch (e: Exception) {
            ()
        }
        Directory.create(outRoot, recursive: true)
    }

    private static func appendOptional(blocks: ArrayList<BlockSpec>, block: ?BlockSpec): Unit {
        if (let Some(value) <- block) {
            blocks.add(value)
        }
    }

    private static func hasPackageDeclarations(pkg: DocPackage): Bool {
        return !pkg.types.isEmpty() || !pkg.globalVars.isEmpty() || !pkg.functions.isEmpty()
    }

    private static func countProjectTypes(project: DocProject): Int64 {
        var count: Int64 = 0
        for (pkg in project.packages) {
            count += countTypes(pkg)
        }
        return count
    }

    private static func countProjectFunctions(project: DocProject): Int64 {
        var count: Int64 = 0
        for (pkg in project.packages) {
            count += countPackageFunctions(pkg)
        }
        return count
    }

    private static func countTypes(pkg: DocPackage): Int64 {
        return Int64(pkg.types.size)
    }

    private static func countPackageFunctions(pkg: DocPackage): Int64 {
        var count = Int64(pkg.functions.size)
        for (ty in pkg.types) {
            count += Int64(ty.constructors.size)
            count += Int64(ty.methods.size)
        }
        return count
    }

    private static func countPackageProperties(pkg: DocPackage): Int64 {
        var count = Int64(pkg.globalVars.size)
        for (ty in pkg.types) {
            count += Int64(ty.properties.size)
            count += Int64(ty.staticProperties.size)
        }
        return count
    }
}
