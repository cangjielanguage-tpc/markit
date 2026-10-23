package codehl.core

import codehl.themes.Theme

public class HighlightOptions {

    public HighlightOptions(
        public let lang!: String = "",
        public let classPrefix!: String = "codehl",
        public let highlightLines!: Array<Int64> = [],
        public let i18nLines!: Array<Int64> = [],
        public let targetLang!: String = "",
        public let themeName!: String = "",
        public let theme!: ?Theme = None
    ) {}
}

public class DualThemeOptions {

    public DualThemeOptions(
        public let lightTheme!: String = "light-plus",
        public let darkTheme!: String = "dark-plus",
        public let lightThemeModel!: ?Theme = None,
        public let darkThemeModel!: ?Theme = None,
        public let base!: HighlightOptions = HighlightOptions()
    ) {}
}

public class DualThemeHtml {

    public DualThemeHtml(public let lightHtml: String, public let darkHtml: String) {}
}
