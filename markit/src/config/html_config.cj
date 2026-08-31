package markit.config

import std.collection.ArrayList
import markit.core.render.HtmlConfig as CoreHtmlConfig

public class HtmlConfig {
    private static let current = CoreHtmlConfig()

    public static func setGlobalCssClasses(classNames: ArrayList<String>): Unit {
        current.setGlobalCssClasses(classNames)
    }

    public static func addGlobalCssClass(className: String): Unit {
        current.addGlobalCssClass(className)
    }

    public static func removeGlobalCssClass(className: String): Unit {
        current.removeGlobalCssClass(className)
    }

    public static func getGlobalCssClasses(): ArrayList<String> {
        return current.getGlobalCssClasses()
    }

    public static func setRootWrapper(
        enabled: Bool,
        tag!: String = "div",
        classNames!: ArrayList<String> = ArrayList<String>()
    ): Unit {
        current.setRootWrapper(enabled, tag: tag, classNames: classNames)
    }

    public static func isRootWrapperEnabled(): Bool {
        return current.isRootWrapperEnabled()
    }

    public static func getRootWrapperTag(): String {
        return current.getRootWrapperTag()
    }

    public static func setNodeClasses(nodeType: String, classNames: ArrayList<String>): Unit {
        current.setNodeClasses(nodeType, classNames)
    }

    public static func addNodeClass(nodeType: String, className: String): Unit {
        current.addNodeClass(nodeType, className)
    }

    public static func removeNodeClass(nodeType: String, className: String): Unit {
        current.removeNodeClass(nodeType, className)
    }

    public static func getNodeClasses(nodeType: String): ArrayList<String> {
        return current.getNodeClasses(nodeType)
    }

    public static func getRootWrapperClasses(): ArrayList<String> {
        return current.getRootWrapperClasses()
    }

    public static func hasNodeClasses(nodeType: String): Bool {
        return current.hasNodeClasses(nodeType)
    }

    public static func getConfiguredNodeTypes(): ArrayList<String> {
        return current.getConfiguredNodeTypes()
    }

    public static func reset(): Unit {
        current.reset()
    }

    public static func snapshot(): CoreHtmlConfig {
        return current.copy()
    }
}
