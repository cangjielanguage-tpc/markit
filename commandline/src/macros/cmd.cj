macro package commandline.macros

/* cjlint-ignore -start !G.PKG.01 */
import std.ast.*
import std.collection.ArrayList
/* cjlint-ignore -end */
import commandline.utils.{parseAnnotationParameters, getStringParam, getBoolParam, getArrayParam}
import commandline.model.OptionFieldInfo

/**
 * @Cmd宏实现
 * 处理命令类的注解，生成参数解析和执行逻辑
 * 
 * 支持格式：@Cmd[command: ['repos'], required: true]
 */

/**
 * @Cmd宏主函数
 * 解析@Cmd注解参数并生成命令元数据和相关方法
 * 自动添加Command接口继承，用户无需手动继承
 * 
 * @param attrTokens 注解参数的Token序列
 * @param inputTokens 被注解的代码Token序列
 * @return 扩展后的代码Token序列
 */
public macro Cmd(attrTokens: Tokens, inputTokens: Tokens): Tokens {
    // 解析注解参数
    let params = parseAnnotationParameters(attrTokens)
    
    // 提取命令参数
    let commandNames = getArrayParam(params, "command", ["default"])
    let requiredValue = getBoolParam(params, "required", false)
    let description = getStringParam(params, "description", "")
    let usage = getStringParam(params, "usage", "")
    
    // 解析类声明 - 直接使用ClassDecl构造函数
    let classDecl = try {
        ClassDecl(inputTokens)
    } catch (e: ASTException) {
        throw Exception("@Cmd can only be applied to class declarations: " + e.toString())
    }

    let optionFields = collectOptionFields()
    
    // 自动添加Command接口继承
    addCommandInterfaceInheritance(classDecl)
    
    // 创建isCommand方法的函数声明
    let isCommandMethod = createIsCommandMethod(commandNames)
    
    // 创建required属性的声明
    let requiredProperty = createRequiredProperty(requiredValue)
    
    // 创建commandName属性的声明
    let commandNameProperty = createCommandNameProperty(commandNames)
    
    // 创建帮助相关的方法
    let getDescriptionMethod = createGetDescriptionMethod(description)
    let getUsageMethod = createGetUsageMethod(usage, commandNames)
    let getOptionsHelpMethod = createGetOptionsHelpMethod(optionFields)
    
    // 创建args字段和setArgs方法
    let argsField = createArgsField()
    let cliField = createCLIField()
    let validationFailedField = createValidationFailedField()
    let paramStoreField = createParamStoreField()
    let nameMapField = createNameMapField()
    let paramStoreProp = createParamStoreProp()
    let nameMapProp = createNameMapProp()
    let cliProp = createCLIProp()
    let setArgsMethod = createSetArgsMethod(optionFields.size > 0)
    let setCLIMethod = createSetCLIMethod()
    
    // 创建参数解析构造函数（如果有@Opt字段）
    if (optionFields.size > 0) {
        let parseConstructor = createParameterParsingConstructor(optionFields)
        let parseAndSetOptionsMethod = createParseAndSetOptionsMethod(optionFields)
        let checkRequiredMethod = createCheckRequiredMethod(optionFields)
        let validateOptionsMethod = createValidateOptionsMethod()
        classDecl.body.decls.add(parseConstructor)
        classDecl.body.decls.add(parseAndSetOptionsMethod)
        classDecl.body.decls.add(checkRequiredMethod)
        classDecl.body.decls.add(validateOptionsMethod)
    }
    
    // 将方法和属性添加到类体中
    classDecl.body.decls.add(argsField)
    classDecl.body.decls.add(cliField)
    classDecl.body.decls.add(validationFailedField)
    classDecl.body.decls.add(paramStoreField)
    classDecl.body.decls.add(nameMapField)
    classDecl.body.decls.add(paramStoreProp)
    classDecl.body.decls.add(nameMapProp)
    classDecl.body.decls.add(cliProp)
    classDecl.body.decls.add(isCommandMethod)
    classDecl.body.decls.add(requiredProperty)
    classDecl.body.decls.add(commandNameProperty)
    classDecl.body.decls.add(getDescriptionMethod)
    classDecl.body.decls.add(getUsageMethod)
    classDecl.body.decls.add(getOptionsHelpMethod)
    classDecl.body.decls.add(setArgsMethod)
    classDecl.body.decls.add(setCLIMethod)
    
    // 修改现有的execute方法，在开头添加checkRequired检查
    if (optionFields.size > 0) {
        modifyExecuteMethod(classDecl)
    }
    
    // 返回修改后的类声明
    return classDecl.toTokens()
}

