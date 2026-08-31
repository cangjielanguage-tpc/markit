import std.process.{Process, execute}
import std.fs.{Path, exists, remove, Directory, copy}
import std.env.getVariable

/**
 * 检查是否为 Windows 系统
 */
func isWindows(): Bool {
    // 通过环境变量检测操作系统
    if (let Some(os) <- getVariable("OS")) {
        let osLower = os.toAsciiLower()
        if (osLower.contains("windows")) {
            return true
        }
    }
    return false
}

/**
 * 构建前钩子：在 cjpm build 之前执行
 * 负责构建 ts-render 项目并复制资源文件
 */
func stagePreBuild(): Int64 {
    // 检查ts-render目录是否存在
    let tsRenderPath = Path("ts-render")
    if (!exists(tsRenderPath)) {
        println("[ERROR] ts-render directory not found")
        return 1
    }
    
    // 1. 检查 node_modules 是否存在，不存在才执行 npm install
    let nodeModulesPath = tsRenderPath.join("node_modules")
    if (!exists(nodeModulesPath)) {
        println("[INFO] Installing npm dependencies...")
        let installResult = if (isWindows()) {
            execute("cmd.exe", ["/c", "npm", "install"], workingDirectory: Some(tsRenderPath))
        } else {
            execute("npm", ["install"], workingDirectory: Some(tsRenderPath))
        }
        if (installResult != 0) {
            println("[ERROR] npm install failed, exit code: ${installResult}")
            return installResult
        }
    } else {
        println("[OK] npm dependencies already installed, skipping npm install")
    }
    
    // 2. 执行构建
    println("[INFO] Building TypeScript...")
    let buildResult = if (isWindows()) {
        execute("cmd.exe", ["/c", "npm", "run", "build:prod"], workingDirectory: Some(tsRenderPath))
    } else {
        execute("npm", ["run", "build:prod"], workingDirectory: Some(tsRenderPath))
    }
    if (buildResult != 0) {
        println("[ERROR] TypeScript build failed, exit code: ${buildResult}")
        return buildResult
    }

    // 3. 同步 codehl 内置 grammar/theme，供打包后的 markit-cli 在运行时读取
    let codehlAssetResult = copyBundledCodehlAssets()
    if (codehlAssetResult != 0) {
        return codehlAssetResult
    }
    
    // 4. 验证构建产物
    let assetsPath = Path("assets")
    let jsPath = assetsPath.join("js")
    
    if (!exists(jsPath.join("markit.bundle.js"))) {
        println("[ERROR] markit.bundle.js not found")
        return 1
    }
    
    // 验证 mathtex 复用的 KaTeX CSS 资源
    let katexCssPath = assetsPath.join("css").join("katex.min.css")
    if (!exists(katexCssPath)) {
        println("[WARN] KaTeX CSS not found (mathtex HTML styling may be incomplete)")
    }
    
    return 0
}

/**
 * 构建后钩子：在 cjpm build 之后执行
 */
func stagePostBuild(): Int64 {
    println("[OK] markit-kit build completed")
    return 0
}

func copyBundledCodehlAssets(): Int64 {
    let sourceRoot = Path("..").join("codehl").join("assets").normalize()
    let targetRoot = Path("assets").join("codehl").normalize()
    let grammarSource = sourceRoot.join("grammars")
    let themeSource = sourceRoot.join("themes")

    if (!exists(grammarSource)) {
        println("[ERROR] codehl grammars not found: ${grammarSource.toString()}")
        return 1
    }
    if (!exists(themeSource)) {
        println("[ERROR] codehl themes not found: ${themeSource.toString()}")
        return 1
    }

    removeIfExistsQuiet(targetRoot, true)
    try {
        Directory.create(targetRoot.toString(), recursive: true)
        let grammarCount = copyDirectoryRecursively(grammarSource, targetRoot.join("grammars"))
        let themeCount = copyDirectoryRecursively(themeSource, targetRoot.join("themes"))
        println("[OK] Copied codehl assets (${grammarCount} grammars/resources, ${themeCount} themes)")
        return 0
    } catch (e: Exception) {
        println("[ERROR] Failed to copy codehl assets: ${e.message}")
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

/**
 * 清理前钩子：在 cjpm clean 之前执行
 */
func stagePreClean(): Int64 {
    let tsRenderPath = Path("ts-render")
    if (exists(tsRenderPath)) {
        removeIfExistsQuiet(tsRenderPath.join("dist"), true)
    }
    
    return 0
}

func removeIfExistsQuiet(path: Path, recursive: Bool): Unit {
    try {
        if (exists(path)) {
            remove(path, recursive: recursive)
        }
    } catch (_) {
        println("[WARN] failed to remove ${path.toString()}")
    }
}

main(): Int64 {
    match (Process.current.arguments[0]) {
        case "pre-build" => stagePreBuild()
        case "post-build" => stagePostBuild()
        case "pre-clean" => stagePreClean()
        case _ => 0
    }
}
