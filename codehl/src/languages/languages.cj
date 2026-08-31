package codehl.languages

import std.collection.{ArrayList, HashMap}
import std.fs.*
import codehl.grammar.{Grammar, GrammarLoader}
import seajson.*

public class LanguageRegistration {
    public let language: String
    public let grammar: String
    public let aliases: Array<String>

    public init(language: String, grammar: String, aliases!: Array<String> = []) {
        this.language = language
        this.grammar = grammar
        this.aliases = aliases
    }
}

public class LanguageAlias {
    public let alias: String
    public let language: String

    public init(alias: String, language: String) {
        this.alias = alias
        this.language = language
    }
}

public class LanguageRegistry {
    private let builtInGrammarDirs: Array<String>
    private let userGrammarDirs: Array<String>
    private let grammarCache: HashMap<String, Grammar>
    private let tokenizerCache: HashMap<String, CodeTokenizer>
    private let externalGrammarCache: HashMap<String, HashMap<String, Grammar>>
    private let customGrammars: HashMap<String, String>
    private let customAliases: HashMap<String, String>
    private let customLanguageIds: HashMap<String, Array<String>>
    private let discoveredGrammars: HashMap<String, String>
    private let discoveredScopes: HashMap<String, String>
    private var grammarDiscoveryScanned: Bool

    public init(
        grammarDir!: String = "assets/grammars",
        grammarDirs!: Array<String> = [],
        languages!: Array<LanguageRegistration> = [],
        aliases!: Array<LanguageAlias> = []
    ) {
        this.builtInGrammarDirs = if (grammarDir.trimAscii().isEmpty()) { [] } else { [grammarDir] }
        this.userGrammarDirs = grammarDirs
        this.grammarCache = HashMap<String, Grammar>()
        this.tokenizerCache = HashMap<String, CodeTokenizer>()
        this.externalGrammarCache = HashMap<String, HashMap<String, Grammar>>()
        this.customGrammars = HashMap<String, String>()
        this.customAliases = HashMap<String, String>()
        this.customLanguageIds = HashMap<String, Array<String>>()
        this.discoveredGrammars = HashMap<String, String>()
        this.discoveredScopes = HashMap<String, String>()
        this.grammarDiscoveryScanned = false

        for (registration in languages) {
            let language = normalizeRawLanguage(registration.language)
            if (language.isEmpty() || registration.grammar.trimAscii().isEmpty()) {
                continue
            }
            this.customGrammars[language] = registration.grammar.trimAscii()
            let ids = ArrayList<String>()
            ids.add(language)
            for (alias in registration.aliases) {
                let normalizedAlias = normalizeRawLanguage(alias)
                if (!normalizedAlias.isEmpty()) {
                    this.customAliases[normalizedAlias] = language
                    if (!ids.contains(normalizedAlias)) {
                        ids.add(normalizedAlias)
                    }
                }
            }
            this.customLanguageIds[language] = ids.toArray()
        }

        for (alias in aliases) {
            let normalizedAlias = normalizeRawLanguage(alias.alias)
            let normalizedLanguage = normalizeRawLanguage(alias.language)
            if (!normalizedAlias.isEmpty() && !normalizedLanguage.isEmpty()) {
                this.customAliases[normalizedAlias] = normalizedLanguage
            }
        }
    }

    public func findTokenizer(lang: String): ?CodeTokenizer {
        let normalized = normalizeConfiguredLanguage(lang)
        match (tokenizerCache.get(normalized)) {
            case Some(tokenizer) => return Some(tokenizer)
            case None => ()
        }
        let grammarFile = match (customGrammars.get(normalized)) {
            case Some(fileName) => Some(fileName)
            case None => discoverGrammarFile(normalized)
        }
        match (grammarFile) {
            case Some(fileName) =>
                match (loadGrammar(fileName)) {
                    case Some(grammar) =>
                        let tokenizer = GrammarTokenizer(grammar, languageIdsForConfigured(normalized), loadExternalGrammars(grammar.scopeName))
                        tokenizerCache[normalized] = tokenizer
                        return Some(tokenizer)
                    case None =>
                        return None
                }
            case None =>
                return None
        }
    }

