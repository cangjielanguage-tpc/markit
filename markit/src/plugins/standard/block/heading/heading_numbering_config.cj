package markit.plugins.standard.block.heading

public class HeadingNumberingConfig {
    private let startFromValues: Array<Int64>
    private let initialCounterValues: ?Array<Int64>
    public let enabled: Bool
    public let maxDepth: Int64
    public let includeInHtml: Bool
    public let separator: String
    public let resetBeforeParse: Bool

    public init(
        enabled!: Bool = false,
        startFrom!: (Int64, Int64, Int64, Int64, Int64, Int64) = (1, 1, 1, 1, 1, 1),
        maxDepth!: Int64 = 6,
        includeInHtml!: Bool = true,
        separator!: String = ".",
        resetBeforeParse!: Bool = true,
        initialCounters!: ?Array<Int64> = None
    ) {
        if (maxDepth < 1 || maxDepth > 6) {
            throw IllegalArgumentException("maxDepth must be between 1 and 6")
        }

        this.enabled = enabled
        this.maxDepth = maxDepth
        this.includeInHtml = includeInHtml
        this.separator = separator
        this.resetBeforeParse = resetBeforeParse
        let starts = [
            startFrom[0],
            startFrom[1],
            startFrom[2],
            startFrom[3],
            startFrom[4],
            startFrom[5]
        ]
        this.startFromValues = starts
        this.initialCounterValues = match (initialCounters) {
            case Some(values) => Some(Array<Int64>(6) { i =>
                if (i < values.size) {
                    values[i]
                } else {
                    starts[i] - 1
                }
            })
            case None => None
        }
    }

    public prop startFrom: Array<Int64> {
        get() {
            return startFromValues
        }
    }

    public prop initialCounters: ?Array<Int64> {
        get() {
            return initialCounterValues
        }
    }
}
