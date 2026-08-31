package mermaid4cj.parser

import std.collection.{ArrayList, HashMap}
import mermaid4cj.core.{
    ClassDef,
    ClassDiagram,
    ClassMember,
    ClassNamespace,
    ClassNote,
    ClassParseResult,
    ClassRelation,
    ClassRelationType
}

public class ClassDiagramParser {
    public init() {}

    public func parse(source: String): ClassParseResult {
        let classes = ArrayList<ClassDef>()
        let relations = ArrayList<ClassRelation>()
        let namespaces = ArrayList<ClassNamespace>()
        let notes = ArrayList<ClassNote>()
        let classIndex = HashMap<String, Int64>()
        let namespaceIndex = HashMap<String, Int64>()
        let namespaceStack = ArrayList<String>()
        let diagnostics = ArrayList<String>()
        var sawHeader = false
        var title: ?String = None
        var inClassBlock = false
        var blockClassId = ""
        var skipAccDescrBlock = false
        var lineNo: Int64 = 0

        for (raw in source.lines()) {
            lineNo++
            let line = stripComment(raw).trimAscii()
            if (line.isEmpty()) {
                continue
            }
            let lower = line.toAsciiLower()
            if (skipAccDescrBlock) {
                if (line == "}") {
                    skipAccDescrBlock = false
                }
                continue
            }
            if (!sawHeader) {
                if (lower.startsWith("classdiagram")) {
                    sawHeader = true
                    continue
                }
                if (line == "---" || lower.startsWith("title:") || lower.startsWith("title ")) {
                    if (lower.startsWith("title:")) {
                        title = Some(line["title:".size..line.size].trimAscii())
                    } else if (lower.startsWith("title ")) {
                        title = Some(line["title ".size..line.size].trimAscii())
                    }
                    continue
                }
                diagnostics.add("Line ${lineNo}: expected classDiagram header")
                break
            }

            if (inClassBlock) {
                if (line == "}") {
                    inClassBlock = false
                    blockClassId = ""
                    continue
                }
                if (line.startsWith("<<") && line.endsWith(">>")) {
                    setClassAnnotation(classes, classIndex, blockClassId, line[2..(line.size - 2)].trimAscii())
                } else {
                    addMember(classes, classIndex, blockClassId, line)
                }
                continue
            }

            if (line == "}") {
                if (namespaceStack.size > 0) {
                    namespaceStack.remove(at: namespaceStack.size - 1)
                } else {
                    diagnostics.add("Line ${lineNo}: unexpected closing brace in classDiagram")
                }
            } else if (lower.startsWith("title:")) {
                title = Some(line["title:".size..line.size].trimAscii())
            } else if (lower.startsWith("title ")) {
                title = Some(line["title ".size..line.size].trimAscii())
            } else if (lower.startsWith("acctitle") || lower.startsWith("accdescr")) {
                if (lower.startsWith("accdescr") && line.endsWith("{")) {
                    skipAccDescrBlock = true
                }
            } else if (lower.startsWith("namespace ")) {
                parseNamespace(line["namespace ".size..line.size].trimAscii(), namespaces, namespaceIndex, namespaceStack, diagnostics, lineNo)
            } else if (lower.startsWith("note for ")) {
                parseClassNote(line, notes, diagnostics, lineNo)
            } else if (lower.startsWith("note ")) {
                notes.add(ClassNote(unquote(line["note ".size..line.size].trimAscii())))
            } else if (lower.startsWith("style ") || lower.startsWith("classdef ") || lower.startsWith("linkstyle ") || lower.startsWith("click ")) {
                diagnostics.add("Line ${lineNo}: unsupported classDiagram statement")
            } else if (line.startsWith("<<")) {
                parseAnnotationLine(line, classes, classIndex, currentNamespace(namespaceStack), diagnostics, lineNo)
            } else if (lower.startsWith("class ")) {
                let body = line["class ".size..line.size].trimAscii()
                if (body.endsWith("{")) {
                    let id = parseClassHeader(body[0..(body.size - 1)].trimAscii(), classes, classIndex, currentNamespace(namespaceStack), diagnostics, lineNo)
                    if (!id.isEmpty()) {
                        inClassBlock = true
                        blockClassId = id
                    }
                } else {
                    parseClassHeader(body, classes, classIndex, currentNamespace(namespaceStack), diagnostics, lineNo)
                }
            } else if (let Some(colon) <- findMemberColon(line)) {
                let ownerText = line[0..colon].trimAscii()
                let classId = parseClassId(ownerText)
                let member = line[(colon + 1)..line.size].trimAscii()
                if (classId.isEmpty() || member.isEmpty() || !isMemberOwner(ownerText)) {
                    diagnostics.add("Line ${lineNo}: malformed class member statement")
                } else {
                    ensureClass(classes, classIndex, classId, classId, currentNamespace(namespaceStack), genericType: noGenericType())
                    addMember(classes, classIndex, classId, member)
                }
            } else if (let Some(relation) <- parseRelation(line, currentNamespace(namespaceStack), classes, classIndex)) {
                relations.add(relation)
            } else {
                diagnostics.add("Line ${lineNo}: unsupported classDiagram statement")
            }
        }

        if (!sawHeader && diagnostics.isEmpty()) {
            diagnostics.add("Missing classDiagram header")
        }
        if (inClassBlock) {
            diagnostics.add("Unclosed class block '${blockClassId}'")
        }
        if (namespaceStack.size > 0) {
            diagnostics.add("Unclosed class namespace '${namespaceStack[namespaceStack.size - 1]}'")
        }

        return ClassParseResult(
            ClassDiagram(source, title: title, classes: classes, relations: relations, namespaces: namespaces, notes: notes),
            diagnostics: diagnostics.toArray()
        )
    }

