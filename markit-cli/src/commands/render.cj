package markit_cli.commands

import commandline.interfaces.{Command, CLI}
import commandline.macros.{Cmd, Err, Opt}
import commandline.terminal.progressLogger
import markit_kit.builders.BuildCoordinator
import markit_kit.utils.{ConfigPathParser, Optional, printBanner, CliUtils}
import std.fs.{Path, exists}
import std.collection.ArrayList

@Cmd[command: ["render"], description: "Render Markdown files/folders to website/PDF"]
public class RenderCommand {
    @Opt[["--input", "-i"], help: "Input file or directory path", required: true]
    public var input: ?String = None

    @Opt[["--output", "-o"], help: "Output directory path (default: ./dist)"]
    public var output: ?String = "./dist"

    @Opt[["--config", "-c"], help: "Path to markit.json configuration file(s), comma-separated for multi-language build"]
    public var config: ?String = None

    @Opt[["--jobs", "-j"], help: "Number of parallel rendering jobs (default: 1, use 0 for auto-detect CPU cores)"]
    public var jobs: ?String = Some("1")

    public func execute(): Int {
        // 打印横幅
        printBanner()
        
        // 获取输入路径
        let inputPath = !input
        
        // 验证输入路径
        if (!exists(Path(inputPath))) {
            @Err("Input path '${inputPath}' does not exist")
            return 1
        }
        
        let outputPath = output ?? "./dist"
        
        // 解析配置文件路径（支持逗号分隔的多个路径）
        let configPaths = if (let Some(path) <- config) {
            ConfigPathParser.parseConfigPaths(path)
        } else {
            ArrayList<String>().toArray()
        }
        
        // 解析并发数
        let parallelJobs = CliUtils.parseJobs(jobs ?? "1")
        
        // 使用 BuildCoordinator 执行构建
        return BuildCoordinator.build(
            configPaths,
            inputPath,
            outputPath,
            RuntimePaths.assetsRoot(),
            devMode: false,
            parallelJobs: parallelJobs
        )
    }
}