func collectOptionFields(): Array<OptionFieldInfo> {
    let optionFields = ArrayList<OptionFieldInfo>()
    let messages = getChildMessages("Opt")

    for (message in messages) {
        let fieldName = message.getString("field_name")
        let names = splitOptionNames(message.getString("names"))
        let help = message.getString("help")
        let fieldType = message.getString("field_type")
        let defaultValueRaw = message.getString("default_value")
        let required = message.getString("required") == "true"

        optionFields.add(OptionFieldInfo(
            fieldName: fieldName,
            names: names,
            help: help,
            fieldType: fieldType,
            defaultValue: if (defaultValueRaw.isEmpty()) { None } else { Some(defaultValueRaw) },
            required: required
        ))
    }

    return optionFields.toArray()
}

func splitOptionNames(encoded: String): Array<String> {
    if (encoded.isEmpty()) {
        return []
    }
    return encoded.split("\u{001f}")
}

/**
 * 创建required属性的声明
 * 
 * @param requiredValue required属性的值
 * @return required属性的PropDecl
 */
func createRequiredProperty(requiredValue: Bool): PropDecl {
    // 使用quote创建属性的Token序列
    let propertyTokens = quote(
        /**
         * 获取命令的required属性
         * 由@Cmd宏生成，根据注解参数中的required值
         * @return required属性值
         */
        public prop required: Bool {
            get() { $(requiredValue) }
        }
    )
    
    // 将Token序列转换为PropDecl
    return PropDecl(propertyTokens)
}

/**
 * 创建commandName属性的声明
 * 
 * @param commandNames 命令名称数组
 * @return commandName属性的PropDecl
 */
func createCommandNameProperty(commandNames: Array<String>): PropDecl {
    let primaryCommand = if (commandNames.size > 0) { commandNames[0] } else { "unknown" }
    
    let propertyTokens = quote(
        /**
         * 获取命令名称（主要名称）
         * 由@Cmd宏生成，返回第一个命令名称
         * @return 命令名称
         */
        public prop commandName: String {
            get() { $(primaryCommand) }
        }
    )
    
    return PropDecl(propertyTokens)
}

/**
 * 创建isCommand方法的函数声明
 * 
 * @param commandNames 命令名称数组
 * @return isCommand方法的FuncDecl
 */
func createIsCommandMethod(commandNames: Array<String>): FuncDecl {
    // 使用quote创建方法的Token序列
    let methodTokens = quote(
        /**
         * 检查是否为指定命令名称
         * 由@Cmd宏生成，根据注解参数中的command数组进行匹配
         * @param commandName 要检查的命令名称
         * @return 如果匹配返回true，否则返回false
         */
        public override func isCommand(commandName: String): Bool {
            let names = $(generateArrayLiteral(commandNames))
            for (name in names) {
                if (name == commandName) {
                    return true
                }
            }
            return false
        }
    )
    
    // 将Token序列转换为FuncDecl
    return FuncDecl(methodTokens)
}

/**
 * 生成数组字面量的Token序列
 * 
 * @param items 字符串数组
 * @return 数组字面量的Token序列
 */
func generateArrayLiteral(items: Array<String>): Tokens {
    // 构建数组内容
    var arrayContent = quote()
    
    for (i in 0..items.size) {
        if (i > 0) {
            arrayContent = quote($(arrayContent), $(items[i]))
        } else {
            arrayContent = quote($(items[i]))
        }
    }
    
    // 返回完整的数组字面量
    return quote([$(arrayContent)])
}

/**
 * 创建参数解析构造函数
 * 生成一个构造函数，用于解析命令行参数并设置@Opt字段的值
 * 
 * @return 参数解析构造函数的FuncDecl
 */
