package markit_cli.commands

import commandline.interfaces.{Command, CLI}
import commandline.macros.{Cmd, Plain}
import commandline.terminal.progressLogger

@Cmd[command: ["version", "v", "--version", "-v"], description: "Show version"]
public class VersionCommand {
    public func execute(): Int {
        @Plain(" 🧵 ${cli.name} v${cli.version}\n\n ${cli.description} ")
        return 0
    }
}
