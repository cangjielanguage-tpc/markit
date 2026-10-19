package markit_kit.models

import std.fs.Path

/** Ordered homepage/menu settings, after resolving the target language labels. */
public struct SummaryEntry {
    public SummaryEntry(
        public let home!: Bool = false,
        public let file!: String = "",
        public let showDrafts!: Bool = true,
        public let label!: String = ""
    ) {}
}

public struct SummaryOptions {
    public SummaryOptions(
        public let entries!: Array<SummaryEntry> = [
            SummaryEntry(home: true, label: "Home"),
            SummaryEntry(file: "markit.md", label: "Documentation")
        ],
        public let explicit!: Bool = false,
        public let file!: String = "markit.md",
        public let showDrafts!: Bool = true
    ) {}

    public func hasHome(): Bool {
        for (entry in entries) {
            if (entry.file.isEmpty() && entry.home) { return true }
        }
        return false
    }

    public static func pagePath(path: String): String {
        var normalized = Path(path.replace("\\", "/")).normalize().toString().replace("\\", "/")
        // FileHandler uses the same language-relative paths for rendered documents.
        while (normalized.startsWith("../")) { normalized = normalized[3..] }
        if (normalized.endsWith(".markdown")) { return normalized[..normalized.size - 9] + ".html" }
        if (normalized.endsWith(".md")) { return normalized[..normalized.size - 3] + ".html" }
        return normalized
    }
}

/** A parsed menu and its rendered pages, in Summary order. */
public struct SummaryMenu {
    public SummaryMenu(
        public let entry: SummaryEntry,
        public let config: SummaryConfig,
        public let pages: Array<String>
    ) {}
}
