macro package commandline.macros

/* cjlint-ignore -start !G.PKG.01 */
import std.ast.*
/* cjlint-ignore -end */
import commandline.utils.{extractDefaultValue, getArrayParam, getBoolParam, getStringParam, getVarDeclIdentifier, parseAnnotationParameters}

/**
 * @Opt宏实现
 * 处理选项字段的注解，收集元数据供@Cmd宏使用
 * 
 * 支持数组格式的选项名称，如 @Opt(["--verbose", "-v"], help: "详细输出", required: true)
 */

/**
 * @Opt宏主函数
 * 解析@Opt注解参数并收集选项字段元数据
 * 
 * @param attrTokens 注解参数的Token序列
 * @param inputTokens 被注解的代码Token序列
 * @return 原始的输入Token序列（不修改原始代码）
 */
public macro Opt(attrTokens: Tokens, inputTokens: Tokens): Tokens {
    assertParentContext("Cmd")

    // 解析注解参数
    let params = parseAnnotationParameters(attrTokens)
    
    // 提取选项名称数组和其他参数
    // 第一个参数是位置参数（选项名称数组），没有参数名
    let names = getArrayParam(params, "", ["--default"])  // 空字符串表示第一个位置参数
    let help = getStringParam(params, "help", "")
    let required = getBoolParam(params, "required", false)
    
    let varDecl = try {
        VarDecl(inputTokens)
    } catch (e: ASTException) {
        throw Exception("@Opt can only be applied to variable declarations: " + e.toString())
    }

    let fieldName = extractFieldName(varDecl)
    let fieldType = try {
        varDecl.declType.toTokens().toString()
    } catch (_ : ASTException) {
        "?String"
    }
    let defaultValue = extractDefaultValue(varDecl) ?? ""

    setItem("field_name", fieldName)
    setItem("names", joinOptionNames(names))
    setItem("help", help)
    setItem("field_type", fieldType)
    setItem("default_value", defaultValue)
    setItem("required", if (required) { "true" } else { "false" })
    
    // 返回原始字段声明（不修改）
    return inputTokens
}

/**
 * 将选项名称编码成单个字符串，供父宏恢复
 */
func joinOptionNames(names: Array<String>): String {
    if (names.size == 0) {
        return ""
    }

    let delimiter = "\u{001f}"
    var result = names[0]
    for (i in 1..names.size) {
        result += delimiter + names[i]
    }
    return result
}

func extractFieldName(varDecl: VarDecl): String {
    let identifier = getVarDeclIdentifier(varDecl).value
    if (identifier != "unknown") {
        return identifier
    }

    let declText = varDecl.toTokens().toString()
    let varIndex = declText.indexOf("var ")
    let letIndex = declText.indexOf("let ")
    let keywordIndex = match (varIndex) {
        case Some(idx) => Some(idx + 4)
        case None => match (letIndex) {
            case Some(idx) => Some(idx + 4)
            case None => None<Int64>
        }
    }

    match (keywordIndex) {
        case Some(start) =>
            let remainder = declText[start..].trimAscii()
            let colonIndex = remainder.indexOf(":")
            let assignIndex = remainder.indexOf("=")
            match (colonIndex) {
                case Some(end) => remainder[0..end].trimAscii()
                case None => match (assignIndex) {
                    case Some(end) => remainder[0..end].trimAscii()
                    case None => remainder.trimAscii()
                }
            }
        case None => "unknown"
    }
}
