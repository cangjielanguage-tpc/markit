package commandline_cli_app_demo

import commandline.interfaces.{CLI, Command}
import commandline.macros.{CLIApp, Cmd, Opt, Plain}
import commandline.terminal.progressLogger

@CLIApp[name: "demo", version: "1.0.0", description: "commandline CLI app demo"]
class DemoApp {}

@Cmd[command: ["hello"], description: "Print a greeting"]
class HelloCommand {
    @Opt[["--name", "-n"], help: "Name to greet", required: true]
    public var name: ?String = None

    public func execute(): Int {
        @Plain("Hello, ${name.getOrThrow()}!")
        return 0
    }
}

main(args: Array<String>): Int {
    return DemoApp(args).use(HelloCommand()).execute()
}
