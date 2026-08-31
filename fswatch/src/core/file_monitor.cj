package fswatch.core

/* cjlint-ignore -start !G.ITF.04 !G.VAR.02 !G.EXP.07 !G.FUN.01 !G.ERR.01 !G.PKG.01 */
import fswatch.events.{FileEvent, EventHandlerManager}
import fswatch.backends.{MonitorBackend, BackendType, PollingBackend}
import fswatch.filters.EventFilter
import fswatch.errors.{MonitorError, MonitorException}
import std.fs.{Path, exists}
import std.time.MonoTime
import std.collection.HashSet
import std.sync.Mutex
import std.deriving.*

@When[os == "macOS"]
import fswatch.backends.MacOSFSEventsBackend
@When[os == "Linux"]
import fswatch.backends.LinuxInotifyBackend

/**
 * 文件监听器状态枚举
 */
@Derive[ToString]
public enum MonitorState {
    | Stopped     // 已停止
    | Starting    // 正在启动
    | Running     // 正在运行
    | Stopping    // 正在停止
    | Error       // 错误状态
}

/**
 * 性能统计信息
 */
@Derive[ToString]
public struct PerformanceStats {
    public let eventsProcessed: Int64
    public let eventsPerSecond: Int64  // 改为Int64
    public let averageProcessingTimeMs: Int64  // 改为毫秒
    public let queueSize: Int64
    public let memoryUsage: Int64
    public let uptimeMs: Int64  // 改为毫秒
    
    public init(
        eventsProcessed: Int64,
        eventsPerSecond: Int64,
        averageProcessingTimeMs: Int64,
        queueSize: Int64,
        memoryUsage: Int64,
        uptimeMs: Int64
    ) {
        this.eventsProcessed = eventsProcessed
        this.eventsPerSecond = eventsPerSecond
        this.averageProcessingTimeMs = averageProcessingTimeMs
        this.queueSize = queueSize
        this.memoryUsage = memoryUsage
        this.uptimeMs = uptimeMs
    }
}

/**
 * 文件监听器主类
 * 
 * 提供高级的文件监听功能，支持多种后端、事件过滤、错误恢复等特性。
 */
public class FileMonitor {
    private let config: MonitorConfig
    private var backend: ?MonitorBackend = None
    private let eventHandlerManager: EventHandlerManager = EventHandlerManager()
    private var state: MonitorState = MonitorState.Stopped
    private let mutex = Mutex()
    private let watchedPaths: HashSet<Path> = HashSet<Path>()
    private let recursiveWatches: HashSet<Path> = HashSet<Path>()
    
    // 性能统计
    private var startTime: ?MonoTime = None
    private var eventsProcessed: Int64 = 0
    private var totalProcessingTimeMs: Int64 = 0  // 改为毫秒
    private var lastStatsReport: MonoTime = MonoTime.now()
    
    // 错误恢复
    private var retryCount: Int32 = 0
    private var lastError: ?MonitorException = None
    
    /**
     * 构造文件监听器
     * 验证配置参数并初始化监听器状态
     * 
     * @param config 监听器配置，默认使用标准配置
     * @throws MonitorException.invalidConfiguration 当配置验证失败时抛出，包含具体的验证错误信息
     */
    public init(config!: MonitorConfig = MonitorConfig.default()) {
        this.config = config.clone()
        
        // 验证配置
        let errors = this.config.validate()
        if (!errors.isEmpty()) {
            let errorMsg = String.join(errors, delimiter: "; ")
            throw MonitorException.invalidConfiguration(errorMsg, "FileMonitor.init")
        }
    }
    
    /**
     * 启动文件监听
     * 创建并配置监听后端，开始监听文件系统事件
     * 
     * @throws MonitorException.alreadyRunning 当监听器已在运行时抛出
     * @throws MonitorException.startupFailed 当后端启动失败时抛出，包含具体的失败原因
     */
    public func start(): Unit {
        mutex.lock()
        try {
            match (state) {
                case MonitorState.Running => 
                    throw MonitorException(
                        MonitorError.AlreadyRunning("File monitor is already running"),
                        "FileMonitor.start"
                    )
                case _ => ()
            }
            
            match (state) {
                case MonitorState.Starting => 
                    throw MonitorException(
                        MonitorError.AlreadyRunning("File monitor is already starting"),
                        "FileMonitor.start"
                    )
                case _ => ()
            }
            
            state = MonitorState.Starting
            
            try {
                // 创建后端
                backend = Some(createBackend())
                
                // 配置事件处理
                match (backend) {
                    case Some(b) => configureBackend(b)
                    case None => throw MonitorException(
                        MonitorError.Unknown("Failed to create backend"),
                        "FileMonitor.start"
                    )
                }
                
                state = MonitorState.Running
                startTime = Some(MonoTime.now())
                retryCount = 0
                lastError = None
                
                if (config.enableVerboseLogging) {
                    println("File monitor started with backend: ${getBackendType()}")
                }
                
            } catch (e: Exception) {
                state = MonitorState.Error
                let exception = match (e) {
                    case me: MonitorException => me
                    case _ => MonitorException(
                        MonitorError.Unknown("Failed to start file monitor: ${e.message}"),
                        "FileMonitor.start",
                        Some(e)
                    )
                }
                lastError = Some(exception)
                throw exception
            }
        } finally {
            mutex.unlock()
        }
    }
    
