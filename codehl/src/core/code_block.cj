package codehl.core

import codehl.languages.{Token, TokenizerState}
import codehl.themes.Theme

public type CodeSpan = Token

public class CodeLine {
    public let lineNumber: Int64
    public let text: String
    public let spans: Array<CodeSpan>
    public let highlighted: Bool
    public let visible: Bool

    public init(lineNumber: Int64, text: String, spans: Array<CodeSpan>, highlighted: Bool, visible: Bool) {
        this.lineNumber = lineNumber
        this.text = text
        this.spans = spans
        this.highlighted = highlighted
        this.visible = visible
    }
}

public class CodeBlock {
    public let lang: String
    public let classPrefix: String
    public let lines: Array<CodeLine>
    public let finalState: TokenizerState
    public let theme: ?Theme

    public init(lang: String, classPrefix: String, lines: Array<CodeLine>, finalState: TokenizerState, theme!: ?Theme = None) {
        this.lang = lang
        this.classPrefix = classPrefix
        this.lines = lines
        this.finalState = finalState
        this.theme = theme
    }

    public func toHtml(): String {
        return TokenHtmlRenderer().renderBlock(this)
    }

    public func writeHtmlTo(out: StringBuilder): Unit {
        TokenHtmlRenderer().renderBlockTo(out, this)
    }

    public func withTheme(theme: ?Theme): CodeBlock {
        return CodeBlock(lang, classPrefix, lines, finalState, theme: theme)
    }
}
