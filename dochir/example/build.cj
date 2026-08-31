import dochir.*

main() {
    dochirBuild(DocChirConfig(
        projectName: "dochir_example",
        outputRoot: "dochir-output",
        formats: ["markdown", "website"],
        defaultLang: "en",
        languages: ["en", "zh"],
        assetRoot: "../../markit-kit/assets"
    ))
}
