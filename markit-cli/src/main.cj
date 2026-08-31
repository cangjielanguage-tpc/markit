package markit_cli

import commandline.interfaces.{Command, CLI}
import commandline.macros.CLIApp
import markit_cli.commands.{HelpCommand, VersionCommand, RenderCommand, ServeCommand}
import markit_kit.utils.KitHooks

@CLIApp[
    name: "markit",
    version: "1.0.0",
    description: "A lightweight and flexible Markdown rendering CLI tool that supports converting Markdown files/folders to website/PDF formats, and provides HTTP preview service with optional file watching and hot reloading."
]
class MarkitApp {}

main(args: Array<String>): Int {
    KitHooks.install(CommandlineKitHookSink())
    return MarkitApp(args)
        .use(HelpCommand(), VersionCommand(), RenderCommand(), ServeCommand())
        .execute()
}
