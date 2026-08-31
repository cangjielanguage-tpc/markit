package markit.plugins.standard.inline.link

import std.collection.ArrayList
import markit.utils.slug

public class SmartHeadingLinkResolver {
    public var config: LinkConfig
    private var currentFilePath: String = ""

    public init(config: LinkConfig) {
        this.config = config
        this.currentFilePath = normalizePath(config.currentFilePath)
    }

    public func updateConfig(config: LinkConfig): Unit {
        this.config = config
        this.currentFilePath = normalizePath(config.currentFilePath)
    }

    public func setCurrentFile(path: String): Unit {
        currentFilePath = normalizePath(path)
    }

    public func resolve(url: String, linkText: String): (String, ?String) {
        if (isExternalUrl(url)) {
            return (url, None)
        }

        if (url == "#~") {
            return (buildCurrentPageAnchor(slug(linkText)), None)
        }

        if (url == "~") {
            return resolveByHeadingText(linkText)
        }

        if (url.contains("~")) {
            return resolveWithTilde(url, linkText)
        }

        if (config.renderMode == RenderMode.Flat && url.contains(".md#") && !config.preserveFlatFilePaths) {
            return (resolveFlatCrossFileLink(url), None)
        }

        if (url.endsWith(".md")) {
            return (replaceMarkdownExtension(url), None)
        }

        if (url.contains(".md#")) {
            return (url.replace(".md#", ".${config.outputExtension}#"), None)
        }

        return (url, None)
    }

    private func isExternalUrl(url: String): Bool {
        return url.startsWith("http://") ||
            url.startsWith("https://") ||
            url.startsWith("file://")
    }

    private func resolveWithTilde(url: String, linkText: String): (String, ?String) {
        let anchor = slug(linkText)
        if (url.contains("*")) {
            return resolveWithFuzzyMatch(url, anchor)
        }

        var resolvedUrl = url.replace("~", anchor)
        if (resolvedUrl.endsWith(".md")) {
            resolvedUrl = replaceMarkdownExtension(resolvedUrl)
        } else if (resolvedUrl.contains(".md#")) {
            resolvedUrl = resolvedUrl.replace(".md#", ".${config.outputExtension}#")
        }
        return (resolvedUrl, None)
    }

    private func resolveWithFuzzyMatch(url: String, anchor: String): (String, ?String) {
        let tildeIndex = url.indexOf("~")
        if (tildeIndex.isNone()) {
            return (url, Some("Invalid tilde syntax"))
        }

        var pattern = url[0..tildeIndex.getOrThrow()]
        if (pattern.endsWith("#") || pattern.endsWith("/")) {
            pattern = pattern[0..pattern.size - 1]
        }

        let originalPattern = pattern
        if (pattern.endsWith(".md") || pattern.contains(".md#") || pattern.contains(".md/")) {
            if (let Some(index) <- pattern.indexOf(".md")) {
                pattern = pattern[0..index + 3]
            }
        } else if (!pattern.isEmpty() && !pattern.contains("/")) {
            pattern = pattern + ".md"
        }

        if (let Some(fileTree) <- config.fileTree) {
            var searchPattern = normalizePath(pattern)
            if (!searchPattern.contains("/") && !currentFilePath.isEmpty()) {
                if (let Some(index) <- currentFilePath.lastIndexOf("/")) {
                    searchPattern = "${currentFilePath[0..index]}/${searchPattern}"
                }
            }

            let matches = fileTree.matchPattern(searchPattern)
            if (matches.size == 0) {
                return (url, Some("No files match pattern '${originalPattern}'"))
            }

            var warning: ?String = None
            if (matches.size > 1) {
                warning = Some("Multiple files match pattern '${originalPattern}': ${String.join(matches, delimiter: ", ")}")
            }

            let matchedFile = normalizePath(matches[0])
            if (config.renderMode == RenderMode.Flat && !config.preserveFlatFilePaths) {
                return ("#${anchor}", warning)
            }

            if (!currentFilePath.isEmpty()) {
                return (calculateRelativeUrl(currentFilePath, matchedFile, anchor), warning)
            }

            return ("${replaceMarkdownExtension(matchedFile)}#${anchor}", warning)
        }

        return (url, Some("FileTree not available"))
    }

    private func resolveFlatCrossFileLink(url: String): String {
        if (let Some(index) <- url.indexOf("#")) {
            return url[index..]
        }
        return ""
    }

    private func resolveByHeadingText(linkText: String): (String, ?String) {
        let anchor = slug(linkText)
        if (let Some(fileTree) <- config.fileTree) {
            let headings = fileTree.findHeadingsBySlug(anchor)
            if (headings.size == 0) {
                return (buildCurrentPageAnchor(anchor), None)
            }

            let heading = headings[0]
            if (config.renderMode == RenderMode.Flat && !config.preserveFlatFilePaths) {
                return (heading.getAnchorUrl(), if (headings.size > 1) { Some(multipleHeadingWarning(linkText, headings)) } else { None })
            }

            let targetUrl = calculateRelativeUrl(currentFilePath, heading.filePath, heading.slug)
            if (headings.size > 1) {
                return (targetUrl, Some(multipleHeadingWarning(linkText, headings)))
            }
            return (targetUrl, None)
        }

        return (buildCurrentPageAnchor(anchor), None)
    }

    private func multipleHeadingWarning(linkText: String, headings: Array<HeadingInfo>): String {
        let files = ArrayList<String>()
        for (heading in headings) {
            files.add(heading.filePath)
        }
        return "Multiple headings match '${linkText}': ${String.join(files.toArray(), delimiter: ", ")}"
    }

    private func buildCurrentPageAnchor(anchor: String): String {
        return "#${anchor}"
    }

    private func calculateRelativeUrl(currentPath: String, targetPath: String, anchor: String): String {
        let outputTargetPath = replaceMarkdownExtension(normalizePath(targetPath))
        let normalizedCurrentPath = normalizePath(currentPath)

        if (normalizedCurrentPath.isEmpty()) {
            return "${outputTargetPath}#${anchor}"
        }

        let currentParts = normalizedCurrentPath.split("/")
        let targetParts = outputTargetPath.split("/")
        var commonPrefixLen: Int64 = 0
        let minLen = if (currentParts.size < targetParts.size) { currentParts.size } else { targetParts.size }

        while (commonPrefixLen < minLen - 1 && currentParts[commonPrefixLen] == targetParts[commonPrefixLen]) {
            commonPrefixLen += 1
        }

        let upLevels = currentParts.size - 1 - commonPrefixLen
        let sb = StringBuilder()
        for (_ in 0..upLevels) {
            sb.append("../")
        }
        for (i in commonPrefixLen..targetParts.size) {
            if (i > commonPrefixLen) {
                sb.append("/")
            }
            sb.append(targetParts[i])
        }
        sb.append("#")
        sb.append(anchor)
        return sb.toString()
    }

    private func replaceMarkdownExtension(path: String): String {
        let normalized = normalizePath(path)
        if (normalized.endsWith(".md")) {
            return normalized[0..normalized.size - 3] + ".${config.outputExtension}"
        }
        return normalized
    }

    private func normalizePath(path: String): String {
        return path.replace("\\", "/")
    }
}
