package codehl.core

import codehl.themes.Theme

public class HighlightOptions {
    public let lang: String
    public let classPrefix: String
    public let highlightLines: Array<Int64>
    public let i18nLines: Array<Int64>
    public let targetLang: String
    public let themeName: String
    public let theme: ?Theme

    public init(
        lang!: String = "",
        classPrefix!: String = "codehl",
        highlightLines!: Array<Int64> = [],
        i18nLines!: Array<Int64> = [],
        targetLang!: String = "",
        themeName!: String = "",
        theme!: ?Theme = None
    ) {
        this.lang = lang
        this.classPrefix = classPrefix
        this.highlightLines = highlightLines
        this.i18nLines = i18nLines
        this.targetLang = targetLang
        this.themeName = themeName
        this.theme = theme
    }
}

public class DualThemeOptions {
    public let lightTheme: String
    public let darkTheme: String
    public let lightThemeModel: ?Theme
    public let darkThemeModel: ?Theme
    public let base: HighlightOptions

    public init(
        lightTheme!: String = "light-plus",
        darkTheme!: String = "dark-plus",
        lightThemeModel!: ?Theme = None,
        darkThemeModel!: ?Theme = None,
        base!: HighlightOptions = HighlightOptions()
    ) {
        this.lightTheme = lightTheme
        this.darkTheme = darkTheme
        this.lightThemeModel = lightThemeModel
        this.darkThemeModel = darkThemeModel
        this.base = base
    }
}

public class DualThemeHtml {
    public let lightHtml: String
    public let darkHtml: String

    public init(lightHtml: String, darkHtml: String) {
        this.lightHtml = lightHtml
        this.darkHtml = darkHtml
    }
}
