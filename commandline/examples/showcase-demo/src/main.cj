package commandline_showcase_demo

import commandline.interfaces.{CLI, Command}
import commandline.macros.{Background, CLIApp, Cmd, Color, Confirm, Err, Info, InsertBefore, MultiSelectValues, NewLine, Opt, Plain, Progress, Prompt, RequireConfirm, SelectValue, Spinner, StopProgress, StopSpinner, Styled, Success, UpdateSpinner, Verbose, Warn}
import commandline.terminal.{AnsiColor, ColorUtil, interactiveForm, progressLogger}

@CLIApp[name: "showcase", version: "1.0.0", description: "commandline showcase CLI demo"]
class ShowcaseCliApp {}

@Cmd[command: ["hello"], description: "Print a greeting"]
class ShowcaseHelloCommand {
    @Opt[["--name", "-n"], help: "Name to greet", required: true]
    public var name: ?String = None

    public func execute(): Int {
        @Plain("Hello, ${name.getOrThrow()}!")
        return 0
    }
}

func runOutputDemo(): Unit {
    @Plain("Output Demo")
    @Info("info line")
    @Verbose("verbose line")
    @Warn("warning line")
    @Err("error line")
    @NewLine()
    @Plain("plain line")
    @Success("output demo completed")
}

func runColorDemo(): Unit {
    @Plain("Color Demo")
    @Plain("  " + @Color("cyan", AnsiColor.Cyan) + " " + @Color("green", AnsiColor.Green) + " " + @Color("red", AnsiColor.Red))
    @Plain("  " + @Background(" info ", AnsiColor.BgBlue) + " " + @Background(" warn ", AnsiColor.BgYellow) + " " + @Background(" err ", AnsiColor.BgRed))
    @Plain("  " + @Styled(" banner ", foreground: AnsiColor.White, background: AnsiColor.BgCyan, styles: [AnsiColor.Bold]))
    @Success("Colors rendered")
}

func runProgressDemo(): Unit {
    @Plain("Progress Demo")
    @Info("This section is split further in the Progress submenu.")
}

func runProgressColoredDemo(): Unit {
    let percentages = [20, 40, 60, 80, 100]
    let colors = [
        AnsiColor.BrightRed,
        AnsiColor.Yellow,
        AnsiColor.Cyan,
        AnsiColor.BrightBlue,
        AnsiColor.Green
    ]

    @Plain("Progress: colored bars with text")
    for (i in 0..percentages.size) {
        @Progress("Rendering", percentages[i], width: 20, color: colors[i])
        sleep(Duration.millisecond * 120)
    }
    @StopProgress(@Success("Render completed"))
}

func runProgressBarOnlyDemo(): Unit {
    let percentages = [20, 40, 60, 80, 100]

    @Plain("Progress: bar only")
    for (percent in percentages) {
        @Progress(percent, width: 20, color: AnsiColor.BrightMagenta)
        sleep(Duration.millisecond * 120)
    }
    @StopProgress(@Success("Bar-only progress completed"))
}

func runProgressLayeredDemo(): Unit {
    let layeredProgress = [
        (15, 40),
        (30, 55),
        (45, 70),
        (60, 85),
        (75, 100)
    ]

    @Plain("Progress: three-stage pipeline")
    for ((primary, secondary) in layeredProgress) {
        @Progress("Pipeline", primary, secondary, width: 24, color: AnsiColor.Cyan)
        sleep(Duration.millisecond * 120)
    }
    @StopProgress(@Success("Layered progress completed"))
}

func runProgressInsertBeforeDemo(): Unit {
    let layeredProgress = [
        (15, 40),
        (30, 55),
        (45, 70),
        (60, 85),
        (75, 100)
    ]

    @Plain("Progress: InsertBefore during active progress")
    for ((primary, secondary) in layeredProgress) {
        @Progress("Pipeline", primary, secondary, width: 24, color: AnsiColor.Cyan)
        sleep(Duration.millisecond * 120)
        if (primary == 45) {
            @InsertBefore(@Warn("One asset fell back to cached output"))
        }
    }
    @StopProgress(@Err("Pipeline finished with warnings"))
}

func runProgressAllDemo(): Unit {
    runProgressColoredDemo()
    @NewLine()
    runProgressBarOnlyDemo()
    @NewLine()
    runProgressLayeredDemo()
    @NewLine()
    runProgressInsertBeforeDemo()
}

