package commandline.tests

/**
 * 简化的测试辅助工具
 * 提供测试专用的命令类，直接在execute中进行断言
 */

import commandline.interfaces.{Command, CLI}

/**
 * 测试命令 - 验证execute方法能正常执行
 */
public class TestExecuteCommand <: Command {
    private var _paramStoreImpl: Array<(String, String)> = []
    private var _nameMapImpl: Array<(String, String)> = []
    
    public mut prop _paramStore: Array<(String, String)> { 
        get() { _paramStoreImpl } 
        set(value) { _paramStoreImpl = value }
    }
    public mut prop _nameMap: Array<(String, String)> { 
        get() { _nameMapImpl } 
        set(value) { _nameMapImpl = value }
    }
    
    public TestExecuteCommand(let expectedMessage: String) {}
    
    public func execute(): Int {
        // 直接在这里验证执行逻辑
        println("Test command executed: " + expectedMessage)
        // 可以在这里添加更多的验证逻辑
        return 0
    }
    
    public func isCommand(commandName: String): Bool { commandName == "test" }
    public prop required: Bool { get() { false } }
    public prop commandName: String { get() { "test" } }
    public func getDescription(): String { "Test command" }
    public func getUsage(): String { "test [options]" }
    public func getOptionsHelp(): String { "" }
    public func setArgs(_: Array<String>): Unit { }
    public func setCLI(_: CLI): Unit { }
}

/**
 * 验证命令 - 用于测试required属性
 */
public class TestRequiredCommand <: Command {
    private var _paramStoreImpl: Array<(String, String)> = []
    private var _nameMapImpl: Array<(String, String)> = []
    
    public mut prop _paramStore: Array<(String, String)> { 
        get() { _paramStoreImpl } 
        set(value) { _paramStoreImpl = value }
    }
    public mut prop _nameMap: Array<(String, String)> { 
        get() { _nameMapImpl } 
        set(value) { _nameMapImpl = value }
    }
    
    public TestRequiredCommand(let isRequired: Bool) {}
    
    public func execute(): Int {
        println("Required command executed, required=" + isRequired.toString())
        return 0
    }
    
    public func isCommand(commandName: String): Bool { commandName == "required" }
    public prop required: Bool { get() { isRequired } }
    public prop commandName: String { get() { "required" } }
    public func getDescription(): String { "Required test command" }
    public func getUsage(): String { "required [options]" }
    public func getOptionsHelp(): String { "" }
    public func setArgs(_: Array<String>): Unit { }
    public func setCLI(_: CLI): Unit { }
}