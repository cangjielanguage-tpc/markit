package markit_kit.utils

import std.env.getVariable
import std.deriving.*

/**
 * 操作系统类型枚举
 */
@Derive[Equatable]
public enum OSType {
    | Linux
    | MacOS
    | Windows
    | Unknown
}

/**
 * 平台工具类
 * 提供跨平台的命令执行支持
 */
public class PlatformUtils {
    
    /**
     * 获取当前操作系统类型
     */
    public static func getOSType(): OSType {
        // 通过环境变量检测操作系统
        if (let Some(os) <- getVariable("OS")) {
            let osLower = os.toAsciiLower()
            if (osLower.contains("windows")) {
                return OSType.Windows
            }
        }
        
        // 检查 OSTYPE 环境变量
        if (let Some(ostype) <- getVariable("OSTYPE")) {
            let ostypeLower = ostype.toAsciiLower()
            if (ostypeLower.contains("linux")) {
                return OSType.Linux
            } else if (ostypeLower.contains("darwin")) {
                return OSType.MacOS
            }
        }
        
        // 检查其他可能的环境变量
        if (let Some(platform) <- getVariable("PLATFORM")) {
            let platformLower = platform.toAsciiLower()
            if (platformLower.contains("linux")) {
                return OSType.Linux
            } else if (platformLower.contains("darwin") || platformLower.contains("macos")) {
                return OSType.MacOS
            } else if (platformLower.contains("windows")) {
                return OSType.Windows
            }
        }
        
        return OSType.Unknown
    }
    
    /**
     * 检查是否为 Windows 系统
     */
    public static func isWindows(): Bool {
        return getOSType() == OSType.Windows
    }
}
