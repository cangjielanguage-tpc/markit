package markit.plugins.i18n

import std.collection.ArrayList
import markit.core.nodes.Node
import markit.core.session.{ParseSession, SessionState, SessionStateSnapshot}
import markit.plugins.gfm.block.BlockLineUtils
import markit.plugins.i18n.config.I18nConfig

public class I18nSessionState <: SessionState {
    private let defaultLanguage: String
    private let targetLanguage: String
    private let pendingTopLevelLists = ArrayList<I18nPendingList>()
    private let pendingDefaultAttachments = ArrayList<I18nPendingAttachment>()

    public init(config: I18nConfig) {
        this.defaultLanguage = config.defaultLanguage
        this.targetLanguage = config.targetLanguage
    }

    public func beforeTopLevelEmit(session: ParseSession, node: Node): Bool {
        if (consumePendingDefaultAttachmentIfNeeded(session, node)) {
            return false
        }

        if (tryAttachIndentedBlock(session, node)) {
            return false
        }

        annotateTree(node, defaultLanguage)

        if (isListNode(node)) {
            if (isRenderable(node)) {
                if (tryMergeWithPendingList(session, node, node)) {
                    return false
                }
                addPendingList(session, node, node)
                return true
            }
            return false
        }

        if (node.kind == "I18nBlock" || node.kind == "UniversalBlock") {
            return handleI18nBlock(session, node)
        }

        if (!isRenderable(node)) {
            return false
        }
        flushPendingDefaultAttachments(session)
        clearPendingLists(session)
        return true
    }

    public func beforeSessionFinalize(session: ParseSession): Unit {
        flushPendingDefaultAttachments(session)
    }

    public func reset(): Unit {
        pendingTopLevelLists.clear()
        pendingDefaultAttachments.clear()
    }

    public func snapshot(): SessionStateSnapshot {
        return SessionStateSnapshot(I18nPlugin.stateKey.dynamicName)
    }

    private func handleI18nBlock(session: ParseSession, block: Node): Bool {
        annotateTree(block, defaultLanguage)
        if (!isRenderable(block)) {
            return false
        }

        if (block.children.size == 1 && isListNode(block.children[0])) {
            let list = block.children[0]
            annotateTree(list, block.string("i18n_language") ?? defaultLanguage)
            if (tryMergeWithPendingList(session, list, block)) {
                return false
            }
            addPendingList(session, list, block)
            return true
        }

        if (isAttachableIndentedBlock(block)) {
            if (tryAttachIndentedBlock(session, block)) {
                return false
            }
        }

        flushPendingDefaultAttachments(session)
        clearPendingLists(session)
        return true
    }

    private func tryAttachIndentedBlock(session: ParseSession, node: Node): Bool {
        if (pendingTopLevelLists.isEmpty()) {
            return false
        }
        if (!isAttachableIndentedBlock(node)) {
            return false
        }

        if (isPotentiallyReplacedDefaultAttachment(node)) {
            pendingDefaultAttachments.add(I18nPendingAttachment(node))
            return true
        }

        let attachNode = if (node.kind == "I18nBlock" && node.children.size == 1) {
            annotateTree(node, defaultLanguage)
            if (!isRenderable(node)) {
                return false
            }
            let child = node.children[0]
            child.setInt("i18n_effective_indent", effectiveIndent(node))
            if (isListNode(child)) {
                child.setBool("i18n_translated_attachment", true)
            }
            child
        } else {
            annotateTree(node, "universal")
            if (!isRenderable(node)) {
                return false
            }
            node
        }

        return attachToPendingLists(session, attachNode)
    }

    private func consumePendingDefaultAttachmentIfNeeded(session: ParseSession, node: Node): Bool {
        if (pendingDefaultAttachments.isEmpty()) {
            return false
        }

        if (node.kind == "I18nBlock" && isAttachableIndentedBlock(node)) {
            if (tryAttachIndentedBlock(session, node)) {
                if (shouldReplacePendingDefaultAttachment(node)) {
                    removeReplaceablePendingAttachments()
                } else {
                    flushPendingDefaultAttachments(session)
                }
                return true
            }

            flushPendingDefaultAttachments(session)
            return false
        }

        flushPendingDefaultAttachments(session)
        return false
    }

    private func flushPendingDefaultAttachments(session: ParseSession): Unit {
        while (!pendingDefaultAttachments.isEmpty()) {
            let pending = pendingDefaultAttachments[0]
            pendingDefaultAttachments.remove(at: 0)
            attachExistingIndentedBlock(session, pending.node)
        }
    }

    private func attachExistingIndentedBlock(session: ParseSession, node: Node): Bool {
        if (pendingTopLevelLists.isEmpty()) {
            return false
        }
        annotateTree(node, "universal")
        return attachToPendingLists(session, node)
    }