func createParameterParsingConstructor(optionFields: Array<OptionFieldInfo>): FuncDecl {
    // 生成选项名称映射的代码
    let optionMappingCode = generateOptionMappingCode(optionFields)
    
    // 生成字段赋值的代码
    let fieldAssignmentCode = generateFieldAssignmentCode(optionFields)
    
    // 使用quote创建构造函数的Token序列
    let constructorTokens = quote(
        public init(args !: Array<String> = []) {
            $(optionMappingCode)
            
            // 解析参数
            Command.parseArguments(args, this)
            $(fieldAssignmentCode)
            
            // 验证选项（在参数解析后进行）
            if (!this.validateOptions(args)) {
                // 验证失败，设置标志但不抛出异常
                this._validationFailed = true
            }
        }
    )
    
    // 将Token序列转换为FuncDecl
    return FuncDecl(constructorTokens)
}

/**
 * 生成选项名称映射的代码
 * 为每个@Opt字段生成registerOptionNames调用
 * 
 * @return 选项名称映射代码的Token序列
 */
func generateOptionMappingCode(optionFields: Array<OptionFieldInfo>): Tokens {
    var mappingCode = quote()
    
    for (fieldInfo in optionFields) {
        let fieldNameStr = Token(TokenKind.STRING_LITERAL, fieldInfo.fieldName)
        let namesArray = generateArrayLiteral(fieldInfo.names)
        
        let registerCall = quote(
            this.registerOptionNames($(namesArray), $(fieldNameStr))
        )
        
        if (mappingCode.toString().isEmpty()) {
            mappingCode = registerCall
        } else {
            mappingCode = quote($(mappingCode); $(registerCall))
        }
    }
    
    return mappingCode
}

/**
 * 生成字段赋值的代码
 * 为每个@Opt字段生成从paramStore获取值并赋值的代码
 * 
 * @return 字段赋值代码的Token序列
 */
func generateFieldAssignmentCode(optionFields: Array<OptionFieldInfo>): Tokens {
    var assignmentCode = quote()
    
    for (fieldInfo in optionFields) {
        let fieldAssignment = generateFieldAssignment(fieldInfo)
        
        if (assignmentCode.toString().isEmpty()) {
            assignmentCode = fieldAssignment
        } else {
            assignmentCode = quote($(assignmentCode); $(fieldAssignment))
        }
    }
    
    return assignmentCode
}

/**
 * 生成单个字段的赋值代码
 * 根据字段类型和默认值生成相应的赋值逻辑
 * 
 * @param fieldInfo 字段信息
 * @return 字段赋值代码的Token序列
 */
func generateFieldAssignment(fieldInfo: OptionFieldInfo): Tokens {
    let fieldNameToken = Token(TokenKind.IDENTIFIER, fieldInfo.fieldName)
    let fieldNameStr = Token(TokenKind.STRING_LITERAL, fieldInfo.fieldName)
    
    // 对于 Option 类型字段，只在用户提供参数时才设置值
    // 如果用户没有提供参数，保持字段的原始默认值
    return quote(
        match (this.getParameter($(fieldNameStr))) {
            case Some(value) => this.$(fieldNameToken) = Some(value)
            case None => ()
        }
    )
}

/**
 * 创建_paramStore实现字段
 * 
 * @return _paramStore实现字段的VarDecl
 */
func createParamStoreField(): VarDecl {
    let fieldTokens = quote(
        private var _paramStoreImpl: Array<(String, String)> = []
    )
    return VarDecl(fieldTokens)
}

/**
 * 创建_nameMap实现字段
 * 
 * @return _nameMap实现字段的VarDecl
 */
func createNameMapField(): VarDecl {
    let fieldTokens = quote(
        private var _nameMapImpl: Array<(String, String)> = []
    )
    return VarDecl(fieldTokens)
}

/**
 * 创建_paramStore属性
 * 
 * @return _paramStore属性的PropDecl
 */
func createParamStoreProp(): PropDecl {
    let propTokens = quote(
        public mut prop _paramStore: Array<(String, String)> {
            get() { _paramStoreImpl }
            set(value) { _paramStoreImpl = value }
        }
    )
    return PropDecl(propTokens)
}

/**
 * 创建_nameMap属性
 * 
 * @return _nameMap属性的PropDecl
 */
func createNameMapProp(): PropDecl {
    let propTokens = quote(
        public mut prop _nameMap: Array<(String, String)> {
            get() { _nameMapImpl }
            set(value) { _nameMapImpl = value }
        }
    )
    return PropDecl(propTokens)
}

