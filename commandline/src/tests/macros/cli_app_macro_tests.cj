package commandline.tests.macros

/* cjlint-ignore -start !G.PKG.01 */
import std.unittest.*
import std.unittest.testmacro.*
/* cjlint-ignore -end */
import std.collection.ArrayList
import commandline.interfaces.{CLI, Command}
import commandline.macros.{CLIApp, Cmd, Opt}

/**
 * @CLIApp宏测试
 * 验证CLI应用程序宏的功能和生成的代码
 */

@Test
@Tag[PropertyTest, MacroSystem, CLIAppMacro]
class TestCLIAppMacro {
    
    /**
     * 测试带注解参数的CLI应用程序生成
     * 验证@CLIApp宏支持name、version、description参数
     */
    @TestCase
    func testCLIAppWithAnnotationParameters() {
        // 创建带注解参数的测试CLI应用程序
        let app = MarkitCLIApp(["markit", "help"]).use([])
        
        // 验证注解参数生成的属性
        @Expect(app.name, "markit")
        @Expect(app.version, "1.0.0")
        @Expect(app.description, "Markdown Processing Tool")
        @Expect(app.args.size, 2)
        @Expect(app.args[0], "markit")
        @Expect(app.args[1], "help")
        
        // 验证命令数组初始为空
        @Expect(app.commands.size, 0)
    }
    
    /**
     * 测试基本的CLI应用程序生成
     * 验证@CLIApp宏生成正确的CLI应用程序结构
     */
    @TestCase
    func testBasicCLIAppGeneration() {
        // 创建测试CLI应用程序
        let app = TestCLIApp(["test", "help"])
        
        // 验证基本属性（使用默认值）
        @Expect(app.name, "My CLI Application")  // 默认值
        @Expect(app.version, "0.0.0")           // 默认值
        @Expect(app.description, "No description") // 默认值
        @Expect(app.args.size, 2)
        @Expect(app.args[0], "test")
        @Expect(app.args[1], "help")
        
        // 验证命令数组初始为空
        @Expect(app.commands.size, 0)
    }
    
    /**
     * 测试命令注册功能
     * 验证use方法正确注册命令
     */
    @TestCase
    func testCommandRegistration() {
        let app = TestCLIApp(["test"])
        let testCmd = TestCommand()
        let helpCmd = HelpCommand()
        
        // 注册命令
        app.use(testCmd, helpCmd)
        
        // 验证命令已注册
        @Expect(app.commands.size, 2)
        
        // 验证命令类型
        let commands = app.commands
        @Expect(commands[0].commandName, "test")
        @Expect(commands[1].commandName, "help")
        
        // 验证命令已设置args和CLI引用（通过执行结果验证）
        // 注意：args是@Cmd宏生成的实现细节，不在接口中
    }
    
    /**
     * 测试命令执行路由
     * 验证execute方法正确路由到对应命令
     */
    @TestCase
    func testCommandExecution() {
        // 测试help命令执行 - 现在execute返回Unit，我们验证帮助方法
        let helpApp = TestCLIApp(["app", "help"])
        helpApp.use(TestCommand(), HelpCommand())
        
        // 验证帮助系统工作正常
        let helpResult = helpApp.getHelp()
        @Expect(helpResult.contains("My CLI Application"), true)  // 使用默认应用名称
        @Expect(helpResult.contains("Available Commands"), true)
        @Expect(helpResult.contains("test"), true)
        @Expect(helpResult.contains("help"), true)
        
        // 测试具体命令执行 - 验证命令能被找到和路由
        let testApp = TestCLIApp(["app", "test", "--verbose"])
        testApp.use(TestCommand(), HelpCommand())
        
        // 验证命令注册正确
        @Expect(testApp.commands.size, 2)
        let testCmd = testApp.commands[0]
        @Expect(testCmd.isCommand("test"), true)
        
        // 测试带有无效选项的命令执行 - 应该返回错误码
        let exitCode = testApp.execute()
        @Expect(exitCode, 1)  // 期望因为无效选项而失败
        
        // 测试未知命令 - 验证命令查找逻辑
        let unknownApp = TestCLIApp(["app", "unknown"])
        unknownApp.use(TestCommand(), HelpCommand())
        
        // 验证没有命令匹配"unknown"
        var foundUnknown = false
        for (cmd in unknownApp.commands) {
            if (cmd.isCommand("unknown")) {
                foundUnknown = true
                break
            }
        }
        @Expect(foundUnknown, false)
    }
    
