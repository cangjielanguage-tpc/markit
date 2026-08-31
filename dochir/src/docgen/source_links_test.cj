package dochir.docgen

@Test
func sourceLinkUsesProjectPackageTail(): Unit {
    let links = SourceLinkConfig("demo", "src", "https://github.com/org/repo.git", "main")

    @Expect(
        links.sourceUrl("demo.chir", "api.cj:42") ?? "",
        "https://github.com/org/repo/blob/main/src/chir/api.cj#L42"
    )
}

@Test
func sourceLinkUsesRootPackageSourceRoot(): Unit {
    let links = SourceLinkConfig("demo", "src", "https://github.com/org/repo", "release")

    @Expect(
        links.sourceUrl("demo", "main.cj:7") ?? "",
        "https://github.com/org/repo/blob/release/src/main.cj#L7"
    )
}

@Test
func sourceLinkKeepsExplicitRelativePath(): Unit {
    let links = SourceLinkConfig("demo", "src", "https://github.com/org/repo", "main")

    @Expect(
        links.sourceUrl("demo.chir", "generated/api.cj:9") ?? "",
        "https://github.com/org/repo/blob/main/src/generated/api.cj#L9"
    )
}

@Test
func sourceLinkRequiresRepositoryAndBranch(): Unit {
    let missingRepo = SourceLinkConfig("demo", "src", "", "main")
    let missingBranch = SourceLinkConfig("demo", "src", "https://github.com/org/repo", "")

    @Expect((missingRepo.sourceUrl("demo", "main.cj:1") ?? "").isEmpty())
    @Expect((missingBranch.sourceUrl("demo", "main.cj:1") ?? "").isEmpty())
}
