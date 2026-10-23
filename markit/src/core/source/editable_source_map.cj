package markit.core.source

import std.collection.ArrayList
import markit.core.editing.*

// A map owns its segment array. An equal-length segment maps byte-for-byte;
// a length-changing transformation has unique anchors only at its endpoints.
public class SegmentSourceMap <: ComposableSourceMap {
    private let mapped: Array<SourceMappingSegment>

    public SegmentSourceMap(segments: Array<SourceMappingSegment>) {
        var previousEnd: Int64 = 0
        for (segment in segments) {
            if (segment.viewStart < previousEnd || segment.viewEnd == segment.viewStart) {
                throw IllegalArgumentException("Source map segments must be ordered, nonempty and disjoint")
            }
            previousEnd = segment.viewEnd
        }
        mapped = segments.clone()
    }

    public func mapByte(viewOffset: Int64, affinity: AnchorAffinity): ?SourceAnchor {
        if (let Some(anchor) <- mapPoint(viewOffset, affinity)) {
            return Some(SourceAnchor(anchor.source, anchor.byteOffset, affinity: affinity))
        }
        return None
    }

    internal func mapPoint(viewOffset: Int64, affinity: AnchorAffinity): ?SourceAnchor {
        if (viewOffset < 0 || mapped.isEmpty()) { return None }
        // The rightmost start at or before the requested boundary.
        var low: Int64 = 0; var high = mapped.size
        while (low < high) {
            let mid = low + (high - low) / 2
            if (mapped[mid].viewStart <= viewOffset) { low = mid + 1 } else { high = mid }
        }
        if (low == 0) { return None }
        var index = low - 1
        if (affinity == AnchorAffinity.Before && mapped[index].viewStart == viewOffset && index > 0 &&
            mapped[index - 1].viewEnd == viewOffset) { index -= 1 }
        let segment = mapped[index]
        if (viewOffset < segment.viewStart || viewOffset > segment.viewEnd || segment.synthetic) { return None }
        if (viewOffset == segment.viewStart) {
            return Some(SourceAnchor(segment.source, segment.rawStart, affinity: AnchorAffinity.After))
        }
        if (viewOffset == segment.viewEnd) {
            return Some(SourceAnchor(segment.source, segment.rawEnd, affinity: AnchorAffinity.Before))
        }
        if (segment.viewEnd - segment.viewStart != segment.rawEnd - segment.rawStart) { return None }
        return Some(SourceAnchor(segment.source, segment.rawStart + viewOffset - segment.viewStart, affinity: affinity))
    }

    public func segments(start: Int64, end: Int64): Array<SourceMappingSegment> {
        if (start < 0 || end < start) { throw IllegalArgumentException("Invalid mapped range") }
        let result = ArrayList<SourceMappingSegment>()
        if (start == end) { return result.toArray() }
        var low: Int64 = 0; var high = mapped.size
        while (low < high) {
            let mid = low + (high - low) / 2
            if (mapped[mid].viewEnd <= start) { low = mid + 1 } else { high = mid }
        }
        var index = low
        while (index < mapped.size && mapped[index].viewStart < end) {
            let segment = mapped[index]
            let first = if (start > segment.viewStart) { start } else { segment.viewStart }
            let last = if (end < segment.viewEnd) { end } else { segment.viewEnd }
            let linear = segment.viewEnd - segment.viewStart == segment.rawEnd - segment.rawStart
            result.add(SourceMappingSegment(first, last,
                if (linear) { segment.rawStart + first - segment.viewStart } else { segment.rawStart },
                if (linear) { segment.rawStart + last - segment.viewStart } else { segment.rawEnd },
                segment.source, synthetic: segment.synthetic))
            index += 1
        }
        return result.toArray()
    }

    public func compose(parent: ComposableSourceMap): ComposableSourceMap {
        return ComposedSourceMap(this, parent)
    }
}

private class ComposedSourceMap <: ComposableSourceMap {
    ComposedSourceMap(private let child: ComposableSourceMap, private let parent: ComposableSourceMap) {}

    public func mapByte(viewOffset: Int64, affinity: AnchorAffinity): ?SourceAnchor {
        if (let Some(anchor) <- mapPoint(viewOffset, affinity)) {
            return Some(SourceAnchor(anchor.source, anchor.byteOffset, affinity: affinity))
        }
        return None
    }