    private func attachToPendingLists(session: ParseSession, node: Node): Bool {
        let pending = bestPendingListForAttachment(node)
        if (let Some(target) <- pending) {
            let targetItem = findAttachmentTargetItem(target.list, node)
            if (let Some(item) <- targetItem) {
                markNestedTranslatedAttachment(target.list, node)
                if (isListNode(node) && tryMergeWithExistingChildList(session, item, node, target.patchTarget)) {
                    target.list.setBool("i18n_tight_override", true)
                    target.list.sourceSpan = target.list.sourceSpan.merge(node.sourceSpan)
                    target.patchTarget.sourceSpan = target.patchTarget.sourceSpan.merge(node.sourceSpan)
                    session.patches.replace(target.patchTarget)
                    return true
                }
                if (node.kind == "Paragraph") {
                    node.setBool("force_block_paragraph", true)
                    target.list.setBool("i18n_tight_override", true)
                }
                if (isListNode(node)) {
                    node.setBool("i18n_tight_override", true)
                    target.list.setBool("i18n_tight_override", true)
                }
                if (shouldHideTranslatedAnchorText(target.list, node)) {
                    hideLeadingTextChild(item)
                }
                item.addChild(node)
                target.list.sourceSpan = target.list.sourceSpan.merge(node.sourceSpan)
                target.patchTarget.sourceSpan = target.patchTarget.sourceSpan.merge(node.sourceSpan)
                session.patches.replace(target.patchTarget)
                if (isListNode(node)) {
                    pushPendingList(session, node, target.patchTarget)
                }
                return true
            }
        }
        return false
    }

    private func tryMergeWithPendingList(session: ParseSession, list: Node, patchTarget: Node): Bool {
        if (pendingTopLevelLists.isEmpty()) {
            return false
        }

        let previous = pendingTopLevelLists[pendingTopLevelLists.size - 1]
        if (!sameListFamily(previous.list, list)) {
            clearPendingLists(session)
            return false
        }

        for (item in list.children) {
            previous.list.addChild(item)
        }
        previous.list.setBool("i18n_tight_override", true)
        previous.list.sourceSpan = previous.list.sourceSpan.merge(list.sourceSpan)
        previous.patchTarget.sourceSpan = previous.patchTarget.sourceSpan.merge(patchTarget.sourceSpan)
        session.patches.replace(previous.patchTarget)
        return true
    }

    private func tryMergeWithExistingChildList(
        session: ParseSession,
        item: Node,
        list: Node,
        patchTarget: Node
    ): Bool {
        var index = item.children.size - 1
        while (index >= 0) {
            let child = item.children[index]
            if (!isListNode(child)) {
                index -= 1
                continue
            }
            if (!sameListFamily(child, list)) {
                return false
            }

            for (newItem in list.children) {
                child.addChild(newItem)
            }
            if (list.bool("i18n_translated_attachment") ?? false) {
                child.setBool("i18n_translated_attachment", true)
            }
            if (list.bool("i18n_nested_translated_attachment") ?? false) {
                child.setBool("i18n_nested_translated_attachment", true)
            }
            child.setBool("i18n_tight_override", true)
            child.sourceSpan = child.sourceSpan.merge(list.sourceSpan)
            pushPendingList(session, child, patchTarget)
            session.patches.replace(patchTarget)
            return true
        }
        return false
    }

    private func findAttachmentTargetItem(list: Node, block: Node): ?Node {
        if (list.children.isEmpty()) {
            return None
        }

        var target = list.children[list.children.size - 1]
        for (i in 0..list.children.size) {
            let item = list.children[i]
            if (block.sourceSpan.startByte >= item.sourceSpan.startByte) {
                target = item
            }
        }
        return Some(target)
    }

    private func annotateTree(node: Node, inheritedLanguage: String): Bool {
        let language = if (let Some(existing) <- node.string("i18n_language")) {
            existing
        } else if (node.kind == "I18nInline" || node.kind == "I18nBlock") {
            node.string("languageId") ?? inheritedLanguage
        } else if (node.kind == "UniversalInline" || node.kind == "UniversalBlock" || isUniversalBlock(node)) {
            "universal"
        } else {
            inheritedLanguage
        }

        node.setString("i18n_language", language)
        node.setString("i18n_target_language", targetLanguage)
        node.removeString("render")

        var childShouldRender = false
        for (child in node.children) {
            if (annotateTree(child, language)) {
                childShouldRender = true
            }
        }

        let shouldRender = shouldRenderLanguage(language) || childShouldRender
        if (!shouldRender) {
            node.setString("render", "false")
        }
        return shouldRender
    }

    private func isRenderable(node: Node): Bool {
        return node.string("render") != Some("false")
    }

    private func shouldRenderLanguage(language: String): Bool {
        if (language == "universal") {
            return true
        }
        if (language == targetLanguage) {
            return true
        }
        return language == defaultLanguage && targetLanguage == defaultLanguage
    }

