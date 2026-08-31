package markit_cli.commands

import commandline.interfaces.{Command, CLI}
import commandline.macros.{Cmd, Err, Info, NewLine, Opt, Progress, StopProgress, Success}
import commandline.terminal.progressLogger
import live_server.LiveServer
import markit_kit.builders.BuildCoordinator
import markit_kit.utils.{ConfigPathParser, Optional, printBanner, CliUtils}
import std.collection.{ArrayList, HashSet}
import std.fs.{Path, exists}

@Cmd[command: ["serve"], description: "Start HTTP server for Markdown preview with auto-rendering and hot reload"]
public class ServeCommand {
    @Opt[["--input", "-i"], help: "Input file or directory path (required)", required: true]
    public var input: ?String = None

    @Opt[["--output", "-o"], help: "Output directory path (default: ./dist)"]
    public var output: ?String = "./dist"

    @Opt[["--config", "-c"], help: "Path to markit.json configuration file(s), comma-separated for multi-language build"]
    public var config: ?String = None

    @Opt[["--host", "-H"], help: "IP address to bind HTTP server (default: 127.0.0.1, use 0.0.0.0 for LAN access)"]
    public var host: ?String = Some("127.0.0.1")

    @Opt[["--port", "-p"], help: "Port for HTTP server (default: 8080)"]
    public var port: ?String = Some("8080")

    @Opt[["--watch", "-w"], help: "Enable file watching (auto-re-render on changes, default: enabled)"]
    public var watch: ?String = Some("true")

    @Opt[["--jobs", "-j"], help: "Number of parallel rendering jobs (default: 1, use 0 for auto-detect CPU cores)"]
    public var jobs: ?String = Some("1")

    public func execute(): Int {
        // 打印横幅
        printBanner()

        let inputPath = !input
        let outputPath = output ?? "./dist"

        // 验证输入路径
        if (!exists(Path(inputPath))) {
            @Err("Input directory '${inputPath}' does not exist")
            return 1
        }

        // 解析服务器参数
        let hostStr = host ?? "127.0.0.1"
        let portInt = CliUtils.parsePort(port ?? "8080")
        let enableWatch = (watch ?? "true") == "true"

        // 解析配置文件路径（支持逗号分隔的多个路径）
        let configPaths = if (let Some(path) <- config) {
            ConfigPathParser.parseConfigPaths(path)
        } else {
            ArrayList<String>().toArray()
        }

        // 解析并发数
        let parallelJobs = CliUtils.parseJobs(jobs ?? "1")
        let assetRoot = RuntimePaths.assetsRoot()

        // 执行初始构建
        let buildResult = BuildCoordinator.build(configPaths, inputPath, outputPath, assetRoot, devMode: enableWatch,
            parallelJobs: parallelJobs)

        if (buildResult != 0) {
            @Err("Failed to render markdown files")
            return 1
        }

        // 启动服务器
        try {
            let loadedConfig = BuildCoordinator.loadConfig(configPaths, inputPath)
            // 获取 summary 文件名（用于文件监控）
            let summaryFile = match (loadedConfig) {
                case Some((cfg, _configPath)) =>
                    let (file, _) = cfg.getSummaryOptions()
                    file
                case None => "markit.md"
            }
            let loadedConfigPath = match (loadedConfig) {
                case Some((_cfg, configPath)) => configPath
                case None => ""
            }
            let watchConfigPaths = this.collectConfigWatchPaths(configPaths, loadedConfigPath)

            let server = LiveServer(outputPath, hostStr, portInt)
            if (enableWatch) {
                this.configureWatching(
                    server,
                    configPaths,
                    watchConfigPaths,
                    inputPath,
                    outputPath,
                    summaryFile,
                    assetRoot,
                    parallelJobs
                )
            }

            // 添加空行分隔
            @NewLine()
            @Info("Server: http://${hostStr}:${portInt}")
            @Info("Serving: ${inputPath} -> ${outputPath}")
            @Info("Press Ctrl+C to stop")
            @NewLine()

            server.start()
            return 0
        } catch (e: Exception) {
            @Err("Error: ${e.message}")
            return 1
        }
    }

