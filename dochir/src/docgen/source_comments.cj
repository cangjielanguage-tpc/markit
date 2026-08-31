package dochir.docgen

import std.collection.{ArrayList, HashMap}
import std.convert.Parsable
import std.fs.{Directory, File, FileInfo, Path, exists}
import stdx.chir.DebugLocation

class SourceLocation {
    let fileName: String
    let line: Int64
    let packageName: String

    init(fileName: String, line: Int64, packageName!: String = "") {
        this.fileName = fileName
        this.line = line
        this.packageName = packageName
    }

    func label(): String {
        return fileName + ":" + line.toString()
    }
}

class SourceDoc {
    let summary: String
    let params: Array<(String, String)>
    let returns: String
    let typeText: String
    let errors: Array<(String, String)>
    let examples: Array<String>

    init(
        summary: String,
        params: Array<(String, String)>,
        returns: String,
        typeText: String,
        errors!: Array<(String, String)> = Array<(String, String)>(),
        examples!: Array<String> = Array<String>()
    ) {
        this.summary = summary
        this.params = params
        this.returns = returns
        this.typeText = typeText
        this.errors = errors
        this.examples = examples
    }
}

class DocParseState {
    let params: ArrayList<(String, String)>
    let errors: ArrayList<(String, String)>
    let examples: ArrayList<String>
    let descriptions: HashMap<String, String>
    let descriptionOrder: ArrayList<String>
    let paramPriorities: HashMap<String, Int64>
    let errorPriorities: HashMap<String, Int64>
    var returns: String
    var returnsPriority: Int64
    var typeText: String

    init() {
        this.params = ArrayList<(String, String)>()
        this.errors = ArrayList<(String, String)>()
        this.examples = ArrayList<String>()
        this.descriptions = HashMap<String, String>()
        this.descriptionOrder = ArrayList<String>()
        this.paramPriorities = HashMap<String, Int64>()
        this.errorPriorities = HashMap<String, Int64>()
        this.returns = ""
        this.returnsPriority = 0
        this.typeText = ""
    }
}

public class SourceComments {
    private static var indexed = false
    private static var filesByName = HashMap<String, ArrayList<Path>>()
    private static var allSourceFiles = ArrayList<Path>()
    private static var contentByPath = HashMap<String, Array<String>>()
    private static var language = "en"
    private static var defaultLang = "en"

    public static func configure(language!: String = "en", defaultLang!: String = "en"): Unit {
        SourceComments.language = normalizeLanguage(language)
        SourceComments.defaultLang = normalizeLanguage(defaultLang)
    }

    public static func descriptionForText(text: String): String {
        if (let Some(loc) <- parseLocation(text)) {
            return docForLocation(loc).summary
        }
        return ""
    }

    public static func descriptionForText(text: String, packageName: String): String {
        return sourceDocForText(text, packageName).summary
    }

    public static func descriptionForLocation(loc: DebugLocation): String {
        return docForLocation(loc).summary
    }

    public static func descriptionForEnumConstructor(packageName: String, enumName: String, ctorName: String): String {
        return sourceDocForEnumConstructor(packageName, enumName, ctorName).summary
    }

    public static func paramSummaryForText(text: String): String {
        if (let Some(loc) <- parseLocation(text)) {
            return paramSummary(docForLocation(loc))
        }
        return ""
    }

    public static func returnDescriptionForText(text: String): String {
        if (let Some(loc) <- parseLocation(text)) {
            return docForLocation(loc).returns
        }
        return ""
    }

    public static func typeTextForLocation(loc: DebugLocation): String {
        return docForLocation(loc).typeText
    }

    public static func locationLabelForText(text: String): String {
        if (let Some(loc) <- parseLocation(text)) {
            return loc.label()
        }
        return ""
    }

    public static func locationLabelForLocation(loc: DebugLocation): String {
        if (!loc.isValid()) {
            return ""
        }
        return loc.filePath.fileName + ":" + loc.start.line.toString()
    }

    static func sourceDocForText(text: String): SourceDoc {
        if (let Some(loc) <- parseLocation(text)) {
            return docForLocation(loc)
        }
        return emptyDoc()
    }

