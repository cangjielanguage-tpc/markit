package markit.plugins.standard.inline.reference_link

import std.collection.ArrayList
import markit.core.block.BlockEditingContext
import markit.core.editing.*
import markit.core.inline.*
import markit.core.nodes.{Node, TextNode, NodeCodec, PersistentNodeCapture, PersistentNodeBundle}
import markit.core.session.ParseSession
import markit.core.source.SourceSpan
import markit.plugins.standard.inline.link.LinkNode
import markit.plugins.standard.inline.image.ImageNode
import markit.plugins.standard.editing.{StandardInlineChildConsumer, standardNormalizedRaw}

private class ReferenceGrammarPayload <: IncrementalStatePayload {
    public func clonePayload(): IncrementalStatePayload { return ReferenceGrammarPayload() }
    public func fingerprint(): String { return "reference-reader-v1" }
}

public func referenceRegistry(session: ParseSession): ?ReferenceLinkRegistry {
    if (let Some(state) <- session.symbolTables.get("ReferenceLinkPlugin.registry")) {
        if (let registry: ReferenceLinkRegistry <- state) { return Some(registry) }
    }
    return None
}

public func retainReferenceSyntax(node: Node, syntax: ReferenceSyntax): Unit {
    node.setString("refLabel", syntax.label)
    node.setString("refForm", syntax.form)
    node.setString("refRaw", syntax.raw)
    node.setString("refText", syntax.text)
    node.setBool("refImage", syntax.image)
}

public open class ReferenceParserBase <: InlineParser & InlineEditingFacet & StandardInlineChildConsumer {
    private var childFactory: ?() -> InlineEditingSession = None
    private var childCodec: ?NodeCodec = None
    public ReferenceParserBase(private let image: Bool) {}
    public prop name: String { get() { return if (image) { "ImageReferenceParser" } else { "ReferenceLinkParser" } } }
    public prop ownerPlugin: String { get() { return "ReferenceLinkPlugin" } }
    public prop priority: Int64 { get() { return if (image) { 600 } else { 400 } } }
    public prop startBytes: Array<Byte> { get() { return if (image) { [b'!'] } else { [b'['] } } }
    public prop owner: String { get() { return ownerPlugin } }
    public prop grammarVersion: String { get() { return if (childFactory.isSome()) { "reference-reader-v1-children" } else { "reference-reader-v1" } } }
    public prop hasEditingChildren: Bool { get() { return childFactory.isSome() } }
    public func configureEditingChildren(factory: () -> InlineEditingSession): Unit {
        if (childFactory.isSome()) { throw IllegalArgumentException("Reference editing children are already configured") }
        let codec = NodeCodec(); registerReferenceEditingCodecs(codec)
        childCodec = Some(codec); childFactory = Some(factory)
    }
    public prop supportsIncremental: Bool { get() { return true } }
    public prop incrementalFacet: ?IncrementalParserFacet { get() { return Some(this) } }
    public prop hasStateCodec: Bool { get() { return true } }
    public prop hasEffectRollback: Bool { get() { return true } }
    public prop hasReadEvidence: Bool { get() { return true } }
    public prop hasNodeCodec: Bool { get() { return true } }
    public func checkpoint(context: IncrementalParserContext): ?IncrementalCheckpoint {
        return Some(IncrementalCheckpoint(context.documentId, owner, context.sourceVersion,
            ReferenceGrammarPayload(), syntaxContext: grammarVersion))
    }
    public func restore(context: IncrementalParserContext, point: IncrementalCheckpoint): Bool {
        return point.documentId == context.documentId && point.owner == owner &&
            point.sourceVersion <= context.sourceVersion && point.syntaxContext == grammarVersion &&
            (point.payload is ReferenceGrammarPayload)
    }
    public func rollbackEffects(context: IncrementalParserContext, point: IncrementalCheckpoint): Bool {
        return restore(context, point) && context.revokeOwnerEffects(owner)
    }
    public func syntaxEquivalent(a: IncrementalCheckpoint, b: IncrementalCheckpoint): Bool {
        return a.documentId == b.documentId && a.owner == owner && b.owner == owner &&
            a.syntaxContext == grammarVersion && b.syntaxContext == grammarVersion &&
            (a.payload is ReferenceGrammarPayload) && (b.payload is ReferenceGrammarPayload)
    }
    public func readDependencies(): ArrayList<IncrementalReadDependency> { return ArrayList<IncrementalReadDependency>() }
    public func leftContext(_: InlineAttemptContext, _: Int64): String { return grammarVersion }
    public func rightContext(_: InlineAttemptContext, _: Int64): String { return grammarVersion }

