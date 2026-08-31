package commandline.model

/**
 * 选项字段信息数据结构
 * 用于在宏处理过程中传递字段元数据
 */
public class OptionFieldInfo {
    public let fieldName: String
    public let names: Array<String>
    public let help: String
    public let fieldType: String
    public let defaultValue: ?String
    public let required: Bool
    
    public OptionFieldInfo(
        fieldName!: String,
        names!: Array<String>,
        help!: String,
        fieldType!: String,
        defaultValue!: ?String = None,
        required!: Bool = false
    ) {
        this.fieldName = fieldName
        this.names = names
        this.help = help
        this.fieldType = fieldType
        this.defaultValue = defaultValue
        this.required = required
    }
}