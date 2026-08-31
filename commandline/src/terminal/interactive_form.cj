package commandline.terminal

public class InteractiveForm {
    private let logger: ProgressLogger

    public init(logger!: ProgressLogger = progressLogger) {
        this.logger = logger
    }

    public func prompt(
        message: String,
        defaultValue!: ?String = None,
        allowEmpty!: Bool = false,
        secret!: Bool = false
    ): String {
        return logger.prompt(message, defaultValue: defaultValue, allowEmpty: allowEmpty, secret: secret)
    }

    public func confirm(message: String, defaultValue!: ?Bool = None): Bool {
        return logger.confirm(message, defaultValue: defaultValue)
    }

    public func requireConfirm(
        message: String,
        defaultValue!: ?Bool = None,
        abortMessage!: String = "Operation cancelled"
    ): Unit {
        if (!confirm(message, defaultValue: defaultValue)) {
            throw Exception(abortMessage)
        }
    }

    public func select(message: String, options: Array<String>, defaultIndex!: ?Int = None): SelectResult {
        return logger.select(message, options, defaultIndex: defaultIndex)
    }

    public func selectValue(message: String, options: Array<String>, defaultIndex!: ?Int = None): ?String {
        match (select(message, options, defaultIndex: defaultIndex)) {
            case SelectResult.Selected(index) => return Some(options[index])
            case SelectResult.Cancelled => return None<String>
        }
    }

    public func multiSelect(
        message: String,
        options: Array<String>,
        defaultIndices!: Array<Int> = []
    ): MultiSelectResult {
        return logger.multiSelect(message, options, defaultIndices: defaultIndices)
    }

    public func multiSelectValues(
        message: String,
        options: Array<String>,
        defaultIndices!: Array<Int> = []
    ): ?Array<String> {
        match (multiSelect(message, options, defaultIndices: defaultIndices)) {
            case MultiSelectResult.Selected(indices) =>
                let result = Array<String>(indices.size, repeat: "")
                for (i in 0..indices.size) {
                    result[i] = options[indices[i]]
                }
                return Some(result)
            case MultiSelectResult.Cancelled => return None<Array<String>>
        }
    }
}
