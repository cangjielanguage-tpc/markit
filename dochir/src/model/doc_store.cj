package dochir.model

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists, remove}

public class DocPluginConfig {
    public let modelDir: String
    public let defaultLang: String
    public let languages: Array<String>

    public init(modelDir: String, defaultLang: String, languages: Array<String>) {
        this.modelDir = modelDir
        this.defaultLang = defaultLang
        this.languages = languages
    }
}

public class DocModelStore {
    public static func defaultModelDir(): String {
        return ".dochir/model"
    }

    public static func writePluginConfig(
        modelDir: String,
        defaultLang!: String = "en",
        languages!: Array<String> = ["en"]
    ): Unit {
        let file = pluginConfigFile()
        let parent = file.parent
        if (!parent.isEmpty() && !exists(parent)) {
            Directory.create(parent.toString(), recursive: true)
        }
        let normalizedLanguages = normalizeLanguages(languages)
        File.writeTo(
            file,
            (modelDir + "\n" + normalizeLanguage(defaultLang) + "\n" +
                String.join(normalizedLanguages, delimiter: ",") + "\n").toArray()
        )
    }

    public static func readPluginConfig(): DocPluginConfig {
        let file = pluginConfigFile()
        if (!exists(file)) {
            return DocPluginConfig(defaultModelDir(), "en", ["en"])
        }
        try {
            let content = String.fromUtf8(File.readFrom(file)).replace("\r\n", "\n").replace("\r", "\n")
            let lines = content.split("\n")
            let modelDir = configLine(lines, 0, defaultModelDir())
            let defaultLang = configLine(lines, 1, "en")
            let languages = configLanguages(configLine(lines, 2, ""))
            return DocPluginConfig(modelDir, defaultLang, languages)
        } catch (e: Exception) {
            return DocPluginConfig(defaultModelDir(), "en", ["en"])
        }
    }

    public static func configuredModelDir(): String {
        return readPluginConfig().modelDir
    }

    public static func languageModelDir(modelDir: String, language: String): String {
        return Path(modelDir).join(safeLanguageDir(language)).normalize().toString()
    }

    public static func clean(modelDir: String): Unit {
        let path = Path(modelDir)
        try {
            if (exists(path)) {
                remove(path, recursive: true)
            }
        } catch (e: Exception) {
            ()
        }
    }

    public static func writePackage(modelDir: String, pkg: DocPackage): Unit {
        let file = packageFile(modelDir, pkg.name)
        let parent = file.parent
        if (!parent.isEmpty() && !exists(parent)) {
            Directory.create(parent.toString(), recursive: true)
        }
        File.writeTo(file, DocCodec.encodePackage(pkg).toArray())
    }

    public static func readProject(modelDir: String, projectName: String): DocProject {
        let packages = ArrayList<DocPackage>()
        collectPackages(Path(modelDir), packages)
        return DocProject(projectName, sortedPackages(packages.toArray(), projectName))
    }

    private static func collectPackages(path: Path, packages: ArrayList<DocPackage>): Unit {
        if (!exists(path)) {
            return
        }

        try {
            for (entry in Directory.readFrom(path)) {
                if (entry.isDirectory()) {
                    collectPackages(entry.path, packages)
                } else if (entry.isRegular() && entry.name.endsWith(".dochir")) {
                    let content = String.fromUtf8(File.readFrom(entry.path))
                    if (let Some(pkg) <- DocCodec.decodePackage(content)) {
                        packages.add(pkg)
                    }
                }
            }
        } catch (e: Exception) {
            ()
        }
    }

    private static func packageFile(modelDir: String, packageName: String): Path {
        let packagePath = packageName.replace(".", "/") + ".dochir"
        return Path(modelDir).join(packagePath).normalize()
    }

    private static func pluginConfigFile(): Path {
        return Path(".dochir").join("plugin.conf").normalize()
    }

    private static func configLine(lines: Array<String>, index: Int64, fallback: String): String {
        if (index >= lines.size) {
            return fallback
        }
        let value = lines[index].trimAscii()
        if (value.isEmpty()) {
            return fallback
        }
        return value
    }

    private static func configLanguages(value: String): Array<String> {
        let out = ArrayList<String>()
        for (item in value.split(",")) {
            appendLanguage(out, item)
        }
        if (out.isEmpty()) {
            out.add("en")
        }
        return out.toArray()
    }

    private static func normalizeLanguages(languages: Array<String>): Array<String> {
        let out = ArrayList<String>()
        for (item in languages) {
            appendLanguage(out, item)
        }
        if (out.isEmpty()) {
            out.add("en")
        }
        return out.toArray()
    }

    private static func appendLanguage(out: ArrayList<String>, value: String): Unit {
        let language = normalizeLanguage(value)
        if (language.isEmpty() || out.contains(language)) {
            return
        }
        out.add(language)
    }

    private static func normalizeLanguage(value: String): String {
        let language = value.trimAscii().toAsciiLower().replace("_", "-")
        if (language.isEmpty()) {
            return "en"
        }
        return language
    }

    private static func safeLanguageDir(language: String): String {
        let normalized = normalizeLanguage(language).replace("\\", "-").replace("/", "-")
        if (normalized.isEmpty()) {
            return "en"
        }
        return normalized
    }

    private static func sortedPackages(packages: Array<DocPackage>, projectName: String): Array<DocPackage> {
        let result = ArrayList<DocPackage>()
        for (pkg in packages) {
            insertPackage(result, pkg, projectName)
        }
        return result.toArray()
    }

    private static func insertPackage(packages: ArrayList<DocPackage>, pkg: DocPackage, projectName: String): Unit {
        let key = packageSortKey(pkg.name, projectName)
        var index: Int64 = 0
        while (index < packages.size && packageSortKey(packages[index].name, projectName) < key) {
            index += 1
        }
        packages.add(pkg, at: index)
    }

    private static func packageSortKey(packageName: String, projectName: String): String {
        if (packageName == projectName) {
            return "0:" + packageName
        }
        if (!projectName.isEmpty() && packageName.startsWith(projectName + ".")) {
            return "1:" + packageName
        }
        return "2:" + packageName
    }
}