    public func tryParse(session: ParseSession, input: String, startByte: Int64, endByte: Int64,
        baseSpan: SourceSpan): ?InlineParseResult {
        let read = { at: Int64 => if (at >= startByte && at < endByte) { Some(input[at]) } else { Option<Byte>.None } }
        let matched = matchReferenceSyntax(read, { a: Int64, b: Int64 => input[a..b] }, startByte, image)
        if (matched.isNone()) { return None }
        let syntax = matched.getOrThrow()
        let registry = referenceRegistry(session)
        if (registry.isNone()) { return None }
        let consumed = syntax.endByte - startByte
        let runes = InlineUtils.countRunes(syntax.raw)
        let definition = registry.getOrThrow().getDefinition(syntax.label)
        if (!image && syntax.form == "shortcut" && definition.isNone()) { return None }
        let node = makeNode(session, syntax, InlineUtils.spanWithRunes(baseSpan, 0, consumed, 0, runes), definition)
        if (!image) {
            session.appendInlineChildren(node, syntax.text, InlineUtils.spanWithRunes(baseSpan,
                syntax.textStart - startByte, syntax.textEnd - startByte,
                syntax.textStart - startByte, syntax.textStart - startByte + InlineUtils.countRunes(syntax.text)))
        }
        if (session.editingContext.isNone() && definition.isNone()) {
            if (image) { registry.getOrThrow().addUnresolvedImage(node) }
            else { registry.getOrThrow().addUnresolvedRef(node) }
        }
        return Some(InlineParseResult(node, consumed, runes))
    }

    public func parseAttempt(context: InlineAttemptContext, startByte: Int64): ?InlineParseResult {
        var before = startByte; var slashes: Int64 = 0
        while (before > 0) {
            before -= 1
            if (context.readByteOrEnd(before) != Some(b'\\')) { break }
            slashes += 1
        }
        if (slashes % 2 == 1) { return None }
        let matched = matchReferenceSyntax({ at: Int64 => context.readByteOrEnd(at) },
            { a: Int64, b: Int64 => context.view.sliceBytes(a, b) }, startByte, image)
        if (matched.isNone()) { return None }
        let syntax = matched.getOrThrow()
        var definition: ?LinkDefinition = None
        if (let Some(effect) <- context.readSemantic(referenceSemanticKey(syntax.label))) {
            if (let value: LinkDefinition <- effect.payload) { definition = Some(value) }
        }
        if (!image && syntax.form == "shortcut" && definition.isNone()) { return None }
        let begin = context.block.resolve(context.view.mapByte(startByte, AnchorAffinity.Before).getOrThrow()).getOrThrow()
        let end = context.block.resolve(context.view.mapByte(syntax.endByte, AnchorAffinity.After).getOrThrow()).getOrThrow()
        let span = SourceSpan(begin, end, context.block.source.coordinateAtByte(begin).getOrThrow().runeOffset,
            context.block.source.coordinateAtByte(end).getOrThrow().runeOffset)
        let session = context.block.session
        if (definition.isNone()) {
            let fallback = session.attachNode(TextNode(session.allocateNodeId(), span, InlineUtils.processEscapes(syntax.raw)))
            retainReferenceSyntax(fallback, syntax)
            return Some(InlineParseResult(fallback, syntax.endByte - startByte, InlineUtils.countRunes(syntax.raw)))
        }
        let node = makeNode(session, syntax, span, definition)
        if (!image && childFactory.isSome()) {
            let child = childFactory.getOrThrow()()
            let owner = PersistentNodeCapture(childCodec.getOrThrow()).capture(node, context.view.source).root
            let identity = "standard.reference.label:${node.id}"
            let body = referenceLabelView(context.view, syntax.textStart, syntax.textEnd, identity,
                normalizedRaw: standardNormalizedRaw(context.block))
            let snapshot = child.parseInitial(context.block, body, owner, semanticOwnerId: context.semanticOwner)
            return Some(EditingInlineParseResult(node, syntax.endByte - startByte, InlineUtils.countRunes(syntax.raw),
                Some(PersistentNodeBundle(snapshot.root)), Some(InlineNestedOwner(child, snapshot, ReferenceLabelProjection(identity)))))
        }
        if (!image) {
            let a = context.block.resolve(context.view.mapByte(syntax.textStart, AnchorAffinity.Before).getOrThrow()).getOrThrow()
            let b = context.block.resolve(context.view.mapByte(syntax.textEnd, AnchorAffinity.After).getOrThrow()).getOrThrow()
            session.appendInlineChildren(node, syntax.text, SourceSpan(a, b,
                context.block.source.coordinateAtByte(a).getOrThrow().runeOffset,
                context.block.source.coordinateAtByte(b).getOrThrow().runeOffset))
        }
        return Some(InlineParseResult(node, syntax.endByte - startByte, InlineUtils.countRunes(syntax.raw)))
    }