    private func parseNamespace(body: String, namespaces: ArrayList<ClassNamespace>, namespaceIndex: HashMap<String, Int64>, namespaceStack: ArrayList<String>, diagnostics: ArrayList<String>, lineNo: Int64): Unit {
        if (!body.endsWith("{")) {
            diagnostics.add("Line ${lineNo}: class namespace must end with '{'")
            return
        }
        let rawName = body[0..(body.size - 1)].trimAscii()
        let parsed = parseIdAndLabel(rawName)
        let parent = currentNamespace(namespaceStack)
        let id = if (parent.isSome() && !parsed.id.contains(".")) { "${parent.getOrThrow()}.${parsed.id}" } else { parsed.id }
        if (id.isEmpty()) {
            diagnostics.add("Line ${lineNo}: class namespace id is empty")
            return
        }
        ensureNamespaceAncestors(id, namespaces, namespaceIndex)
        if (let Some(index) <- namespaceIndex.get(id)) {
            let existing = namespaces[index]
            namespaces[index] = ClassNamespace(id, label: if (parsed.label.isEmpty()) { existing.label } else { parsed.label }, parentId: parentIdForNamespace(id), explicit: true)
        } else {
            namespaceIndex[id] = namespaces.size
            namespaces.add(ClassNamespace(id, label: if (parsed.label.isEmpty()) { shortNamespaceLabel(id) } else { parsed.label }, parentId: parentIdForNamespace(id), explicit: true))
        }
        namespaceStack.add(id)
    }

    private func ensureNamespaceAncestors(id: String, namespaces: ArrayList<ClassNamespace>, namespaceIndex: HashMap<String, Int64>): Unit {
        var start: Int64 = 0
        while (start < id.size) {
            if (let Some(dotRel) <- id[start..id.size].indexOf(".")) {
                let pos = start + dotRel
                let ancestor = id[0..pos]
                if (namespaceIndex.get(ancestor).isNone()) {
                    namespaceIndex[ancestor] = namespaces.size
                    namespaces.add(ClassNamespace(ancestor, label: shortNamespaceLabel(ancestor), parentId: parentIdForNamespace(ancestor), explicit: false))
                }
                start = pos + 1
            } else {
                return
            }
        }
    }

    private func parseClassHeader(body: String, classes: ArrayList<ClassDef>, classIndex: HashMap<String, Int64>, namespaceId: ?String, diagnostics: ArrayList<String>, lineNo: Int64): String {
        let parsed = parseIdAndLabel(body)
        if (parsed.id.isEmpty()) {
            diagnostics.add("Line ${lineNo}: class id is empty")
            return ""
        }
        ensureClass(classes, classIndex, parsed.id, parsed.label, namespaceId, genericType: parsed.genericType)
        return parsed.id
    }

    private func parseAnnotationLine(line: String, classes: ArrayList<ClassDef>, classIndex: HashMap<String, Int64>, namespaceId: ?String, diagnostics: ArrayList<String>, lineNo: Int64): Unit {
        if (let Some(end) <- line.indexOf(">>")) {
            let annotation = line[2..end].trimAscii()
            let id = parseClassId(line[(end + 2)..line.size].trimAscii())
            if (id.isEmpty()) {
                diagnostics.add("Line ${lineNo}: class annotation target is empty")
                return
            }
            ensureClass(classes, classIndex, id, id, namespaceId, genericType: noGenericType())
            setClassAnnotation(classes, classIndex, id, annotation)
        } else {
            diagnostics.add("Line ${lineNo}: malformed class annotation")
        }
    }

