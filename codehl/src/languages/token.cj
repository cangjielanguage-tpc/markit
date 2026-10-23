package codehl.languages

import std.collection.HashMap
import codehl.grammar.{GrammarCapture, GrammarPattern}

public class Token {
    public let startByte: Int64
    public let endByte: Int64
    public let scope: String
    public let scopes: Array<String>

    public Token(startByte: Int64, endByte: Int64, scope: String, scopes!: Array<String> = []) {
        this.startByte = startByte
        this.endByte = endByte
        this.scope = scope
        this.scopes = if (scopes.isEmpty()) { [scope] } else { scopes }
    }
}

public class TokenizerState {

    public TokenizerState(public let mode!: String = "", public let contexts!: Array<TokenizerContext> = []) {}

    public func isInitial(): Bool {
        return mode.isEmpty() && contexts.isEmpty()
    }
}

public class TokenizerContext {

    public TokenizerContext(
        public let scope: String,
        public let contentScope: String,
        public let endPattern: String,
        public let whilePattern: String,
        public let applyEndPatternLast: Bool,
        public let patterns: Array<GrammarPattern>,
        public let endCaptures: HashMap<Int64, GrammarCapture>,
        public let whileCaptures!: HashMap<Int64, GrammarCapture> = HashMap<Int64, GrammarCapture>(),
        public let grammarScope!: String = "",
        public let canCarryAcrossLines!: Bool = true
    ) {}
}

public class LineTokens {

    public LineTokens(public let tokens: Array<Token>, public let state: TokenizerState) {}
}

public interface CodeTokenizer {
    prop name: String
    prop languageIds: Array<String>

    func tokenizeLine(line: String, state: TokenizerState): LineTokens
}
