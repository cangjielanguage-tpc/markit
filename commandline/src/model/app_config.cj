package commandline.model

import commandline.interfaces.Command

/**
 * 应用程序配置
 * 存储CLI应用程序的全局配置
 */
public class AppConfig {
    public let appName: String
    public let version: String
    public let description: String
    public let commands: Array<Command>
    
    public AppConfig(
        appName!: String,
        version!: String = "1.0.0",
        description!: String = "",
        commands!: Array<Command>
    ) {
        this.appName = appName
        this.version = version
        this.description = description
        this.commands = commands
    }
}