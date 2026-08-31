package commandline.tests.macros

/* cjlint-ignore -start !G.PKG.01 */
import std.unittest.*
import std.unittest.testmacro.*
/* cjlint-ignore -end */
import commandline.utils.{getStringParam, getBoolParam, getArrayParam, extractParameterValue}
import commandline.model.AnnotationParameter

/**
 * 宏辅助工具测试
 * 验证宏辅助函数的正确性
 */

@Test
@Tag[UnitTest, UtilityTest]
class TestMacroHelpers {
    
    /**
     * 测试注解参数解析
     * 验证parseAnnotationParameters函数的正确性
     */
    @TestCase
    func testAnnotationParameterParsing() {
        // 注意：由于Tokens是AST类型，这里主要测试参数提取逻辑
        // 实际的宏测试会在集成测试中进行
        
        // 测试参数值提取
        let basicContent = "command: [\"test\", \"t\"], required: true, description: \"Test command\""
        
        // 测试命令参数提取
        let commandValue = extractParameterValue(basicContent, "command")
        @Expect(commandValue, "[\"test\", \"t\"]")
        
        // 测试required参数提取
        let requiredValue = extractParameterValue(basicContent, "required")
        @Expect(requiredValue, "true")
        
        // 测试description参数提取
        let descValue = extractParameterValue(basicContent, "description")
        @Expect(descValue, "\"Test command\"")
    }
    
    /**
     * 测试选项参数解析
     * 验证@Opt宏的参数解析
     */
    @TestCase
    func testOptionParameterParsing() {
        // 测试选项参数解析
        let optionContent = "[\"--verbose\", \"-v\"], help: \"Enable verbose output\", required: true"
        
        // 测试help参数提取
        let helpValue = extractParameterValue(optionContent, "help")
        @Expect(helpValue, "\"Enable verbose output\"")
        
        // 测试required参数提取
        let requiredValue = extractParameterValue(optionContent, "required")
        @Expect(requiredValue, "true")
    }
    
    /**
     * 测试参数值提取
     * 验证extractParameterValue函数的正确性
     */
    @TestCase
    func testParameterValueExtraction() {
        // 测试字符串参数提取
        let stringValue = extractParameterValue("description: \"Test description\"", "description")
        @Expect(stringValue, "\"Test description\"")
        
        // 测试带空格的字符串参数提取
        let spacedValue = extractParameterValue("description:   \"Spaced description\"", "description")
        @Expect(spacedValue, "\"Spaced description\"")
        
        // 测试数组参数提取
        let arrayValue = extractParameterValue("command: [\"test\", \"t\"]", "command")
        @Expect(arrayValue, "[\"test\", \"t\"]")
        
        // 测试布尔参数提取
        let boolTrueValue = extractParameterValue("required: true", "required")
        @Expect(boolTrueValue, "true")
        
        let boolFalseValue = extractParameterValue("required: false", "required")
        @Expect(boolFalseValue, "false")
        
        // 测试不存在的参数
        let missingValue = extractParameterValue("other: value", "missing")
        @Expect(missingValue, "")
        
        // 测试复杂的参数字符串
        let complexValue = extractParameterValue("command: [\"build\", \"b\"], required: false, description: \"Build project\"", "description")
        @Expect(complexValue, "\"Build project\"")
    }
    
    /**
     * 测试字符串参数获取
     * 验证getStringParam函数的正确性
     */
    @TestCase
    func testStringParameterRetrieval() {
        let params = [
            AnnotationParameter(name: "description", value: "\"Test description\"", isArray: false),
            AnnotationParameter(name: "usage", value: "\"test [options]\"", isArray: false),
            AnnotationParameter(name: "empty", value: "\"\"", isArray: false)
        ]
        
        // 测试正常字符串参数
        let description = getStringParam(params, "description", "default")
        @Expect(description, "Test description")
        
        let usage = getStringParam(params, "usage", "default")
        @Expect(usage, "test [options]")
        
        // 测试空字符串参数
        let empty = getStringParam(params, "empty", "default")
        @Expect(empty, "")
        
        // 测试不存在的参数（使用默认值）
        let missing = getStringParam(params, "missing", "default value")
        @Expect(missing, "default value")
        
        // 测试没有引号的参数值
        let paramsNoQuotes = [
            AnnotationParameter(name: "simple", value: "simple_value", isArray: false)
        ]
        let simple = getStringParam(paramsNoQuotes, "simple", "default")
        @Expect(simple, "simple_value")
    }
    