    private func makeNode(session: ParseSession, syntax: ReferenceSyntax, span: SourceSpan, definition: ?LinkDefinition): Node {
        let url = definition.map({ value => value.url }) ?? ""
        let title = definition.map({ value => InlineUtils.processEscapes(value.title) }) ?? ""
        let node: Node = if (image) {
            session.attachNode(ImageNode(session.allocateNodeId(), span, InlineUtils.processEscapes(syntax.text), url, title))
        } else { session.attachNode(LinkNode(session.allocateNodeId(), span, InlineUtils.processEscapes(syntax.text), url, title)) }
        retainReferenceSyntax(node, syntax)
        return node
    }

    public func recoverWindow(context: InlineRecoveryContext): ?InlineRecoveryWindow {
        var start = context.change.startByte; var oldEnd = context.change.oldEndByte
        var newEnd = context.change.newEndByte
        let delta = newEnd - oldEnd
        for (attempt in context.attempts) {
            if (attempt.startByte < start) { start = attempt.startByte }
            if (attempt.endByte > oldEnd) { oldEnd = attempt.endByte }
            if (attempt.readEnd > oldEnd) { oldEnd = attempt.readEnd }
        }
        if (oldEnd + delta > newEnd) { newEnd = oldEnd + delta }
        // A newly introduced opener can extend beyond the previously observed
        // window. Only these actual candidates determine that extension.
        var at = start
        while (at < newEnd && at < context.current.byteLength) {
            let marker = if (image) { b'!' } else { b'[' }
            if (context.current.readByte(at) == marker) {
                let result = matchReferenceSyntax({ pos: Int64 =>
                    if (pos < context.current.byteLength) { Some(context.current.readByte(pos)) } else { Option<Byte>.None }
                },
                    { a: Int64, b: Int64 => context.current.sliceBytes(a, b) }, at, image)
                if (let Some(value) <- result) { if (value.endByte > newEnd) { newEnd = value.endByte } }
                else { newEnd = context.current.byteLength }
            }
            at += 1
        }
        if (newEnd - delta > oldEnd) { oldEnd = newEnd - delta }
        if (start > oldEnd || oldEnd > context.previous.byteLength || newEnd > context.current.byteLength) { return None }
        return Some(InlineRecoveryWindow(start, oldEnd, newEnd, "reference actual bracket and EOF reads", grammarVersion))
    }
}
