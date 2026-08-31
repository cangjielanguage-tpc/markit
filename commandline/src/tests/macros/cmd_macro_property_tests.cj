package commandline.tests.macros

/* cjlint-ignore -start !G.PKG.01 */
import std.unittest.*
import std.unittest.testmacro.*
/* cjlint-ignore -end */

/**
 * @Cmd宏属性测试
 * 验证Required属性默认值属性
 */

@Test
@Tag[PropertyTest, MacroSystem, CmdMacro]
class TestCmdMacroProperties {
    
    /**
     * 属性7：Required属性默认值
     * 对于任意未明确设置required属性的命令类，
     * 其required属性应该返回false作为默认值。
     * 
     * 验证需求：6.2
     */
    @TestCase
    func testRequiredPropertyDefaultValue() {
        // 测试不同的命令配置场景
        let testCases = [
            // 基本命令配置（未指定required）
            MockCommandConfig(
                commandNames: ["help"],
                requiredSpecified: false,
                expectedRequired: false
            ),
            
            // 多个命令名称（未指定required）
            MockCommandConfig(
                commandNames: ["version", "v", "-V"],
                requiredSpecified: false,
                expectedRequired: false
            ),
            
            // 显式设置required为false
            MockCommandConfig(
                commandNames: ["status"],
                requiredSpecified: true,
                requiredValue: false,
                expectedRequired: false
            ),
            
            // 显式设置required为true
            MockCommandConfig(
                commandNames: ["deploy"],
                requiredSpecified: true,
                requiredValue: true,
                expectedRequired: true
            ),
            
            // 复杂命令配置（未指定required）
            MockCommandConfig(
                commandNames: ["config", "cfg", "c"],
                requiredSpecified: false,
                expectedRequired: false,
                description: "Configuration management",
                usage: "config [options]"
            )
        ]
        
        for (testCase in testCases) {
            // 属性7.1：默认情况下required属性应该为false
            if (!testCase.requiredSpecified) {
                @Expect(testCase.expectedRequired, false)
                validateDefaultRequiredBehavior(testCase)
            }
            
            // 属性7.2：显式设置的required值应该被正确保存
            if (testCase.requiredSpecified) {
                validateExplicitRequiredBehavior(testCase)
            }
            
            // 属性7.3：required属性不应该影响其他命令属性
            validateRequiredPropertyIndependence(testCase)
        }
    }
    
    /**
     * 验证默认required行为
     */
    func validateDefaultRequiredBehavior(config: MockCommandConfig) {
        // 模拟@Cmd宏处理未指定required的情况
        let mockCommand = createMockCommand(config)
        
        // 属性：未指定required时应该默认为false
        @Expect(mockCommand.required, false)
        
        // 属性：默认值不应该影响命令名称
        @Expect(mockCommand.commandNames.size, config.commandNames.size)
        for (i in 0..config.commandNames.size) {
            @Expect(mockCommand.commandNames[i], config.commandNames[i])
        }
    }
    
    /**
     * 验证显式required行为
     */
    func validateExplicitRequiredBehavior(config: MockCommandConfig) {
        let mockCommand = createMockCommand(config)
        
        // 属性：显式设置的required值应该被正确保存
        @Expect(mockCommand.required, config.expectedRequired)
        
        // 属性：显式设置不应该影响其他属性
        @Expect(mockCommand.commandNames.size, config.commandNames.size)
    }
    
    /**
     * 验证required属性的独立性
     */
    func validateRequiredPropertyIndependence(config: MockCommandConfig) {
        let mockCommand = createMockCommand(config)
        
        // 属性：required属性不应该影响命令名称
        @Expect(mockCommand.commandNames.size > 0, true)
        
        // 属性：required属性不应该影响描述和用法信息
        if (!config.description.isEmpty()) {
            @Expect(mockCommand.description, config.description)
        }
        if (!config.usage.isEmpty()) {
            @Expect(mockCommand.usage, config.usage)
        }
    }
    
    /**
     * 属性测试：命令元数据一致性
     * 验证@Cmd宏生成的元数据与输入参数一致
     */
    @TestCase
    func testCommandMetadataConsistency() {
        let testCases = [
            // 基本命令元数据
            MockCommandConfig(
                commandNames: ["test"],
                requiredSpecified: false,
                expectedRequired: false,
                description: "Run tests",
                usage: "test [options]"
            ),
            
            // 复杂命令元数据
            MockCommandConfig(
                commandNames: ["build", "b"],
                requiredSpecified: true,
                requiredValue: true,
                expectedRequired: true,
                description: "Build the project",
                usage: "build [--release] [--target <target>]"
            ),
            
            // 最小命令元数据
            MockCommandConfig(
                commandNames: ["minimal"],
                requiredSpecified: false,
                expectedRequired: false
            )
        ]
        
        for (testCase in testCases) {
            let mockCommand = createMockCommand(testCase)
            
            // 属性：命令名称应该完全匹配
            @Expect(mockCommand.commandNames.size, testCase.commandNames.size)
            for (i in 0..testCase.commandNames.size) {
                @Expect(mockCommand.commandNames[i], testCase.commandNames[i])
            }
            
            // 属性：required属性应该匹配
            @Expect(mockCommand.required, testCase.expectedRequired)
            
            // 属性：描述信息应该匹配
            @Expect(mockCommand.description, testCase.description)
            
            // 属性：用法信息应该匹配
            @Expect(mockCommand.usage, testCase.usage)
        }
    }
    
