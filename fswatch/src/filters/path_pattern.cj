package fswatch.filters

/* cjlint-ignore -start !G.OPR.01 !G.CHK.04 */
import std.regex.Regex
import std.fs.Path

/**
 * 模式类型枚举
 */
public enum PatternType {
    | Wildcard    // 通配符模式 (*, ?, **)
    | Regex       // 正则表达式模式
    | Exact       // 精确匹配
    | Extension   // 文件扩展名匹配
    | Prefix      // 前缀匹配
    | Suffix      // 后缀匹配
    
    /**
     * 相等性比较
     */
    public operator func ==(other: PatternType): Bool {
        match ((this, other)) {
            case (Wildcard, Wildcard) => true
            case (Regex, Regex) => true
            case (Exact, Exact) => true
            case (Extension, Extension) => true
            case (Prefix, Prefix) => true
            case (Suffix, Suffix) => true
            case _ => false
        }
    }
}

/**
 * 路径模式匹配器
 * 
 * 提供灵活的路径匹配功能，支持通配符、正则表达式等多种匹配方式。
 */
public class PathPattern {
    private let pattern: String
    private let patternType: PatternType
    private let caseSensitive: Bool
    private var regexPattern: ?Regex
    
    /**
     * 构造函数
     */
    public init(
        pattern: String,
        patternType: PatternType,
        caseSensitive: Bool
    ) {
        this.pattern = pattern
        this.patternType = patternType
        this.caseSensitive = caseSensitive
        this.regexPattern = None  // Initialize first
        
        // 如果是正则表达式模式，预编译正则表达式
        if (patternType == PatternType.Regex) {
            this.regexPattern = tryCompileRegex(pattern)
        }
    }
    
    private func tryCompileRegex(pattern: String): Option<Regex> {
        try {
            Some(Regex(pattern))
        } catch (_: Exception) {
            None
        }
    }
    
    /**
     * 检查路径是否匹配模式
     */
    public func matches(path: Path): Bool {
        let pathStr = if (caseSensitive) {
            path.toString()
        } else {
            path.toString().toAsciiLower()
        }
        
        let patternStr = if (caseSensitive) {
            pattern
        } else {
            pattern.toAsciiLower()
        }
        
        match (patternType) {
            case PatternType.Exact => pathStr == patternStr
            case PatternType.Prefix => pathStr.startsWith(patternStr)
            case PatternType.Suffix => pathStr.endsWith(patternStr)
            case PatternType.Extension => matchExtension(pathStr, patternStr)
            case PatternType.Wildcard => matchWildcard(pathStr, patternStr)
            case PatternType.Regex => matchRegex(pathStr)
        }
    }
    
    /**
     * 匹配文件扩展名
     */
    private func matchExtension(pathStr: String, ext: String): Bool {
        let cleanExt = if (ext.startsWith(".")) { ext } else { ".${ext}" }
        return pathStr.endsWith(cleanExt)
    }
    
    /**
     * 通配符匹配
     */
    private func matchWildcard(pathStr: String, patternStr: String): Bool {
        // 简化的通配符实现
        if (patternStr == "*") {
            return true
        }
        
        if (patternStr == "**") {
            return true  // 匹配任何路径，包括子目录
        }
        
        if (patternStr.startsWith("*.")) {
            let ext = patternStr[1..]
            return pathStr.endsWith(ext)
        }
        
        if (patternStr.endsWith("*")) {
            let prefix = patternStr[0..patternStr.size - 1]
            return pathStr.startsWith(prefix)
        }
        
        if (patternStr.startsWith("*")) {
            let suffix = patternStr[1..]
            return pathStr.endsWith(suffix)
        }
        
        // 包含通配符的复杂模式
        if (patternStr.contains("*") || patternStr.contains("?")) {
            return matchComplexWildcard(pathStr, patternStr)
        }
        
        return pathStr == patternStr
    }
    
    /**
     * 复杂通配符匹配（支持 * 和 ?）
     */
    private func matchComplexWildcard(text: String, pattern: String): Bool {
        let textLen = text.size
        let patternLen = pattern.size
        
        // 动态规划实现通配符匹配
        let dp = Array<Array<Bool>>(textLen + 1, repeat: Array<Bool>(patternLen + 1, repeat: false))
        dp[0][0] = true
        
        // 处理模式开头的 * 
        for (j in 1..patternLen) {
            if (Rune(pattern[j - 1]) == r'*') {
                dp[0][j] = dp[0][j - 1]
            }
        }
        
        for (i in 1..textLen) {
            for (j in 1..patternLen) {
                if (Rune(pattern[j - 1]) == r'*') {
                    dp[i][j] = dp[i - 1][j] || dp[i][j - 1]
                } else if (Rune(pattern[j - 1]) == r'?' || text[i - 1] == pattern[j - 1]) {
                    dp[i][j] = dp[i - 1][j - 1]
                }
            }
        }
        
        return dp[textLen][patternLen]
    }
    
    /**
     * 正则表达式匹配
     */
    private func matchRegex(pathStr: String): Bool {
        match (regexPattern) {
            case Some(r) => r.matches(pathStr)
            case None => false
        }
    }
    
    /**
     * 获取模式字符串
     */
    public func getPattern(): String {
        return pattern
    }
    
    /**
     * 获取模式类型
     */
    public func getPatternType(): PatternType {
        return patternType
    }
    
    /**
     * 是否大小写敏感
     */
    public func isCaseSensitive(): Bool {
        return caseSensitive
    }
    
    /**
     * 创建通配符模式
     */
    public static func wildcard(pattern: String, caseSensitive: Bool): PathPattern {
        return PathPattern(pattern, PatternType.Wildcard, caseSensitive)
    }
    
    /**
     * 创建正则表达式模式
     */
    public static func regex(pattern: String, caseSensitive: Bool): PathPattern {
        return PathPattern(pattern, PatternType.Regex, caseSensitive)
    }
    
    /**
     * 创建扩展名模式
     */
    public static func extension(ext: String, caseSensitive: Bool): PathPattern {
        return PathPattern(ext, PatternType.Extension, caseSensitive)
    }
    
    /**
     * 创建前缀模式
     */
    public static func prefix(prefix: String, caseSensitive: Bool): PathPattern {
        return PathPattern(prefix, PatternType.Prefix, caseSensitive)
    }
    
    /**
     * 创建后缀模式
     */
    public static func suffix(suffix: String, caseSensitive: Bool): PathPattern {
        return PathPattern(suffix, PatternType.Suffix, caseSensitive)
    }
}
/* cjlint-ignore -end */