    private func isAttachableIndentedBlock(node: Node): Bool {
        if (node.kind == "I18nBlock" || node.kind == "UniversalBlock") {
            if (BlockLineUtils.indentationWidth(node.rawContent()) > 0) {
                return true
            }
            return node.children.size == 1 && isAttachableIndentedBlock(node.children[0])
        }
        if (isListNode(node) || node.kind == "FencedCodeBlock" || node.kind == "MathBlock" || node.kind == "Paragraph") {
            return BlockLineUtils.indentationWidth(node.rawContent()) > 0
        }
        return false
    }

    private func isListNode(node: Node): Bool {
        return node.kind == "List" || node.kind == "TaskList" || node.kind == "AlphabeticList"
    }

    private func sameListFamily(left: Node, right: Node): Bool {
        if (left.kind != right.kind) {
            return false
        }
        if (left.kind == "List") {
            return (left.bool("ordered") ?? false) == (right.bool("ordered") ?? false)
        }
        return true
    }

    private func isUniversalBlock(node: Node): Bool {
        return node.kind == "FencedCodeBlock" || node.kind == "Table" || node.kind == "MathBlock" || node.kind == "Divider"
    }

    private func markNestedTranslatedAttachment(targetList: Node, node: Node): Unit {
        if (!isListNode(node)) {
            return
        }
        if ((targetList.bool("i18n_translated_attachment") ?? false) ||
            (targetList.bool("i18n_nested_translated_attachment") ?? false)) {
            node.setBool("i18n_nested_translated_attachment", true)
        }
    }

    private func shouldHideTranslatedAnchorText(targetList: Node, node: Node): Bool {
        return (targetList.bool("i18n_nested_translated_attachment") ?? false) && isUniversalBlock(node)
    }

    private func hideLeadingTextChild(item: Node): Unit {
        for (child in item.children) {
            if (child.kind == "Text") {
                child.setString("render", "false")
                return
            }
        }
    }

    private func clearPendingLists(session: ParseSession): Unit {
        pendingDefaultAttachments.clear()
        pendingTopLevelLists.clear()
        session.setTopLevelIndentedBlockStartsAllowed(false)
    }

    private func addPendingList(session: ParseSession, list: Node, patchTarget: Node): Unit {
        pendingTopLevelLists.add(I18nPendingList(list, patchTarget))
        session.setTopLevelIndentedBlockStartsAllowed(true)
    }

    private func isPotentiallyReplacedDefaultAttachment(node: Node): Bool {
        return node.kind == "Paragraph" || isListNode(node)
    }

    private func shouldReplacePendingDefaultAttachment(node: Node): Bool {
        return node.kind == "I18nBlock" && node.children.size == 1 && isPotentiallyReplacedDefaultAttachment(node.children[0])
    }

    private func removeReplaceablePendingAttachments(): Unit {
        var index: Int64 = pendingDefaultAttachments.size - 1
        while (index >= 0) {
            if (isPotentiallyReplacedDefaultAttachment(pendingDefaultAttachments[index].node)) {
                pendingDefaultAttachments.remove(at: index)
                return
            }
            index -= 1
        }
    }

    private func pushPendingList(session: ParseSession, list: Node, patchTarget: Node): Unit {
        let indent = listIndent(list)
        while (!pendingTopLevelLists.isEmpty()) {
            let last = pendingTopLevelLists[pendingTopLevelLists.size - 1]
            if (listIndent(last.list) < indent) {
                break
            }
            pendingTopLevelLists.remove(at: pendingTopLevelLists.size - 1)
        }
        addPendingList(session, list, patchTarget)
    }

    private func bestPendingListForAttachment(node: Node): ?I18nPendingList {
        if (pendingTopLevelLists.isEmpty()) {
            return None
        }

        let nodeIndent = effectiveIndent(node)
        var index = pendingTopLevelLists.size - 1
        while (index >= 0) {
            let pending = pendingTopLevelLists[index]
            if (listIndent(pending.list) < nodeIndent) {
                return Some(pending)
            }
            index -= 1
        }

        return Some(pendingTopLevelLists[0])
    }

    private func listIndent(list: Node): Int64 {
        return list.int("i18n_effective_indent") ?? (list.int("baseIndent") ?? effectiveIndent(list))
    }

    private func effectiveIndent(node: Node): Int64 {
        return node.int("i18n_effective_indent") ?? BlockLineUtils.indentationWidth(node.rawContent())
    }
}

private class I18nPendingList {
    public let list: Node
    public let patchTarget: Node

    public init(list: Node, patchTarget: Node) {
        this.list = list
        this.patchTarget = patchTarget
    }
}

private class I18nPendingAttachment {
    public let node: Node

    public init(node: Node) {
        this.node = node
    }
}