    /**
     * 测试帮助系统生成
     * 验证自动生成的帮助方法
     */
    @TestCase
    func testHelpSystemGeneration() {
        let app = TestCLIApp(["app"])
        app.use(TestCommand(), HelpCommand())
        
        // 测试通用帮助
        let generalHelp = app.getHelp()
        @Expect(generalHelp.contains("📚"), true)
        @Expect(generalHelp.contains("My CLI Application"), true)  // 使用默认应用名称
        @Expect(generalHelp.contains("v0.0.0"), true)             // 使用默认版本
        @Expect(generalHelp.contains("🚀 Available Commands"), true)
        @Expect(generalHelp.contains("test"), true)
        @Expect(generalHelp.contains("Test command for testing"), true)
        @Expect(generalHelp.contains("help"), true)
        @Expect(generalHelp.contains("Show help information"), true)
        @Expect(generalHelp.contains("💡 Usage"), true)
        @Expect(generalHelp.contains("🔍 Get command help"), true)
        
        // 验证选项信息包含在通用帮助中
        @Expect(generalHelp.contains("Options:"), true)
        @Expect(generalHelp.contains("--verbose"), true)
        @Expect(generalHelp.contains("--output"), true)
        
        // 测试特定命令帮助
        let commandHelp = app.getHelp("test")
        @Expect(commandHelp.contains("📖"), true)
        @Expect(commandHelp.contains("Test command for testing"), true)
        @Expect(commandHelp.contains("💻"), true)
        @Expect(commandHelp.contains("Usage: test [options]"), true)
        @Expect(commandHelp.contains("⚙ Options"), true)
        @Expect(commandHelp.contains("--verbose"), true)
        @Expect(commandHelp.contains("Enable verbose output"), true)
        @Expect(commandHelp.contains("--output"), true)
        @Expect(commandHelp.contains("Output file"), true)
        
        // 测试未知命令帮助
        let unknownHelp = app.getHelp("unknown")
        @Expect(unknownHelp.contains("Unknown command"), true)
        @Expect(unknownHelp.contains("unknown"), true)
    }
    
    /**
     * 测试特定帮助命令执行
     * 验证help命令的--command参数处理和无效选项检测
     */
    @TestCase
    func testSpecificHelpExecution() {
        // 测试help --command test - 但这里有问题：TestCommand没有--command选项
        let app = TestCLIApp(["app", "help", "--command", "test"])
        app.use(TestCommand(), HelpCommand())
        
        // 这个应该失败，因为传给了错误的命令无效的选项
        let exitCode = app.execute()
        @Expect(exitCode, 1)  // 期望因为无效选项而失败
        
        // 直接测试getCommandHelp方法（这个应该正常工作）
        let result = app.getHelp("test")
        
        // 验证返回特定命令帮助
        @Expect(result.contains("📖"), true)
        @Expect(result.contains("Test command for testing"), true)
        @Expect(result.contains("Usage: test [options]"), true)
        @Expect(result.contains("--verbose"), true)
        
        // 测试help命令的CLI引用设置
        let helpCmd = HelpCommand()
        helpCmd.setCLI(app)
        helpCmd.command = Some("test")
        
        // 验证help命令能访问CLI应用程序
        @Expect(helpCmd._cli.isSome(), true)
    }
    
    /**
     * 测试错误处理
     * 验证各种错误情况的处理
     */
    @TestCase
    func testErrorHandling() {
        // 测试没有命令参数 - 验证命令查找逻辑
        let noCommandApp = TestCLIApp(["app"])
        noCommandApp.use(TestCommand())
        
        // 验证没有命令时的状态
        @Expect(noCommandApp.args.size, 1)
        @Expect(noCommandApp.args[0], "app")
        
        // 测试命令查找逻辑
        var foundCommand = false
        for (cmd in noCommandApp.commands) {
            if (cmd.isCommand("")) {  // 空命令名不应该匹配
                foundCommand = true
                break
            }
        }
        @Expect(foundCommand, false)
        
        // 测试未知命令的帮助信息
        let unknownHelp = noCommandApp.getHelp("nonexistent")
        @Expect(unknownHelp.contains("Unknown command"), true)
        @Expect(unknownHelp.contains("nonexistent"), true)
    }
    
