package markit_kit.utils

import markit.utils.TypstEscaper
import markit_kit.models.GlobalContext
import std.collection.ArrayList
import std.fs.{Path, exists}

public class TypstDocumentBuilder {
    public static func wrapDocument(body: String, title: String, currentPagePath!: String = ""): String {
        let escapedTitle = TypstEscaper.escapeText(title)
        let normalizedBody = if (body.endsWith("\n")) { body } else { body + "\n" }
        let bodyFonts = "(\"HarmonyOS Sans SC\", \"Libertinus Serif\")"
        let emphasisFonts = "(\"HarmonyOS Sans SC\", \"Libertinus Serif\")"
        let codeFonts = "(\"JetBrains Mono\", \"HarmonyOS Sans SC\")"
        let textLangConfig = renderTextLangConfig()
        let codeTextConfig = renderCodeTextConfig()
        let rawConfig = renderRawConfig(currentPagePath)
        let wrapMarkerPath = resolveWrapMarkerPath(currentPagePath)
        let pageNumberConfig = renderPageNumberPageConfig()
        let paragraphStyleConfig = renderScripstParagraphStyle()
        let headingStyleConfig = renderHeadingStyleConfig()
        return renderTypstTemplate(
            "document.typ",
            [
                ("ESCAPED_TITLE", escapedTitle),
                ("PAGE_NUMBER_CONFIG", pageNumberConfig),
                ("BODY_FONTS", bodyFonts),
                ("TEXT_LANG_CONFIG", textLangConfig),
                ("PARAGRAPH_STYLE_CONFIG", paragraphStyleConfig),
                ("HEADING_STYLE_CONFIG", headingStyleConfig),
                ("EMPHASIS_FONTS", emphasisFonts),
                ("RAW_CONFIG", rawConfig),
                ("WRAP_MARKER_PATH", TypstEscaper.escapeString(wrapMarkerPath)),
                ("CODE_FONTS", codeFonts),
                ("CODE_TEXT_CONFIG", codeTextConfig),
                ("NORMALIZED_BODY", normalizedBody)
            ]
        )
    }

    public static func renderSourceComment(path: String): String {
        return "// Source: ${path}\n\n"
    }

    public static func renderCoverFrontMatter(siteTitle: String, currentPagePath!: String = "merged.typ"): String {
        if (let Some(config) <- GlobalContext.renderConfig) {
            if (!config.pdfTypstCoverEnabled) {
                return ""
            }

            let title = if (!config.pdfTypstCoverTitle.trimAscii().isEmpty()) {
                config.pdfTypstCoverTitle
            } else {
                siteTitle
            }
            let subtitle = config.pdfTypstCoverSubtitle.trimAscii()
            let logoPath = resolveCoverLogoPath(currentPagePath)
            let authorsBlock = renderCoverAuthors(config.pdfTypstCoverAuthors)
            let footerBlock = renderCoverFooter(
                config.pdfTypstCoverVersion.trimAscii(),
                config.pdfTypstCoverOrganization.trimAscii(),
                config.pdfTypstCoverSuborganization.trimAscii()
            )

            let coverHeader = if (!logoPath.isEmpty()) {
                renderTypstTemplate(
                    "cover-header-with-logo.typ",
                    [
                        ("LOGO_PATH", TypstEscaper.escapeString(logoPath)),
                        ("TITLE", TypstEscaper.escapeText(title))
                    ]
                ) + "\n"
            } else {
                renderTypstTemplate(
                    "cover-header-title.typ",
                    [("TITLE", TypstEscaper.escapeText(title))]
                ) + "\n"
            }
            let coverSubtitle = if (!subtitle.isEmpty()) {
                renderTypstTemplate(
                    "cover-subtitle.typ",
                    [("SUBTITLE", TypstEscaper.escapeText(subtitle))]
                ) + "\n"
            } else {
                ""
            }
            let renderedFooter = if (!footerBlock.isEmpty()) {
                renderTypstTemplate(
                    "cover-footer.typ",
                    [("FOOTER_LINE", footerBlock)]
                ) + "\n"
            } else {
                ""
            }

            return renderTypstTemplate(
                "cover.typ",
                [
                    ("COVER_HEADER", coverHeader),
                    ("COVER_SUBTITLE", coverSubtitle),
                    ("AUTHORS_BLOCK", authorsBlock),
                    ("FOOTER_BLOCK", renderedFooter)
                ]
            )
        }
        return ""
    }

    public static func renderTocFrontMatter(): String {
        if (let Some(config) <- GlobalContext.renderConfig) {
            if (!config.enableToc) {
                return ""
            }

            let tocTitle = getTocTitle()
            return renderTypstTemplate(
                "toc.typ",
                [
                    ("TOC_TITLE", TypstEscaper.escapeText(tocTitle)),
                    ("TOC_MAX_LEVEL", config.pdfTypstTocMaxLevel.toString())
                ]
            )
        } else {
            return ""
        }
    }