/**
 * 创建args字段
 * 
 * @return args字段的VarDecl
 */
func createArgsField(): VarDecl {
    let fieldTokens = quote(
        public var args: Array<String> = []
    )
    return VarDecl(fieldTokens)
}

/**
 * 创建_validationFailed字段
 * 
 * @return _validationFailed字段的VarDecl
 */
func createValidationFailedField(): VarDecl {
    let fieldTokens = quote(
        private var _validationFailed: Bool = false
    )
    return VarDecl(fieldTokens)
}

/**
 * 创建_cli字段
 * 
 * @return cli字段的VarDecl
 */
func createCLIField(): VarDecl {
    let fieldTokens = quote(
        public var _cli: ?CLI = None
    )
    return VarDecl(fieldTokens)
}

/**
 * 创建cliprop
 *
 * @param cli CLI实例
 * @return cli属性的PropDecl
 */
 func createCLIProp(): PropDecl {
    let propTokens = quote(
        public mut prop cli : CLI { 
            get() { 
                if(let Some(cli) <- _cli) {
                    cli
                } else {
                    throw Exception("CLI is not set")
                }

            }
            set(value) { 
                if(_cli.isNone()) {
                    _cli = value
                } else {
                    throw Exception("CLI is already set")
                }
            }
        }
    )
    return PropDecl(propTokens)
 }

/**
 * 创建setArgs方法
 * 
 * @param hasOptions 是否有@Opt字段需要解析
 * @return setArgs方法的FuncDecl
 */
func createSetArgsMethod(hasOptions: Bool): FuncDecl {
    let methodTokens = if (hasOptions) {
        quote(
            public func setArgs(args: Array<String>): Unit {
                this.args = args
                // 重新解析参数并设置@Opt字段
                this.parseAndSetOptions()
            }
        )
    } else {
        quote(
            public func setArgs(args: Array<String>): Unit {
                this.args = args
            }
        )
    }
    return FuncDecl(methodTokens)
}

/**
 * 创建setCLI方法
 * 
 * @return setCLI方法的FuncDecl
 */
func createSetCLIMethod(): FuncDecl {
    let methodTokens = quote(
        public func setCLI(cli: CLI): Unit {
            this.cli = cli
            match(this.cli){ case cli => () }
        }
    )
    return FuncDecl(methodTokens)
}

/**
 * 创建参数解析方法
 * 
 * @return parseAndSetOptions方法的FuncDecl
 */
func createParseAndSetOptionsMethod(optionFields: Array<OptionFieldInfo>): FuncDecl {
    // 生成选项名称映射的代码
    let optionMappingCode = generateOptionMappingCode(optionFields)
    
    // 生成字段赋值的代码
    let fieldAssignmentCode = generateFieldAssignmentCode(optionFields)
    
    let methodTokens = quote(
        private func parseAndSetOptions(): Unit {
            $(optionMappingCode)
            
            // 解析参数
            Command.parseArguments(this.args, this)
            $(fieldAssignmentCode)
            
            // 验证选项（在参数解析后进行）
            if (!this.validateOptions(this.args)) {
                // 验证失败，设置标志但不抛出异常
                this._validationFailed = true
            }
        }
    )
    return FuncDecl(methodTokens)
}

/**
 * 创建getDescription方法
 * 
 * @param description 命令描述
 * @return getDescription方法的FuncDecl
 */
func createGetDescriptionMethod(description: String): FuncDecl {
    let methodTokens = quote(
        public func getDescription(): String {
            return $(description)
        }
    )
    return FuncDecl(methodTokens)
}

/**
 * 创建getUsage方法
 * 
 * @param usage 用法说明
 * @param commandNames 命令名称数组
 * @return getUsage方法的FuncDecl
 */
func createGetUsageMethod(usage: String, commandNames: Array<String>): FuncDecl {
    let primaryCommand = if (commandNames.size > 0) { commandNames[0] } else { "command" }
    let usageText = if (usage.isEmpty()) {
        "Usage: " + primaryCommand + " [options]"
    } else {
        usage
    }
    
    let methodTokens = quote(
        public func getUsage(): String {
            return $(usageText)
        }
    )
    return FuncDecl(methodTokens)
}

/**
 * 创建getOptionsHelp方法
 * 
 * @return getOptionsHelp方法的FuncDecl
 */
