package dochir.docgen

public class Pathing {
    /** `a.b.c` -> `a/b/c` */
    public static func packageNameToPath(packageName: String): String {
        return packageName.replace(".", "/")
    }

    public static func packageIndexFile(): String {
        return "index.md"
    }

    public static func elementFileName(elementName: String): String {
        return elementName + ".md"
    }

    public static func topLevelValueFileName(name: String): String {
        return "variables/" + slug(name) + ".md"
    }

    public static func topLevelFunctionFileName(declaration: String): String {
        return "functions/" + slug(declaration) + ".md"
    }

    public static func typePropertyFileName(typeName: String, name: String): String {
        return typeName + "/properties/" + slug(name) + ".md"
    }

    public static func typeStaticPropertyFileName(typeName: String, name: String): String {
        return typeName + "/static-properties/" + slug(name) + ".md"
    }

    public static func typeConstructorFileName(typeName: String, declaration: String): String {
        return typeName + "/constructors/" + slug(declaration) + ".md"
    }

    public static func typeMethodFileName(typeName: String, declaration: String): String {
        return typeName + "/methods/" + slug(declaration) + ".md"
    }

    public static func enumConstructorFileName(typeName: String, declaration: String): String {
        return typeName + "/enum-constructors/" + slug(declaration) + ".md"
    }

    public static func slug(text: String): String {
        let out = StringBuilder()
        var pendingDash = false
        var index: Int64 = 0
        while (index < text.size) {
            let byte = text[index]
            if (isAsciiLetter(byte) || isAsciiDigit(byte)) {
                if (pendingDash && out.size > 0) {
                    out.append("-")
                }
                out.append(text[index..index + 1].toAsciiLower())
                pendingDash = false
                index += 1
            } else {
                pendingDash = true
                index += utf8Width(byte)
            }
        }

        let value = out.toString()
        if (value.isEmpty()) {
            return "item"
        }
        return value
    }

    private static func isAsciiLetter(byte: Byte): Bool {
        return (byte >= b'a' && byte <= b'z') || (byte >= b'A' && byte <= b'Z')
    }

    private static func isAsciiDigit(byte: Byte): Bool {
        return byte >= b'0' && byte <= b'9'
    }

    private static func utf8Width(first: Byte): Int64 {
        if (first < 0x80) {
            return 1
        }
        if ((first & 0xE0) == 0xC0) {
            return 2
        }
        if ((first & 0xF0) == 0xE0) {
            return 3
        }
        if ((first & 0xF8) == 0xF0) {
            return 4
        }
        return 1
    }
}

