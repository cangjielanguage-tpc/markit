package fswatch.filters

/* cjlint-ignore -start !G.ITF.04 */
import fswatch.events.{FileEvent, EventType}
import std.fs.FileInfo
import std.core.Array
import std.time.DateTime

/**
 * 组合操作类型
 */
public enum Operation {
    | And    // 所有过滤器都通过
    | Or     // 任一过滤器通过
    | Not    // 取反
}

/**
 * 事件过滤器接口
 * 
 * 定义事件过滤的基本接口，用于筛选需要处理的文件系统事件。
 */
public interface EventFilter {
    /**
     * 检查事件是否应该被处理
     * 
     * @param event 文件系统事件
     * @return true 如果事件应该被处理，false 否则
     */
    func shouldProcess(event: FileEvent): Bool
}

/**
 * 组合事件过滤器
 * 
 * 支持多个过滤器的逻辑组合（AND、OR、NOT）。
 */
public class CompositeEventFilter <: EventFilter {
    private let filters: Array<EventFilter>
    private let operation: Operation
    
    /**
     * 构造函数
     */
    public init(filters: Array<EventFilter>, operation: Operation) {
        this.filters = filters
        this.operation = operation
    }
    
    /**
     * 检查事件是否应该被处理
     */
    public func shouldProcess(event: FileEvent): Bool {
        match (operation) {
            case Operation.And => processAndOperation(event)
            case Operation.Or => processOrOperation(event)
            case Operation.Not => processNotOperation(event)
        }
    }
    
    private func processAndOperation(event: FileEvent): Bool {
        for (filter in filters) {
            if (!filter.shouldProcess(event)) {
                return false
            }
        }
        return true
    }
    
    private func processOrOperation(event: FileEvent): Bool {
        for (filter in filters) {
            if (filter.shouldProcess(event)) {
                return true
            }
        }
        return false
    }
    
    private func processNotOperation(event: FileEvent): Bool {
        // NOT 操作只对第一个过滤器生效
        if (filters.size > 0) {
            return !filters[0].shouldProcess(event)
        }
        return true
    }
    
    /**
     * 创建 AND 组合过滤器
     */
    public static func and(filters: Array<EventFilter>): CompositeEventFilter {
        return CompositeEventFilter(filters, Operation.And)
    }
    
    /**
     * 创建 OR 组合过滤器
     */
    public static func or(filters: Array<EventFilter>): CompositeEventFilter {
        return CompositeEventFilter(filters, Operation.Or)
    }
    
    /**
     * 创建 NOT 过滤器
     */
    public static func not(filter: EventFilter): CompositeEventFilter {
        return CompositeEventFilter([filter], Operation.Not)
    }
}

/**
 * 路径过滤器
 * 
 * 基于路径模式过滤事件。
 */
public class PathEventFilter <: EventFilter {
    private let patterns: Array<PathPattern>
    private let includeMode: Bool  // true: 包含模式，false: 排除模式
    
    /**
     * 构造函数
     */
    public init(patterns: Array<PathPattern>, includeMode: Bool) {
        this.patterns = patterns
        this.includeMode = includeMode
    }
    
    /**
     * 检查事件是否应该被处理
     */
    public func shouldProcess(event: FileEvent): Bool {
        var matches = false
        for (pattern in patterns) {
            if (pattern.matches(event.path)) {
                matches = true
                break
            }
        }
        return if (includeMode) { matches } else { !matches }
    }
    
    /**
     * 创建包含过滤器
     */
    public static func include(patterns: Array<PathPattern>): PathEventFilter {
        return PathEventFilter(patterns, true)
    }
    
    /**
     * 创建排除过滤器
     */
    public static func exclude(patterns: Array<PathPattern>): PathEventFilter {
        return PathEventFilter(patterns, false)
    }
}

/**
 * 事件类型过滤器
 * 
 * 基于事件类型过滤事件。
 */
public class EventTypeFilter <: EventFilter {
    private let allowedTypes: Array<EventType>
    
    /**
     * 构造函数
     */
    public init(allowedTypes: Array<EventType>) {
        this.allowedTypes = allowedTypes
    }
    
    /**
     * 检查事件是否应该被处理
     */
    public func shouldProcess(event: FileEvent): Bool {
        for (eventType in allowedTypes) {
            if (eventType == event.eventType) {
                return true
            }
        }
        return false
    }
    
    /**
     * 创建只处理文件事件的过滤器
     */
    public static func filesOnly(): EventTypeFilter {
        return EventTypeFilter([
            EventType.Created,
            EventType.Modified,
            EventType.Deleted,
            EventType.Moved,
            EventType.AttributeChanged
        ])
    }
    
    /**
     * 创建只处理目录事件的过滤器
     */
    public static func directoriesOnly(): EventTypeFilter {
        return EventTypeFilter([
            EventType.DirectoryCreated,
            EventType.DirectoryDeleted
        ])
    }
    
    /**
     * 创建只处理修改事件的过滤器
     */
    public static func modificationsOnly(): EventTypeFilter {
        return EventTypeFilter([
            EventType.Modified,
            EventType.AttributeChanged
        ])
    }
}

/**
 * 文件大小过滤器
 * 
 * 基于文件大小过滤事件。
 */
public class FileSizeFilter <: EventFilter {
    /**
     * 构造函数
     */
    public FileSizeFilter(let minSize: ?Int64, let maxSize: ?Int64) { }
    
    /**
     * 检查事件是否应该被处理
     */
    public func shouldProcess(event: FileEvent): Bool {
        // 只对文件事件检查大小
        if (!event.isFileEvent()) {
            return true
        }
        
        try {
            let fileInfo = FileInfo(event.path)
            let size = fileInfo.size
            
            // Check minimum size constraint
            if (let Some(min) <- minSize) {
                if (size < min) {
                    return false
                }
            }
            
            // Check maximum size constraint
            if (let Some(max) <- maxSize) {
                if (size > max) {
                    return false
                }
            }
            
            return true
        } catch (_: Exception) {
            // 如果无法获取文件信息，默认通过
            return true
        }
    }
}

/**
 * 时间范围过滤器
 * 
 * 基于事件发生时间过滤事件。
 */
public class TimeRangeFilter <: EventFilter {
    private let startTime: ?DateTime
    private let endTime: ?DateTime
    
    /**
     * 构造函数
     */
    public init(startTime: ?DateTime, endTime: ?DateTime) {
        this.startTime = startTime
        this.endTime = endTime
    }
    
    /**
     * 检查事件是否应该被处理
     */
    public func shouldProcess(event: FileEvent): Bool {
        let eventTime = event.timestamp
        
        // Check start time constraint
        if (let Some(start) <- startTime) {
            if (eventTime < start) {
                return false
            }
        }
        
        // Check end time constraint
        if (let Some(end) <- endTime) {
            if (eventTime > end) {
                return false
            }
        }
        
        return true
    }
}
/* cjlint-ignore -end */