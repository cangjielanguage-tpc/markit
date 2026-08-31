package markit_kit.processors

import markit_kit.interfaces.Processor
import markit_kit.models.GlobalContext
import markit_kit.utils.TypstDocumentBuilder
import markit.plugins.standard.inline.link.LinkConfig
import markit.plugins.standard.block.fenced_code_block.FencedCodeBlockNode
import markit.core.nodes.{DocumentNode, Node}
import markit_kit.utils.{CliMarkitFactory, PathUtils}
import std.fs.Path
import markit.utils.TypstEscaper
import markit.plugins.standard.inline.image.ImageNode
import mermaid4cj.{MermaidRenderOptions, MermaidRenderer, MermaidTheme}

/**
 * Typst 处理器
 * 用于单文件/批量导出 Typst：parse 后输出 toTypst()。
 */
public class TypstProcessor <: Processor {
    private let config = GlobalContext.renderConfig.getOrThrow()
    private var linkConfig: LinkConfig = GlobalContext.linkConfig ?? LinkConfig()
    private var headingInitialState: Array<Int64> = CliMarkitFactory.defaultHeadingState(config)

    public init(themeName!: String = "") {
    }

    public func setLinkConfig(config: LinkConfig): Unit {
        this.linkConfig = config
    }

    public func setHeadingInitialState(state: Array<Int64>): Unit {
        this.headingInitialState = state
    }

    public func process(content: String, title: String, currentPagePath!: String = "", asDocument!: Bool = false): (String, DocumentNode) {
        let parser = CliMarkitFactory.build(
            config,
            linkConfig: Some(linkConfig),
            currentPagePath: currentPagePath,
            headingInitialState: Some(headingInitialState)
        )
        let parseResult = try {
            parser.parse(content)
        } catch (e: Exception) {
            throw IllegalArgumentException("TypstProcessor parse failed for ${currentPagePath}: ${e.toString()}")
        }
        let document = try {
            CliMarkitFactory.documentOf(parseResult)
        } catch (e: Exception) {
            throw IllegalArgumentException("TypstProcessor document extraction failed for ${currentPagePath}: ${e.toString()}")
        }
        try {
            preprocessTypstAssets(document, currentPagePath)
        } catch (e: Exception) {
            throw IllegalArgumentException("TypstProcessor asset preprocess failed for ${currentPagePath}: ${e.toString()}")
        }
        let typstContent = try {
            postprocessTypst(document.toTypst())
        } catch (e: Exception) {
            throw IllegalArgumentException("TypstProcessor render failed for ${currentPagePath}: ${e.toString()}")
        }
        return (typstContent, document)
    }

    public func wrapHtmlContent(htmlContent: String, title: String, currentPagePath: String): String {
        return TypstDocumentBuilder.wrapDocument(htmlContent, title, currentPagePath: currentPagePath)
    }

    public func getExtension(): String {
        return "typ"
    }

    public func getType(): String {
        return "typst"
    }

    private func preprocessTypstAssets(document: DocumentNode, currentPagePath: String): Unit {
        let assetState = TypstAssetState(currentPagePath)
        rewriteLocalImagePaths(document, assetState)
        rewriteMermaidBlocks(document, assetState)
    }

    private func postprocessTypst(content: String): String {
        return content
    }

    private func rewriteMermaidBlocks(node: Node, state: TypstAssetState): Unit {
        for (i in 0..node.children.size) {
            let child = node.children[i]
            match (child) {
                case fenced: FencedCodeBlockNode =>
                    if (shouldRenderMermaidBlock(fenced)) {
                        if (let Some(rawTypst) <- renderMermaidBlock(fenced, state)) {
                            node.replaceChild(child, rawTypst)
                            continue
                        }
                    }
                case _ => ()
            }
            rewriteMermaidBlocks(child, state)
        }
    }

    private func shouldRenderMermaidBlock(node: FencedCodeBlockNode): Bool {
        return node.fileGroups.isEmpty() && node.language.toAsciiLower() == "mermaid"
    }

