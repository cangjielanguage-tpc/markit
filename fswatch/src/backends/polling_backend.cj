package fswatch.backends

/* cjlint-ignore -start !G.VAR.02 !G.ERR.01 */
import fswatch.events.{FileEvent, EventType}
import std.fs.{Path, FileInfo, Directory}
import std.time.{DateTime, MonoTime}
import std.collection.{HashMap, HashSet, ArrayList}

/**
 * 文件状态信息
 */
struct FileState {
    let path: Path
    var lastModified: DateTime
    var size: Int64
    var isDirectory: Bool
    var exists: Bool
    
    init(path: Path) {
        this.path = path
        
        try {
            let info = FileInfo(path)
            if (info.isRegular() || info.isDirectory()) {
                try {
                    this.lastModified = info.lastModificationTime
                    this.size = info.size
                    this.isDirectory = info.isDirectory()
                    this.exists = true
                } catch (_: Exception) {
                    this.lastModified = DateTime.now()
                    this.size = 0
                    this.isDirectory = false
                    this.exists = false
                }
            } else {
                this.lastModified = DateTime.now()
                this.size = 0
                this.isDirectory = false
                this.exists = false
            }
        } catch (_: Exception) {
            this.lastModified = DateTime.now()
            this.size = 0
            this.isDirectory = false
            this.exists = false
        }
    }
    
    func hasChanged(other: FileState): Bool {
        return exists != other.exists ||
               lastModified != other.lastModified ||
               size != other.size
    }
}

/**
 * 轮询监听后端
 * 
 * 通过定期轮询文件系统状态来检测文件变化。
 * 虽然性能不如原生API，但具有最好的跨平台兼容性。
 */
public class PollingBackend <: AbstractMonitorBackend {
    private var pollInterval: Int64  // milliseconds
    private var maxDepth: Int32
    private var pollingFuture: ?String = None  // Using String as placeholder for Future
    private let fileStates: HashMap<String, FileState> = HashMap<String, FileState>()
    private let recursiveWatches: HashSet<Path> = HashSet<Path>()
    
    /**
     * 构造函数
     */
    public init(pollInterval: Int64, maxDepth: Int32) {
        this.pollInterval = pollInterval
        this.maxDepth = maxDepth
    }
    
    /**
     * 获取后端类型
     */
    public func getBackendType(): BackendType {
        return BackendType.Polling
    }
    
    /**
     * 获取支持的特性
     */
    public func getSupportedFeatures(): HashSet<String> {
        let features = HashSet<String>()
        features.add("recursive_watch")
        features.add("file_creation")
        features.add("file_modification")
        features.add("file_deletion")
        features.add("directory_creation")
        features.add("directory_deletion")
        return features
    }
    
    /**
     * 启动轮询
     */
    protected func doStart(): Unit {
        if (pollingFuture.isSome()) {
            println("Polling is already running")
            return
        }
        
        // 初始化文件状态
        initializeFileStates()
        
        // 启动轮询任务
        pollingFuture = Some("polling_task")  // Using String as placeholder
        spawn {
            pollLoop()
        }
    }
    
    /**
     * 停止轮询
     */
    protected func doStop(): Unit {
        if (let Some(future) <- pollingFuture) {
            cancelPollingTask()
        }
        // No polling task to cancel if None
        
        fileStates.clear()
        recursiveWatches.clear()
    }
    
    private func cancelPollingTask(): Unit {
        // 取消轮询任务
        // 注意：这里需要实现任务取消机制
        pollingFuture = None
    }
    
    /**
     * 添加监听路径
     */
    protected func doAddWatch(path: Path, recursive: Bool): Unit {
        if (recursive) {
            recursiveWatches.add(path)
        }
        
        // 扫描并记录初始状态
        scanPath(path, recursive, 0)
    }
    
    /**
     * 移除监听路径
     */
    protected func doRemoveWatch(path: Path): Unit {
        recursiveWatches.remove(path)
        
        // 移除相关的文件状态
        let pathStr = path.toString()
        let keysToRemove = ArrayList<String>()
        
        for ((key, _) in fileStates) {
            if (key.startsWith(pathStr)) {
                keysToRemove.add(key)
            }
        }
        
        for (key in keysToRemove) {
            fileStates.remove(key)
        }
    }
    
    /**
     * 初始化文件状态
     */
    private func initializeFileStates(): Unit {
        fileStates.clear()
        
        for (path in watchedPaths) {
            let isRecursive = recursiveWatches.contains(path)
            scanPath(path, isRecursive, 0)
        }
    }
    
    /**
     * 扫描路径并记录文件状态
     */
    private func scanPath(path: Path, recursive: Bool, depth: Int32): Unit {
        if (depth > maxDepth) {
            return
        }
        
        let pathStr = path.toString()
        let state = FileState(path)
        fileStates[pathStr] = state
        
        // 如果是目录且存在，扫描其内容
        if (state.isDirectory && state.exists) {
            try {
                let entries = Directory.readFrom(path)
                for (entry in entries) {
                    // 对于非递归模式，只扫描直接子项（depth == 0）
                    // 对于递归模式，继续递归扫描
                    if (!recursive && depth == 0) {
                        // 非递归模式：只扫描直接子项，不再递归
                        let entryPathStr = entry.path.toString()
                        let entryState = FileState(entry.path)
                        fileStates[entryPathStr] = entryState
                    } else if (recursive) {
                        // 递归模式：继续递归扫描
                        scanPath(entry.path, true, depth + 1)
                    }
                }
            } catch (_: Exception) {
                // 忽略无法访问的目录
            }
        }
    }
    
