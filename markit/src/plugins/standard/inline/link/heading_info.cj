package markit.plugins.standard.inline.link

public class HeadingInfo {
    public let text: String
    public let slug: String
    public let filePath: String
    public let level: Int64

    public init(text: String, slug: String, filePath: String, level: Int64) {
        this.text = text
        this.slug = slug
        this.filePath = filePath
        this.level = level
    }

    public func getFullUrl(outputExtension!: String = "html"): String {
        return "${replaceExtension(filePath, outputExtension)}#${slug}"
    }

    public func getAnchorUrl(): String {
        return "#${slug}"
    }
}

private func replaceExtension(path: String, extension: String): String {
    let normalized = path.replace("\\", "/")
    if (normalized.endsWith(".md")) {
        return normalized[0..normalized.size - 3] + ".${extension}"
    }
    return normalized
}