func createGetOptionsHelpMethod(optionFields: Array<OptionFieldInfo>): FuncDecl {
    let optionsHelpCode = generateOptionsHelpCode(optionFields)
    
    let methodTokens = quote(
        public func getOptionsHelp(): String {
            var help = ""
            $(optionsHelpCode)
            return help
        }
    )
    return FuncDecl(methodTokens)
}

/**
 * 生成选项帮助代码
 * 
 * @return 选项帮助代码的Token序列
 */
func generateOptionsHelpCode(optionFields: Array<OptionFieldInfo>): Tokens {
    var helpCode = quote()
    
    for (fieldInfo in optionFields) {
        let namesStr = fieldInfo.names.toString().replace("[", "").replace("]", "").replace("\"", "")
        let helpText = fieldInfo.help
        let requiredText = if (fieldInfo.required) { " ⚠ (required)" } else { "" }
        
        let optionHelp = quote(
            help += "  " + $(namesStr) + "  " + $(helpText) + $(requiredText) + "\n"
        )
        
        if (helpCode.toString().isEmpty()) {
            helpCode = optionHelp
        } else {
            helpCode = quote($(helpCode); $(optionHelp))
        }
    }
    
    return helpCode
}
/**
 * 修改现有的execute方法，在开头添加checkRequired检查
 * 
 * 参考文档：
 * - markit/libs/dev-guide/source_en/Macro/syntax_node.md - 语法节点操作
 * - markit/libs/cangjie_runtime-dev/stdlib/doc/libs/std_en/ast/ast_package_api/ast_package_classes.md - AST API
 * - markit/src/core/parser.cj - 现有仓颉语法示例
 * 
 * @param classDecl 类声明AST节点
 */
func modifyExecuteMethod(classDecl: ClassDecl): Unit {
    // 查找现有的execute方法
    for (i in 0..classDecl.body.decls.size) {
        let decl = classDecl.body.decls[i]
        if (let funcDecl: FuncDecl <- decl) {
            // 检查是否是execute方法 - 通过转换为Tokens字符串来检查
            let funcTokens = funcDecl.toTokens().toString()
            if (funcTokens.contains("func execute(")) {
                // 创建新的execute方法，在开头添加checkRequired检查
                let newExecuteMethod = createModifiedExecuteMethod(funcDecl)
                
                // 替换原有的execute方法
                classDecl.body.decls[i] = newExecuteMethod
                break
            }
        }
    }
}

/**
 * 创建修改后的execute方法，在开头添加checkRequired检查
 * 
 * 参考文档：
 * - markit/libs/dev-guide/source_en/Macro/Tokens_types_and_quote_expressions.md - quote表达式和插值
 * - markit/libs/dev-guide/source_en/Macro/syntax_node.md - 语法节点插值
 * 
 * @param originalExecute 原始的execute方法
 * @return 修改后的execute方法
 */
func createModifiedExecuteMethod(originalExecute: FuncDecl): FuncDecl {
    let originalMethodText = originalExecute.toTokens().toString()
    let originalBlockText = originalExecute.block.toTokens().toString()
    let newBlockTokens = quote({
        if (!this.checkRequired()) {
            return 1
        }
        $(originalExecute.block.nodes)
    })
    let updatedMethodText = originalMethodText.replace(originalBlockText, newBlockTokens.toString())
    return FuncDecl(cangjieLex(updatedMethodText))
}

/**
 * 创建checkRequired方法
 * 检查所有标注为required的Option字段是否都不为None
 * 如果有缺失的必需参数，打印错误信息并返回false
 * 
 * 参考文档：
 * - markit/libs/dev-guide/source_en/error_handle/exception_overview.md - 异常处理
 * 
 * @return checkRequired方法的FuncDecl
 */
func createCheckRequiredMethod(optionFields: Array<OptionFieldInfo>): FuncDecl {
    let checkRequiredCode = generateCheckRequiredCode(optionFields)
    
    let methodTokens = quote(
        /**
         * 检查所有标注为required的Option字段是否都不为None
         * 同时检查选项验证是否失败
         * 由@Cmd宏自动生成，根据@Opt注解中的required参数
         * @return 如果所有required字段都不为None且选项验证通过返回true，否则返回false
         */
        public func checkRequired(): Bool {
            // 首先检查选项验证是否失败
            if (this._validationFailed) {
                return false
            }
            
            $(checkRequiredCode)
            return true
        }
    )
    return FuncDecl(methodTokens)
}

