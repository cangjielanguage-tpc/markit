package markit.plugins.gfm.block.table

public class TableConfig {
    public let enableThreeLineTable: Bool
    public let autoAnchor: Bool

    public init(enableThreeLineTable!: Bool = false, autoAnchor!: Bool = false) {
        this.enableThreeLineTable = enableThreeLineTable
        this.autoAnchor = autoAnchor
    }
}