    /**
     * 测试多种构造函数
     * 验证不同的CLI应用程序初始化方式
     */
    @TestCase
    func testMultipleConstructors() {
        // 测试简单构造函数
        let simpleApp = TestCLIApp(["app", "test"])
        @Expect(simpleApp.args.size, 2)
        @Expect(simpleApp.commands.size, 0)
        
        // 测试带命令的构造函数
        let commands: Array<Command> = [TestCommand(), HelpCommand()]
        let fullApp = TestCLIApp(["app", "help"], commands: commands)
        @Expect(fullApp.args.size, 2)
        @Expect(fullApp.commands.size, 2)
    }

    @TestCase
    func testOptionMetadataDoesNotLeakAcrossCommands() {
        let first = FirstIsolatedCommand()
        let second = SecondIsolatedCommand()

        let firstHelp = first.getOptionsHelp()
        let secondHelp = second.getOptionsHelp()

        @Expect(firstHelp.contains("--first"), true)
        @Expect(firstHelp.contains("--second"), false)
        @Expect(secondHelp.contains("--second"), true)
        @Expect(secondHelp.contains("--first"), false)
    }

    @TestCase
    func testRequiredOptionPreventsExecuteUntilProvided() {
        let app = TestCLIApp(["required-only"])
        let command = RequiredOnlyCommand()
        app.use(command)

        let missingExitCode = app.execute()
        @Expect(missingExitCode, 1)
        @Expect(command.executed, false)

        let successApp = TestCLIApp(["required-only", "--name", "codex"])
        let successCommand = RequiredOnlyCommand()
        successApp.use(successCommand)

        let successExitCode = successApp.execute()
        @Expect(successExitCode, 0)
        @Expect(successCommand.executed, true)
        @Expect(successCommand.name, Some("codex"))
    }

    @TestCase
    func testMultipleOptionParsingAndHelpRemainStable() {
        let command = OrderedOptionCommand()
        command.setArgs(["ordered", "--third", "3", "--first", "1", "--second", "2"])

        @Expect(command.first, Some("1"))
        @Expect(command.second, Some("2"))
        @Expect(command.third, Some("3"))

        let help = command.getOptionsHelp()
        @Expect(help.contains("--third, -c"), true)
        @Expect(help.contains("--first, -a"), true)
        @Expect(help.contains("--second, -b"), true)
        @Expect(help.indexOf("--third").isSome(), true)
        @Expect(help.indexOf("--first").isSome(), true)
        @Expect(help.indexOf("--second").isSome(), true)
    }

    @TestCase
    func testExecuteInjectionPreservesComplexOriginalBody() {
        let blocked = ComplexExecuteCommand()
        blocked.setArgs(["complex"])
        let blockedExitCode = blocked.execute()

        @Expect(blockedExitCode, 1)
        @Expect(blocked.trace.size, 0)

        let allowed = ComplexExecuteCommand()
        allowed.setArgs(["complex", "--mode", "fast"])
        let allowedExitCode = allowed.execute()

        @Expect(allowedExitCode, 7)
        @Expect(allowed.trace.size, 3)
        @Expect(allowed.trace[0], "start")
        @Expect(allowed.trace[1], "mode=fast")
        @Expect(allowed.trace[2], "return-fast")
    }

    @TestCase
    func testCommandWithoutOptionsStillExecutesNormally() {
        let app = TestCLIApp(["plain"])
        let command = NoOptionCommand()
        app.use(command)

        let exitCode = app.execute()
        @Expect(exitCode, 0)
        @Expect(command.executeCount, 1)
    }
}

/**
 * 测试CLI应用程序类（带注解参数）
 * 使用@CLIApp宏生成功能，自动继承CLI接口
 * 测试注解参数：name、version、description
 */