    static func sourceDocForText(text: String, packageName: String): SourceDoc {
        if (let Some(loc) <- parseLocation(text)) {
            let scopedPackage = if (loc.packageName.isEmpty()) { packageName } else { loc.packageName }
            return docForLocation(SourceLocation(loc.fileName, loc.line, packageName: scopedPackage))
        }
        return emptyDoc()
    }

    static func sourceDocForLocation(loc: DebugLocation): SourceDoc {
        return docForLocation(loc)
    }

    static func sourceDocForEnumConstructor(packageName: String, enumName: String, ctorName: String): SourceDoc {
        ensureIndexed()
        for (path in preferredSourceFiles(packageName)) {
            let doc = sourceDocForEnumConstructorInFile(path, enumName, ctorName)
            if (!doc.summary.isEmpty() || !doc.returns.isEmpty() || !doc.params.isEmpty() ||
                !doc.typeText.isEmpty() || !doc.errors.isEmpty() || !doc.examples.isEmpty()) {
                return doc
            }
        }
        return emptyDoc()
    }

    static func docForTesting(lines: Array<String>, declarationLine: Int64): SourceDoc {
        return extractLeadingComment(lines, declarationLine)
    }

    static func enumConstructorDocForTesting(lines: Array<String>, enumName: String, ctorName: String): SourceDoc {
        return sourceDocForEnumConstructorInLines(lines, enumName, ctorName)
    }

    private static func docForLocation(loc: DebugLocation): SourceDoc {
        if (!loc.isValid()) {
            return emptyDoc()
        }
        return docForPath(loc.filePath, loc.start.line)
    }

    private static func docForLocation(loc: SourceLocation): SourceDoc {
        ensureIndexed()
        for (path in preferredPaths(loc)) {
            if (exists(path)) {
                let doc = docForPath(path, loc.line)
                if (!doc.summary.isEmpty() || !doc.returns.isEmpty() || !doc.params.isEmpty() ||
                    !doc.typeText.isEmpty() || !doc.errors.isEmpty() || !doc.examples.isEmpty()) {
                    return doc
                }
            }
        }
        if (let Some(paths) <- filesByName.get(loc.fileName)) {
            for (path in paths) {
                let doc = docForPath(path, loc.line)
                if (!doc.summary.isEmpty() || !doc.returns.isEmpty() || !doc.params.isEmpty() ||
                    !doc.typeText.isEmpty() || !doc.errors.isEmpty() || !doc.examples.isEmpty()) {
                    return doc
                }
            }
        }
        let direct = Path(loc.fileName)
        if (exists(direct)) {
            return docForPath(direct, loc.line)
        }
        return emptyDoc()
    }

    private static func docForPath(path: Path, line: Int64): SourceDoc {
        if (line <= 1) {
            return emptyDoc()
        }
        let lines = readLines(path)
        if (lines.isEmpty()) {
            return emptyDoc()
        }
        if (line > lines.size) {
            return emptyDoc()
        }
        return extractLeadingComment(lines, line)
    }

    private static func sourceDocForEnumConstructorInFile(path: Path, enumName: String, ctorName: String): SourceDoc {
        let lines = readLines(path)
        return sourceDocForEnumConstructorInLines(lines, enumName, ctorName)
    }

    private static func sourceDocForEnumConstructorInLines(
        lines: Array<String>,
        enumName: String,
        ctorName: String
    ): SourceDoc {
        var inEnum = false
        var depth: Int64 = 0
        for (i in 0..lines.size) {
            let trimmed = lines[i].trimAscii()
            if (!inEnum) {
                if (isEnumDeclarationLine(trimmed, enumName)) {
                    inEnum = true
                    depth += braceDelta(trimmed)
                }
                continue
            }

            if (isEnumConstructorLine(trimmed, ctorName)) {
                return extractLeadingComment(lines, i + 1)
            }

            depth += braceDelta(trimmed)
            if (depth <= 0) {
                inEnum = false
            }
        }
        return emptyDoc()
    }

    private static func readLines(path: Path): Array<String> {
        let key = path.normalize().toString()
        if (let Some(lines) <- contentByPath.get(key)) {
            return lines
        }
        try {
            let text = String.fromUtf8(File.readFrom(path))
            let lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
            contentByPath[key] = lines
            return lines
        } catch (e: Exception) {
            return Array<String>()
        }
    }

