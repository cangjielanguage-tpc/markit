package fswatch.errors

/**
 * 文件监听错误类型枚举
 * 
 * 定义了文件监听过程中可能出现的各种错误类型。
 */
public enum MonitorError {
    /**
     * 监听目标不存在
     */
    | TargetNotFound(String)
    
    /**
     * 权限不足
     */
    | PermissionDenied(String)
    
    /**
     * 系统资源不足
     */
    | ResourceExhausted(String)
    
    /**
     * 原生后端不可用
     */
    | NativeBackendUnavailable(String)
    
    /**
     * 监听器已经在运行
     */
    | AlreadyRunning(String)
    
    /**
     * 监听器未运行
     */
    | NotRunning(String)
    
    /**
     * 无效的配置
     */
    | InvalidConfiguration(String)
    
    /**
     * 事件队列溢出
     */
    | EventQueueOverflow(String)
    
    /**
     * 网络或I/O错误
     */
    | IOError(String)
    
    /**
     * 系统调用失败
     */
    | SystemCallFailed(String, Int32)
    
    /**
     * 未知错误
     */
    | Unknown(String)
    
    /**
     * 获取错误的字符串表示
     */
    public func toString(): String {
        match (this) {
            case TargetNotFound(msg) => "Target not found: ${msg}"
            case PermissionDenied(msg) => "Permission denied: ${msg}"
            case ResourceExhausted(msg) => "Resource exhausted: ${msg}"
            case NativeBackendUnavailable(msg) => "Native backend unavailable: ${msg}"
            case AlreadyRunning(msg) => "Already running: ${msg}"
            case NotRunning(msg) => "Not running: ${msg}"
            case InvalidConfiguration(msg) => "Invalid configuration: ${msg}"
            case EventQueueOverflow(msg) => "Event queue overflow: ${msg}"
            case IOError(msg) => "I/O error: ${msg}"
            case SystemCallFailed(msg, code) => "System call failed: ${msg} (code: ${code})"
            case Unknown(msg) => "Unknown error: ${msg}"
        }
    }
    
    /**
     * 获取错误代码
     */
    public func getErrorCode(): Int32 {
        match (this) {
            case TargetNotFound(_) => 1001
            case PermissionDenied(_) => 1002
            case ResourceExhausted(_) => 1003
            case NativeBackendUnavailable(_) => 1004
            case AlreadyRunning(_) => 1005
            case NotRunning(_) => 1006
            case InvalidConfiguration(_) => 1007
            case EventQueueOverflow(_) => 1008
            case IOError(_) => 1009
            case SystemCallFailed(_, code) => code
            case Unknown(_) => 9999
        }
    }
    
    /**
     * 判断是否为可恢复的错误
     */
    public func isRecoverable(): Bool {
        match (this) {
            case ResourceExhausted(_) | EventQueueOverflow(_) | IOError(_) => true
            case _ => false
        }
    }
    
    /**
     * 判断是否应该重试
     */
    public func shouldRetry(): Bool {
        match (this) {
            case ResourceExhausted(_) | IOError(_) => true
            case _ => false
        }
    }
}