package commandline.tests.interfaces

import commandline.interfaces.{Command, CLI}

/* cjlint-ignore -start !G.PKG.01 */
import std.unittest.*
import std.unittest.testmacro.*
/* cjlint-ignore -end */

/**
 * Command接口属性测试
 * 验证命令执行一致性属性
 */

class PropertyTestCommand <: Command {
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
    
    public PropertyTestCommand(let result: String, let isRequired!: Bool = false) {}
    
    public func execute(): Int { 
        // 模拟命令执行，直接打印结果
        println(result)
        return 0
    }
    
    public func isCommand(commandName: String): Bool { commandName == "test" }
    
    public prop required: Bool { get() { isRequired } }
    public prop commandName: String { get() { "test" } }
    public func getDescription(): String { "Property test command" }
    public func getUsage(): String { "test [options]" }
    public func getOptionsHelp(): String { "" }
    public func setArgs(_: Array<String>): Unit { }
    public func setCLI(_: CLI): Unit { }
}

@Test
@Tag[PropertyTest, CoreFunction, CommandInterface]
class TestCommandProperties {
    
    /**
     * 属性1：命令执行一致性
     * 对于任意实现Command接口的命令，调用execute()方法应该能够正常执行，
     * 且多次调用应该产生一致的行为（不抛出异常）。
     * 
     * 验证需求：1.4
     */
    @TestCase
    func testCommandExecutionConsistency() {
        let testResults = [
            "success",
            "completed", 
            "processed",
            "executed successfully"
        ]
        
        // 测试多个不同的命令实现
        for (i in 0..testResults.size) {
            let testResult = testResults[i]
            let isRequired = (i % 2) == 0
            
            let command = PropertyTestCommand(testResult, isRequired: isRequired)
            
            // 属性1.1：execute()应该能够正常执行而不抛出异常
            try {
                command.execute()
                @Assert(true) // 如果没有异常，测试通过
            } catch (e: Exception) {
                @Fail("Command execution should not throw exception: " + e.message)
            }
            
            // 属性1.2：多次调用应该保持一致性（不抛出异常）
            try {
                command.execute()
                command.execute()
                @Assert(true) // 如果没有异常，测试通过
            } catch (e: Exception) {
                @Fail("Multiple command executions should not throw exception: " + e.message)
            }
            
            // 属性1.3：required属性应该保持一致
            let required1 = command.required
            let required2 = command.required
            @Expect(required1, required2)
            @Expect(required1, isRequired)
        }
    }
}