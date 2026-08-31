package commandline.tests.terminal

/* cjlint-ignore -start !G.PKG.01 */
import std.unittest.*
import std.unittest.testmacro.*
/* cjlint-ignore -end */

import commandline.terminal.{AnsiColor, ColorUtil, InteractiveForm, MultiSelectResult, ProgressLogger, SelectResult, TerminalKey}

@Test
@Tag[UnitTest, TerminalRuntime]
class TestTerminalRuntime {
    @TestCase
    func testColorizeAppliesAnsiPrefixAndReset() {
        let result = ColorUtil.colorize("hello", AnsiColor.Cyan)

        @Expect(result.startsWith(AnsiColor.Cyan.code()), true)
        @Expect(result.endsWith(AnsiColor.Reset.code()), true)
        @Expect(result.contains("hello"), true)
    }

    @TestCase
    func testStyleSupportsForegroundAndBackground() {
        let result = ColorUtil.style("banner", AnsiColor.White, AnsiColor.BgBlue)

        @Expect(result.startsWith(AnsiColor.White.code() + AnsiColor.BgBlue.code()), true)
        @Expect(result.endsWith(AnsiColor.Reset.code()), true)
        @Expect(result.contains("banner"), true)
    }

    @TestCase
    func testProgressBarGenerationFromPercent() {
        let bar = ProgressLogger.generateProgressBar(60, width: 10)

        @Expect(bar, "[██████░░░░] 60%")
    }

    @TestCase
    func testProgressBarGenerationFromTwoPercents() {
        let bar = ProgressLogger.generateProgressBar(25, 75, width: 8)

        @Expect(bar, "[██▒▒▒▒░░] 25%/75%")
    }

    @TestCase
    func testScanProgressBarGeneration() {
        let bar = ProgressLogger.generateScanProgressBar(2, 4, width: 8)

        @Expect(bar, "[▓▓▓▓░░░░]")
    }

    @TestCase
    func testPipelineProgressBarGeneration() {
        let bar = ProgressLogger.generatePipelineProgressBar(2, 3, 5, width: 10)

        @Expect(bar.contains("[▓▓▓▓▒▒░░░░]"), true)
        @Expect(bar.contains("2 rendered, 3 parsed, 5 total"), true)
    }

    @TestCase
    func testMultiPhaseProgressBarGeneration() {
        let bar = ProgressLogger.generateMultiPhaseProgressBar([2, 4, 8], ["#", "=", "."], width: 8)

        @Expect(bar, "[##==....]")
    }

    @TestCase
    func testProgressPrintOverloadsKeepTransientState() {
        let logger = ProgressLogger(enableColor: false)

        logger.printProgress(40, width: 10, color: AnsiColor.Green)
        @Expect(logger.hasActiveTransientLine(), true)

        logger.printProgress("Rendering", 60, width: 10, color: AnsiColor.Cyan)
        @Expect(logger.hasActiveTransientLine(), true)

        logger.printProgress("Pipeline", 25, 75, width: 8, color: AnsiColor.Yellow)
        @Expect(logger.hasActiveTransientLine(), true)

        logger.stopProgress()
        @Expect(logger.hasActiveTransientLine(), false)
    }

    @TestCase
    func testMessageOutputRequiresIdleTerminalState() {
        let logger = ProgressLogger(enableColor: false)
        var raised = false

        logger.startSpinner("working")
        sleep(Duration.millisecond * 150)

        try {
            logger.printSuccess("done")
        } catch (_ : Exception) {
            raised = true
        }

        logger.stopSpinner()
        @Expect(raised, true)
    }

    @TestCase
    func testInterruptWithWarningRestoresSpinnerState() {
        let logger = ProgressLogger(enableColor: false)

        logger.startSpinner("working")
        sleep(Duration.millisecond * 150)
        logger.interruptWithWarning("warn")

        @Expect(logger.hasActiveTransientLine(), true)
        @Expect(logger.getTransientMessage(), Some("working"))

        logger.stopSpinner()
        @Expect(logger.hasActiveTransientLine(), false)
    }

    @TestCase
    func testPromptUsesQueuedInputAndClearsInteractiveState() {
        let logger = ProgressLogger(enableColor: false)
        logger.pushTestInputs(["workspace"])

        let result = logger.prompt("Project name")

        @Expect(result, "workspace")
        @Expect(logger.isInteractiveActive(), false)
    }

    @TestCase
    func testPromptFallsBackToDefaultOnEmptyInput() {
        let logger = ProgressLogger(enableColor: false)
        logger.pushTestInputs(["   "])

        let result = logger.prompt("Project name", defaultValue: Some("markit"))

        @Expect(result, "markit")
    }

