package markit_cli.commands

import markit_kit.utils.{KitHookSink, KitLogLevel, KitProgressEvent}
import std.env.getStdErr

/** Keep diagnostics, but never allow terminal animation into the JSON pipe. */
class PreviewKitHookSink <: KitHookSink {
    public func log(level: KitLogLevel, message: String): Unit {
        let output = getStdErr()
        output.writeln(message)
        output.flush()
    }
    public func write(message: String): Unit {
        let output = getStdErr()
        output.write(message)
        output.flush()
    }
    public func newLine(): Unit { getStdErr().writeln("") }
    public func color(message: String, _style: String): String { return message }
    public func progress(_event: KitProgressEvent): Unit {}
    public func hasActiveTransientLine(): Bool { return false }
    public func dismissTransientLine(): Unit {}
}