func runSpinnerDemo(): Unit {
    @Plain("Spinner Demo")
    @Spinner("Packaging project...")
    sleep(Duration.millisecond * 150)
    @UpdateSpinner("Packaging assets...")
    sleep(Duration.millisecond * 150)
    @InsertBefore(@Warn("One asset fell back to cached output"))
    sleep(Duration.millisecond * 150)
    @StopSpinner(@Success("Package completed"))
}

func runInteractiveDemo(): Unit {
    @Plain("Interactive Demo")
    let projectName = @Prompt("Project name", defaultValue: Some("demo-app"))
    let accessToken = @Prompt("Access token", secret: true)
    let templateValue = @SelectValue("Template", ["basic", "docs", "website"], defaultIndex: Some(0))
    let featureValues = @MultiSelectValues(
        "Features",
        ["spinner", "color", "interactive", "password-prompt"],
        defaultIndices: [0, 1]
    )
    let shouldGenerate = @Confirm("Generate project?", defaultValue: Some(true))

    @Plain("project=${projectName}")
    @Plain("token.length=${accessToken.toRuneArray().size}")
    match (templateValue) {
        case Some(value) => @Plain("template=${value}")
        case None => @Plain("template=cancelled")
    }
    match (featureValues) {
        case Some(values) => @Plain("features=${values}")
        case None => @Plain("features=cancelled")
    }
    @Plain("confirm=${shouldGenerate}")

    if (shouldGenerate) {
        @RequireConfirm("Final confirmation", defaultValue: Some(true), abortMessage: "final confirmation declined")
        @Success("Project confirmed")
    } else {
        @Plain("Confirmation declined")
    }
}

func runCliAppDemo(): Unit {
    @Plain("CLI App Demo")
    @Plain("Help output:")
    _ = ShowcaseCliApp(["showcase", "--help"]).use(ShowcaseHelloCommand()).execute()
    @NewLine()
    @Plain("Command execution:")
    _ = ShowcaseCliApp(["showcase", "hello", "--name", "world"]).use(ShowcaseHelloCommand()).execute()
    @Success("CLI app demo completed")
}

func runCategory(category: String): Unit {
    @NewLine()
    match (category) {
        case "Output" => runOutputDemo()
        case "Color" => runColorDemo()
        case "Progress" => runProgressDemo()
        case "Spinner" => runSpinnerDemo()
        case "Interactive" => runInteractiveDemo()
        case "CLI App" => runCliAppDemo()
        case _ => @Warn("Unknown category: ${category}")
    }
    @NewLine()
}

func runAllExamples(): Unit {
    @Info("Running all showcase categories")
    runOutputDemo()
    @NewLine()
    runColorDemo()
    @NewLine()
    runProgressAllDemo()
    @NewLine()
    runSpinnerDemo()
    @NewLine()
    runInteractiveDemo()
    @NewLine()
    runCliAppDemo()
}

func runProgressMenu(): Unit {
    while (true) {
        let action = @SelectValue(
            "Progress showcase",
            [
                "Colored bars with text",
                "Bar only",
                "Three-stage progress",
                "InsertBefore + final error",
                "Spinner comparison",
                "Run all progress demos",
                "Back"
            ],
            defaultIndex: Some(0)
        )

        match (action) {
            case Some("Colored bars with text") => runProgressColoredDemo()
            case Some("Bar only") => runProgressBarOnlyDemo()
            case Some("Three-stage progress") => runProgressLayeredDemo()
            case Some("InsertBefore + final error") => runProgressInsertBeforeDemo()
            case Some("Spinner comparison") => runSpinnerDemo()
            case Some("Run all progress demos") => runProgressAllDemo()
            case Some("Back") => return
            case None => return
            case Some(other) => @Warn("Unsupported progress action: ${other}")
        }

        @NewLine()
    }
}

main(): Int {
    @Plain("commandline showcase")
    @Plain("Select a category. Complex areas like Progress have a second-level menu.")

    while (true) {
        let mode = @SelectValue(
            "Showcase home",
            ["Output", "Color", "Progress", "Interactive", "CLI App", "Run all examples", "Exit"],
            defaultIndex: Some(0)
        )

        match (mode) {
            case Some("Output") => runOutputDemo()
            case Some("Color") => runColorDemo()
            case Some("Progress") => runProgressMenu()
            case Some("Interactive") => runInteractiveDemo()
            case Some("CLI App") => runCliAppDemo()
            case Some("Run all examples") =>
                runAllExamples()
            case Some("Exit") =>
                @Success("Showcase finished")
                return 0
            case None =>
                @Success("Showcase finished")
                return 0
            case Some(other) =>
                @Warn("Unsupported mode: ${other}")
        }
    }

    return 0
}
