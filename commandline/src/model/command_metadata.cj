package commandline.model

/**
 * 命令元数据
 * 存储@Cmd注解的信息
 */
public class CommandMetadata {
    public let commandNames: Array<String>
    public let required: Bool
    public let description: String
    public let usage: String
    
    public CommandMetadata(
        commandNames!: Array<String>,
        required!: Bool = false,
        description!: String = "",
        usage!: String = ""
    ) {
        this.commandNames = commandNames
        this.required = required
        this.description = description
        this.usage = usage
    }
}