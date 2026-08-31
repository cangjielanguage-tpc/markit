package fswatch.tests.unit.backends

/* cjlint-ignore -start !G.PKG.01 */
import std.unittest.*
import std.unittest.testmacro.*
/* cjlint-ignore -end */
import std.fs.{Path, exists}
import std.collection.HashSet
import fswatch.backends.{PollingBackend, BackendType}
import fswatch.events.FileEvent

/**
 * PollingBackend单元测试
 * 测试轮询后端的功能
 */
@Test
@Tag[UnitTest, Backend, PollingBackend]
class TestPollingBackend {
    
    /**
     * 测试PollingBackend基本构造
     */
    @TestCase
    func testPollingBackendConstruction() {
        let backend = PollingBackend(1000, 10)
        
        @Expect(backend.isRunning(), false)
        @Expect(backend.getBackendType().toString(), "BackendType.Polling")
        @Expect(backend.getPollInterval(), 1000)
        @Expect(backend.getMaxDepth(), 10)
    }
    
    /**
     * 测试后端启动和停止
     */
    @TestCase
    func testBackendStartStop() {
        let backend = PollingBackend(1000, 10)
        
        // 测试启动
        backend.start()
        @Expect(backend.isRunning(), true)
        
        // 测试停止
        backend.stop()
        @Expect(backend.isRunning(), false)
        
        // 清理
        backend.cleanup()
    }
    
    /**
     * 测试支持的特性
     */
    @TestCase
    func testSupportedFeatures() {
        let backend = PollingBackend(1000, 10)
        let features = backend.getSupportedFeatures()
        
        @Expect(features.contains("recursive_watch"), true)
        @Expect(features.contains("file_creation"), true)
        @Expect(features.contains("file_modification"), true)
        @Expect(features.contains("file_deletion"), true)
        @Expect(features.contains("directory_creation"), true)
        @Expect(features.contains("directory_deletion"), true)
        
        backend.cleanup()
    }
    
    /**
     * 测试监听路径管理
     */
    @TestCase
    func testWatchPathManagement() {
        let backend = PollingBackend(1000, 10)
        let testPath = Path("temp")  // 使用项目内的临时目录
        
        if (exists(testPath)) {
            // 添加监听路径
            backend.addWatch(testPath, false)
            @Expect(backend.getWatchedPathCount(), 1)
            
            // 移除监听路径
            backend.removeWatch(testPath)
            @Expect(backend.getWatchedPathCount(), 0)
        }
        
        backend.cleanup()
    }
    
    /**
     * 测试事件处理器设置
     */
    @TestCase
    func testEventHandlerSetting() {
        let backend = PollingBackend(1000, 10)
        
        let handler = { event: FileEvent =>
            // 简单的事件处理逻辑
            println("Event received: ${event}")
        }
        
        // 设置事件处理器
        backend.setEventHandler(handler)
        
        backend.cleanup()
    }
    
    /**
     * 测试轮询间隔设置
     */
    @TestCase
    func testPollIntervalSetting() {
        let backend = PollingBackend(1000, 10)
        
        @Expect(backend.getPollInterval(), 1000)
        
        backend.setPollInterval(2000)
        @Expect(backend.getPollInterval(), 2000)
        
        backend.cleanup()
    }
    
    /**
     * 测试最大深度设置
     */
    @TestCase
    func testMaxDepthSetting() {
        let backend = PollingBackend(1000, 10)
        
        @Expect(backend.getMaxDepth(), 10)
        
        backend.setMaxDepth(20)
        @Expect(backend.getMaxDepth(), 20)
        
        backend.cleanup()
    }
    
    /**
     * 测试事件队列轮询
     */
    @TestCase
    func testEventPolling() {
        let backend = PollingBackend(1000, 10)
        
        // 获取队列中的事件（应该为空）
        let events = backend.pollEvents()
        @Expect(events.size, 0)
        
        backend.cleanup()
    }
}