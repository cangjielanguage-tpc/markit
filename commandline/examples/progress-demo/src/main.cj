package commandline_progress_demo

import commandline.macros.{Err, InsertBefore, Progress, StopProgress, Success, Warn}
import commandline.terminal.{AnsiColor, progressLogger}

main(): Int {
    let percentages = [20, 40, 60, 80, 100]
    let colors = [
        AnsiColor.BrightRed,
        AnsiColor.Yellow,
        AnsiColor.Cyan,
        AnsiColor.BrightBlue,
        AnsiColor.Green
    ]

    for (i in 0..percentages.size) {
        let percent = percentages[i]
        @Progress("Rendering", percent, width: 20, color: colors[i])
        sleep(Duration.millisecond * 120)
    }
    @StopProgress(@Success("Render completed"))

    for (percent in percentages) {
        @Progress(percent, width: 20, color: AnsiColor.BrightMagenta)
        sleep(Duration.millisecond * 120)
    }
    @StopProgress(@Success("Bar-only progress completed"))

    let layeredProgress = [
        (15, 40),
        (30, 55),
        (45, 70),
        (60, 85),
        (75, 100)
    ]
    for ((primary, secondary) in layeredProgress) {
        @Progress("Pipeline", primary, secondary, width: 24, color: AnsiColor.Cyan)
        sleep(Duration.millisecond * 120)
    }
    @InsertBefore(@Warn("One asset fell back to cached output"))
    @StopProgress(@Err("Pipeline finished with warnings"))

    return 0
}
