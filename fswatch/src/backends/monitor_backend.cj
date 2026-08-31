package fswatch.backends

/* cjlint-ignore -start !G.VAR.02 !G.ERR.01 !G.PKG.01 */
import fswatch.events.FileEvent
import std.fs.{Path, exists}
import std.collection.concurrent.ConcurrentLinkedQueue
import std.collection.{HashSet, ArrayList}
import std.sync.Mutex
import std.deriving.*

/**
 * 监听后端类型枚举
 */
@Derive[ToString]
public enum BackendType {
    | Native      // 原生系统API（例如 inotify、FSEvents）
    | Polling     // 轮询模式
    | Auto        // 自动选择
}

/**
 * 监听后端接口
 * 
 * 定义文件监听后端的基本接口，支持不同的实现方式。
 */
public interface MonitorBackend {
    /**
     * 启动监听
     */
    func start(): Unit
    
    /**
     * 停止监听
     */
    func stop(): Unit
    
    /**
     * 添加监听路径
     */
    func addWatch(path: Path, recursive: Bool): Unit
    
    /**
     * 移除监听路径
     */
    func removeWatch(path: Path): Unit
    
    /**
     * 检查是否正在运行
     */
    func isRunning(): Bool
    
    /**
     * 获取后端类型
     */
    func getBackendType(): BackendType
    
    /**
     * 设置事件处理器
     */
    func setEventHandler(handler: (FileEvent) -> Unit): Unit
    
    /**
     * 获取支持的特性
     */
    func getSupportedFeatures(): HashSet<String>
    
    /**
     * 清理资源
     */
    func cleanup(): Unit
}

/**
 * 抽象监听后端基类
 * 
 * 提供监听后端的通用实现和状态管理。
 */
public open class AbstractMonitorBackend <: MonitorBackend {
    protected var isRunningFlag: Bool = false
    protected var eventHandler: ?((FileEvent) -> Unit) = None
    protected let watchedPaths: HashSet<Path> = HashSet<Path>()
    protected let eventQueue: ConcurrentLinkedQueue<FileEvent> = ConcurrentLinkedQueue<FileEvent>()
    protected let mutex = Mutex()
    
    /**
     * 启动监听
     * 
     * @throws Exception 当启动过程中发生错误时抛出
     */
    public func start(): Unit {
        synchronized(mutex) {
            if (isRunningFlag) {
                return  // Already running
            }
            
            try {
                doStart()
                isRunningFlag = true
            } catch (e: Exception) {
                println("Failed to start monitor backend")
                throw e
            }
        }
    }
    
    /**
     * 停止监听
     * 
     * @throws Exception 当停止过程中发生错误时抛出
     */
    public func stop(): Unit {
        synchronized(mutex) {
            if (!isRunningFlag) {
                return  // Already stopped
            }
            
            try {
                doStop()
                isRunningFlag = false
            } catch (e: Exception) {
                println("Failed to stop monitor backend")
                throw e
            }
        }
    }
    
    /**
     * 检查是否正在运行
     */
    public func isRunning(): Bool {
        synchronized(mutex) {
            return isRunningFlag
        }
    }
    
    /**
     * 设置事件处理器
     */
    public func setEventHandler(handler: (FileEvent) -> Unit): Unit {
        synchronized(mutex) {
            this.eventHandler = Some(handler)
        }
    }
    
    /**
     * 添加监听路径
     */
    public func addWatch(path: Path, recursive: Bool): Unit {
        synchronized(mutex) {
            if (!exists(path)) {
                println("Path does not exist: ${path}")
                return
            }
            
            if (watchedPaths.contains(path)) {
                return  // 已经在监听，直接返回
            }
            
            try {
                doAddWatch(path, recursive)
                watchedPaths.add(path)
            } catch (_: Exception) {
                println("Failed to add watch for path: ${path}")
            }
        }
    }
    
    /**
     * 移除监听路径
     */
    public func removeWatch(path: Path): Unit {
        synchronized(mutex) {
            if (!watchedPaths.contains(path)) {
                return  // 没有在监听，直接返回
            }
            
            try {
                doRemoveWatch(path)
                watchedPaths.remove(path)
            } catch (_: Exception) {
                println("Failed to remove watch for path: ${path}")
            }
        }
    }
    
    /**
     * 清理资源
     */
    public func cleanup(): Unit {
        try {
            if (isRunning()) {
                stop()
            }
        } catch (_: Exception) {
            // 忽略清理时的错误
        }
        
        synchronized(mutex) {
            watchedPaths.clear()
            // Clear the queue by removing all elements
            while (eventQueue.size > 0) {
                eventQueue.remove()
            }
            eventHandler = None
        }
    }
    
    /**
     * 处理事件
     */
    protected func handleEvent(event: FileEvent): Unit {
        match (eventHandler) {
            case Some(handler) => handleEventWithHandler(handler, event)
            case None => eventQueue.add(event)
        }
    }
    
    private func handleEventWithHandler(handler: (FileEvent) -> Unit, event: FileEvent): Unit {
        try {
            handler(event)
        } catch (_: Exception) {
            // 记录错误但不中断监听
            println("Error handling event: ${event}")
        }
    }
    
    /**
     * 获取队列中的事件
     */
    public func pollEvents(): Array<FileEvent> {
        let events = ArrayList<FileEvent>()
        while (eventQueue.size > 0) {
            match (eventQueue.remove()) {
                case Some(event) => events.add(event)
                case None => break
            }
        }
        return events.toArray()
    }
    
    /**
     * 获取监听的路径数量
     */
    public func getWatchedPathCount(): Int64 {
        synchronized(mutex) {
            return watchedPaths.size
        }
    }
    
    // 需要子类实现的方法
    public open func getBackendType(): BackendType {
        throw Exception("getBackendType() must be implemented by subclass")
    }
    
    public open func getSupportedFeatures(): HashSet<String> {
        throw Exception("getSupportedFeatures() must be implemented by subclass")
    }
    
    // 虚拟方法，由具体实现重写
    protected open func doStart(): Unit {
        // Default implementation - do nothing
    }
    
    protected open func doStop(): Unit {
        // Default implementation - do nothing
    }
    
    protected open func doAddWatch(_: Path, _: Bool): Unit {
        // Default implementation - do nothing
    }
    
    protected open func doRemoveWatch(_: Path): Unit {
        // Default implementation - do nothing
    }
}
/* cjlint-ignore -end */
