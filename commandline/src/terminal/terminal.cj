package commandline.terminal

import std.collection.ArrayList
import std.convert.Parsable
import std.env.{ConsoleReader, ConsoleWriter, getStdIn, getStdOut}
import std.sync.{AtomicBool, Mutex}

public class Spinner {
    private static let frames: Array<String> = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    private var currentFrame: Int = 0

    public func next(): String {
        let frame = Spinner.frames[currentFrame]
        currentFrame = (currentFrame + 1) % Spinner.frames.size
        return frame
    }

    public func reset(): Unit {
        currentFrame = 0
    }
}

public enum AnsiColor {
    | Reset
    | Bold
    | Dim
    | Black
    | Red
    | Green
    | Yellow
    | Blue
    | Magenta
    | Cyan
    | White
    | Gray
    | BrightBlack
    | BrightRed
    | BrightGreen
    | BrightYellow
    | BrightBlue
    | BrightMagenta
    | BrightCyan
    | BrightWhite
    | BgBlack
    | BgRed
    | BgGreen
    | BgYellow
    | BgBlue
    | BgMagenta
    | BgCyan
    | BgWhite
    | BgGray
    | BgBrightBlack
    | BgBrightRed
    | BgBrightGreen
    | BgBrightYellow
    | BgBrightBlue
    | BgBrightMagenta
    | BgBrightCyan
    | BgBrightWhite

    public func code(): String {
        return match (this) {
            case Reset => "\u{001b}[0m"
            case Bold => "\u{001b}[1m"
            case Dim => "\u{001b}[2m"
            case Black => "\u{001b}[30m"
            case Red => "\u{001b}[31m"
            case Green => "\u{001b}[32m"
            case Yellow => "\u{001b}[33m"
            case Blue => "\u{001b}[34m"
            case Magenta => "\u{001b}[35m"
            case Cyan => "\u{001b}[36m"
            case White => "\u{001b}[37m"
            case Gray => "\u{001b}[90m"
            case BrightBlack => "\u{001b}[90m"
            case BrightRed => "\u{001b}[91m"
            case BrightGreen => "\u{001b}[92m"
            case BrightYellow => "\u{001b}[93m"
            case BrightBlue => "\u{001b}[94m"
            case BrightMagenta => "\u{001b}[95m"
            case BrightCyan => "\u{001b}[96m"
            case BrightWhite => "\u{001b}[97m"
            case BgBlack => "\u{001b}[40m"
            case BgRed => "\u{001b}[41m"
            case BgGreen => "\u{001b}[42m"
            case BgYellow => "\u{001b}[43m"
            case BgBlue => "\u{001b}[44m"
            case BgMagenta => "\u{001b}[45m"
            case BgCyan => "\u{001b}[46m"
            case BgWhite => "\u{001b}[47m"
            case BgGray => "\u{001b}[100m"
            case BgBrightBlack => "\u{001b}[100m"
            case BgBrightRed => "\u{001b}[101m"
            case BgBrightGreen => "\u{001b}[102m"
            case BgBrightYellow => "\u{001b}[103m"
            case BgBrightBlue => "\u{001b}[104m"
            case BgBrightMagenta => "\u{001b}[105m"
            case BgBrightCyan => "\u{001b}[106m"
            case BgBrightWhite => "\u{001b}[107m"
        }
    }
}

public enum TerminalKey {
    | Up
    | Down
    | Left
    | Right
    | Enter
    | Space
    | Backspace
    | Escape
    | SelectAll
    | Clear
    | Char(String)
    | Eof
}

public enum SelectResult {
    | Selected(Int)
    | Cancelled
}

public enum MultiSelectResult {
    | Selected(Array<Int>)
    | Cancelled
}

public class ColorUtil {
    public static func colorize(text: String, color: AnsiColor): String {
        return "${color.code()}${text}${AnsiColor.Reset.code()}"
    }

    public static func colorizeBackground(text: String, color: AnsiColor): String {
        return "${color.code()}${text}${AnsiColor.Reset.code()}"
    }

    public static func style(text: String, foreground: AnsiColor, background: AnsiColor): String {
        return "${foreground.code()}${background.code()}${text}${AnsiColor.Reset.code()}"
    }

    public static func style(
        text: String,
        foreground!: ?AnsiColor = None,
        background!: ?AnsiColor = None,
        styles!: Array<AnsiColor> = []
    ): String {
        let sb = StringBuilder()
        for (style in styles) {
            sb.append(style.code())
        }
        match (foreground) {
            case Some(color) => sb.append(color.code())
            case None => ()
        }
        match (background) {
            case Some(color) => sb.append(color.code())
            case None => ()
        }
        sb.append(text)
        sb.append(AnsiColor.Reset.code())
        return sb.toString()
    }
}

public class ProgressLogger {
    private static let ansiEscape: String = "\u{001b}"

    private let reader: ConsoleReader
    private let writer: ConsoleWriter
    private let enableColor: Bool
    private let spinner: Spinner
    private let mutex: Mutex
    private let spinnerRunning: AtomicBool
    private let testInputQueue: ArrayList<String>
    private let testKeyQueue: ArrayList<TerminalKey>
    private let terminalBackend: TerminalBackend

    private var lastLineLength: Int = 0
    private var isInProgress: Bool = false
    private var currentMessage: String = ""
    private var interactiveActive: Bool = false

    public init(enableColor!: Bool = true) {
        this.reader = getStdIn()
        this.writer = getStdOut()
        this.enableColor = enableColor
        this.spinner = Spinner()
        this.mutex = Mutex()
        this.spinnerRunning = AtomicBool(false)
        this.testInputQueue = ArrayList<String>()
        this.testKeyQueue = ArrayList<TerminalKey>()
        this.terminalBackend = NativeTerminalBackend(this.testKeyQueue, this.mutex)
    }