    @TestCase
    func testPromptUsesQueuedKeysWithBackspaceEditing() {
        let logger = ProgressLogger(enableColor: false)
        logger.pushTestKeys([TerminalKey.Char("a"), TerminalKey.Char("b"), TerminalKey.Backspace, TerminalKey.Char("c"), TerminalKey.Enter])

        let result = logger.prompt("Project name")

        @Expect(result, "ac")
    }

    @TestCase
    func testPromptClearingDefaultDoesNotSnapBackToDefault() {
        let logger = ProgressLogger(enableColor: false)
        logger.pushTestKeys([
            TerminalKey.Backspace, TerminalKey.Backspace, TerminalKey.Backspace,
            TerminalKey.Enter, TerminalKey.Char("x"), TerminalKey.Enter
        ])

        let result = logger.prompt("Project name", defaultValue: Some("abc"))

        @Expect(result, "x")
    }

    @TestCase
    func testSecretPromptAcceptsQueuedKeys() {
        let logger = ProgressLogger(enableColor: false)
        logger.pushTestKeys([TerminalKey.Char("s"), TerminalKey.Char("3"), TerminalKey.Char("c"), TerminalKey.Enter])

        let result = logger.prompt("Access token", secret: true)

        @Expect(result, "s3c")
    }

    @TestCase
    func testConfirmParsingSupportsDefaultAndAliases() {
        @Expect(ProgressLogger.parseConfirmValue("YES"), Some(true))
        @Expect(ProgressLogger.parseConfirmValue("0"), Some(false))
        @Expect(ProgressLogger.parseConfirmValue(" ", defaultValue: Some(true)), Some(true))
        @Expect(ProgressLogger.parseConfirmValue("maybe"), None<Bool>)
    }

    @TestCase
    func testConfirmUsesQueuedInput() {
        let logger = ProgressLogger(enableColor: false)
        logger.pushTestInputs(["n"])

        let result = logger.confirm("Continue?")

        @Expect(result, false)
        @Expect(logger.isInteractiveActive(), false)
    }

    @TestCase
    func testConfirmUsesQueuedArrowKeys() {
        let logger = ProgressLogger(enableColor: false)
        logger.pushTestKeys([TerminalKey.Down, TerminalKey.Enter])

        let result = logger.confirm("Continue?")

        @Expect(result, false)
        @Expect(logger.isInteractiveActive(), false)
    }

    @TestCase
    func testConfirmSupportsDirectShortcutKeys() {
        let logger = ProgressLogger(enableColor: false)
        logger.pushTestKeys([TerminalKey.Char("y")])

        let result = logger.confirm("Continue?")

        @Expect(result, true)
    }

    @TestCase
    func testConfirmEscapeFallsBackToDefaultInRawMode() {
        let logger = ProgressLogger(enableColor: false)
        logger.pushTestKeys([TerminalKey.Escape])

        let result = logger.confirm("Continue?", defaultValue: Some(false))

        @Expect(result, false)
    }

    @TestCase
    func testSelectParsingSupportsDefaultAndRangeChecks() {
        @Expect(ProgressLogger.parseSelectValue("2", 3), Some(1))
        @Expect(ProgressLogger.parseSelectValue(" ", 3, defaultIndex: Some(2)), Some(2))
        @Expect(ProgressLogger.parseSelectValue("4", 3), None<Int>)
        @Expect(ProgressLogger.parseSelectValue("abc", 3), None<Int>)
    }

    @TestCase
    func testSelectUsesQueuedInput() {
        let logger = ProgressLogger(enableColor: false)
        logger.pushTestInputs(["2"])

        let result = logger.select("Theme", ["light", "dark", "system"])

        match (result) {
            case SelectResult.Selected(index) => @Expect(index, 1)
            case SelectResult.Cancelled => @Fail("select should not be cancelled")
        }
    }

    @TestCase
    func testSelectUsesQueuedArrowKeys() {
        let logger = ProgressLogger(enableColor: false)
        logger.pushTestKeys([TerminalKey.Down, TerminalKey.Down, TerminalKey.Enter])

        let result = logger.select("Theme", ["light", "dark", "system"])

        match (result) {
            case SelectResult.Selected(index) => @Expect(index, 2)
            case SelectResult.Cancelled => @Fail("select should not be cancelled")
        }
    }

    @TestCase
    func testSelectReturnsCancelledOnEscape() {
        let logger = ProgressLogger(enableColor: false)
        logger.pushTestKeys([TerminalKey.Escape])

        let result = logger.select("Theme", ["light", "dark", "system"])

        match (result) {
            case SelectResult.Selected(_) => @Fail("select should be cancelled")
            case SelectResult.Cancelled => @Expect(true, true)
        }
    }

