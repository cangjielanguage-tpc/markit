package markit.plugins.standard.block.fenced_code_block

import codehl.{LanguageAlias, LanguageRegistration}

public class FencedCodeBlockConfig {
    public FencedCodeBlockConfig(
        public let enableGroup!: Bool = false,
        public let theme!: String = "",
        public let lightTheme!: String = "light-plus",
        public let darkTheme!: String = "dark-plus",
        public let enableCodehl!: Bool = true,
        public let enableMermaid!: Bool = true,
        public let targetLanguage!: String = "",
        public let codehlGrammarDirs!: Array<String> = [],
        public let codehlThemeDirs!: Array<String> = [],
        public let codehlLanguages!: Array<LanguageRegistration> = [],
        public let codehlAliases!: Array<LanguageAlias> = [],
        public let autoAnchor!: Bool = false
    ) {}
}
