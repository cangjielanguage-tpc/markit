package markit_kit.models

import markit.plugins.i18n.config.I18nConfig
import markit.plugins.standard.block.heading.HeadingNumberingConfig
import codehl.{LanguageAlias, LanguageRegistration}

/**
 * 渲染配置
 */
public struct RenderConfig {
    public RenderConfig(
        public let inputPath: String,
        public let outputPath: String,
        public let outputFormat: String,
        public let codeblockGroupEnabled: Bool,
        public let codeBlockTheme: String,
        public let codeBlockLightTheme: String,
        public let codeBlockDarkTheme: String,
        public let codeBlockHighlightEnabled: Bool,
        public let codeBlockGrammarDirs: Array<String>,
        public let codeBlockThemeDirs: Array<String>,
        public let codeBlockLanguages: Array<LanguageRegistration>,
        public let codeBlockAliases: Array<LanguageAlias>,
        public let codeBlockAutoAnchor: Bool,
        public let devMode: Bool,
        public let enableToc: Bool,
        public let themeName: String,
        public let siteTitle: String,
        public let i18nConfig: ?I18nConfig,
        public let headingNumberingConfig: ?HeadingNumberingConfig,
        public let headingResetFor: String,
        public let chapterNavigation: Bool,
        public let chapterPrevText: String,
        public let chapterNextText: String,
        public let statisticTotalTexts: Bool,
        public let statisticTotalTextsTemplate: String,
        public let statisticSpentTime: Bool,
        public let statisticSpentTimeTemplate: String,
        public let statisticSecond: String,
        public let statisticMinute: String,
        public let gitPrefix: String,
        public let reposGithub: String,
        public let reposGitcode: String,
        public let reposGitee: String,
        public let reposGitlab: String,
        public let listMultiLevelOrderedList: Bool,
        public let listAutoAnchor: Bool,
        public let mathAutoAnchor: Bool,
        public let tableThreeLine: Bool,
        public let tableAutoAnchor: Bool,
        public let blockAutoAnchor: Bool,
        public let headingClosable: Bool,
        public let pdfTypstUseBundledSyntaxes: Bool,
        public let pdfTypstUseBundledTheme: Bool,
        public let pdfTypstSyntaxes: Array<String>,
        public let pdfTypstTheme: String,
        public let pdfTypstCodeLigatures: Bool,
        public let pdfTypstCoverEnabled: Bool,
        public let pdfTypstCoverLogo: String,
        public let pdfTypstCoverTitle: String,
        public let pdfTypstCoverSubtitle: String,
        public let pdfTypstCoverAuthors: Array<String>,
        public let pdfTypstCoverVersion: String,
        public let pdfTypstCoverOrganization: String,
        public let pdfTypstCoverSuborganization: String,
        public let pdfTypstTocMaxLevel: Int64,
        public let pdfTypstPageNumberEnabled: Bool,
        public let pdfTypstPageNumberPosition: String,
        public let pdfTypstPageNumberAlign: String,
        public let customJsAssets: Array<String>,
        public let customCssAssets: Array<String>,
        public let websiteCodeLigatures: Bool
    ) {}
}

/**
 * 渲染结果
 */
public struct RenderResult {
    public RenderResult(
        public let success!: Bool,
        public let processedFiles!: Array<(String, String)> = [],  // (filename, title) pairs
        public let errorMessage !: ?String = None
    ) {}
}
