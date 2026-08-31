package fswatch.core

import fswatch.backends.BackendType
import fswatch.filters.EventFilter
import std.collection.ArrayList
/* cjlint-ignore -start !G.PKG.01 */
import std.deriving.*
/* cjlint-ignore -end */

/**
 * 文件监听器配置
 * 
 * 包含文件监听器的所有配置选项。
 */
public class MonitorConfig {
    /**
     * 监听后端类型
     */
    public var backendType: BackendType = BackendType.Auto
    
    /**
     * 轮询间隔（毫秒，仅用于轮询模式）
     */
    public var pollInterval: Int64 = 1000
    
    /**
     * 事件队列最大容量
     */
    public var eventQueueCapacity: Int64 = 10000
    
    /**
     * 是否启用递归监听
     */
    public var enableRecursiveWatch: Bool = true
    
    /**
     * 递归监听的最大深度
     */
    public var maxRecursiveDepth: Int32 = 10
    
    /**
     * 是否启用事件批处理
     */
    public var enableBatchProcessing: Bool = false
    
    /**
     * 批处理大小
     */
    public var batchSize: Int64 = 100
    
    /**
     * 批处理超时时间（毫秒）
     */
    public var batchTimeoutMs: Int64 = 100
    
    /**
     * 是否启用事件去重
     */
    public var enableEventDeduplication: Bool = true
    
    /**
     * 事件去重时间窗口（毫秒）
     */
    public var deduplicationWindowMs: Int64 = 50
    
    /**
     * 是否启用错误恢复
     */
    public var enableErrorRecovery: Bool = true
    
    /**
     * 错误恢复重试次数
     */
    public var maxRetryAttempts: Int32 = 3
    
    /**
     * 错误恢复重试间隔（毫秒）
     */
    public var retryIntervalMs: Int64 = 1000
    
    /**
     * 是否启用性能监控
     */
    public var enablePerformanceMonitoring: Bool = false
    
    /**
     * 性能统计报告间隔（毫秒）
     */
    public var performanceReportIntervalMs: Int64 = 300000  // 5分钟
    
    /**
     * 是否启用详细日志
     */
    public var enableVerboseLogging: Bool = false
    
    /**
     * 日志级别
     */
    public var logLevel: LogLevel = LogLevel.Info
    
    /**
     * 事件过滤器
     */
    public var eventFilter: ?EventFilter = None
    
    /**
     * 构造函数
     */
    public init() {}
    
    /**
     * 创建默认配置
     */
    public static func default(): MonitorConfig {
        return MonitorConfig()
    }
    
    /**
     * 创建高性能配置
     */
    public static func highPerformance(): MonitorConfig {
        let config = MonitorConfig()
        config.backendType = BackendType.Native
        config.enableBatchProcessing = true
        config.batchSize = 500
        config.batchTimeoutMs = 50
        config.enableEventDeduplication = true
        config.deduplicationWindowMs = 25
        config.eventQueueCapacity = 50000
        config.enablePerformanceMonitoring = true
        return config
    }
    
    /**
     * 创建低资源消耗配置
     */
    public static func lowResource(): MonitorConfig {
        let config = MonitorConfig()
        config.backendType = BackendType.Polling
        config.pollInterval = 2000
        config.eventQueueCapacity = 1000
        config.enableBatchProcessing = false
        config.enableEventDeduplication = false
        config.maxRecursiveDepth = 5
        config.enablePerformanceMonitoring = false
        return config
    }
    
    /**
     * 创建调试配置
     */
    public static func debug(): MonitorConfig {
        let config = MonitorConfig()
        config.enableVerboseLogging = true
        config.logLevel = LogLevel.Debug
        config.enablePerformanceMonitoring = true
        config.performanceReportIntervalMs = 60000  // 1分钟
        config.enableErrorRecovery = true
        return config
    }
    
    /**
     * 验证配置的有效性
     */
    public func validate(): Array<String> {
        let errors = ArrayList<String>()
        
        if (pollInterval < 10) {
            errors.add("Poll interval must be at least 10ms")
        }
        
        if (eventQueueCapacity <= 0) {
            errors.add("Event queue capacity must be positive")
        }
        
        if (maxRecursiveDepth < 0) {
            errors.add("Max recursive depth cannot be negative")
        }
        
        if (batchSize <= 0) {
            errors.add("Batch size must be positive")
        }
        
        if (batchTimeoutMs < 1) {
            errors.add("Batch timeout must be at least 1ms")
        }
        
        if (deduplicationWindowMs < 0) {
            errors.add("Deduplication window cannot be negative")
        }
        
        if (maxRetryAttempts < 0) {
            errors.add("Max retry attempts cannot be negative")
        }
        
        if (retryIntervalMs < 0) {
            errors.add("Retry interval cannot be negative")
        }
        
        return errors.toArray()
    }
    
    /**
     * 克隆配置
     */
    public func clone(): MonitorConfig {
        let config = MonitorConfig()
        config.backendType = this.backendType
        config.pollInterval = this.pollInterval
        config.eventQueueCapacity = this.eventQueueCapacity
        config.enableRecursiveWatch = this.enableRecursiveWatch
        config.maxRecursiveDepth = this.maxRecursiveDepth
        config.enableBatchProcessing = this.enableBatchProcessing
        config.batchSize = this.batchSize
        config.batchTimeoutMs = this.batchTimeoutMs
        config.enableEventDeduplication = this.enableEventDeduplication
        config.deduplicationWindowMs = this.deduplicationWindowMs
        config.enableErrorRecovery = this.enableErrorRecovery
        config.maxRetryAttempts = this.maxRetryAttempts
        config.retryIntervalMs = this.retryIntervalMs
        config.enablePerformanceMonitoring = this.enablePerformanceMonitoring
        config.performanceReportIntervalMs = this.performanceReportIntervalMs
        config.enableVerboseLogging = this.enableVerboseLogging
        config.logLevel = this.logLevel
        config.eventFilter = this.eventFilter
        return config
    }
    
    /**
     * 获取配置的字符串表示
     */
    public func toString(): String {
        return "MonitorConfig{" +
               "backendType=${backendType}, " +
               "pollInterval=${pollInterval}, " +
               "eventQueueCapacity=${eventQueueCapacity}, " +
               "enableRecursiveWatch=${enableRecursiveWatch}, " +
               "maxRecursiveDepth=${maxRecursiveDepth}, " +
               "enableBatchProcessing=${enableBatchProcessing}, " +
               "batchSize=${batchSize}, " +
               "enableEventDeduplication=${enableEventDeduplication}, " +
               "enableErrorRecovery=${enableErrorRecovery}, " +
               "enablePerformanceMonitoring=${enablePerformanceMonitoring}, " +
               "logLevel=${logLevel}" +
               "}"
    }
}

/**
 * 日志级别枚举
 */
@Derive[ToString]
public enum LogLevel {
    | Debug
    | Info
    | Warning
    | Error
    
    public func getLevel(): Int32 {
        match (this) {
            case Debug => 0
            case Info => 1
            case Warning => 2
            case Error => 3
        }
    }
}
