package fswatch.utils

/* cjlint-ignore -start !G.OPR.01 */
import std.env.getVariable

/**
 * 操作系统类型枚举
 */
public enum OSType <: Equatable<OSType> & ToString {
    | Linux
    | MacOS
    | Windows
    | OHOS
    | Unknown
    
    public func toString(): String {
        match (this) {
            case Linux => "Linux"
            case MacOS => "macOS"
            case Windows => "Windows"
            case OHOS => "OHOS"
            case Unknown => "Unknown"
        }
    }
    
    public operator func ==(right: OSType): Bool {
        match (this) {
            case Linux => match (right) { case Linux => true; case _ => false }
            case MacOS => match (right) { case MacOS => true; case _ => false }
            case Windows => match (right) { case Windows => true; case _ => false }
            case OHOS => match (right) { case OHOS => true; case _ => false }
            case Unknown => match (right) { case Unknown => true; case _ => false }
        }
    }
}

/**
 * 平台工具类
 * 
 * 提供平台检测和平台相关的工具函数。
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
            } else if (osLower.contains("ohos")) {
                return OSType.OHOS
            }
        }
        
        // 检查 OSTYPE 环境变量
        if (let Some(ostype) <- getVariable("OSTYPE")) {
            let ostypeLower = ostype.toAsciiLower()
            if (ostypeLower.contains("linux")) {
                return OSType.Linux
            } else if (ostypeLower.contains("darwin")) {
                return OSType.MacOS
            } else if (ostypeLower.contains("ohos")) {
                return OSType.OHOS
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
            } else if (platformLower.contains("ohos") || platformLower.contains("harmonyos")) {
                return OSType.OHOS
            }
        }
        
        // 默认基于当前平台推测（macOS）
        return OSType.MacOS
    }
    
    /**
     * 检查是否为 Linux 系统
     */
    public static func isLinux(): Bool {
        return getOSType() == OSType.Linux
    }
    
    /**
     * 检查是否为 macOS 系统
     */
    public static func isMacOS(): Bool {
        return getOSType() == OSType.MacOS
    }
    
    /**
     * 检查是否为 Windows 系统
     */
    public static func isWindows(): Bool {
        return getOSType() == OSType.Windows
    }
    
    /**
     * 检查是否为 OHOS 系统
     */
    public static func isOHOS(): Bool {
        return getOSType() == OSType.OHOS
    }
    
    /**
     * 检查是否为 Unix-like 系统
     */
    public static func isUnixLike(): Bool {
        let osType = getOSType()
        return osType == OSType.Linux || osType == OSType.MacOS || osType == OSType.OHOS
    }
    
    /**
     * 获取路径分隔符
     */
    public static func getPathSeparator(): String {
        if (isWindows()) {
            return "\\"
        } else {
            return "/"
        }
    }
    
    /**
     * 获取环境变量路径分隔符
     */
    public static func getPathListSeparator(): String {
        if (isWindows()) {
            return ";"
        } else {
            return ":"
        }
    }
    
    /**
     * 获取行分隔符
     */
    public static func getLineSeparator(): String {
        if (isWindows()) {
            return "\r\n"
        } else {
            return "\n"
        }
    }
    
    /**
     * 获取临时目录路径
     */
    public static func getTempDirectory(): String {
        if (let Some(tmpdir) <- getVariable("TMPDIR")) {
            return tmpdir
        }
        
        if (let Some(temp) <- getVariable("TEMP")) {
            return temp
        }
        
        if (let Some(tmp) <- getVariable("TMP")) {
            return tmp
        }
        
        // 默认临时目录
        if (isWindows()) {
            return "C:\\Windows\\Temp"
        } else {
            return "/tmp"
        }
    }
    
    /**
     * 获取用户主目录路径
     */
    public static func getHomeDirectory(): String {
        if (let Some(home) <- getVariable("HOME")) {
            return home
        }
        
        if (isWindows()) {
            if (let Some(userProfile) <- getVariable("USERPROFILE")) {
                return userProfile
            } else {
                return "C:\\Users\\Default"
            }
        } else {
            return "/home"
        }
    }
    
    /**
     * 检查是否支持原生文件监听
     */
    public static func supportsNativeFileWatching(): Bool {
        let osType = getOSType()
        return osType == OSType.Linux || osType == OSType.MacOS || osType == OSType.OHOS
    }
    
    /**
     * 获取推荐的原生文件监听API名称
     */
    public static func getNativeFileWatchingAPI(): String {
        match (getOSType()) {
            case OSType.Linux => "inotify"
            case OSType.MacOS => "FSEvents"
            case OSType.Windows => "polling"
            case OSType.OHOS => "inotify"
            case OSType.Unknown => "polling"
        }
    }
    
    /**
     * 获取系统信息字符串
     */
    public static func getSystemInfo(): String {
        let osType = getOSType()
        let nativeAPI = getNativeFileWatchingAPI()
        let supportsNative = supportsNativeFileWatching()
        
        return "Platform: ${osType}, Native API: ${nativeAPI}, Supports Native: ${supportsNative}"
    }
}
/* cjlint-ignore -end */