/**
 * 生成checkRequired方法的检查代码
 * 为每个标注为required的字段生成检查逻辑
 * 
 * @return 检查代码的Token序列
 */
func generateCheckRequiredCode(optionFields: Array<OptionFieldInfo>): Tokens {
    var checkCode = quote()
    
    // 收集所有required字段
    let requiredFields = ArrayList<OptionFieldInfo>()
    for (fieldInfo in optionFields) {
        if (fieldInfo.required) {
            requiredFields.add(fieldInfo)
        }
    }
    
    // 如果没有required字段，直接返回true
    if (requiredFields.size == 0) {
        return quote()
    }
    
    // 为每个required字段生成检查代码
    for (fieldInfo in requiredFields) {
        let fieldNameToken = Token(TokenKind.IDENTIFIER, fieldInfo.fieldName)
        let fieldNameStr = Token(TokenKind.STRING_LITERAL, fieldInfo.fieldName)
        
        let fieldCheck = quote(
            if (this.$(fieldNameToken).isNone()) {
                CLI.printMissingRequiredOption($(fieldNameStr))
                return false
            }
        )
        
        if (checkCode.toString().isEmpty()) {
            checkCode = fieldCheck
        } else {
            checkCode = quote($(checkCode); $(fieldCheck))
        }
    }
    
    return checkCode
}

/**
 * 创建选项验证方法
 * 检查用户输入的选项是否都是支持的选项，如果有不支持的选项则提供建议
 * 
 * @return validateOptions方法的FuncDecl
 */
func createValidateOptionsMethod(): FuncDecl {
    let methodTokens = quote(
        /**
         * 验证用户输入的选项是否都是支持的选项
         * 如果有不支持的选项，会打印错误信息和建议，并设置验证失败标志
         * @param args 命令行参数数组
         * @return 如果所有选项都有效返回true，否则返回false
         */
        private func validateOptions(args: Array<String>): Bool {
            // 从Command接口动态获取所有有效的选项名称
            let allOptionNames = this.getAllRegisteredOptions()
            
            // 找出所有无效的选项，并去重
            let invalidOptions = args.filter { arg: String => 
                arg.startsWith("-") && !allOptionNames.any { validOption: String => validOption == arg }
            }
            let uniqueInvalidOptions = CLI.uniqueStrings(invalidOptions)
            
            // 如果有无效选项，打印错误信息
            if (uniqueInvalidOptions.size > 0) {
                CLI.printUnknownOptions(this.commandName, uniqueInvalidOptions, allOptionNames)
                return false
            }
            
            return true
        }
    )
    return FuncDecl(methodTokens)
}


/**
 * 自动添加Command接口继承
 * 如果类没有继承Command接口, 则自动添加
 * 
 * 参考文档:
 * - markit/libs/dev-guide/source_en/class_and_interface/interface.md - 接口实现语法
 * - markit/libs/cangjie_runtime-dev/stdlib/doc/libs/std_en/ast/ast_package_api/ast_package_classes.md - ClassDecl API
 * 
 * @param classDecl 类声明AST节点
 */
func addCommandInterfaceInheritance(classDecl: ClassDecl): Unit {
    // 检查是否已经继承了Command接口
    var hasCommandInterface = false
    for (superType in classDecl.superTypes) {
        let typeTokens = superType.toTokens().toString()
        if (typeTokens.contains("Command")) {
            hasCommandInterface = true
            break
        }
    }
    
    // 如果没有继承Command接口, 则添加
    if (!hasCommandInterface) {
        // 创建Command接口类型节点
        let commandTypeTokens = quote(Command)
        let commandTypeNode = parseType(commandTypeTokens)
        
        // 如果没有父类型, 设置upperBound操作符
        if (classDecl.superTypes.size == 0) {
            let upperBoundTokens = quote(<:)
            classDecl.upperBound = upperBoundTokens[0]
        } else {
            // 如果已有父类型, 添加&操作符
            classDecl.superTypeBitAnds = classDecl.superTypeBitAnds + quote(&)
        }
        
        // 添加Command接口到父类型列表
        classDecl.superTypes.add(commandTypeNode)
    }
}