    private func clearCurrentLineUnsafe(): Unit {
        if (lastLineLength > 0 && isInProgress) {
            writer.write("\r")
            let spaces = repeatString(" ", lastLineLength)
            writer.write(spaces)
            writer.write("\r")
            writer.flush()
        }
    }

    private func calculateDisplayLength(text: String): Int {
        var cleanText = text
        let colors = [
            AnsiColor.Reset, AnsiColor.Bold, AnsiColor.Dim, AnsiColor.Black, AnsiColor.Red,
            AnsiColor.Green, AnsiColor.Yellow, AnsiColor.Blue, AnsiColor.Magenta, AnsiColor.Cyan,
            AnsiColor.White, AnsiColor.Gray, AnsiColor.BrightBlack, AnsiColor.BrightRed,
            AnsiColor.BrightGreen, AnsiColor.BrightYellow, AnsiColor.BrightBlue, AnsiColor.BrightMagenta,
            AnsiColor.BrightCyan, AnsiColor.BrightWhite, AnsiColor.BgBlack, AnsiColor.BgRed,
            AnsiColor.BgGreen, AnsiColor.BgYellow, AnsiColor.BgBlue, AnsiColor.BgMagenta,
            AnsiColor.BgCyan, AnsiColor.BgWhite, AnsiColor.BgGray, AnsiColor.BgBrightBlack,
            AnsiColor.BgBrightRed, AnsiColor.BgBrightGreen, AnsiColor.BgBrightYellow,
            AnsiColor.BgBrightBlue, AnsiColor.BgBrightMagenta, AnsiColor.BgBrightCyan,
            AnsiColor.BgBrightWhite
        ]
        for (color in colors) {
            cleanText = cleanText.replace(color.code(), "")
        }
        return cleanText.toRuneArray().size
    }

    public func startSpinner(message: String): Unit {
        if (spinnerRunning.load()) {
            stopSpinner()
        }

        mutex.lock()
        currentMessage = message
        isInProgress = true
        mutex.unlock()

        spinnerRunning.store(true)
        spawn {
            while (spinnerRunning.load()) {
                updateSpinnerFrame()
                sleep(Duration.millisecond * 100)
            }
        }
    }

    private func updateSpinnerFrame(): Unit {
        if (!spinnerRunning.load()) {
            return
        }

        mutex.lock()
        if (!spinnerRunning.load()) {
            mutex.unlock()
            return
        }

        clearCurrentLineUnsafe()
        if (!spinnerRunning.load()) {
            mutex.unlock()
            return
        }

        let spinnerFrame = spinner.next()
        let coloredSpinner = if (enableColor) { ColorUtil.colorize(spinnerFrame, AnsiColor.Cyan) } else { spinnerFrame }
        let coloredMessage = if (enableColor) { ColorUtil.colorize(currentMessage, AnsiColor.Cyan) } else { currentMessage }
        let line = "${coloredSpinner} ${coloredMessage}"
        writer.write(line)
        writer.flush()
        lastLineLength = calculateDisplayLength(line)
        mutex.unlock()
    }

    public func updateSpinnerMessage(message: String): Unit {
        if (!spinnerRunning.load()) {
            return
        }

        mutex.lock()
        if (!spinnerRunning.load()) {
            mutex.unlock()
            return
        }

        clearCurrentLineUnsafe()
        if (!spinnerRunning.load()) {
            mutex.unlock()
            return
        }

        currentMessage = message
        let spinnerFrame = spinner.next()
        let coloredSpinner = if (enableColor) { ColorUtil.colorize(spinnerFrame, AnsiColor.Cyan) } else { spinnerFrame }
        let coloredMessage = if (enableColor) { ColorUtil.colorize(currentMessage, AnsiColor.Cyan) } else { currentMessage }
        let line = "${coloredSpinner} ${coloredMessage}"
        writer.write(line)
        writer.flush()
        lastLineLength = calculateDisplayLength(line)
        mutex.unlock()
    }

    public func stopSpinner(): Unit {
        if (!spinnerRunning.load()) {
            return
        }

        dismissTransientLine()
    }

    public func hasActiveTransientLine(): Bool {
        mutex.lock()
        let active = spinnerRunning.load() || isInProgress
        mutex.unlock()
        return active
    }

    public func isSpinnerRunning(): Bool {
        return spinnerRunning.load()
    }

    public func getTransientMessage(): ?String {
        mutex.lock()
        let result = if (spinnerRunning.load() || isInProgress) { Some(currentMessage) } else { None<String> }
        mutex.unlock()
        return result
    }

    public func dismissTransientLine(): Unit {
        if (spinnerRunning.load()) {
            spinnerRunning.store(false)
            sleep(Duration.millisecond * 350)
        }

        mutex.lock()
        clearCurrentLineUnsafe()
        lastLineLength = 0
        isInProgress = false
        spinner.reset()
        mutex.unlock()
    }

    public func interruptWithWarning(message: String): Unit {
        let resumeMessage = getTransientMessage()
        let shouldResume = spinnerRunning.load()
        dismissTransientLine()
        printWarning(message)
        if (shouldResume) {
            match (resumeMessage) {
                case Some(text) => startSpinner(text)
                case None => ()
            }
        }
    }

