package commandline.tests.macros

/* cjlint-ignore -start !G.PKG.01 */
import std.unittest.*
import std.unittest.testmacro.*
/* cjlint-ignore -end */

import commandline.macros.{Background, Color, Confirm, Err, Info, InsertBefore, MultiSelect, MultiSelectValues, NewLine, Plain, Progress, ProgressBar, Prompt, RequireConfirm, Select, SelectValue, Spinner, StopProgress, StopSpinner, Styled, Success, UpdateSpinner, Verbose, Warn}
import commandline.terminal.{AnsiColor, ColorUtil, MultiSelectResult, ProgressLogger, SelectResult, TerminalKey, interactiveForm, progressLogger}

@Test
@Tag[MacroSystem, TerminalMacro]
class TestTerminalMacros {
    @TestCase
    func testColorMacroExpandsToColorUtilCall() {
        let colored = @Color("hello", AnsiColor.Green)
        let background = @Background("world", AnsiColor.BgBlue)
        let styled = @Styled("banner", foreground: AnsiColor.White, background: AnsiColor.BgBlue)
        let progress = @ProgressBar(60, width: 10)
        let layeredProgress = @ProgressBar(25, 75, width: 8)

        @Expect(colored, ColorUtil.colorize("hello", AnsiColor.Green))
        @Expect(background, ColorUtil.colorizeBackground("world", AnsiColor.BgBlue))
        @Expect(styled, ColorUtil.style("banner", foreground: AnsiColor.White, background: AnsiColor.BgBlue))
        @Expect(progress, "[██████░░░░] 60%")
        @Expect(layeredProgress, "[██▒▒▒▒░░] 25%/75%")
    }

    @TestCase
    func testLoggingMacrosExpandInScope() {
        try {
            @Success("done")
            @Warn("warn")
            @Err("error")
            @Info("info")
            @Verbose("trace")
            @Plain("plain")
            @NewLine()
            @Assert(true)
        } catch (e: Exception) {
            @Fail("Terminal logging macros should expand and execute: " + e.message)
        }
    }

    @TestCase
    func testSpinnerMacrosExpandInScope() {
        try {
            @Spinner("loading")
            @UpdateSpinner("loaded")
            @StopSpinner(@Success("done"))
            @Assert(true)
        } catch (e: Exception) {
            @Fail("Spinner macros should expand and execute: " + e.message)
        }
    }

    @TestCase
    func testProgressMacrosSupportOverloadsAndStop() {
        try {
            @Progress(40, width: 10, color: AnsiColor.Green)
            @Progress("Rendering", 60, width: 10, color: AnsiColor.Cyan)
            @Progress("Pipeline", 25, 75, width: 8, color: AnsiColor.Yellow)
            @InsertBefore(@Warn("warn"))
            @StopProgress(@Success("done"))
            @Assert(true)
        } catch (e: Exception) {
            @Fail("Progress macros should expand and execute: " + e.message)
        }
    }

    @TestCase
    func testDirectStatusMacroFailsWhenSpinnerIsActive() {
        var raised = false

        try {
            @Spinner("loading")
            @Success("done")
        } catch (_ : Exception) {
            raised = true
        }

        progressLogger.stopSpinner()
        @Expect(raised, true)
    }

    @TestCase
    func testInsertBeforeMacroExpandsInScope() {
        try {
            @Spinner("loading")
            @InsertBefore(@Warn("warn"))
            @InsertBefore(@Err("err"))
            @InsertBefore(@Info("info"))
            @InsertBefore(@Verbose("trace"))
            @StopSpinner(@Success("done"))
            @Assert(true)
        } catch (e: Exception) {
            @Fail("InsertBefore macro should expand and execute: " + e.message)
        }
    }

    @TestCase
    func testInteractiveMacrosExpandAndReturnValues() {
        progressLogger.clearTestInputs()
        progressLogger.clearTestKeys()
        progressLogger.pushTestInputs(["workspace"])
        progressLogger.pushTestKeys([
            TerminalKey.Char("y"),
            TerminalKey.Down, TerminalKey.Enter,
            TerminalKey.Space, TerminalKey.Down, TerminalKey.Down, TerminalKey.Space, TerminalKey.Enter
        ])

        try {
            let project = @Prompt("Project name")
            let confirmed = @Confirm("Continue?")
            let theme = @Select("Theme", ["light", "dark"])
            let features = @MultiSelect("Features", ["spinner", "prompt", "select"])

            @Expect(project, "workspace")
            @Expect(confirmed, true)
            match (theme) {
                case SelectResult.Selected(index) => @Expect(index, 1)
                case SelectResult.Cancelled => @Fail("theme should not be cancelled")
            }
            match (features) {
                case MultiSelectResult.Selected(indices) => @Expect(indices, [0, 2])
                case MultiSelectResult.Cancelled => @Fail("features should not be cancelled")
            }
        } catch (e: Exception) {
            @Fail("Interactive macros should expand and execute: " + e.message)
        }
    }

    @TestCase
    func testValueLevelInteractiveMacrosExpandAndReturnValues() {
        progressLogger.clearTestInputs()
        progressLogger.clearTestKeys()
        progressLogger.pushTestKeys([
            TerminalKey.Down, TerminalKey.Enter,
            TerminalKey.Space, TerminalKey.Down, TerminalKey.Space, TerminalKey.Enter,
            TerminalKey.Char("y")
        ])

        try {
            let template = @SelectValue("Template", ["basic", "docs"])
            let features = @MultiSelectValues("Features", ["spinner", "color"])
            @RequireConfirm("Continue?", defaultValue: Some(true), abortMessage: "stopped")

            @Expect(template, Some("docs"))
            @Expect(features, Some(["spinner", "color"]))
        } catch (e: Exception) {
            @Fail("Value-level interactive macros should expand and execute: " + e.message)
        }
    }
}
