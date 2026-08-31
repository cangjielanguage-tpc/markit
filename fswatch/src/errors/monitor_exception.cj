package fswatch.errors

/**
 * 文件监听异常类
 * 
 * 封装文件监听过程中的异常信息，提供详细的错误上下文。
 */
public class MonitorException <: Exception {
    /**
     * 错误类型
     */
    public let error: MonitorError
    
    /**
     * 错误上下文信息
     */
    public let context: String
    
    /**
     * 内部异常（如果有）
     */
    public let innerException: ?Exception
    
    /**
     * 构造函数（完整参数）
     */
    public init(
        error: MonitorError,
        context: String,
        innerException: ?Exception
    ) {
        super(error.toString())
        this.error = error
        this.context = context
        this.innerException = innerException
    }
    
    /**
     * 构造函数（无内部异常）
     */
    public init(error: MonitorError, context: String) {
        super(error.toString())
        this.error = error
        this.context = context
        this.innerException = None
    }
    
    /**
     * 构造函数（仅错误）
     */
    public init(error: MonitorError) {
        super(error.toString())
        this.error = error
        this.context = ""
        this.innerException = None
    }
    
    /**
     * 获取完整的错误信息
     */
    public func getFullMessage(): String {
        var msg = error.toString()
        
        if (!context.isEmpty()) {
            msg += " [Context: ${context}]"
        }
        
        match (innerException) {
            case Some(inner) => msg += " [Inner: ${inner.message}]"
            case None => msg = msg  // 无内部异常，保持原样
        }
        
        return msg
    }
    
    /**
     * 获取错误代码
     */
    public func getErrorCode(): Int32 {
        return error.getErrorCode()
    }
    
    /**
     * 判断是否为可恢复的错误
     */
    public func isRecoverable(): Bool {
        return error.isRecoverable()
    }
    
    /**
     * 判断是否应该重试
     */
    public func shouldRetry(): Bool {
        return error.shouldRetry()
    }
    
    /**
     * 创建权限拒绝异常（带上下文）
     */
    public static func permissionDenied(path: String, context: String): MonitorException {
        return MonitorException(
            MonitorError.PermissionDenied("Cannot access path: ${path}"),
            context
        )
    }
    
    /**
     * 创建权限拒绝异常（无上下文）
     */
    public static func permissionDenied(path: String): MonitorException {
        return MonitorException(
            MonitorError.PermissionDenied("Cannot access path: ${path}")
        )
    }
    
    /**
     * 创建目标不存在异常（带上下文）
     */
    public static func targetNotFound(path: String, context: String): MonitorException {
        return MonitorException(
            MonitorError.TargetNotFound("Path does not exist: ${path}"),
            context
        )
    }
    
    /**
     * 创建目标不存在异常（无上下文）
     */
    public static func targetNotFound(path: String): MonitorException {
        return MonitorException(
            MonitorError.TargetNotFound("Path does not exist: ${path}")
        )
    }
    
    /**
     * 创建资源耗尽异常（带上下文）
     */
    public static func resourceExhausted(resource: String, context: String): MonitorException {
        return MonitorException(
            MonitorError.ResourceExhausted("Resource exhausted: ${resource}"),
            context
        )
    }
    
    /**
     * 创建资源耗尽异常（无上下文）
     */
    public static func resourceExhausted(resource: String): MonitorException {
        return MonitorException(
            MonitorError.ResourceExhausted("Resource exhausted: ${resource}")
        )
    }
    
    /**
     * 创建配置无效异常（带上下文）
     */
    public static func invalidConfiguration(config: String, context: String): MonitorException {
        return MonitorException(
            MonitorError.InvalidConfiguration("Invalid configuration: ${config}"),
            context
        )
    }
    
    /**
     * 创建配置无效异常（无上下文）
     */
    public static func invalidConfiguration(config: String): MonitorException {
        return MonitorException(
            MonitorError.InvalidConfiguration("Invalid configuration: ${config}")
        )
    }
    
    /**
     * 创建系统调用失败异常（带上下文）
     */
    public static func systemCallFailed(
        syscall: String, 
        errorCode: Int32, 
        context: String
    ): MonitorException {
        return MonitorException(
            MonitorError.SystemCallFailed("System call '${syscall}' failed", errorCode),
            context
        )
    }
    
    /**
     * 创建系统调用失败异常（无上下文）
     */
    public static func systemCallFailed(syscall: String, errorCode: Int32): MonitorException {
        return MonitorException(
            MonitorError.SystemCallFailed("System call '${syscall}' failed", errorCode)
        )
    }
}