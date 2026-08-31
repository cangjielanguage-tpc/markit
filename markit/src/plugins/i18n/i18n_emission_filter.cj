package markit.plugins.i18n

import markit.core.nodes.Node
import markit.core.plugin.NodeEmissionFilter
import markit.core.session.ParseSession

public class I18nEmissionFilter <: NodeEmissionFilter {
    public prop ownerPlugin: String {
        get() {
            return "I18nPlugin"
        }
    }

    public func accept(session: ParseSession, node: Node): Bool {
        let state = session.symbolTables.get(I18nPlugin.stateKey)
        return state.beforeTopLevelEmit(session, node)
    }
}