    /**
     * 测试布尔参数获取
     * 验证getBoolParam函数的正确性
     */
    @TestCase
    func testBooleanParameterRetrieval() {
        let params = [
            AnnotationParameter(name: "required", value: "true", isArray: false),
            AnnotationParameter(name: "optional", value: "false", isArray: false),
            AnnotationParameter(name: "invalid", value: "maybe", isArray: false)
        ]
        
        // 测试true值
        let required = getBoolParam(params, "required", false)
        @Expect(required, true)
        
        // 测试false值
        let optional = getBoolParam(params, "optional", true)
        @Expect(optional, false)
        
        // 测试无效值（使用默认值）
        let invalid = getBoolParam(params, "invalid", true)
        @Expect(invalid, true)
        
        // 测试不存在的参数（使用默认值）
        let missing = getBoolParam(params, "missing", false)
        @Expect(missing, false)
    }
    
    /**
     * 测试数组参数获取
     * 验证getArrayParam函数的正确性
     */
    @TestCase
    func testArrayParameterRetrieval() {
        let params = [
            AnnotationParameter(name: "command", value: "[\"test\", \"t\", \"testing\"]", isArray: true),
            AnnotationParameter(name: "options", value: "[\"--verbose\", \"-v\"]", isArray: true),
            AnnotationParameter(name: "single", value: "[\"only\"]", isArray: true),
            AnnotationParameter(name: "empty", value: "[]", isArray: true),
            AnnotationParameter(name: "", value: "[\"pos1\", \"pos2\"]", isArray: true)  // 位置参数
        ]
        
        // 测试多元素数组
        let commands = getArrayParam(params, "command", ["default"])
        @Expect(commands.size, 3)
        @Expect(commands[0], "test")
        @Expect(commands[1], "t")
        @Expect(commands[2], "testing")
        
        // 测试双元素数组
        let options = getArrayParam(params, "options", ["default"])
        @Expect(options.size, 2)
        @Expect(options[0], "--verbose")
        @Expect(options[1], "-v")
        
        // 测试单元素数组
        let single = getArrayParam(params, "single", ["default"])
        @Expect(single.size, 1)
        @Expect(single[0], "only")
        
        // 测试空数组
        let empty = getArrayParam(params, "empty", ["default"])
        @Expect(empty.size, 0)
        
        // 测试位置参数（空名称）
        let positional = getArrayParam(params, "", ["default"])
        @Expect(positional.size, 2)
        @Expect(positional[0], "pos1")
        @Expect(positional[1], "pos2")
        
        // 测试不存在的参数（使用默认值）
        let missing = getArrayParam(params, "missing", ["default1", "default2"])
        @Expect(missing.size, 2)
        @Expect(missing[0], "default1")
        @Expect(missing[1], "default2")
    }
    
    /**
     * 测试复杂的参数解析场景
     * 验证复杂注解参数的正确解析
     */
    @TestCase
    func testComplexParameterScenarios() {
        // 测试包含特殊字符的参数
        let specialContent = "command: [\"build-all\", \"build_all\", \"ba\"], description: \"Build all components (debug & release)\""
        
        let commandValue = extractParameterValue(specialContent, "command")
        @Expect(commandValue.contains("build-all"), true)
        @Expect(commandValue.contains("build_all"), true)
        @Expect(commandValue.contains("ba"), true)
        
        let descValue = extractParameterValue(specialContent, "description")
        @Expect(descValue.contains("Build all components"), true)
        
        // 测试包含Unicode字符的参数
        let unicodeContent = "description: \"处理数据文件\", usage: \"处理 [选项]\""
        
        let unicodeDesc = extractParameterValue(unicodeContent, "description")
        @Expect(unicodeDesc.contains("处理数据文件"), true)
        
        let unicodeUsage = extractParameterValue(unicodeContent, "usage")
        @Expect(unicodeUsage.contains("处理 [选项]"), true)
    }
    
    /**
     * 测试边界情况和错误处理
     * 验证各种边界情况的正确处理
     */
    @TestCase
    func testEdgeCasesAndErrorHandling() {
        // 测试格式错误的数组
        let malformedArrayValue = extractParameterValue("command: [\"test\", \"t\"", "command")
        @Expect(malformedArrayValue, "")
        
        // 测试格式错误的字符串
        let malformedStringValue = extractParameterValue("description: \"unclosed string", "description")
        @Expect(malformedStringValue, "")
        
        // 测试不存在的参数
        let missingValue = extractParameterValue("other: value", "missing")
        @Expect(missingValue, "")
        
        // 测试空数组参数
        let emptyArrayParams = [
            AnnotationParameter(name: "empty", value: "[]", isArray: true)
        ]
        let emptyArray = getArrayParam(emptyArrayParams, "empty", ["default"])
        @Expect(emptyArray.size, 0)
    }
}