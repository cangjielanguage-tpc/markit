package fswatch.events

import std.collection.ArrayList
import std.sync.Mutex

/**
 * 事件处理器包装类
 * 
 * 提供事件处理的统一接口和错误处理机制。
 */
public class EventHandlerWrapper {
    private let handler: (FileEvent) -> Unit
    private let errorHandler: ?((Exception) -> Unit)
    private var isEnabled: Bool = true
    
    /**
     * 构造函数（带错误处理器）
     */
    public init(
        handler: (FileEvent) -> Unit,
        errorHandler: (Exception) -> Unit
    ) {
        this.handler = handler
        this.errorHandler = Some(errorHandler)
    }
    
    /**
     * 构造函数（无错误处理器）
     */
    public init(handler: (FileEvent) -> Unit) {
        this.handler = handler
        this.errorHandler = None
    }
    
    /**
     * 处理事件
     */
    public func handle(event: FileEvent): Unit {
        if (!isEnabled) {
            return
        }
        
        try {
            handler(event)
        } catch (e: Exception) {
            match (errorHandler) {
                case Some(eh) => eh(e)
                case None => println("Error handling event: ${e.message}")
            }
        }
    }
    
    /**
     * 启用事件处理器
     */
    public func enable(): Unit {
        isEnabled = true
    }
    
    /**
     * 禁用事件处理器
     */
    public func disable(): Unit {
        isEnabled = false
    }
    
    /**
     * 检查事件处理器是否启用
     */
    public func isHandlerEnabled(): Bool {
        return isEnabled
    }
}

/**
 * 事件处理器管理器
 * 
 * 管理多个事件处理器，支持添加、移除和批量处理。
 */
public class EventHandlerManager {
    private var handlers: ArrayList<EventHandlerWrapper> = ArrayList<EventHandlerWrapper>()
    private let mutex = Mutex()
    
    /**
     * 添加事件处理器（带错误处理器）
     */
    public func addHandler(handler: (FileEvent) -> Unit, errorHandler: (Exception) -> Unit): Unit {
        mutex.lock()
        let wrapper = EventHandlerWrapper(handler, errorHandler)
        handlers.add(wrapper)
        mutex.unlock()
    }
    
    /**
     * 添加事件处理器（无错误处理器）
     */
    public func addHandler(handler: (FileEvent) -> Unit): Unit {
        mutex.lock()
        let wrapper = EventHandlerWrapper(handler)
        handlers.add(wrapper)
        mutex.unlock()
    }
    
    /**
     * 移除所有事件处理器
     */
    public func clearHandlers(): Unit {
        mutex.lock()
        handlers = ArrayList<EventHandlerWrapper>()
        mutex.unlock()
    }
    
    /**
     * 处理事件（分发给所有处理器）
     */
    public func handleEvent(event: FileEvent): Unit {
        mutex.lock()
        let currentHandlers = ArrayList<EventHandlerWrapper>()
        for (i in 0..handlers.size) {
            currentHandlers.add(handlers[i])
        }
        mutex.unlock()
        
        for (i in 0..currentHandlers.size) {
            currentHandlers[i].handle(event)
        }
    }
    
    /**
     * 批量处理事件
     */
    public func handleEvents(events: Array<FileEvent>): Unit {
        for (event in events) {
            handleEvent(event)
        }
    }
    
    /**
     * 获取处理器数量
     */
    public func getHandlerCount(): Int64 {
        mutex.lock()
        let count = handlers.size
        mutex.unlock()
        return count
    }
    
    /**
     * 启用所有处理器
     */
    public func enableAllHandlers(): Unit {
        mutex.lock()
        for (i in 0..handlers.size) {
            handlers[i].enable()
        }
        mutex.unlock()
    }
    
    /**
     * 禁用所有处理器
     */
    public func disableAllHandlers(): Unit {
        mutex.lock()
        for (i in 0..handlers.size) {
            handlers[i].disable()
        }
        mutex.unlock()
    }
}