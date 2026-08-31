package commandline.utils

/* cjlint-ignore -start !G.PKG.01 */
import std.ast.*
/* cjlint-ignore -end */
import std.collection.ArrayList
import commandline.model.AnnotationParameter

/* cjlint-ignore -start !G.FUN.01 */

/**
 * 宏辅助工具类
 * 提供注解参数解析和数据结构处理功能
 * 
 * 参考文档：markit/libs/dev-guide/source_en/Macro/macro_introduction.md
 */

/**
 * 解析注解参数
 * 从注解的Tokens中提取参数信息
 * 
 * @param attrTokens 注解的Token序列
 * @return 解析后的参数映射
 */
public func parseAnnotationParameters(attrTokens: Tokens): Array<AnnotationParameter> {
    let parameters = ArrayList<AnnotationParameter>()
    
    // 将Tokens转换为字符串进行简单解析
    let tokenStr = attrTokens.toString()
    
    // 首先检查是否有位置参数（以 [ 开头的数组）
    if (tokenStr.startsWith("[")) {
        match (tokenStr.indexOf("]")) {
            case Some(endIdx) => 
                let arrayValue = tokenStr[0..(endIdx + 1)]
                parameters.add(AnnotationParameter(
                    name: "",  // 位置参数没有名称
                    value: arrayValue,
                    isArray: true
                ))
            case None => 
                // 没有找到结束括号，忽略
                let _ = 0
        }
    }
    
    // 简化的参数解析逻辑
    // 这里实现基本的参数提取，支持数组和字符串参数
    if (tokenStr.contains("name:")) {
        let nameValue = extractParameterValue(tokenStr, "name")
        parameters.add(AnnotationParameter(
            name: "name",
            value: nameValue,
            isArray: false
        ))
    }
    
    if (tokenStr.contains("version:")) {
        let versionValue = extractParameterValue(tokenStr, "version")
        parameters.add(AnnotationParameter(
            name: "version",
            value: versionValue,
            isArray: false
        ))
    }
    
    if (tokenStr.contains("description:")) {
        let descriptionValue = extractParameterValue(tokenStr, "description")
        parameters.add(AnnotationParameter(
            name: "description",
            value: descriptionValue,
            isArray: false
        ))
    }
    
    if (tokenStr.contains("command:")) {
        let commandValue = extractParameterValue(tokenStr, "command")
        let isArrayParam = commandValue.startsWith("[") && commandValue.endsWith("]")
        parameters.add(AnnotationParameter(
            name: "command",
            value: commandValue,
            isArray: isArrayParam
        ))
    }
    
    if (tokenStr.contains("required:")) {
        let requiredValue = extractParameterValue(tokenStr, "required")
        parameters.add(AnnotationParameter(
            name: "required",
            value: requiredValue,
            isArray: false
        ))
    }
    
    if (tokenStr.contains("help:")) {
        let helpValue = extractParameterValue(tokenStr, "help")
        parameters.add(AnnotationParameter(
            name: "help",
            value: helpValue,
            isArray: false
        ))
    }
    
    if (tokenStr.contains("description:")) {
        let descriptionValue = extractParameterValue(tokenStr, "description")
        parameters.add(AnnotationParameter(
            name: "description",
            value: descriptionValue,
            isArray: false
        ))
    }
    
    if (tokenStr.contains("usage:")) {
        let usageValue = extractParameterValue(tokenStr, "usage")
        parameters.add(AnnotationParameter(
            name: "usage",
            value: usageValue,
            isArray: false
        ))
    }
    
    return parameters.toArray()
}
/* cjlint-ignore -end */

/**
 * 从参数字符串中提取指定参数的值
 * 
 * @param tokenStr 完整的参数字符串
 * @param paramName 参数名称
 * @return 参数值
 */
public func extractParameterValue(tokenStr: String, paramName: String): String {
    // 简化的参数值提取逻辑
    let startPattern = paramName + ":"
    match (tokenStr.indexOf(startPattern)) {
        case Some(startIndex) => 
            let valueStart = startIndex + startPattern.size
            var remaining = tokenStr[valueStart..]
            
            // 跳过空格
            remaining = remaining.trimAscii()
            
            // 处理数组参数 [...]
            if (remaining.startsWith("[")) {
                match (remaining.indexOf("]")) {
                    case Some(endIdx) => return remaining[0..(endIdx + 1)]
                    case None => return ""
                }
            }
            
            // 处理字符串参数 "..."
            if (remaining.startsWith("\"")) {
                match (remaining.indexOf("\"", 1)) {
                    case Some(endIdx) => return remaining[0..(endIdx + 1)]
                    case None => return ""
                }
            }
            
            // 处理布尔参数
            if (remaining.startsWith("true")) {
                return "true"
            }
            if (remaining.startsWith("false")) {
                return "false"
            }
            
            return ""
        case None => return ""
    }
}