    private static func extractLeadingComment(lines: Array<String>, line: Int64): SourceDoc {
        var i = line - 2
        while (i >= 0 && lines[i].trimAscii().isEmpty()) {
            i--
        }
        while (i >= 0 && lines[i].trimAscii().startsWith("@")) {
            i--
            while (i >= 0 && lines[i].trimAscii().isEmpty()) {
                i--
            }
        }
        if (i < 0) {
            return emptyDoc()
        }

        let trimmed = lines[i].trimAscii()
        if (trimmed.startsWith("///")) {
            return emptyDoc()
        }
        if (trimmed.startsWith("//")) {
            return extractLineDoc(lines, i)
        }
        if (trimmed.endsWith("*/")) {
            return extractBlockDoc(lines, i)
        }
        return emptyDoc()
    }

    private static func extractLineDoc(lines: Array<String>, endIndex: Int64): SourceDoc {
        let items = ArrayList<String>()
        var i = endIndex
        while (i >= 0) {
            let trimmed = lines[i].trimAscii()
            if (!trimmed.startsWith("//") || trimmed.startsWith("///")) {
                break
            }
            items.add(cleanLineDoc(trimmed), at: 0)
            i--
        }
        return parseDocLines(items)
    }

    private static func cleanLineDoc(line: String): String {
        return line.removePrefix("//").trimAscii()
    }

    private static func extractBlockDoc(lines: Array<String>, endIndex: Int64): SourceDoc {
        let items = ArrayList<String>()
        var i = endIndex
        while (i >= 0) {
            let raw = lines[i].trimAscii()
            var text = raw
            if (text.endsWith("*/")) {
                text = text[0..(text.size - 2)].trimAscii()
            }
            if (text.startsWith("/**")) {
                text = text.removePrefix("/**").trimAscii()
                if (!text.isEmpty()) {
                    items.add(cleanBlockLine(text), at: 0)
                }
                break
            }
            items.add(cleanBlockLine(text), at: 0)
            i--
        }
        return parseDocLines(items)
    }

    private static func cleanBlockLine(line: String): String {
        let trimmed = line.trimAscii()
        if (trimmed.startsWith("*")) {
            return trimmed.removePrefix("*").trimAscii()
        }
        return trimmed
    }

    private static func parseDocLines(lines: ArrayList<String>): SourceDoc {
        let summary = ArrayList<String>()
        let state = DocParseState()
        var activeTag = ""
        var activeParam = ""
        var activeLang = ""
        let activeText = ArrayList<String>()

        for (line in lines) {
            let trimmed = line.trimAscii()
            if (trimmed.isEmpty()) {
                continue
            }
            if (trimmed.startsWith("@")) {
                flushTag(state, activeTag, activeParam, activeLang, activeText)
                activeText.clear()
                activeParam = ""
                activeLang = ""
                if (isDescriptionTag(trimmed)) {
                    activeTag = "description"
                    activeLang = descriptionTagLanguage(trimmed)
                    addIfNotEmpty(activeText, descriptionTagText(trimmed))
                } else if (isLocalizedTag(trimmed, "param")) {
                    activeTag = "param"
                    activeLang = localizedTagLanguage(trimmed, "param")
                    let rest = localizedTagText(trimmed)
                    let (name, text) = splitTaggedName(rest)
                    activeParam = name
                    addIfNotEmpty(activeText, text)
                } else if (isLocalizedTag(trimmed, "return")) {
                    activeTag = "return"
                    activeLang = localizedTagLanguage(trimmed, "return")
                    addIfNotEmpty(activeText, localizedTagText(trimmed))
                } else if (trimmed.startsWith("@type ")) {
                    activeTag = "type"
                    activeText.add(cleanTypeText(trimmed.removePrefix("@type ").trimAscii()))
                } else if (trimmed == "@type") {
                    activeTag = "type"
                } else if (isLocalizedTag(trimmed, "throws")) {
                    activeTag = "throws"
                    activeLang = localizedTagLanguage(trimmed, "throws")
                    let (name, text) = splitTaggedName(localizedTagText(trimmed))
                    activeParam = name
                    addIfNotEmpty(activeText, text)
                } else if (isLocalizedTag(trimmed, "exception")) {
                    activeTag = "throws"
                    activeLang = localizedTagLanguage(trimmed, "exception")
                    let (name, text) = splitTaggedName(localizedTagText(trimmed))
                    activeParam = name
                    addIfNotEmpty(activeText, text)
                } else if (trimmed.startsWith("@example ")) {
                    activeTag = "example"
                    activeText.add(trimmed.removePrefix("@example ").trimAscii())
                } else if (trimmed == "@example") {
                    activeTag = "example"
                } else {
                    activeTag = "unknown"
                    activeText.add(trimmed)
                }
            } else if (!activeTag.isEmpty()) {
                activeText.add(trimmed)
            } else {
                summary.add(trimmed)
            }
        }
        flushTag(state, activeTag, activeParam, activeLang, activeText)

        return SourceDoc(
            selectedDescription(state, compactDocLines(summary)),
            state.params.toArray(),
            state.returns,
            state.typeText,
            errors: state.errors.toArray(),
            examples: state.examples.toArray()
        )
    }

