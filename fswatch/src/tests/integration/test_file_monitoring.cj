package fswatch.tests.integration

/* cjlint-ignore -start !G.PKG.01 !G.FUN.01 */
import std.unittest.*
import std.unittest.testmacro.*
import std.fs.{Path, exists, File, Directory, remove}
import std.collection.ArrayList
import fswatch.core.{FileMonitor, MonitorConfig}
import fswatch.events.{FileEvent, EventType}
import fswatch.backends.BackendType

/**
 * 文件监听集成测试
 * 测试真实的文件操作监听功能
 */
@Test
@Tag[IntegrationTest, FileMonitoring]
class TestFileMonitoring {
    
    private let testDir = Path("temp")
    private let testFile = Path("temp/test_file.txt")
    private let testSubDir = Path("temp/subdir")
    private let testSubFile = Path("temp/subdir/sub_file.txt")
    
    /**
     * 测试文件创建监听
     */
    @TestCase
    func testFileCreationMonitoring() {
        // 确保测试目录存在
        if (!exists(testDir)) {
            Directory.create(testDir, recursive: true)
        }
        
        // 如果测试文件已存在，先删除
        if (exists(testFile)) {
            remove(testFile)
        }
        
        let config = MonitorConfig.default()
        config.backendType = BackendType.Polling
        config.pollInterval = 100  // 快速轮询用于测试
        
        let monitor = FileMonitor(config: config)
        let receivedEvents = ArrayList<FileEvent>()
        
        // 设置事件处理器
        monitor.addEventHandler({ event =>
            receivedEvents.add(event)
        })
        
        try {
            // 开始监听
            monitor.watch(testDir, recursive: false)
            monitor.start()
            
            // 等待监听器启动
            sleep(200 * Duration.millisecond)
            
            // 创建文件
            File.writeTo(testFile, "Test".toArray())
            
            // 等待事件被检测到
            sleep(500 * Duration.millisecond)
            
            // 验证事件
            @Expect(receivedEvents.size > 0, true)
            
            var hasCreatedEvent = false
            for (event in receivedEvents) {
                if (event.path.toString().contains("test_file.txt")) {
                    match (event.eventType) {
                        case EventType.Created => hasCreatedEvent = true
                        case _ => ()
                    }
                }
            }
            @Expect(hasCreatedEvent, true)
            
        } finally {
            monitor.stop()
            monitor.cleanup()
            
            // 清理测试文件
            if (exists(testFile)) {
                remove(testFile)
            }
        }
    }
    
    /**
     * 测试文件修改监听
     */
    @TestCase
    func testFileModificationMonitoring() {
        // 确保测试目录存在
        if (!exists(testDir)) {
            Directory.create(testDir, recursive: true)
        }
        
        // 创建测试文件
        File.writeTo(testFile, "Initial".toArray())
        
        let config = MonitorConfig.default()
        config.backendType = BackendType.Polling
        config.pollInterval = 100
        
        let monitor = FileMonitor(config: config)
        let receivedEvents = ArrayList<FileEvent>()
        
        monitor.addEventHandler({ event =>
            receivedEvents.add(event)
        })
        
        try {
            monitor.watch(testDir, recursive: false)
            monitor.start()
            
            // 等待监听器启动
            sleep(200 * Duration.millisecond)
            
            // 清空之前的事件
            receivedEvents.clear()
            
            // 修改文件
            File.writeTo(testFile, "Modified".toArray())
            
            // 等待事件被检测到
            sleep(500 * Duration.millisecond)
            
            // 验证修改事件
            var hasModifiedEvent = false
            for (event in receivedEvents) {
                if (event.path.toString().contains("test_file.txt")) {
                    match (event.eventType) {
                        case EventType.Modified => hasModifiedEvent = true
                        case _ => ()
                    }
                }
            }
            @Expect(hasModifiedEvent, true)
            
        } finally {
            monitor.stop()
            monitor.cleanup()
            
            // 清理测试文件
            if (exists(testFile)) {
                remove(testFile)
            }
        }
    }
    
    /**
     * 测试文件删除监听
     */
    @TestCase
    func testFileDeletionMonitoring() {
        // 确保测试目录存在
        if (!exists(testDir)) {
            Directory.create(testDir, recursive: true)
        }
        
        // 创建测试文件
        File.writeTo(testFile, "Delete".toArray())
        
        let config = MonitorConfig.default()
        config.backendType = BackendType.Polling
        config.pollInterval = 100
        
        let monitor = FileMonitor(config: config)
        let receivedEvents = ArrayList<FileEvent>()
        
        monitor.addEventHandler({ event =>
            receivedEvents.add(event)
        })
        
        try {
            monitor.watch(testDir, recursive: false)
            monitor.start()
            
            // 等待监听器启动
            sleep(200 * Duration.millisecond)
            
            // 清空之前的事件
            receivedEvents.clear()
            
            // 删除文件
            remove(testFile)
            
            // 等待事件被检测到
            sleep(500 * Duration.millisecond)
            
            // 验证删除事件
            var hasDeletedEvent = false
            for (event in receivedEvents) {
                if (event.path.toString().contains("test_file.txt")) {
                    match (event.eventType) {
                        case EventType.Deleted => hasDeletedEvent = true
                        case _ => ()
                    }
                }
            }
            @Expect(hasDeletedEvent, true)
            
        } finally {
            monitor.stop()
            monitor.cleanup()
        }
    }
    
