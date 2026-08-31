package codehl.grammar

import std.collection.{ArrayList, HashMap}
import std.convert.Parsable
import seajson.*

public class Grammar {
    public let name: String
    public let scopeName: String
    public let fileTypes: Array<String>
    public let patterns: Array<GrammarPattern>
    public let injections: Array<GrammarPattern>
    public let repository: HashMap<String, GrammarPattern>

    public init(
        name: String,
        scopeName: String,
        patterns: Array<GrammarPattern>,
        repository: HashMap<String, GrammarPattern>,
        fileTypes!: Array<String> = [],
        injections!: Array<GrammarPattern> = []
    ) {
        this.name = name
        this.scopeName = scopeName
        this.fileTypes = fileTypes
        this.patterns = patterns
        this.injections = injections
        this.repository = repository
    }
}

public class GrammarPattern {
    public let name: String
    public let contentName: String
    public let matchPattern: String
    public let include: String
    public let begin: String
    public let end: String
    public let whilePattern: String
    public let applyEndPatternLast: Bool
    public let patterns: Array<GrammarPattern>
    public let captures: HashMap<Int64, GrammarCapture>
    public let beginCaptures: HashMap<Int64, GrammarCapture>
    public let endCaptures: HashMap<Int64, GrammarCapture>
    public let whileCaptures: HashMap<Int64, GrammarCapture>

    public init(
        name!: String = "",
        contentName!: String = "",
        matchPattern!: String = "",
        include!: String = "",
        begin!: String = "",
        end!: String = "",
        whilePattern!: String = "",
        applyEndPatternLast!: Bool = false,
        patterns!: Array<GrammarPattern> = [],
        captures!: HashMap<Int64, GrammarCapture> = HashMap<Int64, GrammarCapture>(),
        beginCaptures!: HashMap<Int64, GrammarCapture> = HashMap<Int64, GrammarCapture>(),
        endCaptures!: HashMap<Int64, GrammarCapture> = HashMap<Int64, GrammarCapture>(),
        whileCaptures!: HashMap<Int64, GrammarCapture> = HashMap<Int64, GrammarCapture>()
    ) {
        this.name = name
        this.contentName = contentName
        this.matchPattern = matchPattern
        this.include = include
        this.begin = begin
        this.end = end
        this.whilePattern = whilePattern
        this.applyEndPatternLast = applyEndPatternLast
        this.patterns = patterns
        this.captures = captures
        this.beginCaptures = beginCaptures
        this.endCaptures = endCaptures
        this.whileCaptures = whileCaptures
    }
}

public class GrammarCapture {
    public let name: String
    public let patterns: Array<GrammarPattern>

    public init(name!: String = "", patterns!: Array<GrammarPattern> = []) {
        this.name = name
        this.patterns = patterns
    }
}

public class GrammarLoader {
    public init() {}

    public func loadFromJson(json: String): Grammar {
        return load(parseJson(json))
    }

    public func load(root: JsonValue): Grammar {
        let name = jsonFieldString(root, "name") ?? ""
        let scopeName = jsonFieldString(root, "scopeName") ?? ""
        if (scopeName.isEmpty()) {
            throw IllegalArgumentException("TextMate grammar requires scopeName")
        }

        let patterns = parsePatterns(jsonField(root, "patterns"))
        let fileTypes = parseStringArray(jsonField(root, "fileTypes"))
        let injections = parseInjections(jsonField(root, "injections"))
        let repository = HashMap<String, GrammarPattern>()
        match (jsonField(root, "repository")) {
            case Some(JsonObjVal(entries)) =>
                for ((key, value) in entries) {
                    repository[key] = parsePattern(value)
                }
            case _ => ()
        }

        return Grammar(name, scopeName, patterns, repository, fileTypes: fileTypes, injections: injections)
    }

    private static func parseStringArray(value: ?JsonValue): Array<String> {
        let out = ArrayList<String>()
        match (value) {
            case Some(JsonArrVal(items)) =>
                for (item in items) {
                    match (item) {
                        case JsonStrVal(value) =>
                            let trimmed = value.trimAscii()
                            if (!trimmed.isEmpty()) {
                                out.add(trimmed)
                            }
                        case _ => ()
                    }
                }
            case _ => ()
        }
        return out.toArray()
    }

    private static func parsePatterns(value: ?JsonValue): Array<GrammarPattern> {
        let out = ArrayList<GrammarPattern>()
        match (value) {
            case Some(JsonArrVal(items)) =>
                for (item in items) {
                    out.add(parsePattern(item))
                }
            case _ => ()
        }
        return out.toArray()
    }

    private static func parsePattern(value: JsonValue): GrammarPattern {
        match (value) {
            case JsonObjVal(_) =>
                let captures = parseCaptures(jsonField(value, "captures"))
                let beginCaptures = parseCaptures(jsonField(value, "beginCaptures"))
                let endCaptures = parseCaptures(jsonField(value, "endCaptures"))
                let whileCaptures = parseCaptures(jsonField(value, "whileCaptures"))
                return GrammarPattern(
                    name: jsonFieldString(value, "name") ?? "",
                    contentName: jsonFieldString(value, "contentName") ?? "",
                    matchPattern: jsonFieldString(value, "match") ?? "",
                    include: jsonFieldString(value, "include") ?? "",
                    begin: jsonFieldString(value, "begin") ?? "",
                    end: jsonFieldString(value, "end") ?? "",
                    whilePattern: jsonFieldString(value, "while") ?? "",
                    applyEndPatternLast: jsonFieldTextMateBool(value, "applyEndPatternLast") ?? false,
                    patterns: parsePatterns(jsonField(value, "patterns")),
                    captures: captures,
                    beginCaptures: if (beginCaptures.isEmpty()) { captures } else { beginCaptures },
                    endCaptures: if (endCaptures.isEmpty()) { captures } else { endCaptures },
                    whileCaptures: if (whileCaptures.isEmpty()) { captures } else { whileCaptures }
                )
            case _ =>
                return GrammarPattern()
        }
    }

    private static func parseInjections(value: ?JsonValue): Array<GrammarPattern> {
        let out = ArrayList<GrammarPattern>()
        match (value) {
            case Some(JsonObjVal(entries)) =>
                for ((_, item) in entries) {
                    let parsed = parsePattern(item)
                    if (!parsed.matchPattern.isEmpty() || !parsed.begin.isEmpty() || !parsed.include.isEmpty() || !parsed.patterns.isEmpty()) {
                        out.add(parsed)
                    }
                }
            case _ => ()
        }
        return out.toArray()
    }

    private static func jsonFieldTextMateBool(root: JsonValue, key: String): ?Bool {
        match (jsonField(root, key)) {
            case Some(JsonBoolVal(value)) => return Some(value)
            case Some(JsonIntVal(value)) => return Some(value != 0)
            case Some(JsonInt32Val(value)) => return Some(value != 0)
            case _ => return None
        }
    }

    private static func parseCaptures(value: ?JsonValue): HashMap<Int64, GrammarCapture> {
        let out = HashMap<Int64, GrammarCapture>()
        match (value) {
            case Some(JsonObjVal(entries)) =>
                for ((key, item) in entries) {
                    try {
                        let index = Int64.parse(key)
                        let capture = GrammarCapture(
                            name: jsonFieldString(item, "name") ?? "",
                            patterns: parsePatterns(jsonField(item, "patterns"))
                        )
                        if (!capture.name.isEmpty() || !capture.patterns.isEmpty()) {
                            out[index] = capture
                        }
                    } catch (_: Exception) {
                        ()
                    }
                }
            case _ => ()
        }
        return out
    }
}