    public func interruptWithError(message: String): Unit {
        let resumeMessage = getTransientMessage()
        let shouldResume = spinnerRunning.load()
        dismissTransientLine()
        printError(message)
        if (shouldResume) {
            match (resumeMessage) {
                case Some(text) => startSpinner(text)
                case None => ()
            }
        }
    }

    public func interruptWithInfo(
        message: String,
        icon!: String = "ℹ",
        color!: AnsiColor = AnsiColor.Blue
    ): Unit {
        let resumeMessage = getTransientMessage()
        let shouldResume = spinnerRunning.load()
        dismissTransientLine()
        printInfo(message, icon: icon, color: color)
        if (shouldResume) {
            match (resumeMessage) {
                case Some(text) => startSpinner(text)
                case None => ()
            }
        }
    }

    private func ensureIdleForMessageUnsafe(action: String): Unit {
        if (spinnerRunning.load() || isInProgress || interactiveActive) {
            throw Exception("${action} requires an idle terminal state. Use stopSpinner(...) first.")
        }
    }

    private func ensureIdleForInteractiveUnsafe(action: String): Unit {
        if (spinnerRunning.load() || isInProgress || interactiveActive) {
            throw Exception("${action} requires an idle terminal state. Stop the transient line before entering interactive mode.")
        }
    }

    private func beginInteractive(action: String): Unit {
        mutex.lock()
        ensureIdleForInteractiveUnsafe(action)
        interactiveActive = true
        mutex.unlock()
    }

    private func endInteractive(): Unit {
        mutex.lock()
        interactiveActive = false
        mutex.unlock()
    }

    public func isInteractiveActive(): Bool {
        mutex.lock()
        let active = interactiveActive
        mutex.unlock()
        return active
    }

    public func pushTestInputs(inputs: Array<String>): Unit {
        mutex.lock()
        for (input in inputs) {
            testInputQueue.add(input)
        }
        mutex.unlock()
    }

    public func clearTestInputs(): Unit {
        mutex.lock()
        while (testInputQueue.size > 0) {
            testInputQueue.remove(0..1)
        }
        mutex.unlock()
    }

    public func pushTestKeys(keys: Array<TerminalKey>): Unit {
        mutex.lock()
        for (key in keys) {
            testKeyQueue.add(key)
        }
        mutex.unlock()
    }

    public func clearTestKeys(): Unit {
        mutex.lock()
        while (testKeyQueue.size > 0) {
            testKeyQueue.remove(0..1)
        }
        mutex.unlock()
    }

    private func readNextInputLine(): ?String {
        mutex.lock()
        if (testInputQueue.size > 0) {
            let value = testInputQueue[0]
            testInputQueue.remove(0..1)
            mutex.unlock()
            return Some(value)
        }
        mutex.unlock()
        return reader.readln()
    }

    private func hasQueuedKeyInput(): Bool {
        mutex.lock()
        let result = testKeyQueue.size > 0
        mutex.unlock()
        return result
    }

    private func hasQueuedLineInput(): Bool {
        mutex.lock()
        let result = testInputQueue.size > 0
        mutex.unlock()
        return result
    }

    private func canUseRawInteractive(): Bool {
        if (hasQueuedLineInput()) {
            return false
        }
        return terminalBackend.supportsKeyNavigation()
    }

    private func readNextKey(): TerminalKey {
        return terminalBackend.readKey()
    }

    private func clearRenderedInteractiveBlock(lineCount: Int): Unit {
        if (lineCount <= 0) {
            return
        }

        writer.write("\r${ProgressLogger.ansiEscape}[2K")
        var remaining = lineCount - 1
        while (remaining > 0) {
            writer.write("${ProgressLogger.ansiEscape}[1A\r${ProgressLogger.ansiEscape}[2K")
            remaining -= 1
        }
        writer.flush()
    }

    private func formatInteractiveOption(
        index: Int,
        option: String,
        cursor: Int,
        multi!: Bool = false,
        selected!: Bool = false
    ): String {
        let marker = if (index == cursor) { "›" } else { " " }
        let body = if (multi) {
            let checkbox = if (selected) { "[x]" } else { "[ ]" }
            "${marker} ${checkbox} ${option}"
        } else {
            "${marker} ${option}"
        }

        if (enableColor && index == cursor) {
            return ColorUtil.style(body, foreground: Some(AnsiColor.Cyan), styles: [AnsiColor.Bold])
        }
        if (enableColor && multi && selected) {
            return ColorUtil.colorize(body, AnsiColor.Green)
        }
        return body
    }

    private func renderSelectMenu(
        message: String,
        options: Array<String>,
        cursor: Int
    ): Int {
        writer.writeln(message)
        for (i in 0..options.size) {
            writer.writeln(formatInteractiveOption(i, options[i], cursor))
        }
        writer.write("Use ↑/↓ to move, Enter to confirm, Esc to cancel.")
        writer.flush()
        return options.size + 2
    }

    private func renderMultiSelectMenu(
        message: String,
        options: Array<String>,
        state: MultiSelectMenuState
    ): Int {
        writer.writeln(message)
        for (i in 0..options.size) {
            writer.writeln(formatInteractiveOption(i, options[i], state.cursor, multi: true, selected: state.isSelected(i)))
        }
        writer.write("Use ↑/↓ to move, Space to toggle, Enter to confirm, a to select all, c to clear, Esc to cancel.")
        writer.flush()
        return options.size + 2
    }

    private func renderConfirmMenu(message: String, cursor: Int): Int {
        writer.writeln(message)
        writer.writeln(formatInteractiveOption(0, "Yes", cursor))
        writer.writeln(formatInteractiveOption(1, "No", cursor))
        writer.write("Use ↑/↓ to move, Enter to confirm, or press y/n directly.")
        writer.flush()
        return 4
    }

