package commandline_output_demo

import commandline.macros.{Err, Info, NewLine, Plain, Success, Verbose, Warn, Write}
import commandline.terminal.{AnsiColor, progressLogger}

main(): Int {
    @Plain("plain line")
    @Info("info line")
    @Verbose("verbose line")
    @Warn("warning line")
    @Err("error line")
    @NewLine()
    @Write("write without newline -> ")
    @Plain("continued")
    @Success("output demo completed")
    return 0
}