    private static func flushTag(
        state: DocParseState,
        activeTag: String,
        activeParam: String,
        activeLang: String,
        activeText: ArrayList<String>
    ): Unit {
        if (activeTag.isEmpty()) {
            return
        }
        let text = if (activeTag == "example") { compactExampleLines(activeText) } else { compactDocLines(activeText) }
        if (activeTag == "description") {
            addDescription(state, activeLang, text)
        } else if (activeTag == "param" && !activeParam.isEmpty()) {
            addParam(state, activeLang, activeParam, text)
        } else if (activeTag == "return") {
            addReturn(state, activeLang, text)
        } else if (activeTag == "type") {
            state.typeText = text
        } else if (activeTag == "throws" && !activeParam.isEmpty()) {
            addError(state, activeLang, activeParam, text)
        } else if (activeTag == "example" && !text.isEmpty()) {
            state.examples.add(text)
        }
    }

    private static func addParam(state: DocParseState, lang: String, name: String, text: String): Unit {
        let priority = localizedPriority(lang)
        if (let Some(existing) <- state.paramPriorities.get(name)) {
            if (priority < existing) {
                return
            }
            for (i in 0..state.params.size) {
                if (state.params[i][0] == name) {
                    state.params[i] = (name, text)
                    state.paramPriorities[name] = priority
                    return
                }
            }
        }
        state.params.add((name, text))
        state.paramPriorities[name] = priority
    }

    private static func addReturn(state: DocParseState, lang: String, text: String): Unit {
        let priority = localizedPriority(lang)
        if (priority < state.returnsPriority) {
            return
        }
        state.returns = text
        state.returnsPriority = priority
    }

    private static func addError(state: DocParseState, lang: String, name: String, text: String): Unit {
        let priority = localizedPriority(lang)
        if (let Some(existing) <- state.errorPriorities.get(name)) {
            if (priority < existing) {
                return
            }
            for (i in 0..state.errors.size) {
                if (state.errors[i][0] == name) {
                    state.errors[i] = (name, text)
                    state.errorPriorities[name] = priority
                    return
                }
            }
        }
        state.errors.add((name, text))
        state.errorPriorities[name] = priority
    }

    private static func addDescription(state: DocParseState, lang: String, text: String): Unit {
        if (text.isEmpty()) {
            return
        }
        let key = if (lang.isEmpty()) { defaultLang } else { normalizeLanguage(lang) }
        if (let Some(existing) <- state.descriptions.get(key)) {
            state.descriptions[key] = existing + " " + text
        } else {
            state.descriptions[key] = text
            state.descriptionOrder.add(key)
        }
    }

    private static func selectedDescription(state: DocParseState, legacySummary: String): String {
        if (let Some(value) <- state.descriptions.get(language)) {
            return value
        }
        if (let Some(value) <- state.descriptions.get(defaultLang)) {
            return value
        }
        if (let Some(value) <- state.descriptions.get("en")) {
            return value
        }
        if (!state.descriptionOrder.isEmpty()) {
            if (let Some(value) <- state.descriptions.get(state.descriptionOrder[0])) {
                return value
            }
        }
        return legacySummary
    }

    private static func isLocalizedTag(text: String, name: String): Bool {
        let tag = firstToken(text)
        let base = "@" + name
        return tag == base || tag.startsWith(base + "-")
    }

    private static func localizedTagLanguage(text: String, name: String): String {
        let tag = firstToken(text)
        let base = "@" + name
        if (tag == base) {
            return defaultLang
        }
        if (tag.startsWith(base + "-")) {
            return normalizeLanguage(tag[(base.size + 1)..tag.size])
        }
        return defaultLang
    }

