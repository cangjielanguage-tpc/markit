package markit.plugins.standard.block.divider

import markit.core.block.LeafBlockParser
import markit.core.nodes.Node
import markit.core.session.ParseSession

public class DividerBlockParser <: LeafBlockParser {
    public prop name: String {
        get() {
            return "DividerBlockParser"
        }
    }

    public prop ownerPlugin: String {
        get() {
            return "DividerPlugin"
        }
    }

    public prop priority: Int64 {
        get() {
            return 90
        }
    }

    public prop startBytes: Array<Byte> {
        get() {
            return [b'-', b'*', b'_']
        }
    }

    public prop acceptsAnyNonBlank: Bool {
        get() {
            return false
        }
    }

    public func tryParse(session: ParseSession, line: String): ?Node {
        let trimmed = line.trimAscii()
        if (trimmed.isEmpty()) {
            return None
        }
        let marker = trimmed[0]
        if (marker != b'-' && marker != b'*' && marker != b'_') {
            return None
        }

        var count: Int64 = 0
        for (b in trimmed) {
            if (b == marker) {
                count += 1
            } else if (b != b' ' && b != b'\t') {
                return None
            }
        }

        if (count < 3) {
            return None
        }
        return Some(session.attachNode(DividerNode(
            session.allocateNodeId(),
            session.currentLineSpan(),
            marker: marker,
            markerCount: count
        )))
    }
}