    public func normalizeConfiguredLanguage(lang: String): String {
        let raw = normalizeRawLanguage(lang)
        match (customAliases.get(raw)) {
            case Some(language) => return normalizeRawLanguage(language)
            case None => return normalizeLanguage(raw)
        }
    }

    public static func normalizeLanguage(lang: String): String {
        let lower = normalizeRawLanguage(lang)
        return match (lower) {
            case "" => "plain"
            case "text" => "plain"
            case "txt" => "plain"
            case "plaintext" => "plain"
            case "bat" => "batchfile"
            case "cmd" => "batchfile"
            case "coffee" => "coffeescript"
            case "cc" => "cpp"
            case "cxx" => "cpp"
            case "c++" => "cpp"
            case "h" => "c"
            case "hpp" => "cpp"
            case "cu" => "cuda-cpp"
            case "cs" => "csharp"
            case "cj" => "cangjie"
            case "dockerfile" => "docker"
            case "env" => "dotenv"
            case "fs" => "fsharp"
            case "fsx" => "fsharp"
            case "gitignore" => "ignore"
            case "hbs" => "handlebars"
            case "handlebars" => "handlebars"
            case "js" => "javascript"
            case "mjs" => "javascript"
            case "cjs" => "javascript"
            case "jsx" => "javascriptreact"
            case "tex" => "latex"
            case "bib" => "bibtex"
            case "mk" => "make"
            case "makefile" => "make"
            case "sh" => "bash"
            case "shell" => "bash"
            case "shellscript" => "bash"
            case "zsh" => "bash"
            case "fish" => "bash"
            case "ksh" => "bash"
            case "md" => "markdown"
            case "objc" => "objective-c"
            case "objcpp" => "objective-cpp"
            case "ps1" => "powershell"
            case "py" => "python"
            case "python3" => "python"
            case "rb" => "ruby"
            case "rs" => "rust"
            case "rst" => "restructuredtext"
            case "ts" => "typescript"
            case "tsx" => "typescriptreact"
            case "vbnet" => "vb"
            case "antlr" => "antlr4"
            case "g4" => "antlr4"
            case "yml" => "yaml"
            case _ => lower
        }
    }

    private static func normalizeRawLanguage(lang: String): String {
        return lang.trimAscii().toAsciiLower()
    }

    private func loadGrammar(fileName: String): ?Grammar {
        match (grammarCache.get(fileName)) {
            case Some(grammar) => return Some(grammar)
            case None => ()
        }
        let path = resolveGrammarPath(fileName)
        if (path.isEmpty()) {
            return None
        }
        try {
            let json = String.fromUtf8(File.readFrom(Path(path)))
            let grammar = GrammarLoader().loadFromJson(json)
            grammarCache[fileName] = grammar
            return Some(grammar)
        } catch (_: Exception) {
            return None
        }
    }

    private func loadExternalGrammars(rootScope: String): HashMap<String, Grammar> {
        match (externalGrammarCache.get(rootScope)) {
            case Some(cached) => return cached
            case None => ()
        }
        let out = HashMap<String, Grammar>()
        ensureGrammarDiscovery()
        for ((scopeName, fileName) in discoveredScopes) {
            if (scopeName == rootScope) {
                continue
            }
            match (loadGrammar(fileName)) {
                case Some(grammar) =>
                    out[scopeName] = grammar
                    out[grammar.scopeName] = grammar
                case None => ()
            }
        }
        externalGrammarCache[rootScope] = out
        return out
    }

    private func resolveGrammarPath(fileName: String): String {
        let direct = Path(fileName)
        if (isAbsolutePath(fileName) && exists(direct)) {
            return direct.normalize().toString()
        }
        for (grammarDir in userGrammarDirs) {
            for (base in grammarDirCandidateBases(grammarDir)) {
                let candidate = base.join(fileName).normalize().toString()
                if (exists(Path(candidate))) {
                    return candidate
                }
            }
        }
        for (grammarDir in builtInGrammarDirs) {
            for (base in grammarDirCandidateBases(grammarDir)) {
                let candidate = base.join(fileName).normalize().toString()
                if (exists(Path(candidate))) {
                    return candidate
                }
            }
        }
        return ""
    }