    /**
     * 停止文件监听
     * 
     * @throws MonitorException 当停止过程中发生错误时抛出
     */
    public func stop(): Unit {
        mutex.lock()
        try {
            match (state) {
                case MonitorState.Stopped => return  // 已经停止
                case _ => ()
            }
            
            match (state) {
                case MonitorState.Stopping => return  // 正在停止
                case _ => ()
            }
            
            state = MonitorState.Stopping
            
            try {
                match (backend) {
                    case Some(b) => stopBackend(b)
                    case None => ()
                }
                
                backend = None
                state = MonitorState.Stopped
                startTime = None
                
                if (config.enableVerboseLogging) {
                    println("File monitor stopped")
                }
                
            } catch (e: Exception) {
                state = MonitorState.Error
                let exception = match (e) {
                    case me: MonitorException => me
                    case _ => MonitorException(
                        MonitorError.Unknown("Failed to stop file monitor: ${e.message}"),
                        "FileMonitor.stop",
                        Some(e)
                    )
                }
                lastError = Some(exception)
                throw exception
            }
        } finally {
            mutex.unlock()
        }
    }
    
    /**
     * 添加监听路径
     * 将指定路径添加到监听列表，开始监听该路径下的文件系统事件
     * 
     * @param path 要监听的文件或目录路径
     * @param recursive 是否递归监听子目录，默认为false
     * @throws MonitorException.pathNotFound 当指定路径不存在时抛出
     * @throws MonitorException.addWatchFailed 当添加监听失败时抛出，可能由于权限不足或系统限制
     */
    public func watch(path: Path, recursive!: Bool = false): Unit {
        mutex.lock()
        try {
            if (!exists(path)) {
                throw MonitorException.targetNotFound(path.toString(), "FileMonitor.watch")
            }
            
            watchedPaths.add(path)
            if (recursive) {
                recursiveWatches.add(path)
            }
            
            // 如果监听器正在运行，立即添加到后端
            match (state) {
                case MonitorState.Running => 
                    match (backend) {
                        case Some(b) => b.addWatch(path, recursive)
                        case None => ()
                    }
                case _ => ()
            }
            
            if (config.enableVerboseLogging) {
                println("Added watch for path: ${path} (recursive: ${recursive})")
            }
        } finally {
            mutex.unlock()
        }
    }
    
    /**
     * 移除监听路径
     */
    public func unwatch(path: Path): Unit {
        mutex.lock()
        try {
            watchedPaths.remove(path)
            recursiveWatches.remove(path)
            
            // 如果监听器正在运行，从后端移除
            match (state) {
                case MonitorState.Running => 
                    match (backend) {
                        case Some(b) => b.removeWatch(path)
                        case None => ()
                    }
                case _ => ()
            }
            
            if (config.enableVerboseLogging) {
                println("Removed watch for path: ${path}")
            }
        } finally {
            mutex.unlock()
        }
    }
    
    /**
     * 添加事件处理器
     */
    public func addEventHandler(handler: (FileEvent) -> Unit): Unit {
        eventHandlerManager.addHandler(handler)
    }
    
    /**
     * 清除所有事件处理器
     */
    public func clearEventHandlers(): Unit {
        eventHandlerManager.clearHandlers()
    }
    
    /**
     * 获取当前状态
     */
    public func getState(): MonitorState {
        mutex.lock()
        try {
            return state
        } finally {
            mutex.unlock()
        }
    }
    
    /**
     * 检查是否正在运行
     */
    public func isRunning(): Bool {
        match (getState()) {
            case MonitorState.Running => true
            case _ => false
        }
    }
    