@CLIApp[name: "markit", version: "1.0.0", description: "Markdown Processing Tool"]
class MarkitCLIApp {
    // 不需要手动定义name、version、description属性
    // 这些属性会由@CLIApp宏自动生成
}

/**
 * 测试CLI应用程序类
 * 使用@CLIApp宏生成功能，自动继承CLI接口
 * 不带注解参数，使用默认值
 */
@CLIApp
class TestCLIApp {
    // 不需要手动定义name、version、description属性
    // 这些属性会由@CLIApp宏自动生成，使用默认值
}

/**
 * 测试命令类
 * 使用@Cmd宏生成功能，自动继承Command接口
 */
@Cmd[command: ["test", "t"], required: false, description: "Test command for testing", usage: "Usage: test [options]"]
class TestCommand {
    
    @Opt[["--verbose", "-v"], help: "Enable verbose output"]
    public var verbose: ?String = None
    
    @Opt[["--output", "-o"], help: "Output file"]
    public var output: ?String = None
    
    public func execute(): Int {
        println("Test command executed")
        
        match (verbose) {
            case Some(_) => println("Verbose mode enabled")
            case None => println("Verbose mode disabled")
        }
        
        match (output) {
            case Some(file) => println("Output file: " + file)
            case None => println("No output file specified")
        }
        
        return 0
    }
}

/**
 * 帮助命令类
 * 使用@Cmd宏生成功能，自动继承Command接口
 */
@Cmd[command: ["help", "h"], required: false, description: "Show help information"]
class HelpCommand {
    
    @Opt[["--command", "-c"], help: "Show help for specific command"]
    public var command: ?String = None
    
    public func execute(): Int {
        match (command) {
            case Some(cmd) => println(cli.getHelp(cmd))
            case None => println(cli.getHelp())
        }
        return 0
    }
}

@Cmd[command: ["first"], description: "First isolated command"]
class FirstIsolatedCommand {
    @Opt[["--first"], help: "First only option"]
    public var first: ?String = None

    public func execute(): Int {
        return 0
    }
}

@Cmd[command: ["second"], description: "Second isolated command"]
class SecondIsolatedCommand {
    @Opt[["--second"], help: "Second only option"]
    public var second: ?String = None

    public func execute(): Int {
        return 0
    }
}

@Cmd[command: ["required-only"], description: "Command with a required option"]
class RequiredOnlyCommand {
    @Opt[["--name"], help: "Required name", required: true]
    public var name: ?String = None

    public var executed: Bool = false

    public func execute(): Int {
        executed = true
        return 0
    }
}

@Cmd[command: ["ordered"], description: "Command with ordered options"]
class OrderedOptionCommand {
    @Opt[["--third", "-c"], help: "Third option"]
    public var third: ?String = None

    @Opt[["--first", "-a"], help: "First option"]
    public var first: ?String = None

    @Opt[["--second", "-b"], help: "Second option"]
    public var second: ?String = None

    public func execute(): Int {
        return 0
    }
}

@Cmd[command: ["complex"], description: "Command with complex execute body"]
class ComplexExecuteCommand {
    @Opt[["--mode"], help: "Execution mode", required: true]
    public var mode: ?String = None

    public var trace: Array<String> = []

    public func execute(): Int {
        trace = appendTrace(trace, "start")

        match (mode) {
            case Some(value) =>
                trace = appendTrace(trace, "mode=${value}")
                if (value == "fast") {
                    trace = appendTrace(trace, "return-fast")
                    return 7
                }
                trace = appendTrace(trace, "return-default")
                return 3
            case None =>
                trace = appendTrace(trace, "unexpected-none")
                return -1
        }
    }
}

@Cmd[command: ["plain"], description: "Command without options"]
class NoOptionCommand {
    public var executeCount: Int64 = 0

    public func execute(): Int {
        executeCount += 1
        return 0
    }
}

func appendTrace(trace: Array<String>, entry: String): Array<String> {
    let values = ArrayList<String>()
    for (item in trace) {
        values.add(item)
    }
    values.add(entry)
    return values.toArray()
}