    private func parseClassNote(line: String, notes: ArrayList<ClassNote>, diagnostics: ArrayList<String>, lineNo: Int64): Unit {
        let rest = line["note for ".size..line.size].trimAscii()
        let split = splitFirstWhitespace(rest)
        if (split.left.isEmpty() || split.right.isEmpty()) {
            diagnostics.add("Line ${lineNo}: malformed class note")
            return
        }
        notes.add(ClassNote(unquote(split.right), classId: Some(parseClassId(split.left))))
    }

    private func parseRelation(line: String, namespaceId: ?String, classes: ArrayList<ClassDef>, classIndex: HashMap<String, Int64>): ?ClassRelation {
        let tokens = ["<|--|>", "<|..|>", "--|>", "<|--", "<|..", "..|>", "--*", "*--", "--o", "o--", "--()", "()--", "-->", "<--", "..>", "<..", "--", ".."]
        for (token in tokens) {
            if (let Some(pos) <- line.indexOf(token)) {
                let left = line[0..pos].trimAscii()
                let rightAndLabel = line[(pos + token.size)..line.size].trimAscii()
                let parts = splitRelationRight(rightAndLabel)
                let source = parseClassId(left)
                let target = parseClassId(parts.left)
                if (source.isEmpty() || target.isEmpty()) {
                    return None
                }
                ensureClass(classes, classIndex, source, source, namespaceId, genericType: noGenericType())
                ensureClass(classes, classIndex, target, target, namespaceId, genericType: noGenericType())
                let markers = markersFor(token)
                return Some(ClassRelation(
                    source,
                    target,
                    token,
                    relationTypeFor(token),
                    label: parts.right,
                    startMarker: markers.left,
                    endMarker: markers.right,
                    dashed: token.contains("..")
                ))
            }
        }
        return None
    }

    private func ensureClass(classes: ArrayList<ClassDef>, classIndex: HashMap<String, Int64>, id: String, label: String, namespaceId: ?String, genericType!: ?String): Unit {
        if (id.isEmpty()) {
            return
        }
        if (let Some(index) <- classIndex.get(id)) {
            let current = classes[index]
            let nextLabel = if (label.isEmpty() || label == id && current.label != id) { current.label } else { label }
            let nextNamespace = if (current.namespaceId.isSome()) { current.namespaceId } else { namespaceId }
            let nextGeneric = if (genericType.isSome()) { genericType } else { current.genericType }
            classes[index] = ClassDef(id, label: nextLabel, annotation: current.annotation, namespaceId: nextNamespace, genericType: nextGeneric, members: current.members)
            return
        }
        classIndex[id] = classes.size
        classes.add(ClassDef(id, label: label, namespaceId: namespaceId, genericType: genericType))
    }

    private func setClassAnnotation(classes: ArrayList<ClassDef>, classIndex: HashMap<String, Int64>, id: String, annotation: String): Unit {
        if (let Some(index) <- classIndex.get(id)) {
            let current = classes[index]
            classes[index] = ClassDef(current.id, label: current.label, annotation: Some(annotation), namespaceId: current.namespaceId, genericType: current.genericType, members: current.members)
        }
    }

    private func addMember(classes: ArrayList<ClassDef>, classIndex: HashMap<String, Int64>, id: String, member: String): Unit {
        if (member.isEmpty()) {
            return
        }
        if (let Some(index) <- classIndex.get(id)) {
            classes[index].members.add(ClassMember(normalizeMember(member), member.contains("(") && member.contains(")")))
        }
    }

    private func normalizeMember(member: String): String {
        let text = member.trimAscii()
        if (let Some(close) <- text.indexOf(") ")) {
            let returnType = text[(close + 2)..text.size].trimAscii()
            if (!returnType.isEmpty() && !returnType.startsWith(":")) {
                return "${text[0..(close + 1)]} : ${returnType}"
            }
        }
        return text
    }

    private func parseIdAndLabel(text: String): ClassIdLabel {
        let trimmed = text.trimAscii()
        var idText = trimmed
        var label = ""
        if (let Some(labelStart) <- trimmed.indexOf("[\"")) {
            idText = trimmed[0..labelStart].trimAscii()
            if (trimmed.endsWith("\"]")) {
                label = trimmed[(labelStart + 2)..(trimmed.size - 2)]
            }
        }
        let generic = parseGenericType(idText)
        let id = parseClassId(stripGenericType(idText))
        return ClassIdLabel(id, label, generic)
    }

    private func parseGenericType(text: String): ?String {
        let trimmed = text.trimAscii()
        if (let Some(start) <- trimmed.indexOf("~")) {
            if (let Some(endRel) <- trimmed[(start + 1)..trimmed.size].indexOf("~")) {
                return Some(trimmed[(start + 1)..(start + 1 + endRel)])
            }
        }
        return None
    }

    private func noGenericType(): ?String {
        return None
    }

    private func stripGenericType(text: String): String {
        let trimmed = text.trimAscii()
        if (let Some(start) <- trimmed.indexOf("~")) {
            return trimmed[0..start].trimAscii()
        }
        return trimmed
    }