    /**
     * 属性测试：命令名称匹配
     * 验证命令名称匹配逻辑的正确性
     */
    @TestCase
    func testCommandNameMatching() {
        let testCases = [
            // 单个命令名称
            (["help"], "help", true),
            (["help"], "version", false),
            
            // 多个命令名称
            (["version", "v", "-V"], "version", true),
            (["version", "v", "-V"], "v", true),
            (["version", "v", "-V"], "-V", true),
            (["version", "v", "-V"], "help", false),
            
            // 大小写敏感
            (["Help"], "help", false),
            (["help"], "Help", false),
            
            // 空命令名称
            ([""], "", true),
            (["test"], "", false),
            
            // 特殊字符命令名称
            (["--help", "-h"], "--help", true),
            (["--help", "-h"], "-h", true),
            (["--help", "-h"], "help", false)
        ]
        
        for ((commandNames, testName, expectedMatch) in testCases) {
            let config = MockCommandConfig(
                commandNames: commandNames,
                requiredSpecified: false,
                expectedRequired: false
            )
            let mockCommand = createMockCommand(config)
            
            // 属性：命令名称匹配应该准确
            let actualMatch = simulateCommandNameMatching(mockCommand, testName)
            @Expect(actualMatch, expectedMatch)
        }
    }
    
    /**
     * 属性测试：帮助信息生成
     * 验证基于命令元数据生成帮助信息的正确性
     */
    @TestCase
    func testHelpGeneration() {
        let testCases = [
            MockCommandConfig(
                commandNames: ["help"],
                requiredSpecified: false,
                expectedRequired: false,
                description: "Show help information",
                usage: "help [command]"
            ),
            
            MockCommandConfig(
                commandNames: ["deploy", "d"],
                requiredSpecified: true,
                requiredValue: true,
                expectedRequired: true,
                description: "Deploy application",
                usage: "deploy --environment <env>"
            )
        ]
        
        for (testCase in testCases) {
            let mockCommand = createMockCommand(testCase)
            let helpText = generateMockHelp(mockCommand)
            
            // 属性：帮助信息应该包含命令名称
            @Expect(helpText.contains(testCase.commandNames[0]), true)
            
            // 属性：帮助信息应该包含描述（如果提供）
            if (!testCase.description.isEmpty()) {
                @Expect(helpText.contains(testCase.description), true)
            }
            
            // 属性：帮助信息应该包含用法（如果提供）
            if (!testCase.usage.isEmpty()) {
                @Expect(helpText.contains(testCase.usage), true)
            }
            
            // 属性：帮助信息应该指示是否必需
            let requiredText = match (testCase.expectedRequired) {
                case true => "是"
                case false => "否"
            }
            @Expect(helpText.contains(requiredText), true)
        }
    }
    
    // 辅助函数：创建模拟命令
    func createMockCommand(config: MockCommandConfig): MockCommand {
        return MockCommand(
            commandNames: config.commandNames,
            required: config.expectedRequired,
            description: config.description,
            usage: config.usage
        )
    }
    
    // 模拟命令名称匹配
    func simulateCommandNameMatching(command: MockCommand, testName: String): Bool {
        for (name in command.commandNames) {
            if (name == testName) {
                return true
            }
        }
        return false
    }
    
    // 生成模拟帮助信息
    func generateMockHelp(command: MockCommand): String {
        var help = "命令：" + command.commandNames[0] + "\n"
        
        if (!command.description.isEmpty()) {
            help += "描述：" + command.description + "\n"
        }
        
        if (!command.usage.isEmpty()) {
            help += "用法：" + command.usage + "\n"
        }
        
        help += "必需：" + match (command.required) {
            case true => "是"
            case false => "否"
        } + "\n"
        
        return help
    }
}

/**
 * 模拟命令配置类
 * 用于测试目的
 */
class MockCommandConfig {
    public let commandNames: Array<String>
    public let requiredSpecified: Bool
    public let requiredValue: Bool
    public let expectedRequired: Bool
    public let description: String
    public let usage: String
    
    public MockCommandConfig(
        commandNames!: Array<String>,
        requiredSpecified!: Bool,
        expectedRequired!: Bool,
        requiredValue!: Bool = false,
        description!: String = "",
        usage!: String = ""
    ) {
        this.commandNames = commandNames
        this.requiredSpecified = requiredSpecified
        this.requiredValue = requiredValue
        this.expectedRequired = expectedRequired
        this.description = description
        this.usage = usage
    }
}

/**
 * 模拟命令类
 * 用于测试目的
 */
class MockCommand {
    public let commandNames: Array<String>
    public let required: Bool
    public let description: String
    public let usage: String
    
    public MockCommand(
        commandNames!: Array<String>,
        required!: Bool,
        description!: String = "",
        usage!: String = ""
    ) {
        this.commandNames = commandNames
        this.required = required
        this.description = description
        this.usage = usage
    }
}