    private static func renderPageNumberPageConfig(): String {
        if (let Some(config) <- GlobalContext.renderConfig) {
            if (!config.pdfTypstPageNumberEnabled) {
                return ""
            }
            let slot = normalizePageNumberPosition(config.pdfTypstPageNumberPosition)
            let align = normalizePageNumberAlign(config.pdfTypstPageNumberAlign)
            return renderTypstTemplate(
                "page-number-enabled.typ",
                [("PAGE_SLOT", slot), ("PAGE_ALIGN", align)]
            )
        }
        return renderTypstTemplate("page-number-default.typ", [])
    }

    private static func renderTextLangConfig(): String {
        let language = GlobalContext.currentLanguage.toAsciiLower()
        if (language.startsWith("zh")) {
            return ", lang: \"zh\", region: \"cn\""
        }
        if (language.startsWith("ja")) {
            return ", lang: \"ja\", region: \"jp\""
        }
        if (language.startsWith("ko")) {
            return ", lang: \"ko\", region: \"kr\""
        }
        if (language.startsWith("en")) {
            return ", lang: \"en\", region: \"us\""
        }
        return ""
    }

    private static func renderScripstParagraphStyle(): String {
        let language = GlobalContext.currentLanguage.toAsciiLower()
        if (language.startsWith("zh") || language.startsWith("ja") || language.startsWith("ko")) {
            return renderTypstTemplate("paragraph-cjk.typ", []) + "\n"
        }
        if (language.startsWith("ru")) {
            return renderTypstTemplate("paragraph-ru.typ", []) + "\n"
        }
        if (language.startsWith("ar")) {
            return renderTypstTemplate("paragraph-ar.typ", []) + "\n"
        }
        if (language.startsWith("hi") || language.startsWith("th") || language.startsWith("vi") || language.startsWith("id") || language.startsWith("ms")) {
            return renderTypstTemplate("paragraph-sea.typ", []) + "\n"
        }
        return renderTypstTemplate("paragraph-default.typ", []) + "\n"
    }

    private static func renderHeadingStyleConfig(): String {
        let language = GlobalContext.currentLanguage.toAsciiLower()
        let chapterNumberLiterals = buildChineseChapterNumberLiterals(120)
        let chapterLabel = getChapterLabel(language)
        let level1Numbering = getLevel1HeadingNumbering(language)
        return renderTypstTemplate(
            "heading-style.typ",
            [
                ("CHAPTER_NUMBER_LITERALS", chapterNumberLiterals),
                ("CHAPTER_LABEL", TypstEscaper.escapeString(chapterLabel)),
                ("LEVEL1_NUMBERING", level1Numbering)
            ]
        ) + "\n"
    }

    private static func getChapterLabel(language: String): String {
        if (language.startsWith("en")) {
            return "Chapter"
        }
        return ""
    }

    private static func getLevel1HeadingNumbering(language: String): String {
        if (language.startsWith("zh")) {
            return "if values.at(0) < markit-chapter-cn.len() { [第#markit-chapter-cn.at(values.at(0))章] } else { [第#values.at(0)章] }"
        }
        if (language.startsWith("en")) {
            return "[#markit-heading-level1-label #values.at(0)]"
        }
        return "numbering(\"1.\", values.at(0))"
    }

    private static func buildChineseChapterNumberLiterals(max: Int64): String {
        let values = ArrayList<String>()
        values.add("\"零\"")
        for (i in 1..max) {
            values.add("\"${toChineseChapterNumber(i)}\"")
        }
        return String.join(values.toArray(), delimiter: ", ")
    }

    private static func toChineseChapterNumber(value: Int64): String {
        if (value <= 0) {
            return value.toString()
        }
        let digits = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
        if (value < 10) {
            return digits[value]
        }
        if (value < 20) {
            let ones = value % 10
            return if (ones == 0) { "十" } else { "十${digits[ones]}" }
        }
        if (value < 100) {
            let tens = value / 10
            let ones = value % 10
            let suffix = if (ones == 0) { "" } else { digits[ones] }
            return "${digits[tens]}十${suffix}"
        }
        return value.toString()
    }

    private static func renderCodeTextConfig(): String {
        if (let Some(config) <- GlobalContext.renderConfig) {
            if (!config.pdfTypstCodeLigatures) {
                return ", ligatures: false, features: (\"calt\": 0)"
            }
        }
        return ""
    }

