package fswatch.tests.unit.events

/* cjlint-ignore -start !G.PKG.01 */
import std.unittest.*
import std.unittest.testmacro.*
/* cjlint-ignore -end */
import std.fs.Path
import std.time.DateTime
import fswatch.events.{FileEvent, EventType}

/**
 * FileEvent单元测试
 * 测试文件事件的功能
 */
@Test
@Tag[UnitTest, Events, FileEvent]
class TestFileEvent {
    
    /**
     * 测试FileEvent基本构造
     */
    @TestCase
    func testFileEventConstruction() {
        let path = Path("/test/file.txt")
        let event = FileEvent(EventType.Created, path)
        
        @Expect(event.eventType.toString(), "EventType.Created")
        @Expect(event.path.toString(), "/test/file.txt")
        @Expect(event.timestamp.toString().isEmpty(), false)  // 时间戳应该存在
    }
    
    /**
     * 测试不同事件类型的创建
     */
    @TestCase
    func testDifferentEventTypes() {
        let path = Path("/test/file.txt")
        
        let createdEvent = FileEvent(EventType.Created, path)
        @Expect(createdEvent.eventType.toString(), "EventType.Created")
        
        let modifiedEvent = FileEvent(EventType.Modified, path)
        @Expect(modifiedEvent.eventType.toString(), "EventType.Modified")
        
        let deletedEvent = FileEvent(EventType.Deleted, path)
        @Expect(deletedEvent.eventType.toString(), "EventType.Deleted")
        
        let movedEvent = FileEvent(EventType.Moved, path)
        @Expect(movedEvent.eventType.toString(), "EventType.Moved")
    }
    
    /**
     * 测试目录事件类型
     */
    @TestCase
    func testDirectoryEventTypes() {
        let path = Path("/test/directory")
        
        let dirCreatedEvent = FileEvent(EventType.DirectoryCreated, path)
        @Expect(dirCreatedEvent.eventType.toString(), "EventType.DirectoryCreated")
        
        let dirDeletedEvent = FileEvent(EventType.DirectoryDeleted, path)
        @Expect(dirDeletedEvent.eventType.toString(), "EventType.DirectoryDeleted")
    }
    
    /**
     * 测试属性变更事件
     */
    @TestCase
    func testAttributeChangedEvent() {
        let path = Path("/test/file.txt")
        let event = FileEvent(EventType.AttributeChanged, path)
        
        @Expect(event.eventType.toString(), "EventType.AttributeChanged")
        @Expect(event.path.toString(), "/test/file.txt")
    }
    
    /**
     * 测试文件事件检测
     */
    @TestCase
    func testIsFileEvent() {
        let path = Path("/test/file.txt")
        
        let fileEvent = FileEvent(EventType.Created, path)
        @Expect(fileEvent.isFileEvent(), true)
        
        let dirEvent = FileEvent(EventType.DirectoryCreated, path)
        @Expect(dirEvent.isFileEvent(), false)
    }
    
    /**
     * 测试目录事件检测
     */
    @TestCase
    func testIsDirectoryEvent() {
        let path = Path("/test/directory")
        
        let dirEvent = FileEvent(EventType.DirectoryCreated, path)
        @Expect(dirEvent.isDirectoryEvent(), true)
        
        let fileEvent = FileEvent(EventType.Created, path)
        @Expect(fileEvent.isDirectoryEvent(), false)
    }
    
    /**
     * 测试事件时间戳
     */
    @TestCase
    func testEventTimestamp() {
        let path = Path("/test/file.txt")
        let beforeTime = DateTime.now()
        let event = FileEvent(EventType.Created, path)
        let afterTime = DateTime.now()
        
        // 事件时间戳应该在创建前后时间之间
        @Expect(event.timestamp >= beforeTime, true)
        @Expect(event.timestamp <= afterTime, true)
    }
    
    /**
     * 测试事件ToString表示
     */
    @TestCase
    func testEventToString() {
        let path = Path("/test/file.txt")
        let event = FileEvent(EventType.Created, path)
        
        let eventStr = event.toString()
        @Expect(eventStr.contains("Created"), true)
        @Expect(eventStr.contains("/test/file.txt"), true)
    }
}