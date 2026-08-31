package markit.plugins.standard.inline.hard_break

import markit.core.session.{SessionState, SessionStateSnapshot}

public class HardBreakState <: SessionState {
    public func reset(): Unit {}

    public func snapshot(): SessionStateSnapshot {
        return SessionStateSnapshot("HardBreakPlugin.enabled")
    }
}
