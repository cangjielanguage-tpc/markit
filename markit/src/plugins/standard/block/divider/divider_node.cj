package markit.plugins.standard.block.divider

import markit.core.nodes.Node
import markit.core.source.SourceSpan

public class DividerNode <: Node {
    public let marker: Byte
    public let markerCount: Int64

    public init(
        id: Int64,
        sourceSpan: SourceSpan,
        marker!: Byte = b'-',
        markerCount!: Int64 = 3
    ) {
        super("Divider", id: id, sourceSpan: sourceSpan)
        this.marker = marker
        this.markerCount = markerCount
        setString("marker", String.fromUtf8([marker]))
        setInt("markerCount", markerCount)
    }

    public override prop name: String {
        get() {
            return "DividerNode"
        }
    }

    public func isHyphenLine(): Bool {
        return marker == b'-' && markerCount >= 3
    }
}