    internal func mapPoint(viewOffset: Int64, affinity: AnchorAffinity): ?SourceAnchor {
        if (let Some(anchor) <- sourceMapPoint(child, viewOffset, affinity)) {
            return sourceMapPoint(parent, anchor.byteOffset, anchor.affinity)
        }
        return None
    }

    public func segments(start: Int64, end: Int64): Array<SourceMappingSegment> {
        let result = ArrayList<SourceMappingSegment>()
        for (segment in child.segments(start, end)) {
            if (segment.synthetic) { result.add(segment); continue }
            let linear = segment.viewEnd - segment.viewStart == segment.rawEnd - segment.rawStart
            let origins = parent.segments(segment.rawStart, segment.rawEnd)
            if (origins.isEmpty()) {
                result.add(SourceMappingSegment(segment.viewStart, segment.viewEnd, segment.rawStart,
                    segment.rawEnd, segment.source, synthetic: true))
            }
            for (origin in origins) {
                // A nonlinear byte may derive from several raw spans. Retain
                // every span instead of fabricating one enclosing raw range.
                let first = if (linear) { segment.viewStart + origin.viewStart - segment.rawStart } else { segment.viewStart }
                let last = if (linear) { segment.viewStart + origin.viewEnd - segment.rawStart } else { segment.viewEnd }
                result.add(SourceMappingSegment(first, last, origin.rawStart, origin.rawEnd,
                    origin.source, synthetic: origin.synthetic))
            }
        }
        return result.toArray()
    }

    public func compose(parent: ComposableSourceMap): ComposableSourceMap {
        return ComposedSourceMap(this, parent)
    }
}

private func sourceMapPoint(map: ComposableSourceMap, offset: Int64, affinity: AnchorAffinity): ?SourceAnchor {
    if (let Some(segmentMap) <- (map as SegmentSourceMap)) { return segmentMap.mapPoint(offset, affinity) }
    if (let Some(composedMap) <- (map as ComposedSourceMap)) { return composedMap.mapPoint(offset, affinity) }
    return map.mapByte(offset, affinity)
}

public class MappedText {
    public MappedText(public let text: String, public let sourceMap: ComposableSourceMap) {}
}

// Callers choose retained ranges. This builder has no knowledge of markers,
// indentation, Markdown, or the syntax that requested the transformation.
public class MappedTextBuilder {
    private let output = StringBuilder()
    private let mapped = ArrayList<SourceMappingSegment>()
    private var length: Int64 = 0
    public MappedTextBuilder(private let syntheticSource!: SourceVersionIdentity = SourceVersionIdentity("synthetic", 0)) {}

    public func appendSource(source: EditableSourceVersion, start: Int64, end: Int64): Unit {
        appendMapped(source.sliceBytes(start, end), source.identity, start, end, false)
    }

    public func appendTransformed(text: String, source: EditableSourceVersion, start: Int64, end: Int64): Unit {
        if (source.coordinateAtByte(start).isNone() || source.coordinateAtByte(end).isNone() || end < start) {
            throw IllegalArgumentException("Invalid transformed source range")
        }
        appendMapped(text, source.identity, start, end, false)
    }

    public func appendSynthetic(text: String): Unit {
        appendMapped(text, syntheticSource, 0, 0, true)
    }

    public func appendNormalized(source: EditableSourceVersion, start: Int64, end: Int64): Unit {
        let text = source.sliceBytes(start, end)
        var runStart: Int64 = 0; var p: Int64 = 0
        while (p < text.size) {
            if (text[p] == 13) {
                if (runStart < p) { appendMapped(text[runStart..p], source.identity, start + runStart, start + p, false) }
                let width: Int64 = if (p + 1 < text.size && text[p + 1] == 10) { 2 } else { 1 }
                appendMapped("\n", source.identity, start + p, start + p + width, false)
                p += width; runStart = p
            } else { p += 1 }
        }
        if (runStart < text.size) { appendMapped(text[runStart..text.size], source.identity, start + runStart, end, false) }
    }

    public func build(): MappedText {
        return MappedText(output.toString().clone(), SegmentSourceMap(mapped.toArray()))
    }

    private func appendMapped(text: String, source: SourceVersionIdentity, start: Int64, end: Int64, synthetic: Bool): Unit {
        if (text.isEmpty()) { return }
        output.append(text)
        mapped.add(SourceMappingSegment(length, length + text.size, start, end, source, synthetic: synthetic))
        length += text.size
    }
}
