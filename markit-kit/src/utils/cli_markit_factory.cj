package markit_kit.utils

import markit.{Markit, ParseOutput}
import markit.bundles.GFMBundle
import markit.core.nodes.DocumentNode
import markit.plugins.commonmark.block.html_block.HtmlBlockConfig
import markit.plugins.gfm.block.math_block.MathBlockConfig
import markit.plugins.gfm.block.table.TableConfig
import markit.plugins.i18n.I18nPlugin
import markit.plugins.standard.block.fenced_code_block.FencedCodeBlockConfig
import markit.plugins.standard.block.heading.{HeadingClosableConfig, HeadingNumberingConfig, HeadingSlugConfig}
import markit.plugins.standard.block.list.ListConfig
import markit.plugins.standard.inline.link.LinkConfig
import markit_kit.models.{GlobalContext, RenderConfig}

public class CliMarkitFactory {
    public static func build(
        config: RenderConfig,
        linkConfig!: ?LinkConfig = None,
        currentPagePath!: String = "",
        headingInitialState!: ?Array<Int64> = None,
        headingNumberingOverride!: ?HeadingNumberingConfig = None,
        headingSlugPathLabels!: Bool = false,
        htmlInlineMarkdownParsing!: Bool = true
    ): Markit {
        let baseHeadingConfig = headingNumberingOverride ?? defaultHeadingNumberingConfig(config)
        let state = headingInitialState ?? defaultHeadingState(config)
        let effectiveHeadingConfig = withHeadingState(baseHeadingConfig, state)
        let baseLinkConfig = linkConfig ?? (GlobalContext.linkConfig ?? LinkConfig())
        let effectiveLinkConfig = withCurrentFile(baseLinkConfig, currentPagePath)
        let closableConfig = HeadingClosableConfig(enabled: config.headingClosable)
        let i18nPlugin = if (let Some(i18nConfig) <- config.i18nConfig) {
            I18nPlugin(config: i18nConfig)
        } else {
            I18nPlugin()
        }

        return Markit()
            .use(
                GFMBundle(
                    headingNumberingConfig: effectiveHeadingConfig,
                    closableConfig: closableConfig,
                    headingSlugConfig: HeadingSlugConfig(
                        currentPagePath: currentPagePath,
                        enablePathLabels: headingSlugPathLabels
                    ),
                    linkConfig: effectiveLinkConfig,
                    fencedCodeBlockConfig: FencedCodeBlockConfig(
                        enableGroup: config.codeblockGroupEnabled,
                        theme: config.codeBlockTheme,
                        lightTheme: config.codeBlockLightTheme,
                        darkTheme: config.codeBlockDarkTheme,
                        enableCodehl: config.codeBlockHighlightEnabled,
                        targetLanguage: config.i18nConfig?.targetLanguage ?? "",
                        codehlGrammarDirs: config.codeBlockGrammarDirs,
                        codehlThemeDirs: config.codeBlockThemeDirs,
                        codehlLanguages: config.codeBlockLanguages,
                        codehlAliases: config.codeBlockAliases,
                        autoAnchor: config.codeBlockAutoAnchor
                    ),
                    listConfig: ListConfig(autoAnchor: config.listAutoAnchor),
                    mathBlockConfig: MathBlockConfig(autoAnchor: config.mathAutoAnchor),
                    tableConfig: TableConfig(enableThreeLineTable: config.tableThreeLine, autoAnchor: config.tableAutoAnchor),
                    htmlBlockConfig: HtmlBlockConfig(enableInlineMarkdownParsing: htmlInlineMarkdownParsing),
                    blockAutoAnchor: config.blockAutoAnchor
                )
            )
            .use(i18nPlugin)
    }

    public static func buildSummaryParser(config: RenderConfig): Markit {
        return build(
            config,
            headingNumberingOverride: HeadingNumberingConfig(
                enabled: false,
                startFrom: (1, 1, 1, 1, 1, 1)
            ),
            htmlInlineMarkdownParsing: false
        )
    }

    public static func documentOf(output: ParseOutput): DocumentNode {
        return (output.root() as DocumentNode).getOrThrow()
    }

    public static func defaultHeadingNumberingConfig(config: RenderConfig): HeadingNumberingConfig {
        return config.headingNumberingConfig ?? HeadingNumberingConfig(
            enabled: false,
            startFrom: (1, 1, 1, 1, 1, 1)
        )
    }

    public static func defaultHeadingState(config: RenderConfig): Array<Int64> {
        let startFrom = defaultHeadingNumberingConfig(config).startFrom
        return Array<Int64>(6) { i => startFrom[i] - 1 }
    }

    public static func withCurrentFile(config: LinkConfig, currentPagePath: String): LinkConfig {
        return LinkConfig(
            fileTree: config.fileTree,
            renderMode: config.renderMode,
            outputExtension: config.outputExtension,
            preserveFlatFilePaths: config.preserveFlatFilePaths,
            currentFilePath: currentPagePath
        )
    }

    public static func withHeadingState(config: HeadingNumberingConfig, state: Array<Int64>): HeadingNumberingConfig {
        return HeadingNumberingConfig(
            enabled: config.enabled,
            startFrom: (
                config.startFrom[0],
                config.startFrom[1],
                config.startFrom[2],
                config.startFrom[3],
                config.startFrom[4],
                config.startFrom[5]
            ),
            maxDepth: config.maxDepth,
            includeInHtml: config.includeInHtml,
            separator: config.separator,
            resetBeforeParse: config.resetBeforeParse,
            initialCounters: Some(copyHeadingState(state, config.startFrom))
        )
    }

    private static func copyHeadingState(state: Array<Int64>, fallbackStart: Array<Int64>): Array<Int64> {
        return Array<Int64>(6) { i =>
            if (i < state.size) {
                state[i]
            } else {
                fallbackStart[i] - 1
            }
        }
    }
}