    /**
     * 轮询循环
     */
    private func pollLoop(): Unit {
        while (isRunning()) {
            try {
                performPoll()
                sleepMs(pollInterval)
            } catch (_: Exception) {
                println("Error during polling")
                sleepMs(pollInterval)
            }
        }
    }
    
    /**
     * 简单的睡眠实现（毫秒）
     */
    private func sleepMs(ms: Int64): Unit {
        let startTime = MonoTime.now()
        let targetNs = ms * 1000000  // 转换为纳秒
        while (true) {
            let elapsed = MonoTime.now() - startTime
            if (elapsed.toNanoseconds() >= targetNs) {
                break
            }
        }
    }
    
    /**
     * 执行一次轮询检查
     */
    private func performPoll(): Unit {
        let currentStates = HashMap<String, FileState>()
        
        // 扫描当前状态
        for (path in watchedPaths) {
            let isRecursive = recursiveWatches.contains(path)
            scanPathForPoll(path, isRecursive, 0, currentStates)
        }
        
        // 检测变化
        detectChanges(currentStates)
        
        // 更新状态
        fileStates.clear()
        for ((key, state) in currentStates) {
            fileStates[key] = state
        }
    }
    
    /**
     * 为轮询扫描路径
     */
    private func scanPathForPoll(
        path: Path, 
        recursive: Bool, 
        depth: Int32, 
        states: HashMap<String, FileState>
    ): Unit {
        if (depth > maxDepth) {
            return
        }
        
        let pathStr = path.toString()
        let state = FileState(path)
        states[pathStr] = state
        
        // 如果是目录且存在，扫描其内容
        if (state.isDirectory && state.exists) {
            try {
                let entries = Directory.readFrom(path)
                for (entry in entries) {
                    // 对于非递归模式，只扫描直接子项（depth == 0）
                    // 对于递归模式，继续递归扫描
                    if (!recursive && depth == 0) {
                        // 非递归模式：只扫描直接子项，不再递归
                        let entryPathStr = entry.path.toString()
                        let entryState = FileState(entry.path)
                        states[entryPathStr] = entryState
                    } else if (recursive) {
                        // 递归模式：继续递归扫描
                        scanPathForPoll(entry.path, true, depth + 1, states)
                    }
                }
            } catch (_: Exception) {
                // 忽略无法访问的目录
            }
        }
    }
    
    /**
     * 检测文件变化
     */
    private func detectChanges(currentStates: HashMap<String, FileState>): Unit {
        // 检查修改和删除
        for ((pathStr, oldState) in fileStates) {
            match (currentStates.get(pathStr)) {
                case Some(newState) => handleStateChange(oldState, newState)
                case None => handleStateRemoval(oldState)
            }
        }
        
        // 检查新创建的文件
        for ((pathStr, newState) in currentStates) {
            if (!fileStates.contains(pathStr) && newState.exists) {
                // 新文件被创建
                let eventType = if (newState.isDirectory) {
                    EventType.DirectoryCreated
                } else {
                    EventType.Created
                }
                let event = FileEvent(eventType, newState.path)
                handleEvent(event)
            }
        }
    }
    
    /**
     * 设置轮询间隔
     */
    public func setPollInterval(interval: Int64): Unit {
        // 注意：如果正在运行，需要重启轮询任务
        this.pollInterval = interval
    }
    
    /**
     * 获取轮询间隔
     */
    public func getPollInterval(): Int64 {
        return pollInterval
    }
    
    /**
     * 设置最大扫描深度
     */
    public func setMaxDepth(depth: Int32): Unit {
        this.maxDepth = depth
    }
    
    /**
     * 获取最大扫描深度
     */
    public func getMaxDepth(): Int32 {
        return maxDepth
    }
    
    private func handleStateChange(oldState: FileState, newState: FileState): Unit {
        if (oldState.hasChanged(newState)) {
            if (!newState.exists && oldState.exists) {
                // 文件被删除
                let eventType = if (oldState.isDirectory) {
                    EventType.DirectoryDeleted
                } else {
                    EventType.Deleted
                }
                let event = FileEvent(eventType, oldState.path)
                handleEvent(event)
            } else if (newState.exists && oldState.exists) {
                // 文件被修改
                if (!newState.isDirectory) {
                    let event = FileEvent(EventType.Modified, newState.path)
                    handleEvent(event)
                }
            }
        }
    }
    
    private func handleStateRemoval(oldState: FileState): Unit {
        // 文件被删除（不在当前状态中）
        if (oldState.exists) {
            let eventType = if (oldState.isDirectory) {
                EventType.DirectoryDeleted
            } else {
                EventType.Deleted
            }
            let event = FileEvent(eventType, oldState.path)
            handleEvent(event)
        }
    }
}
/* cjlint-ignore -end */