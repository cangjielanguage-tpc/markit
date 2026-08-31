package fswatch.tests.unit.core

/* cjlint-ignore -start !G.PKG.01 */
import std.unittest.*
import std.unittest.testmacro.*
/* cjlint-ignore -end */
import std.fs.{Path, exists}
import fswatch.core.{FileMonitor, MonitorConfig, MonitorState}
import fswatch.events.FileEvent
import fswatch.backends.BackendType
import fswatch.errors.MonitorException

/**
 * FileMonitor单元测试
 * 测试文件监听器的核心功能
 */
@Test
@Tag[UnitTest, Core, FileMonitor]
class TestFileMonitor {
    
    /**
     * 测试FileMonitor基本构造
     */
    @TestCase
    func testFileMonitorConstruction() {
        let config = MonitorConfig.default()
        let monitor = FileMonitor(config: config)
        
        @Expect(monitor.getState().toString(), "MonitorState.Stopped")
        @Expect(monitor.isRunning(), false)
        @Expect(monitor.getWatchedPathCount(), 0)
    }
    
    /**
     * 测试FileMonitor启动和停止
     */
    @TestCase
    func testFileMonitorStartStop() {
        let config = MonitorConfig.default()
        let monitor = FileMonitor(config: config)
        
        // 测试启动
        monitor.start()
        @Expect(monitor.isRunning(), true)
        @Expect(monitor.getState().toString(), "MonitorState.Running")
        
        // 测试停止
        monitor.stop()
        @Expect(monitor.isRunning(), false)
        @Expect(monitor.getState().toString(), "MonitorState.Stopped")
        
        // 清理
        monitor.cleanup()
    }
    
    /**
     * 测试重复启动应该抛出异常
     */
    @TestCase
    func testDoubleStartThrowsException() {
        let config = MonitorConfig.default()
        let monitor = FileMonitor(config: config)
        
        monitor.start()
        
        var exceptionThrown = false
        try {
            monitor.start()  // 应该抛出异常
        } catch (e: MonitorException) {
            exceptionThrown = true
        }
        
        @Expect(exceptionThrown, true)
        
        monitor.stop()
        monitor.cleanup()
    }
    
    /**
     * 测试添加和移除监听路径
     */
    @TestCase
    func testWatchPathManagement() {
        let config = MonitorConfig.default()
        let monitor = FileMonitor(config: config)
        
        // 使用项目内的临时目录
        let testPath = Path("temp")
        
        if (exists(testPath)) {
            // 添加监听路径
            monitor.watch(testPath, recursive: false)
            @Expect(monitor.getWatchedPathCount(), 1)
            
            // 移除监听路径
            monitor.unwatch(testPath)
            @Expect(monitor.getWatchedPathCount(), 0)
        }
        
        monitor.cleanup()
    }
    
    /**
     * 测试事件处理器管理
     */
    @TestCase
    func testEventHandlerManagement() {
        let config = MonitorConfig.default()
        let monitor = FileMonitor(config: config)
        
        let handler = { event: FileEvent =>
            println("Event received: ${event}")
        }
        
        // 添加事件处理器
        monitor.addEventHandler(handler)
        
        // 清除事件处理器
        monitor.clearEventHandlers()
        
        monitor.cleanup()
    }
    
    /**
     * 测试性能统计信息
     */
    @TestCase
    func testPerformanceStats() {
        let config = MonitorConfig.default()
        let monitor = FileMonitor(config: config)
        
        let stats = monitor.getPerformanceStats()
        
        @Expect(stats.eventsProcessed, 0)
        @Expect(stats.eventsPerSecond, 0)
        @Expect(stats.averageProcessingTimeMs, 0)
        @Expect(stats.queueSize, 0)
        @Expect(stats.memoryUsage, 0)
        @Expect(stats.uptimeMs, 0)
        
        monitor.cleanup()
    }
    
    /**
     * 测试后端类型获取
     */
    @TestCase
    func testBackendTypeRetrieval() {
        let config = MonitorConfig.default()
        let monitor = FileMonitor(config: config)
        
        let backendType = monitor.getBackendType()
        @Expect(backendType.toString(), "BackendType.Auto")  // 默认应该是Auto后端
        
        monitor.cleanup()
    }

    /**
     * 测试错误状态管理
     */
    @TestCase
    func testErrorStateManagement() {
        let config = MonitorConfig.default()
        let monitor = FileMonitor(config: config)
        
        // 初始状态应该没有错误
        let initialError = monitor.getLastError()
        @Expect(initialError.isSome(), false)
        
        // 重置错误状态
        monitor.resetError()
        @Expect(monitor.getState().toString(), "MonitorState.Stopped")
        
        monitor.cleanup()
    }
}