    private func discoverGrammarFile(lang: String): ?String {
        ensureGrammarDiscovery()
        match (discoveredGrammars.get(lang)) {
            case Some(fileName) => return Some(fileName)
            case None => return None
        }
    }

    private func ensureGrammarDiscovery(): Unit {
        if (grammarDiscoveryScanned) {
            return
        }
        grammarDiscoveryScanned = true
        scanGrammarDirs(userGrammarDirs)
        scanGrammarDirs(builtInGrammarDirs)
    }

    private func scanGrammarDirs(dirs: Array<String>): Unit {
        for (grammarDir in dirs) {
            for (base in grammarDirCandidateBases(grammarDir)) {
                if (exists(base)) {
                    scanGrammarDirectory(base.normalize())
                }
            }
        }
    }

    private static func grammarDirCandidateBases(grammarDir: String): Array<Path> {
        let dir = Path(grammarDir)
        if (isAbsolutePath(grammarDir)) {
            return [dir.normalize()]
        }

        let out = ArrayList<Path>()
        for (prefix in assetSearchPrefixes()) {
            let base = if (prefix.isEmpty()) { dir } else { Path(prefix).join(grammarDir) }
            if (!out.contains(base)) {
                out.add(base)
            }
        }
        return out.toArray()
    }

    private static func isAbsolutePath(path: String): Bool {
        if (Path(path).isAbsolute()) {
            return true
        }
        let normalized = path.replace("/", "\\")
        return normalized.startsWith("\\\\") || hasWindowsDrivePrefix(normalized)
    }

    private static func hasWindowsDrivePrefix(path: String): Bool {
        if (path.size < 3 || path[1] != 58) {
            return false
        }
        let c = path[0]
        return ((c >= 65 && c <= 90) || (c >= 97 && c <= 122)) &&
            (path[2] == 92 || path[2] == 47)
    }

    private func scanGrammarDirectory(dir: Path): Unit {
        try {
            for (entry in Directory.readFrom(dir)) {
                if (entry.isDirectory()) {
                    scanGrammarDirectory(entry.path)
                } else if (isGrammarJson(entry.path)) {
                    indexDiscoveredGrammar(entry.path.normalize())
                }
            }
        } catch (_: Exception) {
            ()
        }
    }

    private func indexDiscoveredGrammar(path: Path): Unit {
        let fileName = path.fileName
        let normalizedPath = path.toString()
        addDiscoveredGrammarId(grammarIdFromFileName(fileName), normalizedPath)
        try {
            let root = parseJson(String.fromUtf8(File.readFrom(path)))
            addDiscoveredGrammarId(jsonFieldString(root, "name") ?? "", normalizedPath)
            if (let Some(scopeName) <- jsonFieldString(root, "scopeName")) {
                if (!scopeName.trimAscii().isEmpty()) {
                    discoveredScopes[scopeName.trimAscii()] = normalizedPath
                }
                addScopeGrammarIds(scopeName, normalizedPath)
            }
            match (jsonField(root, "fileTypes")) {
                case Some(JsonArrVal(items)) =>
                    for (item in items) {
                        match (item) {
                            case JsonStrVal(fileType) => addDiscoveredGrammarId(fileType, normalizedPath)
                            case _ => ()
                        }
                    }
                case _ => ()
            }
        } catch (_: Exception) {
            ()
        }
    }

    private func addScopeGrammarIds(scopeName: String, fileName: String): Unit {
        let parts = scopeName.trimAscii().split(".", removeEmpty: true)
        if (parts.size < 2) {
            addDiscoveredGrammarId(scopeName, fileName)
            return
        }
        addDiscoveredGrammarId(parts[1], fileName)
        addDiscoveredGrammarId(parts[parts.size - 1], fileName)
        let out = StringBuilder(scopeName.size)
        for (i in 1..parts.size) {
            if (i > 1) {
                out.append("-")
            }
            out.append(parts[i])
        }
        addDiscoveredGrammarId(out.toString(), fileName)
    }

