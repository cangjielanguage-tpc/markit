package markit_kit.utils

public enum KitLogLevel {
    Error | Warn | Info | Success | Verbose | Plain
}

public enum KitProgressEvent {
    Start(String)
    | Update(String)
    | Stop
    | StopSuccess(String)
    | Pipeline(Int64, Int64, Int64, String)
}

public interface KitHookSink {
    func log(level: KitLogLevel, message: String): Unit
    func write(message: String): Unit
    func newLine(): Unit
    func color(message: String, style: String): String
    func progress(event: KitProgressEvent): Unit
    func hasActiveTransientLine(): Bool
    func dismissTransientLine(): Unit
}

public class NoopKitHookSink <: KitHookSink {
    public init() {}

    public func log(_level: KitLogLevel, _message: String): Unit {}

    public func write(_message: String): Unit {}

    public func newLine(): Unit {}

    public func color(message: String, _style: String): String {
        return message
    }

    public func progress(_event: KitProgressEvent): Unit {}

    public func hasActiveTransientLine(): Bool {
        return false
    }

    public func dismissTransientLine(): Unit {}
}

public class KitHooks {
    private static var sink: KitHookSink = NoopKitHookSink()

    public static func install(next: KitHookSink): Unit {
        sink = next
    }

    public static func reset(): Unit {
        sink = NoopKitHookSink()
    }

    public static func err(message: String): Unit {
        sink.log(KitLogLevel.Error, message)
    }

    public static func warn(message: String): Unit {
        sink.log(KitLogLevel.Warn, message)
    }

    public static func info(message: String): Unit {
        sink.log(KitLogLevel.Info, message)
    }

    public static func success(message: String): Unit {
        sink.log(KitLogLevel.Success, message)
    }

    public static func verbose(message: String): Unit {
        sink.log(KitLogLevel.Verbose, message)
    }

    public static func plain(message: String): Unit {
        sink.log(KitLogLevel.Plain, message)
    }

    public static func write(message: String): Unit {
        sink.write(message)
    }

    public static func newLine(): Unit {
        sink.newLine()
    }

    public static func color(message: String, style: String): String {
        return sink.color(message, style)
    }

    public static func spinner(message: String): Unit {
        sink.progress(KitProgressEvent.Start(message))
    }

    public static func updateSpinner(message: String): Unit {
        sink.progress(KitProgressEvent.Update(message))
    }

    public static func stopSpinner(): Unit {
        sink.progress(KitProgressEvent.Stop)
    }

    public static func stopSpinnerSuccess(message: String): Unit {
        sink.progress(KitProgressEvent.StopSuccess(message))
    }

    public static func progress(message: String): Unit {
        sink.progress(KitProgressEvent.Start(message))
    }

    public static func stopProgress(): Unit {
        sink.progress(KitProgressEvent.Stop)
    }

    public static func insertBeforeErr(message: String): Unit {
        sink.log(KitLogLevel.Error, message)
    }

    public static func insertBeforeWarn(message: String): Unit {
        sink.log(KitLogLevel.Warn, message)
    }

    public static func hasActiveTransientLine(): Bool {
        return sink.hasActiveTransientLine()
    }

    public static func dismissTransientLine(): Unit {
        sink.dismissTransientLine()
    }

    public static func updatePipelineProgress(
        rendered: Int64,
        parsed: Int64,
        total: Int64,
        prefix!: String = ""
    ): Unit {
        sink.progress(KitProgressEvent.Pipeline(rendered, parsed, total, prefix))
    }

    public static func progressBar(percent: Int64, width!: Int64 = 20): String {
        if (width <= 0) {
            return ""
        }
        let clamped = if (percent < 0) {
            0
        } else if (percent > 100) {
            100
        } else {
            percent
        }
        let filled = (clamped * width) / 100
        var result = "["
        for (i in 0..width) {
            result += if (i < filled) { "=" } else { " " }
        }
        return result + "]"
    }

    public static func scanProgressBar(done: Int64, total: Int64, width!: Int64 = 24): String {
        let percent = if (total <= 0) { 100 } else { (done * 100) / total }
        return progressBar(percent, width: width)
    }

    public static func pipelineProgressBar(rendered: Int64, parsed: Int64, total: Int64): String {
        let bar = scanProgressBar(rendered, total, width: 24)
        return "${bar} rendered ${rendered}, parsed ${parsed}, total ${total}"
    }
}