    private func renderMermaidBlock(node: FencedCodeBlockNode, state: TypstAssetState): ?Node {
        let assetInfo = state.nextMermaidAsset()
        let svgOutputPath = Path(state.outputBasePath).join(assetInfo.outputRelativePath).normalize()
        let result = try {
            MermaidRenderer().renderSvgFile(
                node.content(),
                svgOutputPath,
                options: MermaidRenderOptions(
                    theme: MermaidTheme.Default,
                    classPrefix: "mk-mermaid",
                    idPrefix: "mk-mermaid-${state.mermaidAssetIndex()}"
                )
            )
        } catch (e: Exception) {
            throw IllegalArgumentException("TypstProcessor mermaid SVG render failed for ${state.currentPagePath}, fenced code node=${node.id}: ${e.toString()}")
        }
        if (!result.supported) {
            return None
        }

        let relativeTypstPath = state.toTypstGeneratedAssetPath(assetInfo.outputRelativePath)
        let escapedPath = TypstEscaper.escapeString(relativeTypstPath)
        let altText = TypstEscaper.escapeText("Mermaid diagram")
        let typst = "#figure(image(\"${escapedPath}\", width: 100%), caption: [${altText}])\n\n"
        return Some(Node("RawTypst", literal: typst))
    }

    private func rewriteLocalImagePaths(node: Node, state: TypstAssetState): Unit {
        match (node) {
            case image: ImageNode =>
                let src = image.src
                if (shouldRewriteLocalAssetPath(src)) {
                    image.src = state.toTypstAssetPath(src)
                }
            case _ => ()
        }

        for (child in node.children) {
            rewriteLocalImagePaths(child, state)
        }
    }

    private func shouldRewriteLocalAssetPath(path: String): Bool {
        return PathUtils.isRelativeLocalPath(path)
    }
}

class TypstAssetState {
    public let currentPagePath: String
    public let outputBasePath: String
    public let useSharedPdfAssets: Bool
    private var mermaidCounter: Int64 = 0
    private var lastMermaidIndex: Int64 = 0

    public init(currentPagePath: String) {
        this.currentPagePath = if (currentPagePath.isEmpty()) { "merged.typ" } else { currentPagePath.replace("\\", "/") }
        let config = GlobalContext.renderConfig.getOrThrow()
        let pdfMode = config.outputFormat.toAsciiLower() == "pdf"
        this.useSharedPdfAssets = pdfMode
        this.outputBasePath = if (pdfMode) { Path(config.outputPath).parent.toString() } else { config.outputPath }
    }

    public func nextMermaidAsset(): TypstAssetInfo {
        let pageStem = sanitizePagePath(currentPagePath)
        let index = mermaidCounter
        lastMermaidIndex = index
        mermaidCounter += 1
        let fileName = "${pageStem}-mermaid-${index}.svg"
        return TypstAssetInfo("assets/typst/${fileName}")
    }

    public func mermaidAssetIndex(): Int64 {
        return lastMermaidIndex
    }

    public func toTypstAssetPath(assetPath: String): String {
        let normalizedAssetPath = normalizeRelativeAssetPath(assetPath)
        if (!useSharedPdfAssets) {
            return PathUtils.calculateRelativePath(currentPagePath, normalizedAssetPath).replace("\\", "/")
        }
        let sharedAssetPath = PathUtils.shiftPathToParent(normalizedAssetPath)
        return PathUtils.calculateRelativePath(currentPagePath, sharedAssetPath).replace("\\", "/")
    }

    public func toTypstGeneratedAssetPath(assetPath: String): String {
        let normalizedAssetPath = assetPath.replace("\\", "/")
        if (!useSharedPdfAssets) {
            return PathUtils.calculateRelativePath(currentPagePath, normalizedAssetPath).replace("\\", "/")
        }
        let sharedAssetPath = PathUtils.shiftPathToParent(normalizedAssetPath)
        return PathUtils.calculateRelativePath(currentPagePath, sharedAssetPath).replace("\\", "/")
    }

    private func normalizeRelativeAssetPath(assetPath: String): String {
        return PathUtils.resolveRelativeDocumentPath(currentPagePath, assetPath)
    }

    private func sanitizePagePath(path: String): String {
        var result = path.replace("\\", "/").replace("/", "-")
        result = result.replace(".typ", "")
        result = result.replace(".md", "")
        result = result.replace(".markdown", "")
        result = result.replace(" ", "-")
        result = result.replace(":", "-")
        result = result.replace("(", "-")
        result = result.replace(")", "-")
        result = result.replace("[", "-")
        result = result.replace("]", "-")
        result = result.replace("{", "-")
        result = result.replace("}", "-")
        result = result.replace("'", "-")
        result = result.replace("\"", "-")
        result = result.replace(",", "-")
        result = result.replace(";", "-")
        result = result.replace("?", "-")
        result = result.replace("!", "-")
        result = result.replace("&", "-")
        result = result.replace("#", "-")
        return if (result.isEmpty()) { "document" } else { result }
    }
}

class TypstAssetInfo {
    public let outputRelativePath: String

    public init(outputRelativePath: String) {
        this.outputRelativePath = outputRelativePath
    }
}