    /**
     * 测试递归目录监听
     */
    @TestCase
    func testRecursiveDirectoryMonitoring() {
        // 确保测试目录存在
        if (!exists(testDir)) {
            Directory.create(testDir, recursive: true)
        }
        
        // 清理可能存在的子目录
        if (exists(testSubDir)) {
            if (exists(testSubFile)) {
                remove(testSubFile)
            }
            remove(testSubDir, recursive: true)
        }
        
        let config = MonitorConfig.default()
        config.backendType = BackendType.Polling
        config.pollInterval = 100
        
        let monitor = FileMonitor(config: config)
        let receivedEvents = ArrayList<FileEvent>()
        
        monitor.addEventHandler({ event =>
            receivedEvents.add(event)
        })
        
        try {
            // 启用递归监听
            monitor.watch(testDir, recursive: true)
            monitor.start()
            
            // 等待监听器启动
            sleep(200 * Duration.millisecond)
            
            // 创建子目录
            Directory.create(testSubDir, recursive: true)
            sleep(300 * Duration.millisecond)
            
            // 在子目录中创建文件
            File.writeTo(testSubFile, "SubDir".toArray())
            sleep(300 * Duration.millisecond)
            
            // 验证事件
            @Expect(receivedEvents.size > 0, true)
            
            var hasSubDirEvent = false
            var hasSubFileEvent = false
            
            for (event in receivedEvents) {
                let pathStr = event.path.toString()
                if (pathStr.contains("subdir")) {
                    match (event.eventType) {
                        case EventType.DirectoryCreated => hasSubDirEvent = true
                        case EventType.Created => 
                            if (pathStr.contains("sub_file.txt")) {
                                hasSubFileEvent = true
                            }
                        case _ => ()
                    }
                }
            }
            
            @Expect(hasSubDirEvent, true)
            @Expect(hasSubFileEvent, true)
            
        } finally {
            monitor.stop()
            monitor.cleanup()
            
            // 清理测试文件和目录
            if (exists(testSubFile)) {
                remove(testSubFile)
            }
            if (exists(testSubDir)) {
                remove(testSubDir, recursive: true)
            }
        }
    }
    
    /**
     * 测试多个文件同时监听
     */
    @TestCase
    func testMultipleFileMonitoring() {
        // 确保测试目录存在
        if (!exists(testDir)) {
            Directory.create(testDir, recursive: true)
        }
        
        let testFile1 = Path("temp/file1.txt")
        let testFile2 = Path("temp/file2.txt")
        
        // 清理可能存在的测试文件
        if (exists(testFile1)) {
            remove(testFile1)
        }
        if (exists(testFile2)) {
            remove(testFile2)
        }
        
        let config = MonitorConfig.default()
        config.backendType = BackendType.Polling
        config.pollInterval = 100
        
        let monitor = FileMonitor(config: config)
        let receivedEvents = ArrayList<FileEvent>()
        
        monitor.addEventHandler({ event =>
            receivedEvents.add(event)
        })
        
        try {
            monitor.watch(testDir, recursive: false)
            monitor.start()
            
            // 等待监听器启动
            sleep(200 * Duration.millisecond)
            
            // 同时创建多个文件
            File.writeTo(testFile1, "File1".toArray())
            File.writeTo(testFile2, "File2".toArray())
            
            // 等待事件被检测到
            sleep(500 * Duration.millisecond)
            
            // 验证两个文件的创建事件都被捕获
            var hasFile1Event = false
            var hasFile2Event = false
            
            for (event in receivedEvents) {
                let pathStr = event.path.toString()
                match (event.eventType) {
                    case EventType.Created => 
                        if (pathStr.contains("file1.txt")) {
                            hasFile1Event = true
                        } else if (pathStr.contains("file2.txt")) {
                            hasFile2Event = true
                        }
                    case _ => ()
                }
            }
            
            @Expect(hasFile1Event, true)
            @Expect(hasFile2Event, true)
            
        } finally {
            monitor.stop()
            monitor.cleanup()
            
            // 清理测试文件
            if (exists(testFile1)) {
                remove(testFile1)
            }
            if (exists(testFile2)) {
                remove(testFile2)
            }
        }
    }
    
    /**
     * 测试监听器性能统计
     */
    @TestCase
    func testMonitoringPerformanceStats() {
        // 确保测试目录存在
        if (!exists(testDir)) {
            Directory.create(testDir, recursive: true)
        }
        
        let config = MonitorConfig.default()
        config.backendType = BackendType.Polling
        config.pollInterval = 100
        config.enablePerformanceMonitoring = true
        
        let monitor = FileMonitor(config: config)
        let receivedEvents = ArrayList<FileEvent>()
        
        monitor.addEventHandler({ event =>
            receivedEvents.add(event)
        })
        
        try {
            monitor.watch(testDir, recursive: false)
            monitor.start()
            
            // 等待监听器启动
            sleep(200 * Duration.millisecond)
            
            // 创建一些文件来生成事件
            for (i in 0..5) {
                let file = Path("temp/perf_test_${i}.txt")
                File.writeTo(file, "Perf${i}".toArray())
                sleep(50 * Duration.millisecond)
            }
            
            // 等待事件处理
            sleep(500 * Duration.millisecond)
            
            // 检查性能统计
            let stats = monitor.getPerformanceStats()
            @Expect(stats.eventsProcessed >= 0, true)
            @Expect(stats.uptimeMs > 0, true)
            
        } finally {
            monitor.stop()
            monitor.cleanup()
            
            // 清理测试文件
            for (i in 0..5) {
                let file = Path("temp/perf_test_${i}.txt")
                if (exists(file)) {
                    remove(file)
                }
            }
        }
    }
}
/* cjlint-ignore -end */