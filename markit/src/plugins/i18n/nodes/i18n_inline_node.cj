package markit.plugins.i18n.nodes

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class I18nInlineNode <: Node {
    public let languageId: String
    public let content: String
    public let originalSyntax: String

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        languageId: String,
        content: String,
        originalSyntax: String
    ) {
        super("I18nInline", id: id, sourceSpan: sourceSpan, literal: content)
        this.languageId = languageId
        this.content = content
        this.originalSyntax = originalSyntax
        setString("languageId", languageId)
    }

    public override prop name: String {
        get() {
            return "I18nInlineNode"
        }
    }

    public func getLanguageId(): String {
        return languageId
    }

    public func getContent(): String {
        return content
    }

    public func getOriginalSyntax(): String {
        return originalSyntax
    }

    public override func toString(): String {
        return "${name}(lang: ${languageId}, content: \"${content}\")"
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("languageId").value(languageId)
        w.name("content").value(content)
        w.name("originalSyntax").value(originalSyntax)
        return w
    }
}
