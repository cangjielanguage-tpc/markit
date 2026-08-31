package markit.plugins.standard.block.fenced_code_block

import codehl.{LanguageAlias, LanguageRegistration}

public class FencedCodeBlockConfig {
    public let enableGroup: Bool
    public let theme: String
    public let lightTheme: String
    public let darkTheme: String
    public let enableCodehl: Bool
    public let enableMermaid: Bool
    public let targetLanguage: String
    public let codehlGrammarDirs: Array<String>
    public let codehlThemeDirs: Array<String>
    public let codehlLanguages: Array<LanguageRegistration>
    public let codehlAliases: Array<LanguageAlias>
    public let autoAnchor: Bool

    public init(
        enableGroup!: Bool = false,
        theme!: String = "",
        lightTheme!: String = "light-plus",
        darkTheme!: String = "dark-plus",
        enableCodehl!: Bool = true,
        enableMermaid!: Bool = true,
        targetLanguage!: String = "",
        codehlGrammarDirs!: Array<String> = [],
        codehlThemeDirs!: Array<String> = [],
        codehlLanguages!: Array<LanguageRegistration> = [],
        codehlAliases!: Array<LanguageAlias> = [],
        autoAnchor!: Bool = false
    ) {
        this.enableGroup = enableGroup
        this.theme = theme
        this.lightTheme = lightTheme
        this.darkTheme = darkTheme
        this.enableCodehl = enableCodehl
        this.enableMermaid = enableMermaid
        this.targetLanguage = targetLanguage
        this.codehlGrammarDirs = codehlGrammarDirs
        this.codehlThemeDirs = codehlThemeDirs
        this.codehlLanguages = codehlLanguages
        this.codehlAliases = codehlAliases
        this.autoAnchor = autoAnchor
    }
}