    private func addDiscoveredGrammarId(id: String, fileName: String): Unit {
        let normalized = normalizeLanguage(normalizeRawLanguage(normalizeDiscoveryId(id)))
        if (normalized.isEmpty() || normalized == "plain") {
            return
        }
        match (discoveredGrammars.get(normalized)) {
            case Some(_) => ()
            case None => discoveredGrammars[normalized] = fileName
        }
    }

    private static func isGrammarJson(path: Path): Bool {
        let fileName = path.fileName.toAsciiLower()
        return fileName.endsWith(".json") && fileName != "package.json"
    }

    private static func grammarIdFromFileName(fileName: String): String {
        let lower = fileName.trimAscii()
        if (lower.endsWith(".tmLanguage.json")) {
            return lower[0..(lower.size - ".tmLanguage.json".size)]
        }
        if (lower.endsWith(".json")) {
            return lower[0..(lower.size - ".json".size)]
        }
        return lower
    }

    private static func normalizeDiscoveryId(id: String): String {
        let out = StringBuilder(id.size)
        var lastDash = false
        for (b in id.trimAscii().toArray()) {
            let keep = (b >= b'a' && b <= b'z') || (b >= b'A' && b <= b'Z') || (b >= b'0' && b <= b'9') || b == b'+' || b == b'#'
            if (keep) {
                out.append(String.fromUtf8([b]))
                lastDash = false
            } else if (!lastDash) {
                out.append("-")
                lastDash = true
            }
        }
        return trimAsciiDashes(out.toString())
    }

    private static func trimAsciiDashes(value: String): String {
        var start: Int64 = 0
        var end = value.size
        while (start < end && value[start] == b'-') {
            start += 1
        }
        while (end > start && value[end - 1] == b'-') {
            end -= 1
        }
        return value[start..end]
    }

    private static func assetSearchPrefixes(): Array<String> {
        return ["", "codehl", "..\\codehl", "..\\..\\codehl", "..\\..\\..\\codehl"]
    }

    private func languageIdsForConfigured(lang: String): Array<String> {
        match (customLanguageIds.get(lang)) {
            case Some(ids) => return ids
            case None => return languageIdsFor(lang)
        }
    }

    private static func languageIdsFor(lang: String): Array<String> {
        return match (lang) {
            case "cangjie" => ["cangjie", "cj"]
            case "batchfile" => ["batchfile", "bat", "cmd"]
            case "bash" => ["bash", "shellscript", "sh", "shell", "zsh", "fish", "ksh"]
            case "coffeescript" => ["coffeescript", "coffee"]
            case "cpp" => ["cpp", "c++", "cc", "cxx", "hpp"]
            case "cuda-cpp" => ["cuda-cpp", "cu"]
            case "csharp" => ["csharp", "cs"]
            case "dotenv" => ["dotenv", "env"]
            case "fsharp" => ["fsharp", "fs", "fsx"]
            case "handlebars" => ["handlebars", "hbs"]
            case "javascript" => ["javascript", "js", "mjs", "cjs"]
            case "javascriptreact" => ["javascriptreact", "jsx"]
            case "latex" => ["latex", "tex"]
            case "markdown" => ["markdown", "md"]
            case "objective-c" => ["objective-c", "objc"]
            case "objective-cpp" => ["objective-cpp", "objcpp"]
            case "powershell" => ["powershell", "ps1"]
            case "python" => ["python", "py", "python3"]
            case "restructuredtext" => ["restructuredtext", "rst"]
            case "ruby" => ["ruby", "rb"]
            case "rust" => ["rust", "rs"]
            case "typescript" => ["typescript", "ts"]
            case "typescriptreact" => ["typescriptreact", "tsx"]
            case "antlr4" => ["antlr4", "antlr", "g4"]
            case "jsonl" => ["jsonl", "ndjson"]
            case "toml" => ["toml"]
            case "yaml" => ["yaml", "yml"]
            case _ => [lang]
        }
    }
}
