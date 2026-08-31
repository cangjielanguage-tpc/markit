package markit.utils

public struct HeadingSlugScope {
    public static func normalizePagePath(path: String): String {
        return path.replace("\\", "/")
    }

    public static func buildPathLabel(pagePath: String, headingSlug: String, occurrence!: Int64 = 1): String {
        if (headingSlug.isEmpty()) {
            return ""
        }

        let normalizedPath = normalizePagePath(pagePath)
        let pathPrefix = slug(
            normalizedPath
                .replace(".typ", "")
                .replace(".pdf", "")
                .replace("/", "-")
                .replace(".", "-")
        )
        if (pathPrefix.isEmpty()) {
            return headingSlug
        }
        return if (occurrence <= 1) {
            "${pathPrefix}-${headingSlug}"
        } else {
            "${pathPrefix}-${headingSlug}-${occurrence}"
        }
    }
}
