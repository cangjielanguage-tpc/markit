package commandline.model

/**
 * 注解参数类型
 * 用于存储解析后的注解参数
 */
public class AnnotationParameter {
    public let name: String
    public let value: String
    public let isArray: Bool
    
    public AnnotationParameter(
        name!: String,
        value!: String,
        isArray!: Bool = false
    ) {
        this.name = name
        this.value = value
        this.isArray = isArray
    }
}