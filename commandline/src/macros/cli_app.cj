macro package commandline.macros

/* cjlint-ignore -start !G.PKG.01 */
import std.ast.*
/* cjlint-ignore -end */
import commandline.utils.{parseAnnotationParameters, getStringParam}

/**
 * @CLIApp宏实现
 * 为应用程序类添加命令路由和执行功能
 */

/**
 * @CLIApp宏主函数
 * 解析应用程序类声明并生成命令路由逻辑
 * 自动添加CLI接口继承，用户无需手动继承
 * 支持注解参数：@CLIApp[name: "app", version: "1.0.0", description: "App description"]
 * 
 * @param attrTokens 注解参数的Token序列（可选）
 * @param inputTokens 被注解的代码Token序列
 * @return 扩展后的代码Token序列
 * @throws Exception 当注解不应用于类声明时抛出异常
 */
 public macro CLIApp(attrTokens: Tokens, inputTokens: Tokens): Tokens {
    // 解析注解参数
    let params = parseAnnotationParameters(attrTokens)
    let appName = getStringParam(params, "name", "My CLI Application")
    let appVersion = getStringParam(params, "version", "0.0.0")
    let appDescription = getStringParam(params, "description", "No description")
    
    return generateCLIApp(inputTokens, appName, appVersion, appDescription)
}

/**
 * @CLIApp宏重载版本（无注解参数）
 * 为向后兼容提供的版本
 */
public macro CLIApp(inputTokens: Tokens): Tokens {
    return generateCLIApp(inputTokens, "My CLI Application", "0.0.0", "No description")
}

/**
 * 生成CLI应用程序的核心逻辑
 * @param inputTokens 被注解的类声明Token序列
 * @param appName 应用程序名称
 * @param appVersion 应用程序版本
 * @param appDescription 应用程序描述
 * @return 扩展后的代码Token序列
 * @throws Exception 当输入不是类声明时抛出异常
 */
func generateCLIApp(inputTokens: Tokens, appName: String, appVersion: String, appDescription: String): Tokens {
    // 解析类声明 - 直接使用ClassDecl构造函数
    let classDecl = try {
        ClassDecl(inputTokens)
    } catch (e: ASTException) {
        throw Exception("@CLIApp can only be applied to class declarations: " + e.toString())
    }
    
    // 自动添加CLI接口继承
    addCLIInterfaceInheritance(classDecl)
    
    // 创建私有成员变量
    let commandsVar = createCommandsVariable()
    let argsVar = createArgsVariable()
    
    // 创建属性
    let commandsProperty = createCommandsProperty()
    let argsProperty = createArgsProperty()
    
    // 创建CLI应用程序的三个重载属性
    let nameProperty = createNameProperty(appName)
    let versionProperty = createVersionProperty(appVersion)
    let descriptionProperty = createDescriptionProperty(appDescription)
    
    // 创建构造函数（支持两种方式）
    let constructor = createCLIConstructor()
    
    // 创建命令管理方法
    let useArrayMethod = createUseCommandArrayMethod()
    
    // 创建自动生成的execute方法和帮助方法
    let executeMethod = createExecuteMethod()
    let getGeneralHelpMethod = createGetGeneralHelpMethod()
    let getCommandHelpMethod = createGetCommandHelpMethod()
    
    // 将成员变量、属性和方法添加到类体中
    classDecl.body.decls.add(commandsVar)
    classDecl.body.decls.add(argsVar)
    classDecl.body.decls.add(commandsProperty)
    classDecl.body.decls.add(argsProperty)
    classDecl.body.decls.add(nameProperty)
    classDecl.body.decls.add(versionProperty)
    classDecl.body.decls.add(descriptionProperty)
    classDecl.body.decls.add(constructor)
    classDecl.body.decls.add(useArrayMethod)
    classDecl.body.decls.add(executeMethod)
    classDecl.body.decls.add(getGeneralHelpMethod)
    classDecl.body.decls.add(getCommandHelpMethod)
    
    // 返回修改后的类声明
    return classDecl.toTokens()
}

/**
 * 创建_commands私有成员变量
 */
func createCommandsVariable(): VarDecl {
    let varTokens = quote(
        private var _commands: Array<Command> = Array<Command>()
    )
    return VarDecl(varTokens)
}