    private func renderPromptInput(
        message: String,
        currentValue: String,
        defaultHint: ?String,
        secret: Bool
    ): Int {
        let visibleValue = if (secret) {
            repeatString("*", currentValue.toRuneArray().size)
        } else {
            currentValue
        }
        writer.write("${message}${formatPromptSuffix(defaultHint)}: ${visibleValue}")
        writer.flush()
        return 1
    }

    private func formatPromptSuffix(defaultHint: ?String): String {
        return match (defaultHint) {
            case Some(hint) => " [${hint}]"
            case None => ""
        }
    }

    private func writeInteractivePrompt(message: String, defaultHint: ?String): Unit {
        writer.write("${message}${formatPromptSuffix(defaultHint)}: ")
        writer.flush()
    }

    private func writeInteractiveError(message: String): Unit {
        let text = if (enableColor) {
            ColorUtil.colorize(message, AnsiColor.Yellow)
        } else {
            message
        }
        writer.writeln(text)
        writer.flush()
    }

    private static func normalizePromptValue(input: String, defaultValue: ?String, allowEmpty: Bool): ?String {
        let trimmed = input.trimAscii()
        if (!trimmed.isEmpty()) {
            return Some(input)
        }

        match (defaultValue) {
            case Some(value) => return Some(value)
            case None => ()
        }

        if (allowEmpty) {
            return Some("")
        }
        return None<String>
    }

    private static func normalizePromptBufferValue(
        input: String,
        defaultValue: ?String,
        allowEmpty: Bool,
        dirty: Bool
    ): ?String {
        if (!dirty) {
            return normalizePromptValue(input, defaultValue, allowEmpty)
        }

        let trimmed = input.trimAscii()
        if (!trimmed.isEmpty()) {
            return Some(input)
        }
        if (allowEmpty) {
            return Some("")
        }
        return None<String>
    }

    private static func stringToInputUnits(value: String): ArrayList<String> {
        let units = ArrayList<String>()
        for (rune in value.toRuneArray()) {
            units.add("${rune}")
        }
        return units
    }

    private static func inputUnitsToString(units: ArrayList<String>): String {
        let sb = StringBuilder()
        for (unit in units) {
            sb.append(unit)
        }
        return sb.toString()
    }

    public static func parseConfirmValue(input: String, defaultValue!: ?Bool = None): ?Bool {
        let trimmed = input.trimAscii().toAsciiLower()
        if (trimmed.isEmpty()) {
            return defaultValue
        }

        return match (trimmed) {
            case "y" => Some(true)
            case "yes" => Some(true)
            case "true" => Some(true)
            case "1" => Some(true)
            case "n" => Some(false)
            case "no" => Some(false)
            case "false" => Some(false)
            case "0" => Some(false)
            case _ => None<Bool>
        }
    }

    private static func parseSelectionNumber(input: String): ?Int {
        try {
            let parsed = Int64.parse(input.trimAscii())
            if (parsed < 1) {
                return None<Int>
            }
            return Some(parsed - 1)
        } catch (_ : Exception) {
            return None<Int>
        }
    }

    public static func parseSelectValue(input: String, optionCount: Int, defaultIndex!: ?Int = None): ?Int {
        let trimmed = input.trimAscii()
        if (trimmed.isEmpty()) {
            return match (defaultIndex) {
                case Some(index) => if (index >= 0 && index < optionCount) { Some(index) } else { None<Int> }
                case None => None<Int>
            }
        }

        match (parseSelectionNumber(trimmed)) {
            case Some(index) => if (index >= 0 && index < optionCount) { Some(index) } else { None<Int> }
            case None => None<Int>
        }
    }

    private static func appendUniqueSelection(selections: ArrayList<Int>, index: Int): Unit {
        if (!selections.contains(index)) {
            selections.add(index)
        }
    }

    private static func areValidSelectionIndices(indices: Array<Int>, optionCount: Int): Bool {
        for (index in indices) {
            if (index < 0 || index >= optionCount) {
                return false
            }
        }
        return true
    }

    private static func parseMultiSelectToken(token: String, optionCount: Int, selections: ArrayList<Int>): Bool {
        let trimmed = token.trimAscii()
        if (trimmed.isEmpty()) {
            return true
        }

        if (trimmed.contains("-")) {
            let bounds = trimmed.split("-")
            if (bounds.size != 2) {
                return false
            }

            match (parseSelectionNumber(bounds[0])) {
                case Some(start) =>
                    match (parseSelectionNumber(bounds[1])) {
                        case Some(end) =>
                            if (start > end || start < 0 || end >= optionCount) {
                                return false
                            }
                            for (index in start..(end + 1)) {
                                appendUniqueSelection(selections, index)
                            }
                            return true
                        case None => return false
                    }
                case None => return false
            }
        }

        match (parseSelectionNumber(trimmed)) {
            case Some(index) =>
                if (index < 0 || index >= optionCount) {
                    return false
                }
                appendUniqueSelection(selections, index)
                return true
            case None => return false
        }
    }

    public static func parseMultiSelectValue(
        input: String,
        optionCount: Int,
        defaultIndices!: Array<Int> = []
    ): ?Array<Int> {
        let trimmed = input.trimAscii()
        if (trimmed.isEmpty()) {
            if (!areValidSelectionIndices(defaultIndices, optionCount)) {
                return None<Array<Int>>
            }
            return Some(defaultIndices)
        }

        let selections = ArrayList<Int>()
        for (part in trimmed.split(",")) {
            if (!parseMultiSelectToken(part, optionCount, selections)) {
                return None<Array<Int>>
            }
        }

        if (selections.size == 0) {
            return None<Array<Int>>
        }
        return Some(selections.toArray())
    }

