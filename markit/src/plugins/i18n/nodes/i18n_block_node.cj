package markit.plugins.i18n.nodes

import seajson.JsonWriter
import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class I18nBlockNode <: Node {
    public let languageId: String
    public let content: String

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        languageId: String,
        content: String
    ) {
        super("I18nBlock", id: id, sourceSpan: sourceSpan, literal: content)
        this.languageId = languageId
        this.content = content
        setString("languageId", languageId)
    }

    public override prop name: String {
        get() {
            return "I18nBlockNode"
        }
    }

    public func getLanguageId(): String {
        return languageId
    }

    public func getContent(): String {
        return content
    }

    public override func toString(): String {
        return "${name}(lang: ${languageId}, content: ${children.size} children)"
    }

    protected override func writeJsonFields(w: JsonWriter): JsonWriter {
        w.name("languageId").value(languageId)
        w.name("content").value(content)
        return w
    }
}
