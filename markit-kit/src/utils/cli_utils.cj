package markit_kit.utils

import std.convert.Parsable

/**
 * CLI 工具函数
 */
public class CliUtils {
    
    /**
     * 解析并发任务数参数
     * 
     * @param jobsStr 并发任务数字符串
     * @return 解析后的并发任务数（失败时返回 1）
     */
    public static func parseJobs(jobsStr: String): Int64 {
        try {
            let value = Int64.parse(jobsStr)
            if (value < 0) {
                KitHooks.warn("Invalid jobs value '${jobsStr}', using 1")
                return 1
            }
            return value
        } catch (e: Exception) {
            KitHooks.warn("Invalid jobs value '${jobsStr}', using 1")
            return 1
        }
    }
    
    /**
     * 解析端口号参数
     * 
     * @param portStr 端口号字符串
     * @return 解析后的端口号（失败时返回 8080）
     */
    public static func parsePort(portStr: String): Int32 {
        try {
            let value = Int64.parse(portStr)
            if (value < 1 || value > 65535) {
                KitHooks.warn("Invalid port '${portStr}', using 8080")
                return 8080
            }
            return Int32(value)
        } catch (e: Exception) {
            KitHooks.warn("Invalid port '${portStr}', using 8080")
            return 8080
        }
    }
}