    private func parseClassId(text: String): String {
        return unquote(text.trimAscii())
    }

    private func splitRelationRight(text: String): ClassSplit {
        if (let Some(colon) <- text.indexOf(":")) {
            return ClassSplit(text[0..colon].trimAscii(), unquote(text[(colon + 1)..text.size].trimAscii()))
        }
        return ClassSplit(text.trimAscii(), "")
    }

    private func splitFirstWhitespace(text: String): ClassSplit {
        for (i in 0..text.size) {
            if (text[i] == b' ' || text[i] == b'\t') {
                return ClassSplit(text[0..i].trimAscii(), text[(i + 1)..text.size].trimAscii())
            }
        }
        return ClassSplit(text.trimAscii(), "")
    }

    private func findMemberColon(line: String): ?Int64 {
        for (i in 0..line.size) {
            if (line[i] == b':') {
                return Some(i)
            }
            if (line[i] == b'-' || line[i] == b'.' || line[i] == b'<' || line[i] == b'>') {
                return None
            }
        }
        return None
    }

    private func isMemberOwner(text: String): Bool {
        let trimmed = text.trimAscii()
        if (trimmed.isEmpty()) {
            return false
        }
        if (trimmed.startsWith("`") && trimmed.endsWith("`")) {
            return true
        }
        return !trimmed.contains(" ") && !trimmed.contains("\t")
    }

    private func markersFor(token: String): ClassSplit {
        match (token) {
            case "<|--" | "<|.." => return ClassSplit("inheritance", "")
            case "--|>" | "..|>" => return ClassSplit("", "inheritance")
            case "<|--|>" | "<|..|>" => return ClassSplit("inheritance", "inheritance")
            case "*--" => return ClassSplit("composition", "")
            case "--*" => return ClassSplit("", "composition")
            case "o--" => return ClassSplit("aggregation", "")
            case "--o" => return ClassSplit("", "aggregation")
            case "<--" | "<.." => return ClassSplit("association", "")
            case "-->" | "..>" => return ClassSplit("", "association")
            case "()--" => return ClassSplit("lollipop", "")
            case "--()" => return ClassSplit("", "lollipop")
            case _ => return ClassSplit("", "")
        }
    }

    private func relationTypeFor(token: String): ClassRelationType {
        if (token.contains("<|") || token.contains("|>")) {
            if (token.contains("..")) {
                return ClassRelationType.Realization
            }
            return ClassRelationType.Inheritance
        }
        if (token.contains("*")) {
            return ClassRelationType.Composition
        }
        if (token.contains("o")) {
            return ClassRelationType.Aggregation
        }
        if (token.contains("()")) {
            return ClassRelationType.Lollipop
        }
        if (token.contains(">") || token.contains("<")) {
            if (token.contains("..")) {
                return ClassRelationType.Dependency
            }
            return ClassRelationType.Association
        }
        if (token.contains("..")) {
            return ClassRelationType.DashedLink
        }
        return ClassRelationType.Link
    }

    private func currentNamespace(stack: ArrayList<String>): ?String {
        if (stack.size == 0) {
            return None
        }
        return Some(stack[stack.size - 1])
    }

    private func parentIdForNamespace(id: String): ?String {
        var last: Int64 = -1
        for (i in 0..id.size) {
            if (id[i] == b'.') {
                last = i
            }
        }
        if (last <= 0) {
            return None
        }
        return Some(id[0..last])
    }

    private func shortNamespaceLabel(id: String): String {
        var last: Int64 = -1
        for (i in 0..id.size) {
            if (id[i] == b'.') {
                last = i
            }
        }
        if (last < 0 || last + 1 >= id.size) {
            return id
        }
        return id[(last + 1)..id.size]
    }

    private func stripComment(line: String): String {
        if (let Some(pos) <- line.indexOf("%%")) {
            return line[0..pos]
        }
        return line
    }

    private func unquote(text: String): String {
        let trimmed = text.trimAscii()
        if (trimmed.size >= 2 && ((trimmed[0] == b'"' && trimmed[trimmed.size - 1] == b'"') || (trimmed[0] == b'\'' && trimmed[trimmed.size - 1] == b'\'') || (trimmed[0] == b'`' && trimmed[trimmed.size - 1] == b'`'))) {
            return trimmed[1..(trimmed.size - 1)]
        }
        return trimmed
    }
}

class ClassSplit {
    let left: String
    let right: String

    init(left: String, right: String) {
        this.left = left
        this.right = right
    }
}

class ClassIdLabel {
    let id: String
    let label: String
    let genericType: ?String

    init(id: String, label: String, genericType: ?String) {
        this.id = id
        this.label = label
        this.genericType = genericType
    }
}