/**
 * 创建_args私有成员变量
 */
func createArgsVariable(): VarDecl {
    let varTokens = quote(
        private var _args: Array<String> = []
    )
    return VarDecl(varTokens)
}

/**
 * 创建commands属性
 */
func createCommandsProperty(): PropDecl {
    let propertyTokens = quote(
        public override prop commands: Array<Command> {
            get() { _commands }
        }
    )
    return PropDecl(propertyTokens)
}

/**
 * 创建args属性
 */
func createArgsProperty(): PropDecl {
    let propertyTokens = quote(
        public override prop args: Array<String> {
            get() { _args }
        }
    )
    return PropDecl(propertyTokens)
}

/**
 * 创建构造函数
 */
func createCLIConstructor(): FuncDecl {
    let constructorTokens = quote(
        public init(args: Array<String>, commands!: Array<Command> = []) {
            this._commands = commands
            this._args = args
        }
    )
    return FuncDecl(constructorTokens)
}

/**
 * 创建use方法（支持变长参数）
 */
func createUseCommandArrayMethod(): FuncDecl {
    let methodTokens = quote(
        public func use(commands: Array<Command>): CLI {
            for (cmd in commands) {
                cmd.setCLI(this)
            }
            this._commands = commands
            return this
        }
    )
    return FuncDecl(methodTokens)
}

/**
 * 创建execute方法
 * 生成完整的命令路由逻辑，在内部处理打印
 * 当命令不存在时提供相似命令建议
 */
func createExecuteMethod(): FuncDecl {
    let methodTokens = quote(
        public override func execute(): Int {
            // 找到第一个不是以 - 开头的参数作为命令名
            var commandName: ?String = None
            for (i in 0..args.size) {
                let arg = args[i]
                if (!arg.startsWith("-")) {
                    commandName = Some(arg)
                    break
                }
            }
            if (commandName == None && args.size > 0) {
                commandName = args[0]
            }
            match (commandName) {
                case Some(cmdName) => 
                    // 遍历所有命令，调用@Cmd宏生成的isCommand方法
                    for (command in commands) {
                        if (command.isCommand(cmdName)) {
                            // 只为匹配的命令设置参数，避免其他命令进行不必要的验证
                            command.setArgs(this._args)
                            return command.execute()
                        }
                    }
                    
                    CLI.printUnknownCommand(cmdName, commands)
                    return 1
                case None => 
                    CLI.printMissingCommand()
                    return 1
            }
        }
    )
    return FuncDecl(methodTokens)
}

/**
 * 创建getGeneralHelp方法
 * 生成通用帮助信息
 */
func createGetGeneralHelpMethod(): FuncDecl {
    let methodTokens = quote(
        public override func getHelp(): String {
            var help = "📚 " + name + " (v" + version + ")\n\n"
            help += description + "\n\n"
            help += "🚀 Available Commands:\n"
            
            for (command in commands) {
                let cmdName = command.commandName
                let cmdDesc = command.getDescription()
                help += "  " + cmdName + "  " + cmdDesc + "\n"
                
                // 添加选项信息
                let optionsHelp = command.getOptionsHelp()
                if (!optionsHelp.isEmpty()) {
                    help += "    Options:\n"
                    let optionLines = optionsHelp.split("\n")
                    for (line in optionLines) {
                        if (!line.trimAscii().isEmpty()) {
                            help += "    " + line + "\n"
                        }
                    }
                }
                help += "\n"
            }
            
            help += "💡 Usage:\n"
            help += "  <app> <command> [options]\n"
            help += "\n🔍 Get command help:\n"
            help += "  <app> help -c <command>\n"
            
            return help
        }
    )
    return FuncDecl(methodTokens)
}

/**
 * 创建getCommandHelp方法
 * 生成特定命令的帮助信息
 * 当命令不存在时提供相似命令建议
 */
