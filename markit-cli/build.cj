import std.process.Process
import std.fs.{Path, Directory, exists, remove, copy}

func stagePostBuild(): Int64 {
    let source = Path("..").join("markit-kit").join("assets").normalize()
    let target = Path("target").join("release").join("bin").join("assets").normalize()

    if (!exists(source)) {
        println("[ERROR] markit-kit assets not found: ${source.toString()}")
        return 1
    }

    try {
        if (exists(target)) {
            remove(target, recursive: true)
        }
        let count = copyDirectoryRecursively(source, target)
        println("[OK] Copied ${count} assets to ${target.toString()}")
        return 0
    } catch (e: Exception) {
        println("[ERROR] Failed to copy assets to executable directory: ${e.message}")
        return 1
    }
}

func copyDirectoryRecursively(sourceDir: Path, targetDir: Path): Int64 {
    var count: Int64 = 0
    if (!exists(targetDir)) {
        Directory.create(targetDir.toString(), recursive: true)
    }

    for (entry in Directory.readFrom(sourceDir)) {
        let sourcePath = entry.path
        let targetPath = targetDir.join(entry.path.fileName).normalize()
        if (entry.isDirectory()) {
            count += copyDirectoryRecursively(sourcePath, targetPath)
        } else {
            copy(sourcePath.toString(), to: targetPath.toString(), overwrite: true)
            count += 1
        }
    }
    return count
}

main(): Int64 {
    match (Process.current.arguments[0]) {
        case "post-build" => stagePostBuild()
        case _ => 0
    }
}
