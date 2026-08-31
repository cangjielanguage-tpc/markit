package commandline.interfaces

import commandline.exceptions.NotImplementedException

/**
 * 统一的命令接口
 * 所有CLI命令都必须实现此接口
 * 集成了参数存储和解析功能，简化API使用
 * 使用Array和tuple实现，避免复杂的import依赖
 * 
 * 参考文档：markit/libs/dev-guide/source_en/class_and_interface/class.md
 * 验证需求：1.1, 1.2, 1.3
 */
public interface Command {
    /**
     * 参数存储 - 使用Array<(String, String)>存储所有参数
     * 由@Cmd宏生成具体实现
     */
    mut prop _paramStore: Array<(String, String)>
    
    /**
     * 选项名称映射 - 映射选项名称到字段名，使用Array<(String, String)>
     * 由@Cmd宏生成具体实现
     */
    mut prop _nameMap: Array<(String, String)>
    
    /**
     * 执行命令的核心方法
     * 命令应该在内部处理所有输出，包括打印结果
     * @return 退出码，0表示成功，非0表示失败
     * @throws NotImplementedException 当子类未实现此方法时抛出
     */
    func execute(): Int { 
        throw NotImplementedException("not implemented")
    }
    
    /**
     * 检查是否为指定命令名称
     * 提供默认实现，@Cmd宏会通过扩展覆盖此实现
     * @param commandName 要检查的命令名称
     * @return 如果匹配返回true，否则返回false
     * @throws NotImplementedException 当方法未被@Cmd宏实现时抛出
     */
    func isCommand(commandName: String): Bool { 
        throw NotImplementedException("${commandName} not implemented")
    }
    
    /**
     * 获取命令的required属性
     * 默认返回false，子类可以重写
     * @return required属性值
     * @throws NotImplementedException 当属性未被@Cmd宏实现时抛出
     */
    prop required: Bool { 
        /**
         * @throws NotImplementedException 当属性未被@Cmd宏实现时抛出
         */
        get() { throw NotImplementedException("not implemented") } 
    }
    
    /**
     * 获取命令名称（主要名称）
     * @Cmd宏会生成具体的实现
     * @return 命令名称字符串
     * @throws NotImplementedException 当属性未被@Cmd宏实现时抛出
     */
    prop commandName: String { 
        /**
         * @throws NotImplementedException 当属性未被@Cmd宏实现时抛出
         */
        get() { throw NotImplementedException("commandName not implemented") } 
    }
    
    /**
     * 获取命令描述
     * @Cmd宏会生成具体的实现
     * @return 命令描述字符串
     * @throws NotImplementedException 当方法未被@Cmd宏实现时抛出
     */
    func getDescription(): String {
        throw NotImplementedException("getDescription not implemented")
    }
    
    /**
     * 获取命令用法说明
     * @Cmd宏会生成具体的实现
     * @return 用法说明字符串
     * @throws NotImplementedException 当方法未被@Cmd宏实现时抛出
     */
    func getUsage(): String {
        throw NotImplementedException("getUsage not implemented")
    }
    
    /**
     * 获取命令的所有选项帮助信息
     * @Cmd宏会生成具体的实现
     * @return 选项帮助信息字符串
     * @throws NotImplementedException 当方法未被@Cmd宏实现时抛出
     */
    func getOptionsHelp(): String {
        throw NotImplementedException("getOptionsHelp not implemented")
    }
    
    /**
     * 设置命令行参数
     * 用于在运行时动态设置参数
     * @param args 命令行参数数组
     * @throws NotImplementedException 当方法未被@Cmd宏实现时抛出
     */
    func setArgs(_: Array<String>): Unit {
        throw NotImplementedException("setArgs not implemented")
    }
    
    /**
     * 设置CLI应用程序引用
     * 用于访问所有注册的命令和应用程序信息
     * @param cli CLI应用程序实例
     * @throws NotImplementedException 当方法未被@Cmd宏实现时抛出
     */
    func setCLI(_: CLI): Unit {
        throw NotImplementedException("setCLI not implemented")
    }
    
    /**
     * 注册选项名称数组到字段名的映射
     * @param names 选项名称数组
     * @param fieldName 对应的字段名
     */
    func registerOptionNames(names: Array<String>, fieldName: String): Unit {
        let newMappings = names.map { name: String => (name, fieldName) }
        var result = Array<(String, String)>(_nameMap.size + newMappings.size, repeat: ("", ""))
        
        // 复制现有映射
        for (i in 0.._nameMap.size) {
            result[i] = _nameMap[i]
        }
        
        // 添加新映射
        for (i in 0..newMappings.size) {
            result[_nameMap.size + i] = newMappings[i]
        }
        
        _nameMap = result
    }
    
    /**
     * 根据选项名称获取字段名
     * @param optionName 选项名称
     * @return 对应的字段名，如果不存在返回None
     */
    func getFieldNameForOption(optionName: String): ?String {
        let matches = _nameMap.filter { pair: (String, String) => pair[0] == optionName }
        return if (matches.size > 0) { Some(matches[0][1]) } else { None }
    }
    
    /**
     * 获取所有已注册的选项名称
     * @return 所有选项名称的数组
     */
    func getAllRegisteredOptions(): Array<String> {
        return _nameMap.map { pair: (String, String) => pair[0] }
    }
    
    /**
     * 设置参数值到内部存储
     * @param key 参数键
     * @param value 参数值
     */
    func setParameter(key: String, value: String): Unit {
        // 先移除已存在的key
        let filtered = _paramStore.filter { pair: (String, String) => pair[0] != key }
        
        // 创建新数组包含过滤后的数据和新键值对
        var result = Array<(String, String)>(filtered.size + 1, repeat: ("", ""))
        
        // 复制过滤后的数据
        for (i in 0..filtered.size) {
            result[i] = filtered[i]
        }
        
        // 添加新键值对
        result[filtered.size] = (key, value)
        
        _paramStore = result
    }
    
    /**
     * 从内部存储获取参数值
     * @param key 参数键
     * @return 参数值，如果不存在返回None
     */
    func getParameter(key: String): ?String {
        let matches = _paramStore.filter { pair: (String, String) => pair[0] == key }
        return if (matches.size > 0) { Some(matches[0][1]) } else { None }
    }
    
    /**
     * 检查参数是否存在
     * @param key 参数键
     * @return 如果存在返回true，否则返回false
     */
    func hasParameter(key: String): Bool {
        return _paramStore.any { pair: (String, String) => pair[0] == key }
    }
    
    /**
     * 解析命令行参数并存储到内部存储
     * 静态方法，可以被任何Command实现使用
     * @param args 命令行参数数组
     * @param command 命令实例
     */
    static func parseArguments(args: Array<String>, command: Command): Unit {
        var i = 0
        while (i < args.size) {
            let arg = args[i]
            
            if (arg.startsWith("--") || arg.startsWith("-")) {
                // 处理选项参数
                match (command.getFieldNameForOption(arg)) {
                    case Some(fieldName) => 
                        // 检查是否有值跟随
                        if (i + 1 < args.size && !args[i + 1].startsWith("-")) {
                            // 有值的选项
                            command.setParameter(fieldName, args[i + 1])
                            i += 2  // 跳过选项和值
                        } else {
                            // 布尔选项或标志选项，设置为"true"
                            command.setParameter(fieldName, "true")
                            i += 1
                        }
                    case None => 
                        // 未知选项，跳过
                        i += 1
                }
            } else {
                // 位置参数，暂时跳过
                // 未来可以扩展支持位置参数
                i += 1
            }
        }
    }
}