    private static func renderCoverAuthors(authors: Array<String>): String {
        let normalized = ArrayList<String>()
        for (author in authors) {
            let value = author.trimAscii()
            if (!value.isEmpty()) {
                normalized.add(value)
            }
        }
        if (normalized.isEmpty()) {
            return ""
        }

        var maxAuthorLength = 0
        for (author in normalized) {
            if (author.size > maxAuthorLength) {
                maxAuthorLength = author.size
            }
        }

        let fontSize = if (normalized.size >= 16) {
            "9pt"
        } else if (normalized.size >= 9) {
            "9.5pt"
        } else {
            "10.5pt"
        }

        let authorItems = ArrayList<String>()
        for (author in normalized) {
            authorItems.add("\"${TypstEscaper.escapeString(author)}\"")
        }
        let authorArray = if (authorItems.size == 1) {
            authorItems[0] + ","
        } else {
            String.join(authorItems.toArray(), delimiter: ", ")
        }

        return renderTypstTemplate(
            "cover-authors.typ",
            [
                ("AUTHOR_ARRAY", authorArray),
                ("FONT_SIZE", fontSize)
            ]
        ) + "\n"
    }

    private static func renderTypstTemplate(name: String, replacements: Array<(String, String)>): String {
        var template = FileHandler.readFileContent(ResourceResolver.resolveResourcePath("assets/typst/templates/${name}").toString())
        for ((key, value) in replacements) {
            template = template.replace("{{${key}}}", value)
        }
        return template
    }

    private static func renderCoverFooter(version: String, organization: String, suborganization: String): String {
        let items = ArrayList<String>()
        if (!version.isEmpty()) {
            items.add(version)
        }
        if (!organization.isEmpty()) {
            items.add(organization)
        }
        if (!suborganization.isEmpty()) {
            items.add(suborganization)
        }
        if (items.isEmpty()) {
            return ""
        }

        let escapedItems = ArrayList<String>()
        for (item in items) {
            escapedItems.add(TypstEscaper.escapeText(item))
        }
        return renderTypstTemplate(
            "footer-line.typ",
            [("FOOTER_TEXT", String.join(escapedItems.toArray(), delimiter: "  ·  "))]
        ) + "\n"
    }

    private static func renderRawConfig(currentPagePath: String): String {
        let syntaxPaths = resolveSyntaxPaths(currentPagePath)
        let themePath = resolveThemePath(currentPagePath)
        if (syntaxPaths.isEmpty() && themePath.isEmpty()) {
            return ""
        }

        let syntaxItems = ArrayList<String>()
        for (path in syntaxPaths) {
            syntaxItems.add("\"${TypstEscaper.escapeString(path)}\"")
        }

        let items = ArrayList<String>()
        if (!syntaxItems.isEmpty()) {
            var syntaxLine = "  syntaxes: (" + String.join(syntaxItems.toArray(), delimiter: ", ") + ")"
            if (!themePath.isEmpty()) {
                syntaxLine += ","
            }
            items.add(syntaxLine)
        }
        if (!themePath.isEmpty()) {
            items.add("  theme: \"" + TypstEscaper.escapeString(themePath) + "\"")
        }
        return renderTypstTemplate(
            "raw-config.typ",
            [("RAW_CONFIG_BODY", String.join(items.toArray(), delimiter: "\n"))]
        ) + "\n"
    }

    private static func resolveSyntaxPaths(currentPagePath: String): Array<String> {
        if (let Some(config) <- GlobalContext.renderConfig) {
            let currentPath = getCurrentPagePath(currentPagePath)
            let resolved = ArrayList<String>()
            let customCandidates = ArrayList<String>()
            if (config.pdfTypstUseBundledSyntaxes) {
                addResolvedPathIfMissing(
                    resolved,
                    resolveBundledPdfAssetPath(currentPath, "assets/typst/syntaxes/cangjie.sublime-syntax")
                )
                addResolvedPathIfMissing(
                    resolved,
                    resolveBundledPdfAssetPath(currentPath, "assets/typst/syntaxes/antlr4.sublime-syntax")
                )
            }
            for (path in config.pdfTypstSyntaxes) {
                customCandidates.add(path)
            }
            let customResolved = resolveExistingRelativeAssetPaths(config.outputPath, currentPath, customCandidates.toArray())
            for (path in customResolved) {
                addResolvedPathIfMissing(resolved, path)
            }
            return resolved.toArray()
        }
        return []
    }

    private static func resolveThemePath(currentPagePath: String): String {
        if (let Some(config) <- GlobalContext.renderConfig) {
            let currentPath = getCurrentPagePath(currentPagePath)
            let candidates = ArrayList<String>()
            if (config.pdfTypstUseBundledTheme) {
                candidates.add("assets/typst/themes/markit.tmTheme")
            }
            if (!config.pdfTypstTheme.isEmpty()) {
                candidates.add(config.pdfTypstTheme)
            }
            let resolved = resolveExistingRelativeAssetPaths(config.outputPath, currentPath, candidates.toArray())
            if (!resolved.isEmpty()) {
                return resolved[0]
            }
        }
        return ""
    }

