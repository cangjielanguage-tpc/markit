package fswatch.tests.unit.backends

/* cjlint-ignore -start !G.PKG.01 */
import std.unittest.*
import std.unittest.testmacro.*
/* cjlint-ignore -end */
import std.fs.{Path, exists}
import std.collection.HashSet
import fswatch.backends.{AbstractMonitorBackend, BackendType}
import fswatch.events.FileEvent

/**
 * 测试用的具体后端实现
 */
class TestBackend <: AbstractMonitorBackend {
    public func getBackendType(): BackendType {
        return BackendType.Auto
    }
    
    public func getSupportedFeatures(): HashSet<String> {
        let features = HashSet<String>()
        features.add("test_feature")
        return features
    }
}

/**
 * AbstractMonitorBackend单元测试
 * 测试抽象监听后端的功能
 */
@Test
@Tag[UnitTest, Backend, AbstractMonitorBackend]
class TestMonitorBackend {
    
    /**
     * 测试后端基本构造
     */
    @TestCase
    func testBackendConstruction() {
        let backend = TestBackend()
        
        @Expect(backend.isRunning(), false)
        @Expect(backend.getBackendType().toString(), "BackendType.Auto")
        @Expect(backend.getWatchedPathCount(), 0)
    }
    
    /**
     * 测试后端启动和停止
     */
    @TestCase
    func testBackendStartStop() {
        let backend = TestBackend()
        
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
     * 测试重复启动和停止
     */
    @TestCase
    func testRepeatedStartStop() {
        let backend = TestBackend()
        
        // 重复启动应该安全
        backend.start()
        backend.start()  // 第二次启动应该被忽略
        @Expect(backend.isRunning(), true)
        
        // 重复停止应该安全
        backend.stop()
        backend.stop()  // 第二次停止应该被忽略
        @Expect(backend.isRunning(), false)
        
        backend.cleanup()
    }
    
    /**
     * 测试事件处理器设置
     */
    @TestCase
    func testEventHandlerSetting() {
        let backend = TestBackend()
        
        let handler = { event: FileEvent =>
            // 简单的事件处理逻辑
            println("Event received: ${event}")
        }
        
        // 设置事件处理器
        backend.setEventHandler(handler)
        
        backend.cleanup()
    }
    
    /**
     * 测试监听路径管理
     */
    @TestCase
    func testWatchPathManagement() {
        let backend = TestBackend()
        let testPath = Path("temp")  // 使用项目内的临时目录
        
        if (exists(testPath)) {
            // 添加监听路径
            backend.addWatch(testPath, false)
            @Expect(backend.getWatchedPathCount(), 1)
            
            // 重复添加同一路径应该被忽略
            backend.addWatch(testPath, false)
            @Expect(backend.getWatchedPathCount(), 1)
            
            // 移除监听路径
            backend.removeWatch(testPath)
            @Expect(backend.getWatchedPathCount(), 0)
            
            // 重复移除应该安全
            backend.removeWatch(testPath)
            @Expect(backend.getWatchedPathCount(), 0)
        }
        
        backend.cleanup()
    }
    
    /**
     * 测试不存在路径的处理
     */
    @TestCase
    func testNonExistentPathHandling() {
        let backend = TestBackend()
        let nonExistentPath = Path("non_existent_directory_12345")
        
        // 添加不存在的路径应该被忽略
        backend.addWatch(nonExistentPath, false)
        @Expect(backend.getWatchedPathCount(), 0)
        
        backend.cleanup()
    }
    
    /**
     * 测试事件队列轮询
     */
    @TestCase
    func testEventPolling() {
        let backend = TestBackend()
        
        // 获取队列中的事件（应该为空）
        let events = backend.pollEvents()
        @Expect(events.size, 0)
        
        backend.cleanup()
    }
    
    /**
     * 测试支持的特性
     */
    @TestCase
    func testSupportedFeatures() {
        let backend = TestBackend()
        let features = backend.getSupportedFeatures()
        
        @Expect(features.contains("test_feature"), true)
        @Expect(features.size, 1)
        
        backend.cleanup()
    }
    
    /**
     * 测试清理功能
     */
    @TestCase
    func testCleanup() {
        let backend = TestBackend()
        let testPath = Path("temp")
        
        if (exists(testPath)) {
            // 启动后端并添加监听路径
            backend.start()
            backend.addWatch(testPath, false)
            @Expect(backend.isRunning(), true)
            @Expect(backend.getWatchedPathCount(), 1)
            
            // 清理应该停止后端并清除所有状态
            backend.cleanup()
            @Expect(backend.isRunning(), false)
            @Expect(backend.getWatchedPathCount(), 0)
        } else {
            // 如果temp目录不存在，只测试基本的清理功能
            backend.start()
            @Expect(backend.isRunning(), true)
            
            backend.cleanup()
            @Expect(backend.isRunning(), false)
            @Expect(backend.getWatchedPathCount(), 0)
        }
    }
}