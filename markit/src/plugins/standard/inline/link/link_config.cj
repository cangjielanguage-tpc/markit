package markit.plugins.standard.inline.link

public class LinkConfig {
    public LinkConfig(
        public let fileTree!: ?FileTree = None,
        public let renderMode!: RenderMode = RenderMode.Normal,
        public let outputExtension!: String = "html",
        public let preserveFlatFilePaths!: Bool = false,
        public let currentFilePath!: String = ""
    ) {}
}
