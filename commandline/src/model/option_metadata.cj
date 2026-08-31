package commandline.model

/**
 * 选项元数据
 * 存储@Opt注解的信息
 */
public class OptionMetadata {
    public let names: Array<String>      // 选项名称数组，如["--v", "-V", "--verbose"]
    public let fieldName: String         // 对应的字段名
    public let help: String             // 帮助信息
    public let defaultValue: ?String    // 默认值
    public let required: Bool           // 是否必需
    
    public OptionMetadata(
        names!: Array<String>,
        fieldName!: String,
        help!: String = "",
        defaultValue!: ?String = None,
        required!: Bool = false
    ) {
        this.names = names
        this.fieldName = fieldName
        this.help = help
        this.defaultValue = defaultValue
        this.required = required
    }
}