    /**
     * 获取后端类型
     */
    public func getBackendType(): BackendType {
        mutex.lock()
        try {
            match (backend) {
                case Some(b) => b.getBackendType()
                case None => config.backendType
            }
        } finally {
            mutex.unlock()
        }
    }
    
    /**
     * 获取监听的路径数量
     */
    public func getWatchedPathCount(): Int64 {
        mutex.lock()
        try {
            return watchedPaths.size
        } finally {
            mutex.unlock()
        }
    }
    
    /**
     * 获取性能统计信息
     */
    public func getPerformanceStats(): PerformanceStats {
        mutex.lock()
        try {
            let now = MonoTime.now()
            let uptimeMs = match (startTime) {
                case Some(start) => 
                    let duration = now - start
                    duration.toNanoseconds() / 1000000  // 转换为毫秒
                case None => 0
            }
            
            let eventsPerSecond = if (uptimeMs > 0) {
                let uptimeSeconds = uptimeMs / 1000  // 转换为秒
                if (uptimeSeconds > 0) {
                    eventsProcessed / uptimeSeconds
                } else {
                    0
                }
            } else {
                0
            }
            
            let averageProcessingTimeMs = if (eventsProcessed > 0) {
                totalProcessingTimeMs / eventsProcessed
            } else {
                0
            }
            
            let queueSize = match (backend) {
                case Some(b) => 0  // 这里需要后端提供队列大小信息，占位符
                case None => 0
            }
            
            return PerformanceStats(
                eventsProcessed,
                eventsPerSecond,
                averageProcessingTimeMs,
                queueSize,
                0,  // 需要实现内存使用统计
                uptimeMs
            )
        } finally {
            mutex.unlock()
        }
    }
    
    /**
     * 获取最后的错误
     */
    public func getLastError(): ?MonitorException {
        mutex.lock()
        try {
            return lastError
        } finally {
            mutex.unlock()
        }
    }
    
    /**
     * 重置错误状态
     */
    public func resetError(): Unit {
        mutex.lock()
        try {
            match (state) {
                case MonitorState.Error => state = MonitorState.Stopped
                case _ => ()
            }
            lastError = None
            retryCount = 0
        } finally {
            mutex.unlock()
        }
    }
    
    /**
     * 停止后端
     */
    private func stopBackend(b: MonitorBackend): Unit {
        b.stop()
        b.cleanup()
    }

    private func shouldRetryWithPolling(backend: MonitorBackend): Bool {
        match (config.backendType) {
            case BackendType.Polling => return false
            case _ => ()
        }
        match (backend.getBackendType()) {
            case BackendType.Native => return true
            case _ => return false
        }
    }

    private func warnAndCreatePollingBackend(reason: String): MonitorBackend {
        println("WARNING: Native backend unavailable, falling back to polling: ${reason}")
        return PollingBackend(config.pollInterval, config.maxRecursiveDepth)
    }

    /**
     * 配置后端
     */
    private func configureBackend(b: MonitorBackend): Unit {
        b.setEventHandler({ event => handleEvent(event) })
        
        // 添加已配置的监听路径
        for (path in watchedPaths) {
            let isRecursive = recursiveWatches.contains(path)
            b.addWatch(path, isRecursive)
        }
        
        try {
            b.start()
        } catch (e: Exception) {
            if (!shouldRetryWithPolling(b)) {
                throw e
            }

            b.cleanup()
            let fallbackBackend = warnAndCreatePollingBackend(e.message)
            backend = Some(fallbackBackend)
            fallbackBackend.setEventHandler({ event => handleEvent(event) })
            for (path in watchedPaths) {
                let isRecursive = recursiveWatches.contains(path)
                fallbackBackend.addWatch(path, isRecursive)
            }
            fallbackBackend.start()
        }
    }

    /**
     * 创建监听后端
     */
    private func createBackend(): MonitorBackend {
        match (config.backendType) {
            case BackendType.Polling => PollingBackend(config.pollInterval, config.maxRecursiveDepth)
            case BackendType.Native => createNativeOrFallback()
            case BackendType.Auto => createNativeOrFallback()
        }
    }
    
    /**
     * 创建原生后端或降级到轮询
     */
    private func createNativeOrFallback(): MonitorBackend {
        try {
            return createNativeBackend()
        } catch (e: Exception) {
            println("WARNING: Native backend unavailable, falling back to polling: ${e.message}")
            return PollingBackend(config.pollInterval, config.maxRecursiveDepth)
        }
    }
    
