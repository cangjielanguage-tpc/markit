package dochir

import dochir.docgen.DocMarkdownEmitter
import dochir.model.DocModelStore
import markit_kit.builders.BuildCoordinator
import std.collection.ArrayList
import std.env.getCommandLine
import std.fs.{Directory, File, Path, exists, remove}

public class DocChirConfig {
    public let projectName: String
    public let outputRoot: String
    public let modelDir: String
    public let formats: Array<String>
    public let defaultLang: String
    public let languages: Array<String>
    public let sourceRoot: String
    public let sourceRepository: String
    public let sourceBranch: String
    public let assetRoot: String
    public let parallelJobs: Int64

    public init(
        projectName!: String = "API Reference",
        outputRoot!: String = "dochir-output",
        modelDir!: String = DocModelStore.defaultModelDir(),
        formats!: Array<String> = ["markdown"],
        defaultLang!: String = "en",
        languages!: Array<String> = ["en"],
        sourceRoot!: String = "src",
        sourceRepository!: String = "",
        sourceBranch!: String = "",
        assetRoot!: String = "",
        parallelJobs!: Int64 = 1
    ) {
        this.projectName = projectName
        this.outputRoot = outputRoot
        this.modelDir = modelDir
        this.formats = formats
        this.defaultLang = normalizeLanguage(defaultLang)
        this.languages = normalizeLanguages(languages)
        this.sourceRoot = sourceRoot
        this.sourceRepository = sourceRepository
        this.sourceBranch = sourceBranch
        this.assetRoot = assetRoot
        this.parallelJobs = parallelJobs
    }
}

public func dochirBuild(config: DocChirConfig): Int64 {
    let stage = currentStage()

    match (stage) {
        case "pre-build" =>
            DocModelStore.clean(config.modelDir)
            DocModelStore.writePluginConfig(config.modelDir, defaultLang: config.defaultLang, languages: config.languages)
            return 0
        case "post-build" =>
            return render(config)
        case _ =>
            return 0
    }
}

private func currentStage(): String {
    for (arg in getCommandLine()) {
        if (arg == "pre-build" || arg == "post-build" || arg == "pre-clean") {
            return arg
        }
    }
    return ""
}

private func render(config: DocChirConfig): Int64 {
    cleanOutputRoot(config.outputRoot)
    let markdownRoot = Path(config.outputRoot).join("markdown").normalize().toString()
    emitMarkdown(config, markdownRoot)

    if (hasFormat(config.formats, "website")) {
        if (config.assetRoot.isEmpty()) {
            return 1
        }
        let result = renderWithMarkitKit(config, "website", markdownRoot, Path(config.outputRoot).join("site").normalize().toString())
        if (result != 0) {
            return 1
        }
    }

    return 0
}

private func cleanOutputRoot(outputRoot: String): Unit {
    let path = Path(outputRoot)
    try {
        if (exists(path)) {
            remove(path, recursive: true)
        }
    } catch (e: Exception) {
        ()
    }
}

private func emitMarkdown(config: DocChirConfig, markdownRoot: String): Unit {
    if (config.languages.size == 1) {
        let language = config.languages[0]
        let project = DocModelStore.readProject(
            DocModelStore.languageModelDir(config.modelDir, language),
            config.projectName
        )
        DocMarkdownEmitter.emit(
            project,
            markdownRoot,
            sourceRoot: config.sourceRoot,
            sourceRepository: config.sourceRepository,
            sourceBranch: config.sourceBranch,
            language: language
        )
        return
    }

    for (language in config.languages) {
        let project = DocModelStore.readProject(
            DocModelStore.languageModelDir(config.modelDir, language),
            config.projectName
        )
        DocMarkdownEmitter.emit(
            project,
            Path(markdownRoot).join(languageRoutePrefix(language)).normalize().toString(),
            sourceRoot: config.sourceRoot,
            sourceRepository: config.sourceRepository,
            sourceBranch: config.sourceBranch,
            language: language
        )
    }
}

private func renderWithMarkitKit(config: DocChirConfig, format: String, inputRoot: String, outputRoot: String): Int {
    let configPaths = writeMarkitConfigs(config, format, inputRoot)
    return BuildCoordinator.build(
        configPaths,
        inputRoot,
        outputRoot,
        config.assetRoot,
        devMode: false,
        parallelJobs: config.parallelJobs
    )
}

