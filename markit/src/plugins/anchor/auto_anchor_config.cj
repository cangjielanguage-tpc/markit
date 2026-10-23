package markit.plugins.anchor

public class AutoAnchorConfig {
    public AutoAnchorConfig(
        public let list!: Bool = false,
        public let code!: Bool = false,
        public let math!: Bool = false,
        public let table!: Bool = false,
        public let block!: Bool = false
    ) {}

    public func anyEnabled(): Bool {
        return list || code || math || table || block
    }
}