    public func prompt(
        message: String,
        defaultValue!: ?String = None,
        allowEmpty!: Bool = false,
        secret!: Bool = false
    ): String {
        beginInteractive("prompt")
        try {
            if (canUseRawInteractive()) {
                if (!terminalBackend.enterKeyMode()) {
                    endInteractive()
                    throw Exception("prompt could not enter raw terminal mode")
                }

                let buffer = match (defaultValue) {
                    case Some(value) => ProgressLogger.stringToInputUnits(value)
                    case None => ArrayList<String>()
                }
                var dirty = false
                var renderedLines = renderPromptInput(
                    message,
                    ProgressLogger.inputUnitsToString(buffer),
                    defaultValue,
                    secret
                )

                try {
                    while (true) {
                        match (readNextKey()) {
                            case TerminalKey.Char(value) =>
                                buffer.add(value)
                                dirty = true
                            case TerminalKey.Space =>
                                buffer.add(" ")
                                dirty = true
                            case TerminalKey.Backspace =>
                                if (buffer.size > 0) {
                                    buffer.remove((buffer.size - 1)..buffer.size)
                                    dirty = true
                                }
                            case TerminalKey.Enter =>
                                let currentValue = ProgressLogger.inputUnitsToString(buffer)
                                match (ProgressLogger.normalizePromptBufferValue(
                                    currentValue,
                                    defaultValue,
                                    allowEmpty,
                                    dirty
                                )) {
                                    case Some(value) =>
                                        clearRenderedInteractiveBlock(renderedLines)
                                        terminalBackend.leaveKeyMode()
                                        endInteractive()
                                        return value
                                    case None =>
                                        clearRenderedInteractiveBlock(renderedLines)
                                        writeInteractiveError("Input is required.")
                                        renderedLines = renderPromptInput(
                                            message,
                                            currentValue,
                                            defaultValue,
                                            secret
                                        ) + 1
                                        continue
                                }
                            case TerminalKey.Eof =>
                                clearRenderedInteractiveBlock(renderedLines)
                                terminalBackend.leaveKeyMode()
                                endInteractive()
                                throw Exception("prompt could not read input from stdin")
                            case _ => ()
                        }

                        clearRenderedInteractiveBlock(renderedLines)
                        renderedLines = renderPromptInput(
                            message,
                            ProgressLogger.inputUnitsToString(buffer),
                            defaultValue,
                            secret
                        )
                    }
                } catch (e: Exception) {
                    terminalBackend.leaveKeyMode()
                    throw e
                }
            }

            while (true) {
                writeInteractivePrompt(message, defaultValue)
                match (readNextInputLine()) {
                    case Some(input) =>
                        match (ProgressLogger.normalizePromptValue(input, defaultValue, allowEmpty)) {
                            case Some(value) =>
                                endInteractive()
                                return value
                            case None => writeInteractiveError("Input is required.")
                        }
                    case None =>
                        match (defaultValue) {
                            case Some(value) =>
                                endInteractive()
                                return value
                            case None =>
                                if (allowEmpty) {
                                    endInteractive()
                                    return ""
                                }
                                endInteractive()
                                throw Exception("prompt could not read input from stdin")
                        }
                }
            }
            throw Exception("prompt exited without a value")
        } catch (e: Exception) {
            if (isInteractiveActive()) {
                endInteractive()
            }
            throw e
        }
    }

    public func confirm(message: String, defaultValue!: ?Bool = None): Bool {
        beginInteractive("confirm")
        let defaultHint = match (defaultValue) {
            case Some(true) => Some("Y/n")
            case Some(false) => Some("y/N")
            case None => Some("y/n")
        }

        try {
            if (canUseRawInteractive()) {
                if (!terminalBackend.enterKeyMode()) {
                    endInteractive()
                    throw Exception("confirm could not enter raw terminal mode")
                }

                let state = SelectMenuState(2, defaultIndex: match (defaultValue) {
                    case Some(true) => Some(0)
                    case Some(false) => Some(1)
                    case None => Some(0)
                })
                var renderedLines = renderConfirmMenu(message, state.cursor)

                try {
                    while (true) {
                        match (readNextKey()) {
                            case TerminalKey.Up =>
                                state.moveUp()
                            case TerminalKey.Down =>
                                state.moveDown()
                            case TerminalKey.Enter =>
                                clearRenderedInteractiveBlock(renderedLines)
                                terminalBackend.leaveKeyMode()
                                endInteractive()
                                return state.cursor == 0
                            case TerminalKey.Char(value) =>
                                if (value == "y") {
                                    clearRenderedInteractiveBlock(renderedLines)
                                    terminalBackend.leaveKeyMode()
                                    endInteractive()
                                    return true
                                }
                                if (value == "n") {
                                    clearRenderedInteractiveBlock(renderedLines)
                                    terminalBackend.leaveKeyMode()
                                    endInteractive()
                                    return false
                                }
                            case TerminalKey.Escape =>
                                match (defaultValue) {
                                    case Some(value) =>
                                        clearRenderedInteractiveBlock(renderedLines)
                                        terminalBackend.leaveKeyMode()
                                        endInteractive()
                                        return value
                                    case None => ()
                                }
                            case TerminalKey.Eof =>
                                clearRenderedInteractiveBlock(renderedLines)
                                terminalBackend.leaveKeyMode()
                                endInteractive()
                                throw Exception("confirm could not read input from stdin")
                            case _ => ()
                        }

                        clearRenderedInteractiveBlock(renderedLines)
                        renderedLines = renderConfirmMenu(message, state.cursor)
                    }
                } catch (e: Exception) {
                    terminalBackend.leaveKeyMode()
                    throw e
                }
            }

            while (true) {
                writeInteractivePrompt(message, defaultHint)
                match (readNextInputLine()) {
                    case Some(input) =>
                        match (ProgressLogger.parseConfirmValue(input, defaultValue: defaultValue)) {
                            case Some(value) =>
                                endInteractive()
                                return value
                            case None => writeInteractiveError("Please enter y or n.")
                        }
                    case None =>
                        match (defaultValue) {
                            case Some(value) =>
                                endInteractive()
                                return value
                            case None =>
                                endInteractive()
                                throw Exception("confirm could not read input from stdin")
                        }
                }
            }
            throw Exception("confirm exited without a value")
        } catch (e: Exception) {
            if (isInteractiveActive()) {
                endInteractive()
            }
            throw e
        }
    }

