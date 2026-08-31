package markit_kit.utils

import std.fs.{Path, canonicalize}
import std.collection.ArrayList

/**
 * 路径工具类
 * 提供多语言构建中的路径计算功能
 */
public class PathUtils {
    public static func isRelativeLocalPath(path: String): Bool {
        if (path.isEmpty() ||
            path.startsWith("/") ||
            path.startsWith("#") ||
            path.startsWith("data:") ||
            path.startsWith("http://") ||
            path.startsWith("https://") ||
            path.startsWith("file://")) {
            return false
        }
        return true
    }

    public static func stripLeadingRelativeSegments(path: String): String {
        var normalizedPath = path.replace("\\", "/")
        while (normalizedPath.startsWith("./")) {
            normalizedPath = normalizedPath[2..]
        }
        while (normalizedPath.startsWith("../")) {
            normalizedPath = normalizedPath[3..]
        }
        return normalizedPath
    }

    /**
     * 规范化路径：去掉 ../ 前缀和对应数量的目录层
     * 
     * 例如：
     *   ../docs/getting-started/quick-start.md -> getting-started/quick-start.md
     *   ../../some/docs/getting-started/quick-start.md -> getting-started/quick-start.md
     *   docs/README.md -> docs/README.md (不变)
     * 
     * @param path 原始路径
     * @return 规范化后的路径
     */
    public static func normalizePath(path: String): String {
        var normalizedPath = path.replace("\\", "/")

        if (!normalizedPath.startsWith("../")) {
            return normalizedPath
        }

        // 去掉所有前导的 ../ ，保留剩余路径
        while (normalizedPath.startsWith("../")) {
            normalizedPath = normalizedPath[3..]
        }

        return normalizedPath
    }
    
    /**
     * 计算从 fromPath 到 toPath 的相对路径
     * 
     * @param fromPath 起始路径（如 "README.html"）
     * @param toPath 目标路径（如 "getting-started/quick-start.html"）
     * @return 相对路径（如 "getting-started/quick-start.html" 或 "../README.html"）
     */
    public static func calculateRelativePath(fromPath: String, toPath: String): String {
        // 如果 fromPath 为空，直接返回 toPath
        if (fromPath.isEmpty()) {
            return toPath
        }
        
        // 规范化路径分隔符
        let normalizedFromPath = fromPath.replace("\\", "/")
        let normalizedToPath = toPath.replace("\\", "/")
        
        // 分割路径
        let fromParts = normalizedFromPath.split("/")
        let toParts = normalizedToPath.split("/")
        
        // 找到共同前缀的长度（不包括文件名）
        var commonLength = 0
        let minLength = if (fromParts.size - 1 < toParts.size - 1) { 
            fromParts.size - 1 
        } else { 
            toParts.size - 1 
        }
        
        for (i in 0..minLength) {
            if (fromParts[i] == toParts[i]) {
                commonLength += 1
            } else {
                break
            }
        }
        
        // 计算需要向上的层数（fromPath 的目录深度减去共同前缀）
        let upLevels = (fromParts.size - 1) - commonLength
        
        // 构建相对路径
        var relativePath = ""
        for (_ in 0..upLevels) {
            relativePath += "../"
        }
        
        // 添加 toPath 中非共同前缀的部分
        for (i in commonLength..toParts.size) {
            if (i > commonLength) {
                relativePath += "/"
            }
            relativePath += toParts[i]
        }
        
        return relativePath
    }

    public static func resolveRelativeDocumentPath(currentPath: String, targetPath: String): String {
        let normalizedCurrentPath = currentPath.replace("\\", "/")
        let normalizedTargetPath = targetPath.replace("\\", "/")
        if (normalizedCurrentPath.isEmpty()) {
            return Path(normalizedTargetPath).normalize().toString().replace("\\", "/")
        }
        let currentDir = Path(normalizedCurrentPath).parent
        if (currentDir.isEmpty()) {
            return Path(normalizedTargetPath).normalize().toString().replace("\\", "/")
        }
        return currentDir.join(normalizedTargetPath).normalize().toString().replace("\\", "/")
    }

    public static func rebaseRelativeDocumentPath(path: String, fromPath: String, toPath: String): String {
        let resolvedPath = resolveRelativeDocumentPath(fromPath, path)
        return calculateRelativePath(toPath, resolvedPath).replace("\\", "/")
    }

    public static func shiftPathToParent(path: String, levels!: Int64 = 1): String {
        var prefix = ""
        for (_ in 0..levels) {
            prefix += "../"
        }
        return prefix + path.replace("\\", "/")
    }
    
    /**
     * 计算语言目录内的相对路径
     * 用于访问同一语言目录下的资源（如 JS 文件、其他页面）
     * 
     * @param relativePath 到根目录的相对路径（如 "../" 或 "../../"）
     * @return 到语言目录的相对路径（如 "" 或 "../"）
     * 
     * 示例：
     * - relativePath = "../" → 在语言根目录 → 返回 ""
     * - relativePath = "../../" → 在子目录 → 返回 "../"
     * - relativePath = "../../../" → 在子子目录 → 返回 "../../"
     */
    public static func calculateLanguageDirRelativePath(relativePath: String): String {
        // relativePath 中 "../" 的数量 - 1 就是到语言目录的层级
        if (relativePath.isEmpty()) {
            return ""
        }
        
        let depth = relativePath.split("../").size - 1
        if (depth <= 1) {
            return ""
        }
        
        var jsPath = ""
        for (_ in 0..(depth - 1)) {
            jsPath += "../"
        }
        return jsPath
    }
    
    /**
     * 获取文件相对于基础路径的相对路径（使用 canonicalize）
     * 
     * @param filePath 文件路径
     * @param basePath 基础路径
     * @return 相对路径
     */
    public static func getRelativePathFromBase(filePath: String, basePath: String): String {
        // 使用canonicalize将两个路径都转换为绝对路径
        let canonicalFilePath = canonicalize(filePath).toString()
        let canonicalBasePath = canonicalize(basePath).toString()
        
        // 规范化路径
        let normalizedFilePath = canonicalFilePath.replace("\\", "/")
        let normalizedBasePath = canonicalBasePath.replace("\\", "/").trimEnd("/")
        
        // 如果文件路径包含基础路径
        if (normalizedFilePath.startsWith(normalizedBasePath)) {
            var relativePath = normalizedFilePath[normalizedBasePath.size..]
            // 移除开头的斜杠
            if (relativePath.startsWith("/")) {
                relativePath = relativePath[1..]
            }
            return relativePath
        }
        
        // 如果文件不在基础路径下，计算真正的相对路径
        // 将路径分割成部分
        let fileParts = normalizedFilePath.split("/")
        let baseParts = normalizedBasePath.split("/")
        
        // 找到共同的前缀长度
        var commonLength = 0
        let minLength = if (fileParts.size < baseParts.size) { fileParts.size } else { baseParts.size }
        for (i in 0..minLength) {
            if (fileParts[i] == baseParts[i]) {
                commonLength += 1
            } else {
                break
            }
        }
        
        // 计算需要向上的层数
        let upLevels = baseParts.size - commonLength
        
        // 构建相对路径
        var relativePath = ""
        for (_ in 0..upLevels) {
            relativePath += "../"
        }
        
        // 添加文件路径的剩余部分
        for (i in commonLength..fileParts.size) {
            if (i > commonLength) {
                relativePath += "/"
            }
            relativePath += fileParts[i]
        }
        
        return relativePath
    }
}