    private static func localizedTagText(text: String): String {
        if (let Some(index) <- text.indexOf(" ")) {
            return text[(index + 1)..text.size].trimAscii()
        }
        return ""
    }

    private static func localizedPriority(lang: String): Int64 {
        let normalized = normalizeLanguage(lang)
        if (normalized == language) {
            return 4
        }
        if (normalized == defaultLang) {
            return 3
        }
        if (normalized == "en") {
            return 2
        }
        return 1
    }

    private static func isDescriptionTag(text: String): Bool {
        return text == "@description" || text.startsWith("@description ") ||
            text.startsWith("@description-") || text == "@decription" ||
            text.startsWith("@decription ") || text.startsWith("@decription-")
    }

    private static func descriptionTagLanguage(text: String): String {
        let tag = firstToken(text)
        if (let Some(index) <- tag.indexOf("-")) {
            return normalizeLanguage(tag[(index + 1)..tag.size])
        }
        return defaultLang
    }

    private static func descriptionTagText(text: String): String {
        if (let Some(index) <- text.indexOf(" ")) {
            return text[(index + 1)..text.size].trimAscii()
        }
        return ""
    }

    private static func firstToken(text: String): String {
        if (let Some(index) <- text.indexOf(" ")) {
            return text[0..index].trimAscii()
        }
        return text.trimAscii()
    }

    private static func normalizeLanguage(value: String): String {
        let lang = value.trimAscii().toAsciiLower().replace("_", "-")
        if (lang.isEmpty()) {
            return "en"
        }
        return lang
    }

    private static func splitTaggedName(rest: String): (String, String) {
        if (let Some(space) <- rest.indexOf(" ")) {
            return (rest[0..space].trimAscii(), rest[(space + 1)..rest.size].trimAscii())
        }
        return (rest.trimAscii(), "")
    }

    private static func cleanTypeText(text: String): String {
        let trimmed = text.trimAscii()
        if (trimmed.startsWith("{") && trimmed.endsWith("}") && trimmed.size >= 2) {
            return trimmed[1..(trimmed.size - 1)].trimAscii()
        }
        return trimmed
    }

    private static func addIfNotEmpty(lines: ArrayList<String>, text: String): Unit {
        if (!text.isEmpty()) {
            lines.add(text)
        }
    }

    private static func paramSummary(doc: SourceDoc): String {
        if (doc.params.isEmpty()) {
            return ""
        }
        let items = ArrayList<String>()
        for ((name, text) in doc.params) {
            if (text.isEmpty()) {
                items.add(name)
            } else {
                items.add(name + ": " + text)
            }
        }
        return String.join(items.toArray(), delimiter: "; ")
    }

    private static func compactDocLines(lines: ArrayList<String>): String {
        let result = ArrayList<String>()
        for (line in lines) {
            let trimmed = line.trimAscii()
            if (!trimmed.isEmpty()) {
                result.add(trimmed)
            }
        }
        return String.join(result.toArray(), delimiter: " ")
    }

    private static func compactExampleLines(lines: ArrayList<String>): String {
        let result = ArrayList<String>()
        for (line in lines) {
            result.add(line)
        }
        return String.join(result.toArray(), delimiter: "\n").trimAscii()
    }

    private static func emptyDoc(): SourceDoc {
        return SourceDoc("", Array<(String, String)>(), "", "")
    }

    private static func parseLocation(text: String): ?SourceLocation {
        if (let Some(start) <- text.indexOf("loc: ")) {
            let rest = text[(start + 5)..text.size]
            let comma = rest.indexOf(",") ?? rest.size
            let newline = rest.indexOf("\n") ?? rest.size
            let end = if (comma < newline) { comma } else { newline }
            let token = rest[0..end].trimAscii()
            if (let Some(lastDash) <- token.lastIndexOf("-")) {
                let prefix = token[0..lastDash]
                if (let Some(lineDash) <- prefix.lastIndexOf("-")) {
                    let fileName = prefix[0..lineDash]
                    let lineText = prefix[(lineDash + 1)..prefix.size]
                    try {
                        return Some(SourceLocation(fileName, Int64.parse(lineText), packageName: parsePackageName(text)))
                    } catch (e: Exception) {
                        return None
                    }
                }
            }
        }
        return None
    }