    public func select(message: String, options: Array<String>, defaultIndex!: ?Int = None): SelectResult {
        if (options.size == 0) {
            throw Exception("select requires at least one option")
        }

        beginInteractive("select")

        try {
            if (!canUseRawInteractive()) {
                let defaultHint = match (defaultIndex) {
                    case Some(index) => Some("${index + 1}")
                    case None => None<String>
                }

                writer.writeln(message)
                for (i in 0..options.size) {
                    writer.writeln("  ${i + 1}. ${options[i]}")
                }
                writer.flush()

                while (true) {
                    writeInteractivePrompt("Select one", defaultHint)
                    match (readNextInputLine()) {
                        case Some(input) =>
                            match (ProgressLogger.parseSelectValue(input, options.size, defaultIndex: defaultIndex)) {
                                case Some(index) =>
                                    endInteractive()
                                    return SelectResult.Selected(index)
                                case None => writeInteractiveError("Enter a number between 1 and ${options.size}.")
                            }
                        case None =>
                            match (defaultIndex) {
                                case Some(index) =>
                                    endInteractive()
                                    return SelectResult.Selected(index)
                                case None =>
                                    endInteractive()
                                    throw Exception("select could not read input from stdin")
                            }
                    }
                }
            }

            if (!terminalBackend.enterKeyMode()) {
                endInteractive()
                throw Exception("select could not enter raw terminal mode")
            }

            let state = SelectMenuState(options.size, defaultIndex: defaultIndex)
            var renderedLines = renderSelectMenu(message, options, state.cursor)

            try {
                while (true) {
                    match (readNextKey()) {
                        case TerminalKey.Up =>
                            state.moveUp()
                        case TerminalKey.Down =>
                            state.moveDown()
                        case TerminalKey.Enter =>
                            clearRenderedInteractiveBlock(renderedLines)
                            terminalBackend.leaveKeyMode()
                            endInteractive()
                            return state.result()
                        case TerminalKey.Escape =>
                            clearRenderedInteractiveBlock(renderedLines)
                            terminalBackend.leaveKeyMode()
                            endInteractive()
                            return SelectResult.Cancelled
                        case TerminalKey.Eof =>
                            clearRenderedInteractiveBlock(renderedLines)
                            terminalBackend.leaveKeyMode()
                            endInteractive()
                            throw Exception("select could not read input from stdin")
                        case _ => ()
                    }

                    clearRenderedInteractiveBlock(renderedLines)
                    renderedLines = renderSelectMenu(message, options, state.cursor)
                }
            } catch (e: Exception) {
                terminalBackend.leaveKeyMode()
                throw e
            }

            throw Exception("select exited without a value")
        } catch (e: Exception) {
            if (isInteractiveActive()) {
                endInteractive()
            }
            throw e
        }
    }

    public func multiSelect(
        message: String,
        options: Array<String>,
        defaultIndices!: Array<Int> = []
    ): MultiSelectResult {
        if (options.size == 0) {
            throw Exception("multiSelect requires at least one option")
        }

        beginInteractive("multiSelect")

        try {
            if (!canUseRawInteractive()) {
                let defaultHint = if (defaultIndices.isEmpty()) {
                    None<String>
                } else {
                    Some(String.join(defaultIndices.map { index: Int => "${index + 1}" }, delimiter: ","))
                }

                writer.writeln(message)
                for (i in 0..options.size) {
                    writer.writeln("  ${i + 1}. ${options[i]}")
                }
                writer.flush()

                while (true) {
                    writeInteractivePrompt("Select one or more", defaultHint)
                    match (readNextInputLine()) {
                        case Some(input) =>
                            match (ProgressLogger.parseMultiSelectValue(input, options.size, defaultIndices: defaultIndices)) {
                                case Some(indices) =>
                                    endInteractive()
                                    return MultiSelectResult.Selected(indices)
                                case None =>
                                    writeInteractiveError("Enter comma-separated numbers or ranges like 1,3-5.")
                            }
                        case None =>
                            if (!defaultIndices.isEmpty()) {
                                endInteractive()
                                return MultiSelectResult.Selected(defaultIndices)
                            }
                            endInteractive()
                            throw Exception("multiSelect could not read input from stdin")
                    }
                }
            }

            if (!terminalBackend.enterKeyMode()) {
                endInteractive()
                throw Exception("multiSelect could not enter raw terminal mode")
            }

            let state = MultiSelectMenuState(options.size, defaultIndices: defaultIndices)
            var renderedLines = renderMultiSelectMenu(message, options, state)

            try {
                while (true) {
                    match (readNextKey()) {
                        case TerminalKey.Up =>
                            state.moveUp()
                        case TerminalKey.Down =>
                            state.moveDown()
                        case TerminalKey.Space =>
                            state.toggleCurrent()
                        case TerminalKey.SelectAll =>
                            state.selectAll()
                        case TerminalKey.Clear =>
                            state.clearAll()
                        case TerminalKey.Enter =>
                            match (state.confirm()) {
                                case Some(result) =>
                                    clearRenderedInteractiveBlock(renderedLines)
                                    terminalBackend.leaveKeyMode()
                                    endInteractive()
                                    return result
                                case None =>
                                    clearRenderedInteractiveBlock(renderedLines)
                                    writeInteractiveError("Select at least one item before confirming.")
                                    renderedLines = renderMultiSelectMenu(message, options, state) + 1
                                    continue
                            }
                        case TerminalKey.Escape =>
                            clearRenderedInteractiveBlock(renderedLines)
                            terminalBackend.leaveKeyMode()
                            endInteractive()
                            return MultiSelectResult.Cancelled
                        case TerminalKey.Eof =>
                            clearRenderedInteractiveBlock(renderedLines)
                            terminalBackend.leaveKeyMode()
                            endInteractive()
                            throw Exception("multiSelect could not read input from stdin")
                        case _ => ()
                    }

                    clearRenderedInteractiveBlock(renderedLines)
                    renderedLines = renderMultiSelectMenu(message, options, state)
                }
            } catch (e: Exception) {
                terminalBackend.leaveKeyMode()
                throw e
            }

            throw Exception("multiSelect exited without a value")
        } catch (e: Exception) {
            if (isInteractiveActive()) {
                endInteractive()
            }
            throw e
        }
    }

