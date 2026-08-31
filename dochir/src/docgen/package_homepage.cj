package dochir.docgen

import std.collection.ArrayList
import std.fs.{File, Path, exists}

public class PackageHomepage {
    public static func read(packageName: String, projectName: String, sourceRoot: String, language!: String = ""): String {
        for (file in candidateFiles(packageName, projectName, sourceRoot, language)) {
            if (!exists(Path(file))) {
                continue
            }
            try {
                let content = String.fromUtf8(File.readFrom(Path(file)))
                let homepage = extractHomepageMarkdown(content)
                if (!homepage.isEmpty()) {
                    return homepage
                }
            } catch (e: Exception) {
                ()
            }
        }
        return ""
    }

    static func extractHomepageMarkdown(content: String): String {
        let lines = content.replace("\r\n", "\n").replace("\r", "\n").split("\n")
        let homepageLines = ArrayList<String>()
        var foundMarker = false

        for (line in lines) {
            if (foundMarker) {
                homepageLines.add(line)
            } else if (isHomepageMarkerLine(line)) {
                foundMarker = true
            }
        }

        if (!foundMarker) {
            return ""
        }
        return trimBlankEdges(homepageLines.toArray())
    }

    static func candidateFilesForTesting(
        packageName: String,
        projectName: String,
        sourceRoot: String,
        language!: String = ""
    ): Array<String> {
        return candidateFiles(packageName, projectName, sourceRoot, language)
    }

    private static func candidateFiles(packageName: String, projectName: String, sourceRoot: String, language: String): Array<String> {
        let dirs = ArrayList<String>()
        let root = if (sourceRoot.isEmpty()) { "src" } else { sourceRoot }
        addCandidate(dirs, Path(root).join(packageName.replace(".", "/")).normalize().toString())

        if (!projectName.isEmpty() && packageName == projectName) {
            addCandidate(dirs, Path(root).normalize().toString())
        }

        if (!projectName.isEmpty() && packageName.startsWith(projectName + ".")) {
            let rest = packageName[(projectName.size + 1)..packageName.size]
            addCandidate(dirs, Path(root).join(rest.replace(".", "/")).normalize().toString())
        } else if (let Some(dot) <- packageName.indexOf(".")) {
            let rest = packageName[(dot + 1)..packageName.size]
            addCandidate(dirs, Path(root).join(rest.replace(".", "/")).normalize().toString())
        }

        let files = ArrayList<String>()
        for (dir in dirs) {
            addHomepageCandidates(files, dir, language)
        }
        return files.toArray()
    }

    private static func addHomepageCandidates(files: ArrayList<String>, dir: String, language: String): Unit {
        let normalizedLanguage = normalizeLanguage(language)
        if (!normalizedLanguage.isEmpty()) {
            addCandidate(files, Path(dir).join("markit.${normalizedLanguage}.md").normalize().toString())
            if (let Some(dash) <- normalizedLanguage.indexOf("-")) {
                let baseLanguage = normalizedLanguage[0..dash]
                if (!baseLanguage.isEmpty() && baseLanguage != normalizedLanguage) {
                    addCandidate(files, Path(dir).join("markit.${baseLanguage}.md").normalize().toString())
                }
            }
        }
        addCandidate(files, Path(dir).join("markit.md").normalize().toString())
    }

    private static func normalizeLanguage(language: String): String {
        return language.trimAscii().toAsciiLower().replace("_", "-")
    }

    private static func addCandidate(files: ArrayList<String>, file: String): Unit {
        if (!files.contains(file)) {
            files.add(file)
        }
    }

    private static func isHomepageMarkerLine(line: String): Bool {
        let trimmed = line.trimAscii()
        if (!trimmed.startsWith("<!--") || !trimmed.endsWith("-->") || trimmed.size <= 7) {
            return false
        }

        var inner = trimmed[4..(trimmed.size - 3)].trimAscii()
        while (!inner.isEmpty() && (inner.startsWith("-") || inner.startsWith(" "))) {
            inner = inner[1..inner.size].trimAscii()
        }
        while (!inner.isEmpty() && (inner.endsWith("-") || inner.endsWith(" "))) {
            inner = inner[0..(inner.size - 1)].trimAscii()
        }
        return inner.toAsciiLower() == "homepage"
    }

    private static func trimBlankEdges(lines: Array<String>): String {
        var start: Int64 = 0
        var end = lines.size
        while (start < end && lines[start].trimAscii().isEmpty()) {
            start += 1
        }
        while (end > start && lines[end - 1].trimAscii().isEmpty()) {
            end -= 1
        }
        if (start >= end) {
            return ""
        }

        let result = ArrayList<String>()
        for (i in start..end) {
            result.add(lines[i])
        }
        return String.join(result.toArray(), delimiter: "\n").trimAscii()
    }
}
