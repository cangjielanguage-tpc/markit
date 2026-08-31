package fswatch.tests.unit.events

/* cjlint-ignore -start !G.PKG.01 */
import std.unittest.*
import std.unittest.testmacro.*
/* cjlint-ignore -end */
import fswatch.events.EventType

/**
 * EventType单元测试
 * 测试事件类型枚举的功能
 */
@Test
@Tag[UnitTest, Events, EventType]
class TestEventType {
    
    /**
     * 测试所有事件类型的ToString
     */
    @TestCase
    func testEventTypeToString() {
        @Expect(EventType.Created.toString(), "EventType.Created")
        @Expect(EventType.Modified.toString(), "EventType.Modified")
        @Expect(EventType.Deleted.toString(), "EventType.Deleted")
        @Expect(EventType.Moved.toString(), "EventType.Moved")
        @Expect(EventType.AttributeChanged.toString(), "EventType.AttributeChanged")
        @Expect(EventType.DirectoryCreated.toString(), "EventType.DirectoryCreated")
        @Expect(EventType.DirectoryDeleted.toString(), "EventType.DirectoryDeleted")
    }
    
    /**
     * 测试文件事件类型检测
     */
    @TestCase
    func testIsFileEventType() {
        @Expect(EventType.Created.isFileEvent(), true)
        @Expect(EventType.Modified.isFileEvent(), true)
        @Expect(EventType.Deleted.isFileEvent(), true)
        @Expect(EventType.Moved.isFileEvent(), true)
        @Expect(EventType.AttributeChanged.isFileEvent(), true)
        @Expect(EventType.DirectoryCreated.isFileEvent(), false)
        @Expect(EventType.DirectoryDeleted.isFileEvent(), false)
    }
    
    /**
     * 测试目录事件类型检测
     */
    @TestCase
    func testIsDirectoryEventType() {
        @Expect(EventType.Created.isDirectoryEvent(), false)
        @Expect(EventType.Modified.isDirectoryEvent(), false)
        @Expect(EventType.Deleted.isDirectoryEvent(), false)
        @Expect(EventType.Moved.isDirectoryEvent(), false)
        @Expect(EventType.AttributeChanged.isDirectoryEvent(), false)
        @Expect(EventType.DirectoryCreated.isDirectoryEvent(), true)
        @Expect(EventType.DirectoryDeleted.isDirectoryEvent(), true)
    }
    
    /**
     * 测试事件类型相等性比较
     */
    @TestCase
    func testEventTypeEquality() {
        let created1 = EventType.Created
        let created2 = EventType.Created
        let modified = EventType.Modified
        
        // 使用模式匹配进行相等性比较
        match ((created1, created2)) {
            case (EventType.Created, EventType.Created) => @Expect(true, true)
            case _ => @Expect(false, true)  // 不应该到达这里
        }
        
        match ((created1, modified)) {
            case (EventType.Created, EventType.Created) => @Expect(false, true)  // 不应该到达这里
            case _ => @Expect(true, true)
        }
    }
    
    /**
     * 测试事件类型数组
     */
    @TestCase
    func testEventTypeArray() {
        let fileEvents = [
            EventType.Created,
            EventType.Modified,
            EventType.Deleted,
            EventType.Moved,
            EventType.AttributeChanged
        ]
        
        @Expect(fileEvents.size, 5)
        
        let directoryEvents = [
            EventType.DirectoryCreated,
            EventType.DirectoryDeleted
        ]
        
        @Expect(directoryEvents.size, 2)
    }
    
    /**
     * 测试事件类型在集合中的使用
     */
    @TestCase
    func testEventTypeInArray() {
        let eventArray = [EventType.Created, EventType.Modified, EventType.Created]
        
        @Expect(eventArray.size, 3)  // 数组允许重复元素
        
        // 检查数组中是否包含特定事件类型
        var hasCreated = false
        var hasModified = false
        for (eventType in eventArray) {
            match (eventType) {
                case EventType.Created => hasCreated = true
                case EventType.Modified => hasModified = true
                case _ => ()
            }
        }
        
        @Expect(hasCreated, true)
        @Expect(hasModified, true)
    }
}