    public func updatePipelineProgress(rendered: Int, parsed: Int, total: Int, prefix!: String = "Processing..."): Unit {
        mutex.lock()
        let progressBar = ProgressLogger.generatePipelineProgressBar(rendered, parsed, total)
        currentMessage = "${prefix} ${progressBar}"

        if (spinnerRunning.load()) {
            clearCurrentLineUnsafe()
            let spinnerFrame = spinner.next()
            let coloredSpinner = if (enableColor) { ColorUtil.colorize(spinnerFrame, AnsiColor.Cyan) } else { spinnerFrame }
            let coloredMessage = if (enableColor) { ColorUtil.colorize(currentMessage, AnsiColor.Cyan) } else { currentMessage }
            let line = "${coloredSpinner} ${coloredMessage}"
            writer.write(line)
            writer.flush()
            lastLineLength = calculateDisplayLength(line)
        }

        mutex.unlock()
    }

    public func printProgress(message: String): Unit {
        mutex.lock()
        clearCurrentLineUnsafe()

        let spinnerFrame = spinner.next()
        let coloredSpinner = if (enableColor) { ColorUtil.colorize(spinnerFrame, AnsiColor.Cyan) } else { spinnerFrame }
        let coloredMessage = if (enableColor) { ColorUtil.colorize(message, AnsiColor.Cyan) } else { message }
        let line = "${coloredSpinner} ${coloredMessage}"
        writer.write(line)
        writer.flush()
        lastLineLength = calculateDisplayLength(line)
        isInProgress = true

        mutex.unlock()
    }

    public func printProgress(percent: Int, width!: Int = 20, color!: AnsiColor = AnsiColor.Cyan): Unit {
        printProgressWithBar(None<String>, ProgressLogger.generateProgressBar(percent, width: width), color)
    }

    public func printProgress(
        message: String,
        percent: Int,
        width!: Int = 20,
        color!: AnsiColor = AnsiColor.Cyan
    ): Unit {
        printProgressWithBar(Some(message), ProgressLogger.generateProgressBar(percent, width: width), color)
    }

    public func printProgress(
        primaryPercent: Int,
        secondaryPercent: Int,
        width!: Int = 20,
        color!: AnsiColor = AnsiColor.Cyan
    ): Unit {
        printProgressWithBar(
            None<String>,
            ProgressLogger.generateProgressBar(primaryPercent, secondaryPercent, width: width),
            color
        )
    }

    public func printProgress(
        message: String,
        primaryPercent: Int,
        secondaryPercent: Int,
        width!: Int = 20,
        color!: AnsiColor = AnsiColor.Cyan
    ): Unit {
        printProgressWithBar(
            Some(message),
            ProgressLogger.generateProgressBar(primaryPercent, secondaryPercent, width: width),
            color
        )
    }

    private func printProgressWithBar(message: ?String, bar: String, color: AnsiColor): Unit {
        let decoratedBar = if (enableColor) { ColorUtil.colorize(bar, color) } else { bar }
        let line = match (message) {
            case Some(text) => "${text} ${decoratedBar}"
            case None => decoratedBar
        }
        printProgress(line)
    }

    public func stopProgress(): Unit {
        mutex.lock()
        if (isInProgress) {
            clearCurrentLineUnsafe()
            lastLineLength = 0
            isInProgress = false
            spinner.reset()
        }
        mutex.unlock()
    }

    public func printSuccess(message: String): Unit {
        mutex.lock()
        ensureIdleForMessageUnsafe("printSuccess")

        let icon = if (enableColor) { ColorUtil.colorize("✓", AnsiColor.Green) } else { "✓" }
        let coloredMessage = if (enableColor) { ColorUtil.colorize(message, AnsiColor.Green) } else { message }
        writer.writeln("${icon} ${coloredMessage}")

        mutex.unlock()
    }

