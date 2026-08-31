package markit.plugins.i18n.config

import std.collection.{ArrayList, HashMap}

public struct I18nConfig {
    public let defaultLanguage: String
    public let targetLanguage: String
    public let homeText: String
    public let documentationText: String

    public init(
        defaultLanguage!: String = "en",
        targetLanguage!: String = "en",
        homeText!: String = "Home",
        documentationText!: String = "Documentation"
    ) {
        this.defaultLanguage = validateLanguageId(defaultLanguage) ?? "en"
        this.targetLanguage = validateLanguageId(targetLanguage) ?? "en"
        this.homeText = homeText
        this.documentationText = documentationText
    }

    public static func validateLanguageId(languageId: String): ?String {
        if (languageId.size < 2 || languageId.size > 8) {
            return None
        }

        let sb = StringBuilder()
        for (rune in languageId.runes()) {
            if (isAsciiUpper(rune)) {
                sb.append(rune.toAsciiLowerCase())
                continue
            }
            if (isAsciiLower(rune) || isAsciiDigit(rune) || rune == r'-') {
                sb.append(rune)
                continue
            }
            return None
        }
        return Some(sb.toString())
    }

    public static func createWithValidation(defaultLanguage: String, targetLanguage: String): ConfigResult {
        let errors = ArrayList<String>()
        let defaultValue = validateLanguageId(defaultLanguage)
        let targetValue = validateLanguageId(targetLanguage)

        if (defaultValue.isNone()) {
            errors.add("Invalid default language identifier: '${defaultLanguage}'")
        }
        if (targetValue.isNone()) {
            errors.add("Invalid target language identifier: '${targetLanguage}'")
        }
        if (!errors.isEmpty()) {
            return ConfigResult.Error(errors.toArray())
        }

        return ConfigResult.Success(I18nConfig(
            defaultLanguage: defaultValue.getOrThrow(),
            targetLanguage: targetValue.getOrThrow()
        ))
    }

    public static func getSupportedLanguages(): HashMap<String, String> {
        let languages = HashMap<String, String>()
        languages["en"] = "English"
        languages["zh"] = "中文"
        languages["zh-cn"] = "简体中文"
        languages["zh-tw"] = "繁体中文"
        languages["ja"] = "日本語"
        languages["ko"] = "한국어"
        languages["fr"] = "Français"
        languages["de"] = "Deutsch"
        languages["es"] = "Español"
        languages["pt"] = "Português"
        languages["ru"] = "Русский"
        languages["ar"] = "العربية"
        return languages
    }

    public static func isSupportedLanguage(languageId: String): Bool {
        let normalized = validateLanguageId(languageId) ?? ""
        return getSupportedLanguages().contains(normalized)
    }
}

public enum ConfigResult {
    | Success(I18nConfig)
    | Error(Array<String>)

    public func isSuccess(): Bool {
        match (this) {
            case Success(_) => true
            case Error(_) => false
        }
    }

    public func getConfig(): ?I18nConfig {
        match (this) {
            case Success(config) => Some(config)
            case Error(_) => None
        }
    }

    public func getErrors(): Array<String> {
        match (this) {
            case Success(_) => []
            case Error(errors) => errors
        }
    }
}

private func isAsciiUpper(rune: Rune): Bool {
    return rune >= r'A' && rune <= r'Z'
}

private func isAsciiLower(rune: Rune): Bool {
    return rune >= r'a' && rune <= r'z'
}

private func isAsciiDigit(rune: Rune): Bool {
    return rune >= r'0' && rune <= r'9'
}
