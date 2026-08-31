package markit.plugins.anchor

public class AutoAnchorConfig {
    public let list: Bool
    public let code: Bool
    public let math: Bool
    public let table: Bool
    public let block: Bool

    public init(
        list!: Bool = false,
        code!: Bool = false,
        math!: Bool = false,
        table!: Bool = false,
        block!: Bool = false
    ) {
        this.list = list
        this.code = code
        this.math = math
        this.table = table
        this.block = block
    }

    public func anyEnabled(): Bool {
        return list || code || math || table || block
    }
}