    /**
     * 创建原生后端
     * 根据操作系统类型创建相应的原生文件监听后端
     * 
     * @return 原生监听后端实例
     * @throws Exception 当原生后端不可用时抛出，通常是因为系统不支持或权限不足
     */
    @When[os == "macOS"]
    private func createNativeBackend(): MonitorBackend {
        return MacOSFSEventsBackend(config.maxRecursiveDepth)
    }

    @When[os != "macOS"]
    private func createNativeBackend(): MonitorBackend {
        return createNonMacNativeBackend()
    }

    @When[os == "Linux"]
    private func createNonMacNativeBackend(): MonitorBackend {
        return LinuxInotifyBackend(config.maxRecursiveDepth)
    }

    @When[os != "Linux"]
    private func createNonMacNativeBackend(): MonitorBackend {
        throw MonitorException(
            MonitorError.NativeBackendUnavailable("Native backend is unavailable on the current operating system"),
            "FileMonitor.createNonMacNativeBackend"
        )
    }
    
    /**
     * 处理文件系统事件
     */
    private func handleEvent(event: FileEvent): Unit {
        let eventStartTime = MonoTime.now()
        
        try {
            // 应用事件过滤器
            match (config.eventFilter) {
                case Some(filter) => 
                    if (!filter.shouldProcess(event)) {
                        return
                    }
                case None => ()
            }
            
            // 分发事件给处理器
            eventHandlerManager.handleEvent(event)
            
            // 更新统计信息
            mutex.lock()
            eventsProcessed += 1
            let processingDuration = MonoTime.now() - eventStartTime
            let processingTimeMs = processingDuration.toNanoseconds() / 1000000
            totalProcessingTimeMs += processingTimeMs
            mutex.unlock()
            
            // 定期报告性能统计
            if (config.enablePerformanceMonitoring) {
                let now = MonoTime.now()
                let timeSinceLastReport = now - lastStatsReport
                let timeSinceLastReportMs = timeSinceLastReport.toNanoseconds() / 1000000
                if (config.performanceReportIntervalMs <= timeSinceLastReportMs) {
                    reportPerformanceStats()
                    lastStatsReport = now
                }
            }
            
        } catch (e: Exception) {
            if (config.enableVerboseLogging) {
                println("Error handling event ${event}: ${e.message}")
            }
            
            // 如果启用了错误恢复，尝试恢复
            if (config.enableErrorRecovery) {
                handleError(e)
            }
        }
    }
    
    /**
     * 处理错误并尝试恢复
     */
    private func handleError(error: Exception): Unit {
        mutex.lock()
        try {
            retryCount += 1
            
            if (retryCount <= config.maxRetryAttempts) {
                if (config.enableVerboseLogging) {
                    println("Attempting error recovery (attempt ${retryCount}/${config.maxRetryAttempts})")
                }
                
                // 异步重试
                spawn {
                    // 简单的延迟实现
                    let startDelay = MonoTime.now()
                    let delayNs = config.retryIntervalMs * 1000000  // 转换为纳秒
                    while (true) {
                        let elapsed = MonoTime.now() - startDelay
                        if (elapsed.toNanoseconds() >= delayNs) {
                            break
                        }
                    }
                    
                    try {
                        // 重启监听器
                        stop()
                        start()
                    } catch (e: MonitorException) {
                        if (config.enableVerboseLogging) {
                            println("Error recovery failed: ${e.message}")
                        }
                    }
                }
            } else {
                state = MonitorState.Error
                lastError = Some(MonitorException(
                    MonitorError.Unknown("Max retry attempts exceeded: ${error.message}"),
                    "FileMonitor.handleError",
                    Some(error)
                ))
                
                if (config.enableVerboseLogging) {
                    println("Error recovery failed after ${config.maxRetryAttempts} attempts")
                }
            }
        } finally {
            mutex.unlock()
        }
    }
    
    /**
     * 报告性能统计
     */
    private func reportPerformanceStats(): Unit {
        let stats = getPerformanceStats()
        println("Performance Stats: ${stats}")
    }
    
    /**
     * 清理资源
     * 停止监听并清理所有相关资源，确保监听器完全关闭
     * 此方法保证不会抛出异常，适合在析构或错误恢复时调用
     */
    public func cleanup(): Unit {
        try {
            stop()
        } catch (_: MonitorException) {
            // 清理过程中忽略停止失败的异常，确保清理过程能够完成
            // 这是安全的，因为清理的目的就是释放资源，即使停止失败也要继续清理
        }
        
        eventHandlerManager.clearHandlers()
        watchedPaths.clear()
        recursiveWatches.clear()
    }
}
/* cjlint-ignore -end */
