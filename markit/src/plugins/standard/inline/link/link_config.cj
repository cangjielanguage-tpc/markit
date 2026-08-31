package markit.plugins.standard.inline.link

public class LinkConfig {
    public let fileTree: ?FileTree
    public let renderMode: RenderMode
    public let outputExtension: String
    public let preserveFlatFilePaths: Bool
    public let currentFilePath: String

    public init(
        fileTree!: ?FileTree = None,
        renderMode!: RenderMode = RenderMode.Normal,
        outputExtension!: String = "html",
        preserveFlatFilePaths!: Bool = false,
        currentFilePath!: String = ""
    ) {
        this.fileTree = fileTree
        this.renderMode = renderMode
        this.outputExtension = outputExtension
        this.preserveFlatFilePaths = preserveFlatFilePaths
        this.currentFilePath = currentFilePath
    }
}