    @TestCase
    func testMultiSelectParsingSupportsCommaRangeDefaultsAndDeduplication() {
        @Expect(ProgressLogger.parseMultiSelectValue("1, 3-4, 3", 5), Some([0, 2, 3]))
        @Expect(ProgressLogger.parseMultiSelectValue(" ", 4, defaultIndices: [1, 3]), Some([1, 3]))
        @Expect(ProgressLogger.parseMultiSelectValue("5", 4), None<Array<Int>>)
        @Expect(ProgressLogger.parseMultiSelectValue("3-1", 4), None<Array<Int>>)
    }

    @TestCase
    func testMultiSelectUsesQueuedInput() {
        let logger = ProgressLogger(enableColor: false)
        logger.pushTestInputs(["1,3"])

        let result = logger.multiSelect("Features", ["spinner", "color", "prompt"])

        match (result) {
            case MultiSelectResult.Selected(indices) => @Expect(indices, [0, 2])
            case MultiSelectResult.Cancelled => @Fail("multiSelect should not be cancelled")
        }
    }

    @TestCase
    func testMultiSelectUsesQueuedArrowKeys() {
        let logger = ProgressLogger(enableColor: false)
        logger.pushTestKeys([TerminalKey.Space, TerminalKey.Down, TerminalKey.Down, TerminalKey.Space, TerminalKey.Enter])

        let result = logger.multiSelect("Features", ["spinner", "color", "prompt"])

        match (result) {
            case MultiSelectResult.Selected(indices) => @Expect(indices, [0, 2])
            case MultiSelectResult.Cancelled => @Fail("multiSelect should not be cancelled")
        }
    }

    @TestCase
    func testMultiSelectSupportsSelectAllAndClearHotkeys() {
        let logger = ProgressLogger(enableColor: false)
        logger.pushTestKeys([TerminalKey.SelectAll, TerminalKey.Clear, TerminalKey.Down, TerminalKey.Space, TerminalKey.Enter])

        let result = logger.multiSelect("Features", ["spinner", "color", "prompt"])

        match (result) {
            case MultiSelectResult.Selected(indices) => @Expect(indices, [1])
            case MultiSelectResult.Cancelled => @Fail("multiSelect should not be cancelled")
        }
    }

    @TestCase
    func testMultiSelectReturnsCancelledOnEscape() {
        let logger = ProgressLogger(enableColor: false)
        logger.pushTestKeys([TerminalKey.Escape])

        let result = logger.multiSelect("Features", ["spinner", "color", "prompt"])

        match (result) {
            case MultiSelectResult.Selected(_) => @Fail("multiSelect should be cancelled")
            case MultiSelectResult.Cancelled => @Expect(true, true)
        }
    }

    @TestCase
    func testInteractiveFormSelectValueReturnsOption() {
        let logger = ProgressLogger(enableColor: false)
        let form = InteractiveForm(logger: logger)
        logger.pushTestKeys([TerminalKey.Down, TerminalKey.Enter])

        let result = form.selectValue("Theme", ["light", "dark"])

        @Expect(result, Some("dark"))
    }

    @TestCase
    func testInteractiveFormMultiSelectValuesReturnsLabels() {
        let logger = ProgressLogger(enableColor: false)
        let form = InteractiveForm(logger: logger)
        logger.pushTestKeys([TerminalKey.Space, TerminalKey.Down, TerminalKey.Down, TerminalKey.Space, TerminalKey.Enter])

        let result = form.multiSelectValues("Features", ["spinner", "color", "interactive"])

        @Expect(result, Some(["spinner", "interactive"]))
    }

    @TestCase
    func testInteractiveFormRequireConfirmThrowsOnDecline() {
        let logger = ProgressLogger(enableColor: false)
        let form = InteractiveForm(logger: logger)
        var raised = false
        logger.pushTestKeys([TerminalKey.Char("n")])

        try {
            form.requireConfirm("Continue?", abortMessage: "stopped")
        } catch (e: Exception) {
            raised = e.message == "stopped"
        }

        @Expect(raised, true)
    }

    @TestCase
    func testInteractiveInputRequiresIdleTerminalState() {
        let logger = ProgressLogger(enableColor: false)
        var raised = false

        logger.startSpinner("working")
        sleep(Duration.millisecond * 150)

        try {
            _ = logger.prompt("Project name")
        } catch (_ : Exception) {
            raised = true
        }

        logger.stopSpinner()
        @Expect(raised, true)
    }
}