    public func printError(message: String): Unit {
        mutex.lock()
        ensureIdleForMessageUnsafe("printError")

        let icon = if (enableColor) { ColorUtil.colorize("✗", AnsiColor.Red) } else { "✗" }
        let coloredMessage = if (enableColor) { ColorUtil.colorize(message, AnsiColor.Red) } else { message }
        writer.writeln("${icon} ${coloredMessage}")

        mutex.unlock()
    }

    public func printWarning(message: String): Unit {
        mutex.lock()
        ensureIdleForMessageUnsafe("printWarning")

        let icon = if (enableColor) { ColorUtil.colorize("⚠", AnsiColor.Yellow) } else { "⚠" }
        let coloredMessage = if (enableColor) { ColorUtil.colorize(message, AnsiColor.Yellow) } else { message }
        writer.writeln("${icon} ${coloredMessage}")

        mutex.unlock()
    }

    public func printInfo(message: String, icon!: String = "ℹ", color!: AnsiColor = AnsiColor.Blue): Unit {
        mutex.lock()
        ensureIdleForMessageUnsafe("printInfo")

        let coloredIcon = if (enableColor) { ColorUtil.colorize(icon, color) } else { icon }
        let coloredMessage = if (enableColor) { ColorUtil.colorize(message, color) } else { message }
        writer.writeln("${coloredIcon} ${coloredMessage}")

        mutex.unlock()
    }

    public func log(message: String): Unit {
        mutex.lock()
        ensureIdleForMessageUnsafe("log")
        writer.writeln(message)
        mutex.unlock()
    }

    public func printlnColored(message: String, color: AnsiColor): Unit {
        mutex.lock()
        ensureIdleForMessageUnsafe("printlnColored")

        let coloredMessage = if (enableColor) { ColorUtil.colorize(message, color) } else { message }
        writer.writeln(coloredMessage)

        mutex.unlock()
    }

    public func ensureNewLine(): Unit {
        mutex.lock()
        if (isInProgress) {
            writer.writeln("")
            lastLineLength = 0
            isInProgress = false
            spinner.reset()
        }
        mutex.unlock()
    }

    private static func repeatString(str: String, count: Int): String {
        if (count <= 0) {
            return ""
        }

        let capacity = str.size * count
        let sb = StringBuilder(capacity)
        for (_ in 0..count) {
            sb.append(str)
        }
        return sb.toString()
    }

    private static func clampPercent(percent: Int): Int {
        if (percent < 0) {
            return 0
        }
        if (percent > 100) {
            return 100
        }
        return percent
    }

    public static func generateProgressBar(percent: Int, width!: Int = 20): String {
        let clamped = clampPercent(percent)
        let filledWidth = (clamped * width) / 100
        let emptyWidth = width - filledWidth
        return "[${repeatString("█", filledWidth)}${repeatString("░", emptyWidth)}] ${clamped}%"
    }

    public static func generateProgressBar(primaryPercent: Int, secondaryPercent: Int, width!: Int = 20): String {
        let primary = clampPercent(primaryPercent)
        let secondary = clampPercent(secondaryPercent)
        let startPercent = if (primary <= secondary) { primary } else { secondary }
        let endPercent = if (primary <= secondary) { secondary } else { primary }
        let startWidth = (startPercent * width) / 100
        let endWidth = (endPercent * width) / 100
        let middleWidth = endWidth - startWidth
        let emptyWidth = width - endWidth
        return "[${repeatString("█", startWidth)}${repeatString("▒", middleWidth)}${repeatString("░", emptyWidth)}] ${startPercent}%/${endPercent}%"
    }

    public static func generateScanProgressBar(current: Int, total: Int, width!: Int = 24): String {
        if (total == 0) {
            return "[${repeatString("░", width)}]"
        }

        let filledWidth = (current * width) / total
        let emptyWidth = width - filledWidth
        return "[${repeatString("▓", filledWidth)}${repeatString("░", emptyWidth)}]"
    }

    public static func generateMultiPhaseProgressBar(phases: Array<Int>, symbols: Array<String>, width!: Int = 24): String {
        if (phases.size == 0 || symbols.size == 0 || phases.size != symbols.size) {
            return "[${repeatString("░", width)}]"
        }

        let total = phases[phases.size - 1]
        if (total == 0) {
            return "[${repeatString(symbols[symbols.size - 1], width)}]"
        }

        var charCounts = Array<Int>(phases.size) { _ => 0 }
        for (i in 0..phases.size) {
            charCounts[i] = (phases[i] * width) / total
        }

        let sb = StringBuilder()
        sb.append("[")
        for (i in 0..phases.size) {
            let startChar = if (i == 0) { 0 } else { charCounts[i - 1] }
            let endChar = charCounts[i]
            let count = endChar - startChar
            if (count > 0) {
                sb.append(repeatString(symbols[i], count))
            }
        }

        let currentLength = sb.toString().toRuneArray().size - 1
        if (currentLength < width) {
            sb.append(repeatString(symbols[symbols.size - 1], width - currentLength))
        }

        sb.append("]")
        return sb.toString()
    }

    public static func generatePipelineProgressBar(rendered: Int, parsed: Int, total: Int, width!: Int = 24): String {
        if (total == 0) {
            return "[${repeatString("░", width)}] 0 rendered, 0 parsed, 0 total"
        }

        let phases = [rendered, parsed, total]
        let symbols = ["▓", "▒", "░"]
        let bar = generateMultiPhaseProgressBar(phases, symbols, width: width)
        return "${bar} ${rendered} rendered, ${parsed} parsed, ${total} total"
    }
}

public let progressLogger = ProgressLogger()
public let interactiveForm = InteractiveForm(logger: progressLogger)
