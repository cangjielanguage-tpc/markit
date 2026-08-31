package markit_cli.commands

import std.env.{getCommand, getCommandLine, getVariable, getWorkingDirectory}
import std.fs.{Path, exists}

public class RuntimePaths {
    public static func assetsRoot(): String {
        return executableDirectory().join("assets").normalize().toString()
    }

    private static func executableDirectory(): Path {
        let command = executableCommand()
        if (command.isEmpty()) {
            return getWorkingDirectory()
        }

        let commandPath = Path(command)
        if (commandPath.isAbsolute()) {
            return commandPath.parent
        }

        if (containsPathSeparator(command)) {
            try {
                return getWorkingDirectory().join(command).normalize().parent
            } catch (_) {
                return commandPath.parent
            }
        }

        let pathCommand = resolveCommandFromPath(command)
        if (!pathCommand.isEmpty()) {
            return pathCommand.parent
        }

        return commandPath.parent
    }

    private static func executableCommand(): String {
        try {
            let commandLine = getCommandLine()
            if (commandLine.size > 0 && !commandLine[0].isEmpty()) {
                return commandLine[0]
            }
        } catch (_) {
            // Fall through to getCommand().
        }

        try {
            return getCommand()
        } catch (_) {
            return ""
        }
    }

    private static func containsPathSeparator(path: String): Bool {
        return path.contains("/") || path.contains("\\")
    }

    private static func resolveCommandFromPath(command: String): Path {
        if (let Some(pathValue) <- getVariable("PATH")) {
            let separator = if (isWindows()) { ";" } else { ":" }
            for (directory in pathValue.split(separator)) {
                if (directory.isEmpty()) {
                    continue
                }

                let candidate = Path(directory).join(command).normalize()
                if (exists(candidate)) {
                    return candidate
                }

                if (isWindows() && !command.toAsciiLower().endsWith(".exe")) {
                    let exeCandidate = Path(directory).join(command + ".exe").normalize()
                    if (exists(exeCandidate)) {
                        return exeCandidate
                    }
                }
            }
        }

        return Path("")
    }

    private static func isWindows(): Bool {
        if (let Some(os) <- getVariable("OS")) {
            return os.toAsciiLower().contains("windows")
        }
        return false
    }
}