    private static func parsePackageName(text: String): String {
        if (let Some(start) <- text.indexOf("packageName: ")) {
            let rest = text[(start + 13)..text.size]
            let comma = rest.indexOf(",") ?? rest.size
            let newline = rest.indexOf("\n") ?? rest.size
            let brace = rest.indexOf("}") ?? rest.size
            var end = if (comma < newline) { comma } else { newline }
            if (brace < end) {
                end = brace
            }
            return rest[0..end].trimAscii()
        }
        return ""
    }

    private static func preferredPaths(loc: SourceLocation): Array<Path> {
        let result = ArrayList<Path>()
        result.add(Path(loc.fileName))
        if (loc.packageName.isEmpty() || loc.fileName.contains("/") || loc.fileName.contains("\\")) {
            return result.toArray()
        }
        let parts = loc.packageName.split(".")
        if (!parts.isEmpty()) {
            result.add(Path("src/" + String.join(parts, delimiter: "/") + "/" + loc.fileName))
        }
        if (parts.size > 1) {
            let tail = ArrayList<String>()
            for (i in 1..parts.size) {
                tail.add(parts[i])
            }
            result.add(Path("src/" + String.join(tail.toArray(), delimiter: "/") + "/" + loc.fileName))
        }
        return result.toArray()
    }

    private static func preferredSourceFiles(packageName: String): Array<Path> {
        let result = ArrayList<Path>()
        let parts = packageName.split(".")
        if (!parts.isEmpty()) {
            let packageDir = Path("src/" + String.join(parts, delimiter: "/"))
            for (path in allSourceFiles) {
                if (path.parent.normalize().toString() == packageDir.normalize().toString()) {
                    result.add(path)
                }
            }
        }
        for (path in allSourceFiles) {
            if (!containsPath(result, path)) {
                result.add(path)
            }
        }
        return result.toArray()
    }

    private static func containsPath(paths: ArrayList<Path>, target: Path): Bool {
        let key = target.normalize().toString()
        for (path in paths) {
            if (path.normalize().toString() == key) {
                return true
            }
        }
        return false
    }

    private static func isEnumDeclarationLine(line: String, enumName: String): Bool {
        return line.contains("enum " + enumName) &&
            (line.startsWith("public ") || line.startsWith("protected ") ||
                line.startsWith("internal ") || line.startsWith("private ") ||
                line.startsWith("@") || line.startsWith("enum "))
    }

    private static func isEnumConstructorLine(line: String, ctorName: String): Bool {
        var text = line.trimAscii()
        if (text.startsWith("|")) {
            text = text[1..text.size].trimAscii()
        }
        if (text.startsWith("case ")) {
            text = text.removePrefix("case ").trimAscii()
        }
        if (text == ctorName) {
            return true
        }
        if (!text.startsWith(ctorName)) {
            return false
        }
        if (text.size == ctorName.size) {
            return true
        }
        let next = text[ctorName.size]
        return next == b'(' || next == b' ' || next == b'\t' || next == b'|' || next == b','
    }

    private static func braceDelta(line: String): Int64 {
        var delta: Int64 = 0
        var index: Int64 = 0
        while (index < line.size) {
            let byte = line[index]
            if (byte == b'{') {
                delta += 1
            } else if (byte == b'}') {
                delta -= 1
            }
            index += 1
        }
        return delta
    }

    private static func ensureIndexed(): Unit {
        if (indexed) {
            return
        }
        indexed = true
        let root = Path("src")
        if (exists(root)) {
            indexDirectory(root)
        }
    }

    private static func indexDirectory(dir: Path): Unit {
        try {
            for (entry in Directory.readFrom(dir)) {
                if (entry.isDirectory()) {
                    indexDirectory(entry.path)
                } else if (entry.isRegular() && entry.name.endsWith(".cj")) {
                    addFile(entry)
                }
            }
        } catch (e: Exception) {
            ()
        }
    }

    private static func addFile(entry: FileInfo): Unit {
        let name = entry.path.fileName
        allSourceFiles.add(entry.path)
        if (let Some(paths) <- filesByName.get(name)) {
            paths.add(entry.path)
        } else {
            filesByName[name] = ArrayList<Path>([entry.path])
        }
    }
}
