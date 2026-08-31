package markit.core.render

import std.collection.{ArrayList, HashMap}

public class HtmlConfig {
    private let globalCssClasses = ArrayList<String>()
    private let rootWrapperClasses = ArrayList<String>()
    private let nodeClassMap = HashMap<String, ArrayList<String>>()
    public var enableRootWrapper: Bool = false
    public var rootWrapperTag: String = "div"

    public init() {}

    public func setGlobalCssClasses(classNames: ArrayList<String>): Unit {
        globalCssClasses.clear()
        for (className in classNames) {
            addUnique(globalCssClasses, className)
        }
    }

    public func addGlobalCssClass(className: String): Unit {
        addUnique(globalCssClasses, className)
    }

    public func removeGlobalCssClass(className: String): Unit {
        removeValue(globalCssClasses, className)
    }

    public func getGlobalCssClasses(): ArrayList<String> {
        return copyList(globalCssClasses)
    }

    public func setRootWrapper(
        enabled: Bool,
        tag!: String = "div",
        classNames!: ArrayList<String> = ArrayList<String>()
    ): Unit {
        enableRootWrapper = enabled
        rootWrapperTag = tag
        rootWrapperClasses.clear()
        for (className in classNames) {
            addUnique(rootWrapperClasses, className)
        }
    }

    public func isRootWrapperEnabled(): Bool {
        return enableRootWrapper
    }

    public func getRootWrapperTag(): String {
        return rootWrapperTag
    }

    public func setNodeClasses(nodeType: String, classNames: ArrayList<String>): Unit {
        if (nodeType.isEmpty()) {
            return
        }

        let nodeClasses = ArrayList<String>()
        for (className in classNames) {
            addUnique(nodeClasses, className)
        }
        nodeClassMap[nodeType] = nodeClasses
    }

    public func addNodeClass(nodeType: String, className: String): Unit {
        if (nodeType.isEmpty() || className.isEmpty()) {
            return
        }
        if (!nodeClassMap.contains(nodeType)) {
            nodeClassMap[nodeType] = ArrayList<String>()
        }
        addUnique(nodeClassMap[nodeType], className)
    }

    public func removeNodeClass(nodeType: String, className: String): Unit {
        if (let Some(nodeClasses) <- nodeClassMap.get(nodeType)) {
            removeValue(nodeClasses, className)
        }
    }

    public func getNodeClasses(nodeType: String): ArrayList<String> {
        let classes = copyList(globalCssClasses)
        if (let Some(nodeClasses) <- nodeClassMap.get(nodeType)) {
            for (className in nodeClasses) {
                addUnique(classes, className)
            }
        }
        return classes
    }

    public func getNodeClasses(nodeTypes: ArrayList<String>): ArrayList<String> {
        let classes = copyList(globalCssClasses)
        for (nodeType in nodeTypes) {
            if (let Some(nodeClasses) <- nodeClassMap.get(nodeType)) {
                for (className in nodeClasses) {
                    addUnique(classes, className)
                }
            }
        }
        return classes
    }

    public func getRootWrapperClasses(): ArrayList<String> {
        let classes = copyList(globalCssClasses)
        for (className in rootWrapperClasses) {
            addUnique(classes, className)
        }
        return classes
    }

    public func hasNodeClasses(nodeType: String): Bool {
        if (let Some(nodeClasses) <- nodeClassMap.get(nodeType)) {
            return !nodeClasses.isEmpty()
        }
        return false
    }

    public func getConfiguredNodeTypes(): ArrayList<String> {
        let result = ArrayList<String>()
        for ((nodeType, _) in nodeClassMap) {
            result.add(nodeType)
        }
        return result
    }

    public func reset(): Unit {
        globalCssClasses.clear()
        rootWrapperClasses.clear()
        nodeClassMap.clear()
        enableRootWrapper = false
        rootWrapperTag = "div"
    }

    public func copy(): HtmlConfig {
        let copied = HtmlConfig()
        copied.setGlobalCssClasses(globalCssClasses)
        copied.setRootWrapper(enableRootWrapper, tag: rootWrapperTag, classNames: rootWrapperClasses)
        for ((nodeType, classes) in nodeClassMap) {
            copied.setNodeClasses(nodeType, classes)
        }
        return copied
    }

    public func classAttribute(nodeType: String): String {
        return classAttributeFrom(getNodeClasses(nodeType))
    }

    public func classAttribute(nodeTypes: ArrayList<String>): String {
        return classAttributeFrom(getNodeClasses(nodeTypes))
    }

    public func classSuffix(nodeType: String): String {
        let classes = getNodeClasses(nodeType)
        if (classes.isEmpty()) {
            return ""
        }
        return " " + HtmlEscaper.escape(String.join(classes.toArray(), delimiter: " "))
    }

    public func classSuffix(nodeTypes: ArrayList<String>): String {
        let classes = getNodeClasses(nodeTypes)
        if (classes.isEmpty()) {
            return ""
        }
        return " " + HtmlEscaper.escape(String.join(classes.toArray(), delimiter: " "))
    }

    public func rootClassAttribute(): String {
        return classAttributeFrom(getRootWrapperClasses())
    }

    private func classAttributeFrom(classes: ArrayList<String>): String {
        if (classes.isEmpty()) {
            return ""
        }
        return " class=\"${HtmlEscaper.escape(String.join(classes.toArray(), delimiter: " "))}\""
    }

    private func addUnique(values: ArrayList<String>, value: String): Unit {
        if (!value.isEmpty() && !values.contains(value)) {
            values.add(value)
        }
    }

    private func removeValue(values: ArrayList<String>, value: String): Unit {
        var index: Int64 = 0
        while (index < values.size) {
            if (values[index] == value) {
                values.remove(at: index)
            } else {
                index += 1
            }
        }
    }

    private func copyList(values: ArrayList<String>): ArrayList<String> {
        let result = ArrayList<String>()
        for (value in values) {
            result.add(value)
        }
        return result
    }
}
