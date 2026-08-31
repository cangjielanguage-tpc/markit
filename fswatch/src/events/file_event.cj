package fswatch.events

/* cjlint-ignore -start !G.VAR.02 !G.PKG.01 */
import std.time.DateTime
import std.fs.Path
import std.collection.HashMap
import std.deriving.*

/**
 * 文件系统事件结构体
 * 
 * 表示一个文件系统事件，包含事件类型、路径、时间戳等信息。
 */
@Derive[ToString]
public struct FileEvent {
    /**
     * 事件类型
     */
    public let eventType: EventType
    
    /**
     * 事件发生的文件或目录路径
     */
    public let path: Path
    
    /**
     * 事件发生的时间戳
     */
    public let timestamp: DateTime
    
    /**
     * 可选的旧路径（用于移动/重命名事件）
     */
    public let oldPath: ?Path
    
    /**
     * 事件的附加信息
     */
    public let metadata: HashMap<String, String>
    
    /**
     * 构造函数（完整参数）
     */
    public init(
        eventType: EventType,
        path: Path,
        timestamp: DateTime,
        oldPath: ?Path,
        metadata: HashMap<String, String>
    ) {
        this.eventType = eventType
        this.path = path
        this.timestamp = timestamp
        this.oldPath = oldPath
        this.metadata = metadata
    }
    
    /**
     * 构造函数（无旧路径和元数据）
     */
    public init(
        eventType: EventType,
        path: Path,
        timestamp: DateTime
    ) {
        this.eventType = eventType
        this.path = path
        this.timestamp = timestamp
        this.oldPath = None
        this.metadata = HashMap<String, String>()
    }
    
    /**
     * 构造函数（当前时间戳）
     */
    public init(eventType: EventType, path: Path) {
        this.eventType = eventType
        this.path = path
        this.timestamp = DateTime.now()
        this.oldPath = None
        this.metadata = HashMap<String, String>()
    }
    
    /**
     * 判断是否为目录事件
     */
    public func isDirectoryEvent(): Bool {
        return eventType.isDirectoryEvent()
    }
    
    /**
     * 判断是否为文件事件
     */
    public func isFileEvent(): Bool {
        return eventType.isFileEvent()
    }
    
    /**
     * 获取文件扩展名（如果是文件事件）
     */
    public func getFileExtension(): ?String {
        if (!isFileEvent()) {
            return None
        }
        
        let pathStr = path.toString()
        if (let Some(lastDotIndex) <- pathStr.lastIndexOf(".")) {
            if (lastDotIndex >= 0 && lastDotIndex < pathStr.size - 1) {
                return Some(pathStr[lastDotIndex + 1..])
            }
        }
        return None
    }
    
    /**
     * 检查路径是否匹配指定的模式
     */
    public func matchesPattern(pattern: String): Bool {
        // 简单的通配符匹配实现
        let pathStr = path.toString()
        if (pattern == "*") {
            return true
        }
        
        if (pattern.startsWith("*.")) {
            let ext = pattern[2..]
            return match (getFileExtension()) {
                case Some(fileExt) => fileExt == ext
                case None => false
            }
        }
        
        return pathStr.contains(pattern)
    }
}
/* cjlint-ignore -end */