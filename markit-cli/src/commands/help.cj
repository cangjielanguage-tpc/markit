package markit_cli.commands

import commandline.interfaces.{Command, CLI}
import commandline.macros.{Cmd, Opt, Plain}
import commandline.terminal.progressLogger

@Cmd[command: ["help", "h", "--help", "-h"], description: "Show help information for markit or specific command"]
public class HelpCommand {
    @Opt[["--command", "-c"], help: "Show help for specific command"]
    public var command: ?String = None

    public func execute(): Int {
        @Plain(if (let Some(cmd) <- command) { cli.getHelp(cmd) } else { cli.getHelp() })
        return 0
    }
}