    private func configureWatching(
        server: LiveServer,
        configPaths: Array<String>,
        watchConfigPaths: Array<String>,
        inputPath: String,
        outputPath: String,
        summaryFile: String,
        assetRoot: String,
        parallelJobs: Int64
    ): Unit {
        server.watch(inputPath) {
            changedFiles => this.handleWatchChanges(
                configPaths,
                watchConfigPaths,
                inputPath,
                outputPath,
                summaryFile,
                assetRoot,
                changedFiles,
                parallelJobs
            )
        }

        let watchedDirs = HashSet<String>()
        for (configPath in watchConfigPaths) {
            let parent = Path(configPath).parent
            let watchDir = if (parent.isEmpty()) {
                "."
            } else {
                parent.toString()
            }
            if (!exists(Path(watchDir)) || this.isPathUnder(watchDir, inputPath)) {
                continue
            }

            let normalizedWatchDir = this.normalizeForCompare(watchDir)
            if (watchedDirs.contains(normalizedWatchDir)) {
                continue
            }

            watchedDirs.add(normalizedWatchDir)
            server.watch(
                watchDir,
                {
                    changedFiles => this.handleWatchChanges(
                        configPaths,
                        watchConfigPaths,
                        inputPath,
                        outputPath,
                        summaryFile,
                        assetRoot,
                        changedFiles,
                        parallelJobs
                    )
                },
                recursive: false
            )
        }
    }

    private func handleWatchChanges(
        configPaths: Array<String>,
        watchConfigPaths: Array<String>,
        inputPath: String,
        outputPath: String,
        summaryFile: String,
        assetRoot: String,
        changedFiles: Array<String>,
        parallelJobs: Int64
    ): Unit {
        let markdownFiles = ArrayList<String>()
        let seenMarkdown = HashSet<String>()
        var requiresFullBuild = false

        for (file in changedFiles) {
            if (this.isConfigOrSummaryFile(file, watchConfigPaths, summaryFile)) {
                requiresFullBuild = true
                continue
            }

            if (this.isMarkdownFile(file)) {
                if (!exists(Path(file))) {
                    requiresFullBuild = true
                    continue
                }

                let normalizedFile = this.normalizeForCompare(file)
                if (!seenMarkdown.contains(normalizedFile)) {
                    seenMarkdown.add(normalizedFile)
                    markdownFiles.add(file)
                }
            }
        }

        if (!requiresFullBuild && markdownFiles.size == 0) {
            return
        }

        @StopProgress()
        let fullBuild = requiresFullBuild || markdownFiles.size > 1
        let renderResult = if (fullBuild) {
            @Progress("${changedFiles.size} file change(s), re-rendering...")
            BuildCoordinator.build(configPaths, inputPath, outputPath, assetRoot, devMode: true, parallelJobs: parallelJobs)
        } else {
            let file = markdownFiles[0]
            @Progress("File changed: ${file}, re-rendering...")
            BuildCoordinator.incrementalBuild(configPaths, inputPath, outputPath, assetRoot, true, file,
                parallelJobs: parallelJobs)
        }
        @StopProgress()

        if (renderResult == 0) {
            @Success("Preview updated")
        }
    }

    private func collectConfigWatchPaths(configPaths: Array<String>, loadedConfigPath: String): Array<String> {
        let paths = ArrayList<String>()
        let seen = HashSet<String>()
        for (configPath in configPaths) {
            this.addUniquePath(paths, seen, configPath)
        }
        this.addUniquePath(paths, seen, loadedConfigPath)
        return paths.toArray()
    }

    private func addUniquePath(paths: ArrayList<String>, seen: HashSet<String>, path: String): Unit {
        if (path.isEmpty()) {
            return
        }

        let normalizedPath = this.normalizeForCompare(path)
        if (!seen.contains(normalizedPath)) {
            seen.add(normalizedPath)
            paths.add(path)
        }
    }

    private func isConfigOrSummaryFile(file: String, configPaths: Array<String>, summaryFile: String): Bool {
        if (this.pathLooksSame(file, "markit.json")) {
            return true
        }

        for (configPath in configPaths) {
            if (this.pathLooksSame(file, configPath)) {
                return true
            }
        }

        return this.pathLooksSame(file, summaryFile)
    }

    private func isMarkdownFile(file: String): Bool {
        let lower = file.toAsciiLower()
        return lower.endsWith(".md") || lower.endsWith(".markdown")
    }

    private func isPathUnder(path: String, root: String): Bool {
        let normalizedPath = this.normalizeForCompare(path)
        let normalizedRoot = this.normalizeForCompare(root)
        return normalizedPath == normalizedRoot || normalizedPath.startsWith("${normalizedRoot}/")
    }

    private func pathLooksSame(candidate: String, expected: String): Bool {
        if (candidate.isEmpty() || expected.isEmpty()) {
            return false
        }

        let normalizedCandidate = this.normalizeForCompare(candidate)
        let normalizedExpected = this.normalizeForCompare(expected)
        return normalizedCandidate == normalizedExpected || normalizedCandidate.endsWith("/${normalizedExpected}") ||
            normalizedExpected.endsWith("/${normalizedCandidate}")
    }

    private func normalizeForCompare(path: String): String {
        if (path.isEmpty()) {
            return ""
        }
        return Path(path).normalize().toString().replace("\\", "/")
    }
}
