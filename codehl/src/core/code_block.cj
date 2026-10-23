package codehl.core

import codehl.languages.{Token, TokenizerState}
import codehl.themes.Theme

public type CodeSpan = Token

public class CodeLine {

    public CodeLine(public let lineNumber: Int64, public let text: String, public let spans: Array<CodeSpan>, public let highlighted: Bool, public let visible: Bool) {}
}

public class CodeBlock {

    public CodeBlock(public let lang: String, public let classPrefix: String, public let lines: Array<CodeLine>, public let finalState: TokenizerState, public let theme!: ?Theme = None) {}

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