func createGetCommandHelpMethod(): FuncDecl {
    let methodTokens = quote(
        public override func getHelp(commandName: String): String {
            for (command in commands) {
                if (command.isCommand(commandName)) {
                    var help = "📖 " + command.getDescription() + "\n\n"
                    help += "💻 " + command.getUsage() + "\n\n"
                    
                    let optionsHelp = command.getOptionsHelp()
                    if (!optionsHelp.isEmpty()) {
                        help += "⚙ Options:\n" + optionsHelp
                    }
                    
                    return help
                }
            }
            
            // 命令不存在，提供智能建议
            let suggestions = CLI.findSimilarCommands(commandName, commands)
            
            var errorMsg = "❌ Unknown command: " + commandName
            if (suggestions.size > 0) {
                errorMsg += "\n\n💡 Did you mean:\n"
                for (suggestion in suggestions) {
                    errorMsg += "  " + suggestion + "\n"
                }
            }
            errorMsg += "\nUse 'help' to see all available commands"
            
            return errorMsg
        }
    )
    return FuncDecl(methodTokens)
}

/**
 * 创建name属性
 * 参考文档：
 * - markit/libs/cangjie_runtime-dev/stdlib/doc/libs/std_en/ast/ast_package_api/ast_package_classes.md - PropDecl API
 * - markit/libs/dev-guide/source_en/Macro/macro_introduction.md - quote表达式和插值语法
 */
func createNameProperty(appName: String): PropDecl {
    // 创建包含实际值的字符串字面量token（不需要手动添加引号）
    let nameToken = Token(TokenKind.STRING_LITERAL, appName)
    
    // 使用quote构建属性声明，然后插入实际的值
    let propertyTokens = quote(
        public override prop name: String { get() { $(Tokens([nameToken])) } }
    )
    
    return PropDecl(propertyTokens)
}

/**
 * 创建version属性
 * 参考文档：
 * - markit/libs/cangjie_runtime-dev/stdlib/doc/libs/std_en/ast/ast_package_api/ast_package_classes.md - PropDecl API
 */
func createVersionProperty(appVersion: String): PropDecl {
    // 创建包含实际值的字符串字面量token（不需要手动添加引号）
    let versionToken = Token(TokenKind.STRING_LITERAL, appVersion)
    
    let propertyTokens = quote(
        public override prop version: String { get() { $(Tokens([versionToken])) } }
    )
    
    return PropDecl(propertyTokens)
}

/**
 * 创建description属性
 * 参考文档：
 * - markit/libs/cangjie_runtime-dev/stdlib/doc/libs/std_en/ast/ast_package_api/ast_package_classes.md - PropDecl API
 */
func createDescriptionProperty(appDescription: String): PropDecl {
    // 创建包含实际值的字符串字面量token（不需要手动添加引号）
    let descriptionToken = Token(TokenKind.STRING_LITERAL, appDescription)
    
    let propertyTokens = quote(
        public override prop description: String { get() { $(Tokens([descriptionToken])) } }
    )
    
    return PropDecl(propertyTokens)
}

/**
 * 自动添加CLI接口继承
 * 如果类没有继承CLI接口，则自动添加
 * 
 * 参考文档：
 * - markit/libs/dev-guide/source_en/class_and_interface/interface.md - 接口实现语法
 * - markit/libs/cangjie_runtime-dev/stdlib/doc/libs/std_en/ast/ast_package_api/ast_package_classes.md - ClassDecl API
 * 
 * @param classDecl 类声明AST节点
 */
func addCLIInterfaceInheritance(classDecl: ClassDecl): Unit {
    // 检查是否已经继承了CLI接口
    var hasCLIInterface = false
    for (superType in classDecl.superTypes) {
        if (superType.toTokens().toString().contains("CLI")) {
            hasCLIInterface = true
            break
        }
    }
    
    // 如果没有继承CLI接口，则添加
    if (!hasCLIInterface) {
        // 创建CLI接口类型节点
        let cliTypeTokens = quote(CLI)
        let cliTypeNode = parseType(cliTypeTokens)
        
        // 如果没有父类型，设置upperBound操作符
        if (classDecl.superTypes.size == 0) {
            let upperBoundTokens = quote(<:)
            classDecl.upperBound = upperBoundTokens[0]
        } else {
            // 如果已有父类型，添加&操作符
            classDecl.superTypeBitAnds = classDecl.superTypeBitAnds + quote(&)
        }
        
        // 添加CLI接口到父类型列表
        classDecl.superTypes.add(cliTypeNode)
    }
}
