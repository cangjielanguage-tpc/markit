package markit.plugins.gfm.block.task_list

import markit.core.plugin.{Plugin, PluginRegistrar}

public class TaskListPlugin <: Plugin {
    public prop name: String {
        get() {
            return "TaskListPlugin"
        }
    }

    public prop version: String {
        get() {
            return "2.0.0"
        }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerContinuationBlockParser(TaskListParser())
        registrar.registerHtmlRenderer("TaskList", TaskListHtmlRenderer())
        registrar.registerHtmlRenderer("TaskListItem", TaskListItemHtmlRenderer())
        registrar.registerMarkdownRenderer("TaskList", TaskListMarkdownRenderer())
        registrar.registerMarkdownRenderer("TaskListItem", TaskListItemMarkdownRenderer())
        registrar.registerTypstRenderer("TaskList", TaskListTypstRenderer())
        registrar.registerTypstRenderer("TaskListItem", TaskListItemTypstRenderer())
    }
}
