package fswatch.events

/* cjlint-ignore -start !G.PKG.01 */
import std.deriving.*
/* cjlint-ignore -end */

/**
 * 文件系统事件类型枚举
 * 
 * 定义了所有支持的文件系统事件类型，用于标识文件或目录的变化。
 */
@Derive[ToString]
public enum EventType {
    /**
     * 文件或目录被创建
     */
    | Created
    
    /**
     * 文件内容被修改
     */
    | Modified
    
    /**
     * 文件或目录被删除
     */
    | Deleted
    
    /**
     * 文件或目录被移动或重命名
     */
    | Moved
    
    /**
     * 目录被创建
     */
    | DirectoryCreated
    
    /**
     * 目录被删除
     */
    | DirectoryDeleted
    
    /**
     * 文件属性被修改（权限、所有者等）
     */
    | AttributeChanged
    
    /**
     * 未知或其他类型的事件
     */
    | Other(String)
    
    /**
     * 相等性比较
     */
    public operator func ==(other: EventType): Bool {
        match ((this, other)) {
            case (Created, Created) => true
            case (Modified, Modified) => true
            case (Deleted, Deleted) => true
            case (Moved, Moved) => true
            case (DirectoryCreated, DirectoryCreated) => true
            case (DirectoryDeleted, DirectoryDeleted) => true
            case (AttributeChanged, AttributeChanged) => true
            case (Other(a), Other(b)) => a == b
            case _ => false
        }
    }
    
    /**
     * 判断是否为目录相关事件
     */
    public func isDirectoryEvent(): Bool {
        match (this) {
            case DirectoryCreated | DirectoryDeleted => true
            case _ => false
        }
    }
    
    /**
     * 判断是否为文件相关事件
     */
    public func isFileEvent(): Bool {
        match (this) {
            case Created | Modified | Deleted | Moved | AttributeChanged => true
            case _ => false
        }
    }
}