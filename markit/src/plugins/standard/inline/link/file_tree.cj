package markit.plugins.standard.inline.link

import std.collection.{ArrayList, HashMap}

public class FileTree {
    private let files: Array<String>
    private let headingIndex = HashMap<String, ArrayList<HeadingInfo>>()

    public init(files: Array<String>) {
        this.files = files
    }

    public func addHeading(heading: HeadingInfo): Unit {
        if (!headingIndex.contains(heading.slug)) {
            headingIndex[heading.slug] = ArrayList<HeadingInfo>()
        }
        if (let Some(list) <- headingIndex.get(heading.slug)) {
            list.add(heading)
        }
    }

    public func findHeadingsBySlug(slug: String): Array<HeadingInfo> {
        if (let Some(list) <- headingIndex.get(slug)) {
            return list.toArray()
        }
        return []
    }

    public func hasHeading(slug: String): Bool {
        return headingIndex.contains(slug)
    }

    public func getFiles(): Array<String> {
        return files
    }

    public func matchPattern(pattern: String): Array<String> {
        let matches = ArrayList<String>()
        let normalizedPattern = pattern.replace("\\", "/")
        for (file in files) {
            if (matchesWildcard(file.replace("\\", "/"), normalizedPattern)) {
                matches.add(file)
            }
        }
        return matches.toArray()
    }

    private func matchesWildcard(text: String, pattern: String): Bool {
        let textRunes = ArrayList<Rune>()
        for (rune in text.runes()) {
            textRunes.add(rune)
        }
        let patternRunes = ArrayList<Rune>()
        for (rune in pattern.runes()) {
            patternRunes.add(rune)
        }

        var textIndex: Int64 = 0
        var patternIndex: Int64 = 0
        var starIndex: Int64 = -1
        var starTextIndex: Int64 = 0

        while (textIndex < textRunes.size) {
            if (patternIndex < patternRunes.size &&
                (patternRunes[patternIndex] == r'?' || patternRunes[patternIndex] == textRunes[textIndex])) {
                patternIndex += 1
                textIndex += 1
                continue
            }

            if (patternIndex < patternRunes.size && patternRunes[patternIndex] == r'*') {
                starIndex = patternIndex
                starTextIndex = textIndex
                patternIndex += 1
                continue
            }

            if (starIndex >= 0) {
                patternIndex = starIndex + 1
                starTextIndex += 1
                textIndex = starTextIndex
                continue
            }

            return false
        }

        while (patternIndex < patternRunes.size && patternRunes[patternIndex] == r'*') {
            patternIndex += 1
        }
        return patternIndex == patternRunes.size
    }
}
