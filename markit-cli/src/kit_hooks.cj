package markit_cli

import commandline.terminal.{progressLogger, ProgressLogger, ColorUtil, AnsiColor}
import markit_kit.utils.{KitHookSink, KitLogLevel, KitProgressEvent}

public class CommandlineKitHookSink <: KitHookSink {
    public init() {}

    public func log(level: KitLogLevel, message: String): Unit {
        match (level) {
            case KitLogLevel.Error => progressLogger.printError(message)
            case KitLogLevel.Warn => progressLogger.printWarning(message)
            case KitLogLevel.Info => progressLogger.printInfo(message)
            case KitLogLevel.Success => progressLogger.printSuccess(message)
            case KitLogLevel.Verbose => progressLogger.printInfo(message, icon: "·", color: AnsiColor.Gray)
            case KitLogLevel.Plain => progressLogger.log(message)
        }
    }

    public func write(message: String): Unit {
        print(message, flush: true)
    }

    public func newLine(): Unit {
        progressLogger.log("")
    }

    public func color(message: String, style: String): String {
        if (style == "bold") {
            return ColorUtil.colorize(message, AnsiColor.Bold)
        }
        return message
    }

    public func progress(event: KitProgressEvent): Unit {
        match (event) {
            case KitProgressEvent.Start(message) =>
                progressLogger.startSpinner(message)
            case KitProgressEvent.Update(message) =>
                progressLogger.updateSpinnerMessage(message)
            case KitProgressEvent.Stop =>
                progressLogger.stopSpinner()
            case KitProgressEvent.StopSuccess(message) =>
                progressLogger.stopSpinner()
                progressLogger.printSuccess(message)
            case KitProgressEvent.Pipeline(rendered, parsed, total, prefix) =>
                progressLogger.updateSpinnerMessage("${prefix} ${pipelineProgressBar(rendered, parsed, total)}")
        }
    }

    private func pipelineProgressBar(rendered: Int64, parsed: Int64, total: Int64): String {
        let width: Int64 = 24
        let percent = if (total <= 0) { 100 } else { (rendered * 100) / total }
        let filled = (percent * width) / 100
        var bar = "["
        for (i in 0..width) {
            bar += if (i < filled) { "=" } else { " " }
        }
        return "${bar}] rendered ${rendered}, parsed ${parsed}, total ${total}"
    }

    public func hasActiveTransientLine(): Bool {
        return progressLogger.hasActiveTransientLine()
    }

    public func dismissTransientLine(): Unit {
        progressLogger.dismissTransientLine()
    }
}
