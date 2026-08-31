package markit.utils

public func slug(text: String): String {
    if (text.isEmpty()) {
        return String.empty
    }

    let result = StringBuilder(text.size)
    var inTag = false
    var skipLeading = true
    var pendingHyphen = false

    for (char in text.runes()) {
        if (inTag) {
            if (char == r'>') {
                inTag = false
            }
            continue
        }
        if (char == r'<') {
            inTag = true
            continue
        }
        if (skipLeading && shouldSkipLeadingChar(char)) {
            continue
        }
        skipLeading = false

        if (isSlugChar(char)) {
            if (pendingHyphen && result.size > 0) {
                result.append(r'-')
                pendingHyphen = false
            }
            result.append(toSlugChar(char))
        } else if (isSlugSeparator(char) && result.size > 0) {
            pendingHyphen = true
        }
    }

    return result.toString()
}

private func shouldSkipLeadingChar(char: Rune): Bool {
    return char == r'#' || char.isAsciiWhiteSpace()
}

private func toSlugChar(char: Rune): Rune {
    return if (char.isAsciiUpperCase()) {
        char.toAsciiLowerCase()
    } else {
        char
    }
}

private func isSlugChar(char: Rune): Bool {
    if (char.isAsciiNumberOrLetter()) {
        return true
    }

    let code = UInt32(char)

    if (code >= 0x4E00u32 && code <= 0x9FFFu32) {
        return true
    }
    if (code >= 0x3400u32 && code <= 0x4DBFu32) {
        return true
    }
    if (code >= 0x20000u32 && code <= 0x2A6DFu32) {
        return true
    }
    if (code >= 0x2A700u32 && code <= 0x2B73Fu32) {
        return true
    }
    if (code >= 0x2B740u32 && code <= 0x2B81Fu32) {
        return true
    }
    if (code >= 0x2B820u32 && code <= 0x2CEAFu32) {
        return true
    }
    if (code >= 0x2CEB0u32 && code <= 0x2EBEFu32) {
        return true
    }
    if (code >= 0x00C0u32 && code <= 0x00FFu32) {
        return true
    }
    if (code >= 0x0100u32 && code <= 0x017Fu32) {
        return true
    }
    if (code >= 0x0180u32 && code <= 0x024Fu32) {
        return true
    }
    if (code >= 0x0370u32 && code <= 0x03FFu32) {
        return true
    }
    if (code >= 0x0400u32 && code <= 0x04FFu32) {
        return true
    }
    if (code >= 0x3040u32 && code <= 0x309Fu32) {
        return true
    }
    if (code >= 0x30A0u32 && code <= 0x30FFu32) {
        return true
    }
    if (code >= 0xAC00u32 && code <= 0xD7AFu32) {
        return true
    }

    return false
}

private func isSlugSeparator(char: Rune): Bool {
    if (char.isAsciiWhiteSpace() || char.isAsciiPunctuation()) {
        return true
    }

    let code = UInt32(char)

    if (code == 0xFF1Au32 ||
        code == 0xFF0Cu32 ||
        code == 0xFF0Eu32 ||
        code == 0xFF1Fu32 ||
        code == 0xFF01u32 ||
        code == 0xFF1Bu32 ||
        code == 0x3001u32 ||
        code == 0x3002u32 ||
        code == 0x300Au32 ||
        code == 0x300Bu32 ||
        code == 0x300Cu32 ||
        code == 0x300Du32 ||
        code == 0x300Eu32 ||
        code == 0x300Fu32 ||
        code == 0x2014u32 ||
        code == 0x2026u32) {
        return true
    }

    return false
}
