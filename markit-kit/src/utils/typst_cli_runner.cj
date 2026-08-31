package markit_kit.utils

import std.collection.ArrayList
import std.fs.{Path, exists}
import std.process.executeWithOutput

/**
 * Typst 命令行运行器。
 *
 * PDF 输出依赖系统中可用的 `typst` CLI，而不是 Node.js wrapper。
 */
public class TypstCliRunner {
    public static func isAvailable(): Bool {
        return version().isSome()
    }

    public static func version(): ?String {
        let (exitCode, stdout, stderr) = runTypst(["--version"])
        if (exitCode != 0) {
            return None
        }

        let stdoutText = String.fromUtf8(stdout).trimAscii()
        if (!stdoutText.isEmpty()) {
            return Some(stdoutText)
        }

        let stderrText = String.fromUtf8(stderr).trimAscii()
        if (!stderrText.isEmpty()) {
            return Some(stderrText)
        }

        return Some("typst")
    }

    public static func ensureAvailable(): Bool {
        match (version()) {
            case Some(value) =>
                KitHooks.plain("Typst CLI detected: ${value}")
                return true
            case None =>
                KitHooks.err("PDF output requires the Typst CLI, but `typst --version` failed.")
                KitHooks.plain("   Install Typst and make sure `typst` is available in PATH.")
                KitHooks.plain("   Then rerun markit-cli with format: \"pdf\".")
                return false
        }
    }

    public static func compileToPdf(typPath: String, pdfPath: String): Bool {
        let projectRoot = inferProjectRoot(typPath)
        let args = ArrayList<String>()
        args.add("compile")
        args.add("--root")
        args.add(projectRoot)
        let fontPath = Path(projectRoot).join("assets").join("fonts").normalize()
        if (exists(fontPath)) {
            args.add("--font-path")
            args.add(fontPath.toString())
        }
        args.add(typPath)
        args.add(pdfPath)
        let (exitCode, stdout, stderr) = runTypst(args.toArray())

        if (stdout.size > 0) {
            let output = String.fromUtf8(stdout)
            if (!output.trimAscii().isEmpty()) {
                KitHooks.write(output)
            }
        }

        if (exitCode != 0) {
            KitHooks.err("Typst PDF compilation failed.")
            if (stderr.size > 0) {
                let errorOutput = String.fromUtf8(stderr)
                if (!errorOutput.trimAscii().isEmpty()) {
                    KitHooks.write(errorOutput)
                }
            }
            return false
        }

        return true
    }

    private static func runTypst(args: Array<String>): (Int64, Array<Byte>, Array<Byte>) {
        try {
            if (PlatformUtils.isWindows()) {
                let cmdArgs = ArrayList<String>()
                cmdArgs.add("/c")
                cmdArgs.add("typst")
                for (arg in args) {
                    cmdArgs.add(arg)
                }
                return executeWithOutput("cmd.exe", cmdArgs.toArray())
            }

            return executeWithOutput("typst", args)
        } catch (e: Exception) {
            return (-1, [], e.message.toArray())
        }
    }

    private static func inferProjectRoot(typPath: String): String {
        let typFile = Path(typPath).normalize()
        let typDir = typFile.parent
        if (!typDir.isEmpty()) {
            let parent = typDir.parent
            if (!parent.isEmpty()) {
                return parent.normalize().toString()
            }
            return typDir.normalize().toString()
        }
        return "."
    }
}