private func writeMarkitConfigs(config: DocChirConfig, format: String, inputRoot: String): Array<String> {
    if (config.languages.size == 1) {
        return [writeMarkitConfig(config, format, inputRoot, config.languages[0], None)]
    }

    let paths = ArrayList<String>()
    for (language in websiteLanguageOrder(config)) {
        paths.add(writeMarkitConfig(
            config,
            format,
            inputRoot,
            language,
            Some(languageRoutePrefix(language))
        ))
    }
    return paths.toArray()
}

private func writeMarkitConfig(
    config: DocChirConfig,
    format: String,
    inputRoot: String,
    language: String,
    routePrefix: ?String
): String {
    let configName = match (routePrefix) {
        case Some(prefix) => "markit." + prefix + ".json"
        case None => "markit.json"
    }
    let configPath = Path(inputRoot).join(configName).normalize()
    if (!exists(Path(inputRoot))) {
        Directory.create(inputRoot, recursive: true)
    }
    let routePrefixLine = match (routePrefix) {
        case Some(prefix) => "    \"route_prefix\": " + jsonString(prefix) + ",\n"
        case None => ""
    }
    let content = """
{
  "title": ${jsonString(apiReferenceTitle(config.projectName, language))},
  "theme": "arctic",
  "format": ${jsonString(format)},
  "toc": true,
  "i18n": {
    "default": ${jsonString(language)},
    "target": ${jsonString(language)},
${routePrefixLine}    "home": ${jsonString(homeText(language))},
    "documentation": ${jsonString(documentationText(language))}
  },
  "summary": {
    "file": "markit.md",
    "showDrafts": true
  },
  "codeBlock": {
    "group": false,
    "enabled": true
  },
  "heading": {
    "closable": false,
    "number": {
      "enabled": false,
      "resetFor": "directory",
      "startFrom": [1, 1, 1, 1, 1, 1]
    }
  }
}
"""
    File.writeTo(configPath, content.toArray())
    return configPath.toString()
}

private func websiteLanguageOrder(config: DocChirConfig): Array<String> {
    let result = ArrayList<String>()
    let defaultLang = normalizeLanguage(config.defaultLang)
    if (arrayContains(config.languages, defaultLang)) {
        result.add(defaultLang)
    }
    for (language in config.languages) {
        if (!result.contains(language)) {
            result.add(language)
        }
    }
    return result.toArray()
}

private func arrayContains(values: Array<String>, target: String): Bool {
    for (value in values) {
        if (value == target) {
            return true
        }
    }
    return false
}

private func normalizeLanguages(languages: Array<String>): Array<String> {
    let result = ArrayList<String>()
    for (language in languages) {
        let normalized = normalizeLanguage(language)
        if (!normalized.isEmpty() && !result.contains(normalized)) {
            result.add(normalized)
        }
    }
    if (result.isEmpty()) {
        result.add("en")
    }
    return result.toArray()
}

private func normalizeLanguage(language: String): String {
    let normalized = language.trimAscii().toAsciiLower().replace("_", "-")
    if (normalized.isEmpty()) {
        return "en"
    }
    return normalized
}

private func languageRoutePrefix(language: String): String {
    let normalized = normalizeLanguage(language).replace("\\", "-").replace("/", "-")
    if (normalized.isEmpty()) {
        return "en"
    }
    return normalized
}

private func homeText(language: String): String {
    if (language.startsWith("zh")) {
        return "首页"
    }
    return "Home"
}

private func documentationText(language: String): String {
    if (language.startsWith("zh")) {
        return "文档"
    }
    return "Documentation"
}

private func apiReferenceTitle(projectName: String, language: String): String {
    if (language.startsWith("zh")) {
        return projectName + " api文档"
    }
    return projectName + " API Reference"
}

private func hasFormat(formats: Array<String>, value: String): Bool {
    for (format in formats) {
        if (format.toAsciiLower() == value) {
            return true
        }
    }
    return false
}

private func jsonString(value: String): String {
    var escaped = value.replace("\\", "\\\\")
    escaped = escaped.replace("\"", "\\\"")
    escaped = escaped.replace("\r", "\\r")
    escaped = escaped.replace("\n", "\\n")
    escaped = escaped.replace("\t", "\\t")
    return "\"" + escaped + "\""
}
