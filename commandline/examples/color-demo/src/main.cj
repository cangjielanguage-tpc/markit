package commandline_color_demo

import commandline.macros.{Background, Color, Err, Info, NewLine, Plain, Styled, Success, Verbose, Warn}
import commandline.terminal.{AnsiColor, ColorUtil, progressLogger}

main(): Int {
    @Plain("Foreground Palette")
    @Plain("  " + @Color("black", AnsiColor.Black) + " | " + @Color("red", AnsiColor.Red) + " | " + @Color("green", AnsiColor.Green) + " | " + @Color("yellow", AnsiColor.Yellow))
    @Plain("  " + @Color("blue", AnsiColor.Blue) + " | " + @Color("magenta", AnsiColor.Magenta) + " | " + @Color("cyan", AnsiColor.Cyan) + " | " + @Color("white", AnsiColor.White))
    @Plain("  " + @Color("gray", AnsiColor.Gray) + " | " + @Color("bright red", AnsiColor.BrightRed) + " | " + @Color("bright green", AnsiColor.BrightGreen) + " | " + @Color("bright cyan", AnsiColor.BrightCyan))

    @NewLine()
    @Plain("Background Tags")
    @Plain("  " + @Background(" info ", AnsiColor.BgBlue) + " " + @Background(" warn ", AnsiColor.BgYellow) + " " + @Background(" error ", AnsiColor.BgRed) + " " + @Background(" ok ", AnsiColor.BgGreen))
    @Plain("  " + @Styled(" badge ", foreground: AnsiColor.White, background: AnsiColor.BgMagenta, styles: [AnsiColor.Bold]) + " " + @Styled(" subtle ", foreground: AnsiColor.Black, background: AnsiColor.BgWhite))

    @NewLine()
    @Plain("Composed Styles")
    @Plain("  " + @Styled("PRIMARY", foreground: AnsiColor.White, background: AnsiColor.BgBlue, styles: [AnsiColor.Bold]))
    @Plain("  " + @Styled("SECONDARY", foreground: AnsiColor.BrightBlack, styles: [AnsiColor.Dim]))
    @Plain("  " + @Styled("DANGER", foreground: AnsiColor.White, background: AnsiColor.BgRed, styles: [AnsiColor.Bold]))
    @Plain("  " + @Styled("HIGHLIGHT", foreground: AnsiColor.BrightYellow, background: AnsiColor.BgBlack, styles: [AnsiColor.Bold]))

    @NewLine()
    @Plain("Styled Log Macros")
    @Info("Server: " + @Color("http://127.0.0.1:8080", AnsiColor.Cyan))
    @Info("Serving: " + @Styled("/docs -> /site", foreground: AnsiColor.White, background: AnsiColor.BgBlue))
    @Warn("Cache policy: " + @Background(" stale ", AnsiColor.BgYellow) + " " + @Color("revalidate on demand", AnsiColor.Yellow))
    @Err("Build status: " + @Styled(" failed ", foreground: AnsiColor.White, background: AnsiColor.BgRed, styles: [AnsiColor.Bold]) + " missing asset manifest")
    @Verbose("Theme preview: " + @Styled("dim diagnostic line", foreground: AnsiColor.Gray, styles: [AnsiColor.Dim]))

    @NewLine()
    @Plain("Inline Composition")
    let banner = @Styled(" commandline ", foreground: AnsiColor.White, background: AnsiColor.BgCyan, styles: [AnsiColor.Bold])
    let accent = @Color("macro-first terminal output", AnsiColor.BrightMagenta)
    @Plain("  ${banner} makes ${accent} easier to read")

    @Success("Colors rendered")
    return 0
}
