package fswatch

/**
 * fswatch - 跨平台文件监听核心库
 * 
 * 为 Cangjie 项目提供高性能的文件系统事件监听功能。
 * 该库支持多种操作系统的原生文件监听机制，同时提供轮询备选方案，
 * 确保在所有平台上的可靠性和一致性。
 * 
 * 主要特性：
 * - 跨平台支持（Linux inotify、macOS FSEvents、Windows polling）
 * - 自动降级到轮询模式
 * - 高性能事件处理
 * - 递归目录监听
 * - 事件过滤功能
 * - 错误处理和恢复
 * - 资源管理
 * 
 * 使用示例：
 * ```
 * import fswatch.core.FileMonitor
 * import fswatch.events.EventType
 * 
 * let monitor = FileMonitor()
 * monitor.addEventHandler { event =>
 *     match (event.eventType) {
 *         case EventType.Created => println("File created: ${event.path}")
 *         case EventType.Modified => println("File modified: ${event.path}")
 *         case EventType.Deleted => println("File deleted: ${event.path}")
 *         case _ => ()
 *     }
 * }
 * monitor.watch(Path("/path/to/directory"), recursive: true)
 * monitor.start()
 * ```
 */
