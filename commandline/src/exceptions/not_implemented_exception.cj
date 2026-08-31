package commandline.exceptions

/**
 * 未实现异常
 * 当调用尚未实现的功能时抛出
 */
public class NotImplementedException <: Exception {
    public NotImplementedException(message: String) {
        super(message)
    }
    
    public init() {
        super("not implemented")
    }
}