/**
 * 获取字符串参数值
 * 
 * @param params 参数数组
 * @param name 参数名称
 * @param defaultValue 默认值
 * @return 参数值
 */
public func getStringParam(params: Array<AnnotationParameter>, name: String, defaultValue: String): String {
    for (param in params) {
        if (param.name == name && !param.isArray) {
            // 移除引号
            let value = param.value
            if (value.startsWith("\"") && value.endsWith("\"") && value.size >= 2) {
                return value[1..(value.size - 1)]
            }
            return value
        }
    }
    return defaultValue
}

/**
 * 获取布尔参数值
 * 
 * @param params 参数数组
 * @param name 参数名称
 * @param defaultValue 默认值
 * @return 参数值
 */
public func getBoolParam(params: Array<AnnotationParameter>, name: String, defaultValue: Bool): Bool {
    for (param in params) {
        if (param.name == name && !param.isArray) {
            if (param.value == "true") {
                return true
            } else if (param.value == "false") {
                return false
            } else {
                // 无效值，返回默认值
                return defaultValue
            }
        }
    }
    return defaultValue
}

/**
 * 获取数组参数值
 * 
 * @param params 参数数组
 * @param name 参数名称
 * @param defaultValue 默认值
 * @return 参数值数组
 */
public func getArrayParam(params: Array<AnnotationParameter>, name: String, defaultValue: Array<String>): Array<String> {
    for (param in params) {
        if (param.name == name && param.isArray) {
            return parseArrayValue(param.value)
        }
    }
    return defaultValue
}

/**
 * 解析数组值字符串
 * 将 ["item1", "item2"] 格式的字符串解析为数组
 * 
 * @param arrayStr 数组字符串
 * @return 解析后的字符串数组
 */
func parseArrayValue(arrayStr: String): Array<String> {
    let result = ArrayList<String>()
    
    // 移除方括号
    var content = arrayStr
    if (content.startsWith("[") && content.endsWith("]") && content.size >= 2) {
        content = content[1..(content.size - 1)]
    }
    
    // 简单的逗号分割解析
    let items = content.split(",")
    for (item in items) {
        var trimmed = item.trimAscii()
        
        // 移除引号
        if (trimmed.startsWith("\"") && trimmed.endsWith("\"") && trimmed.size >= 2) {
            trimmed = trimmed[1..(trimmed.size - 1)]
        }
        if (!trimmed.isEmpty()) {
            result.add(trimmed)
        }
    }
    
    return result.toArray()
}

/**
 * 从变量声明中提取默认值
 * 
 * @param varDecl 变量声明节点
 * @return 默认值（如果存在）
 */
public func extractDefaultValue(varDecl: VarDecl): ?String {
    try {
        let expr = varDecl.expr
        // 简化的默认值提取
        return Some(expr.toTokens().toString())
    } catch (e: ASTException) {
        return None
    }
}

/**
 * 获取变量声明的标识符Token
 * 
 * @param varDecl 变量声明节点
 * @return 标识符Token
 */
public func getVarDeclIdentifier(varDecl: VarDecl): Token {
    try {
        let pattern = varDecl.pattern
        // 尝试将pattern转换为VarPattern以获取标识符
        if (let varPattern: VarPattern <- pattern) {
            return varPattern.identifier
        } else {
            // 如果不是VarPattern，返回默认Token
            return Token(TokenKind.IDENTIFIER, "unknown")
        }
    } catch (e: ASTException) {
        return Token(TokenKind.IDENTIFIER, "unknown")
    }
}

/**
 * 获取类声明的标识符Token
 * 
 * @param classDecl 类声明节点
 * @return 标识符Token
 */
public func getClassDeclIdentifier(classDecl: ClassDecl): Token {
    try {
        return classDecl.identifier
    } catch (e: ASTException) {
        return Token(TokenKind.IDENTIFIER, "UnknownClass")
    }
}