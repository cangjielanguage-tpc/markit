package dochir.docgen

@Test
func extractHomepageAfterMarker(): Unit {
    let homepage = PackageHomepage.extractHomepageMarkdown("""
- [Overview](overview.md)

<!-- homepage -->

## Package Overview

Use this package to build CHIR tools.
""")

    @Expect(homepage, "## Package Overview\n\nUse this package to build CHIR tools.")
}

@Test
func extractHomepageWithLooseMarker(): Unit {
    let homepage = PackageHomepage.extractHomepageMarkdown("""
# Navigation

<!-- - homepage - -->

Custom package homepage.
""")

    @Expect(homepage, "Custom package homepage.")
}

@Test
func emptyHomepageWithoutMarker(): Unit {
    let homepage = PackageHomepage.extractHomepageMarkdown("""
# Navigation

- [API](index.md)
""")

    @Expect(homepage, "")
}

@Test
func projectPrefixedPackageLooksUnderSourceTail(): Unit {
    let candidates = PackageHomepage.candidateFilesForTesting("dochir_example.chir", "dochir_example", "src")

    @Expect(candidates.size, 2)
    @Expect(toSlash(candidates[0]), "src/dochir_example/chir/markit.md")
    @Expect(toSlash(candidates[1]), "src/chir/markit.md")
}

@Test
func languageSpecificHomepageFilesArePreferred(): Unit {
    let candidates = PackageHomepage.candidateFilesForTesting(
        "dochir_example.chir",
        "dochir_example",
        "src",
        language: "zh-cn"
    )

    @Expect(candidates.size, 6)
    @Expect(toSlash(candidates[0]), "src/dochir_example/chir/markit.zh-cn.md")
    @Expect(toSlash(candidates[1]), "src/dochir_example/chir/markit.zh.md")
    @Expect(toSlash(candidates[2]), "src/dochir_example/chir/markit.md")
    @Expect(toSlash(candidates[3]), "src/chir/markit.zh-cn.md")
    @Expect(toSlash(candidates[4]), "src/chir/markit.zh.md")
    @Expect(toSlash(candidates[5]), "src/chir/markit.md")
}

@Test
func rootPackageLooksForSourceRootHomepage(): Unit {
    let candidates = PackageHomepage.candidateFilesForTesting("dochir_example", "dochir_example", "src")

    @Expect(candidates.size, 2)
    @Expect(toSlash(candidates[0]), "src/dochir_example/markit.md")
    @Expect(toSlash(candidates[1]), "src/markit.md")
}

@Test
func nonProjectPackageFallsBackToTailPath(): Unit {
    let candidates = PackageHomepage.candidateFilesForTesting("vendor.sample.net", "demo", "source")

    @Expect(candidates.size, 2)
    @Expect(toSlash(candidates[0]), "source/vendor/sample/net/markit.md")
    @Expect(toSlash(candidates[1]), "source/sample/net/markit.md")
}

func toSlash(path: String): String {
    return path.replace("\\", "/")
}