    private static func resolveWrapMarkerPath(currentPagePath: String): String {
        if (let Some(config) <- GlobalContext.renderConfig) {
            let currentPath = getCurrentPagePath(currentPagePath)
            let resolved = resolveExistingRelativeAssetPaths(
                config.outputPath,
                currentPath,
                ["assets/typst/wrap-marker.svg"]
            )
            if (!resolved.isEmpty()) {
                return resolved[0]
            }
        }
        return ""
    }

    private static func resolveBundledPdfAssetPath(currentPagePath: String, assetPath: String): String {
        return PathUtils.calculateRelativePath(
            currentPagePath,
            PathUtils.shiftPathToParent(assetPath)
        ).replace("\\", "/")
    }

    private static func addResolvedPathIfMissing(resolved: ArrayList<String>, path: String): Unit {
        if (!path.isEmpty() && !resolved.contains(path)) {
            resolved.add(path)
        }
    }

    private static func resolveCoverLogoPath(currentPagePath: String): String {
        if (let Some(config) <- GlobalContext.renderConfig) {
            let logoPath = config.pdfTypstCoverLogo.trimAscii()
            if (logoPath.isEmpty()) {
                return ""
            }
            let currentPath = getCurrentPagePath(currentPagePath)
            let resolved = resolveExistingRelativeAssetPaths(config.outputPath, currentPath, [logoPath])
            if (!resolved.isEmpty()) {
                return resolved[0]
            }
        }
        return ""
    }

    private static func resolveExistingRelativeAssetPaths(outputPath: String, currentPagePath: String, candidates: Array<String>): Array<String> {
        let resolved = ArrayList<String>()
        let useSharedPdfAssets = shouldUseSharedPdfAssets(outputPath)
        for (candidate in candidates) {
            if (candidate.isEmpty()) {
                continue
            }
            let outputAssetPath = Path(outputPath).join(candidate).normalize()
            let sharedOutputAssetPath = Path(outputPath).parent.join(candidate).normalize()
            let sourceAssetPath = ResourceResolver.resolveResourcePath(candidate)
            if (exists(outputAssetPath)) {
                let relativePath = PathUtils.calculateRelativePath(currentPagePath, candidate).replace("\\", "/")
                if (!resolved.contains(relativePath)) {
                    resolved.add(relativePath)
                }
                continue
            }
            if (useSharedPdfAssets && exists(sharedOutputAssetPath)) {
                let relativePath = PathUtils.calculateRelativePath(
                    currentPagePath,
                    PathUtils.shiftPathToParent(candidate)
                ).replace("\\", "/")
                if (!resolved.contains(relativePath)) {
                    resolved.add(relativePath)
                }
                continue
            }
            if (useSharedPdfAssets && exists(sourceAssetPath)) {
                let relativePath = PathUtils.calculateRelativePath(
                    currentPagePath,
                    PathUtils.shiftPathToParent(candidate)
                ).replace("\\", "/")
                if (!resolved.contains(relativePath)) {
                    resolved.add(relativePath)
                }
                continue
            }
            if (!exists(sourceAssetPath)) {
                continue
            }
            let relativePath = PathUtils.calculateRelativePath(currentPagePath, candidate).replace("\\", "/")
            if (!resolved.contains(relativePath)) {
                resolved.add(relativePath)
            }
        }
        return resolved.toArray()
    }

    private static func getCurrentPagePath(currentPagePath: String): String {
        if (currentPagePath.isEmpty()) {
            return "merged.typ"
        }
        return currentPagePath.replace("\\", "/")
    }

    private static func shouldUseSharedPdfAssets(outputPath: String): Bool {
        if (let Some(config) <- GlobalContext.renderConfig) {
            return config.outputFormat.toAsciiLower() == "pdf" && !Path(outputPath).parent.isEmpty()
        }
        return false
    }

    private static func normalizePageNumberPosition(position: String): String {
        let normalized = position.toAsciiLower()
        if (normalized == "header") {
            return "header"
        }
        return "footer"
    }

    private static func normalizePageNumberAlign(align: String): String {
        let normalized = align.toAsciiLower()
        if (normalized == "left" || normalized == "center") {
            return normalized
        }
        return "right"
    }

    private static func getTocTitle(): String {
        let currentLanguage = GlobalContext.currentLanguage.toAsciiLower()
        if (currentLanguage.startsWith("zh")) {
            return "目录"
        }
        if (currentLanguage.startsWith("ja")) {
            return "目次"
        }
        if (currentLanguage.startsWith("ko")) {
            return "목차"
        }
        return "Contents"
    }
}
