package markit.tests.generators

public class GeneratorConfig {
    public var maxDepth: Int64
    public var maxLength: Int64
    public var includeEdgeCases: Bool
    public var includeSpecialChars: Bool
    public var seed: UInt64

    public init() {
        this.maxDepth = 3
        this.maxLength = 100
        this.includeEdgeCases = true
        this.includeSpecialChars = true
        this.seed = 0
    }

    public init(maxDepth: Int64, maxLength: Int64) {
        this.maxDepth = maxDepth
        this.maxLength = maxLength
        this.includeEdgeCases = true
        this.includeSpecialChars = true
        this.seed = 0
    }

    public init(
        maxDepth: Int64,
        maxLength: Int64,
        includeEdgeCases: Bool,
        includeSpecialChars: Bool,
        seed: UInt64
    ) {
        this.maxDepth = maxDepth
        this.maxLength = maxLength
        this.includeEdgeCases = includeEdgeCases
        this.includeSpecialChars = includeSpecialChars
        this.seed = seed
    }
}
