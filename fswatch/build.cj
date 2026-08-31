import std.env.getVariable
import std.fs.{Path, exists, Directory, remove}
import std.process.{Process, execute, executeWithOutput}

func isLinux(): Bool {
    try {
        let (exitCode, stdOut, _) = executeWithOutput("uname", ["-s"])
        if (exitCode == 0) {
            return String.fromUtf8(stdOut).trimAscii() == "Linux"
        }
    } catch (_: Exception) {
        // Fall through to environment-based detection.
    }

    if (let Some(ostype) <- getVariable("OSTYPE")) {
        return ostype.toAsciiLower().contains("linux")
    }
    if (let Some(platform) <- getVariable("PLATFORM")) {
        return platform.toAsciiLower().contains("linux")
    }
    return false
}

func isMacOS(): Bool {
    try {
        let (exitCode, stdOut, _) = executeWithOutput("uname", ["-s"])
        if (exitCode == 0) {
            return String.fromUtf8(stdOut).trimAscii() == "Darwin"
        }
    } catch (_: Exception) {
        // Fall through to environment-based detection.
    }

    if (let Some(ostype) <- getVariable("OSTYPE")) {
        return ostype.toAsciiLower().contains("darwin")
    }
    if (let Some(platform) <- getVariable("PLATFORM")) {
        let lower = platform.toAsciiLower()
        return lower.contains("darwin") || lower.contains("macos")
    }
    return false
}

func ensureDirectory(path: Path): Unit {
    if (!exists(path)) {
        Directory.create(path, recursive: true)
    }
}

func getMachineArchitecture(): String {
    try {
        let (exitCode, stdOut, _) = executeWithOutput("uname", ["-m"])
        if (exitCode == 0) {
            return String.fromUtf8(stdOut).trimAscii()
        }
    } catch (_: Exception) {
        // Fall through to environment-based detection.
    }

    if (let Some(arch) <- getVariable("MACHTYPE")) {
        let lower = arch.toAsciiLower()
        if (lower.contains("arm64") || lower.contains("aarch64")) {
            return "arm64"
        }
        if (lower.contains("x86_64")) {
            return "x86_64"
        }
    }
    return "x86_64"
}

func getMacOSLibraryDir(): Path {
    let archDir = if (getMachineArchitecture() == "arm64") {
        "darwin_aarch64"
    } else {
        "darwin_x86_64"
    }
    return Path("native").join("lib").join(archDir)
}

func getLinuxLibraryDir(): Path {
    let archDir = if (getMachineArchitecture() == "arm64") {
        "linux_aarch64"
    } else {
        "linux_x86_64"
    }
    return Path("native").join("lib").join(archDir)
}

func canExecute(command: String): Bool {
    try {
        let result = execute(command, ["--version"])
        return result == 0
    } catch (_: Exception) {
        return false
    }
}

func getCCompiler(): String {
    if (let Some(cc) <- getVariable("CC")) {
        if (!cc.trimAscii().isEmpty()) {
            return cc.trimAscii()
        }
    }

    if (canExecute("clang")) {
        return "clang"
    }
    if (canExecute("gcc")) {
        return "gcc"
    }
    if (canExecute("cc")) {
        return "cc"
    }
    return "clang"
}

func removeIfExists(path: Path): Unit {
    if (exists(path)) {
        remove(path)
    }
}

func cleanupLegacyMacOSArchives(): Unit {
    removeIfExists(Path("target").join("native").join("libfswatch_macos.a"))
    removeIfExists(Path("target").join("release").join("fswatch").join("libfswatch_macos.a"))
    removeIfExists(Path("target").join("debug").join("fswatch").join("libfswatch_macos.a"))
}

func cleanupLegacyLinuxArchives(): Unit {
    removeIfExists(Path("target").join("native").join("libfswatch_linux.a"))
    removeIfExists(Path("target").join("release").join("fswatch").join("libfswatch_linux.a"))
    removeIfExists(Path("target").join("debug").join("fswatch").join("libfswatch_linux.a"))
}

func prepareMacOSBridge(): Int64 {
    if (!isMacOS()) {
        return 0
    }

    cleanupLegacyMacOSArchives()

    let nativeDir = Path("native")
    let sourcePath = nativeDir.join("macos_fsevents_bridge.m")
    let buildNativeDir = Path("target").join("native")
    let objectPath = buildNativeDir.join("macos_fsevents_bridge.o")
    let archiveDir = getMacOSLibraryDir()
    let archivePath = archiveDir.join("libfswatch_macos.a")

    if (!exists(sourcePath)) {
        println("Missing native source: ${sourcePath}")
        return 1
    }

    ensureDirectory(buildNativeDir)
    ensureDirectory(archiveDir)

    let compiler = getCCompiler()
    let compileResult = execute(
        compiler,
        [
            "-c",
            sourcePath.toString(),
            "-fobjc-arc",
            "-fstack-protector-all",
            "-mmacosx-version-min=12.0",
            "-o",
            objectPath.toString()
        ]
    )
    if (compileResult != 0) {
        println("Failed to compile macOS FSEvents bridge with ${compiler}")
        return compileResult
    }

    let archiveResult = execute(
        "ar",
        ["rcs", archivePath.toString(), objectPath.toString()]
    )
    if (archiveResult != 0) {
        println("Failed to archive macOS FSEvents bridge")
        return archiveResult
    }

    return 0
}

func prepareLinuxBridge(): Int64 {
    if (!isLinux()) {
        return 0
    }

    cleanupLegacyLinuxArchives()

    let nativeDir = Path("native")
    let sourcePath = nativeDir.join("linux_inotify_bridge.c")
    let buildNativeDir = Path("target").join("native")
    let objectPath = buildNativeDir.join("linux_inotify_bridge.o")
    let archiveDir = getLinuxLibraryDir()
    let archivePath = archiveDir.join("libfswatch_linux.a")

    if (!exists(sourcePath)) {
        println("Missing native source: ${sourcePath}")
        return 1
    }

    ensureDirectory(buildNativeDir)
    ensureDirectory(archiveDir)

    let compiler = getCCompiler()
    let compileResult = execute(
        compiler,
        [
            "-c",
            sourcePath.toString(),
            "-fstack-protector-all",
            "-D_GNU_SOURCE",
            "-o",
            objectPath.toString()
        ]
    )
    if (compileResult != 0) {
        println("Failed to compile Linux inotify bridge with ${compiler}")
        return compileResult
    }

    let archiveResult = execute(
        "ar",
        ["rcs", archivePath.toString(), objectPath.toString()]
    )
    if (archiveResult != 0) {
        println("Failed to archive Linux inotify bridge")
        return archiveResult
    }

    return 0
}

func stagePreBuild(): Int64 {
    let macResult = prepareMacOSBridge()
    if (macResult != 0) {
        return macResult
    }
    return prepareLinuxBridge()
}

func stagePreTest(): Int64 {
    let macResult = prepareMacOSBridge()
    if (macResult != 0) {
        return macResult
    }
    return prepareLinuxBridge()
}

func stagePreClean(): Int64 {
    let buildNativeDir = Path("target").join("native")
    if (exists(buildNativeDir)) {
        remove(buildNativeDir, recursive: true)
    }
    return 0
}

main(): Int64 {
    let stage = if (Process.current.arguments.size > 1) {
        Process.current.arguments[1]
    } else if (Process.current.arguments.size > 0) {
        Process.current.arguments[0]
    } else {
        ""
    }
    match (stage) {
        case "pre-build" => stagePreBuild()
        case "pre-test" => stagePreTest()
        case "pre-clean" => stagePreClean()
        case _ => 0
    }
}
