package dochir_example.plugin.manager

import dochir_example.chir.*
import std.collection.ArrayList

/**
 * @description Base class shared by all compiler plugin types.
 * @description-zh 所有编译器插件类型共享的基类。
 * @param name Human-readable plugin name.
 * @param-zh name 人类可读的插件名称。
 */
sealed abstract class PluginBase {
    /**
     * @description Stored plugin name.
     * @description-zh 存储的插件名称。
     * @type { String }
     */
    internal let _name: String

    internal init(name: String) {
        this._name = name
    }

    /**
     * @description Plugin display name used in diagnostics.
     * @description-zh 诊断信息中使用的插件显示名称。
     * @type { String }
     */
    public prop name: String {
        get() {
            return _name
        }
    }
}

/**
 * @description Base class for CHIR compiler plugins.
 * @description-zh CHIR 编译器插件的基类。
 * @param name Human-readable plugin name.
 * @param-zh name 人类可读的插件名称。
 */
public abstract class CHIRPluginBase <: PluginBase {
    public init(name: String) {
        super(name)
    }

    /**
     * @description Executes the plugin for one CHIR package.
     * @description-zh 对一个 CHIR 包执行插件逻辑。
     * @param pkg Package to inspect or transform.
     * @param-zh pkg 要检查或转换的包。
     * @return true when plugin execution succeeds.
     * @return-zh 插件执行成功时返回 true。
     */
    public open func run(pkg: Package): Bool
}

/**
 * @description Stores registered CHIR plugin factories.
 * @description-zh 保存已注册的 CHIR 插件工厂。
 */
public class PluginManager {
    internal static let chirPlugins = ArrayList<() -> CHIRPluginBase>()

    /**
     * @description Registers a factory that creates one CHIR plugin instance.
     * @description-zh 注册一个用于创建 CHIR 插件实例的工厂。
     * @param f Factory returning a fresh plugin instance.
     * @param-zh f 返回新插件实例的工厂函数。
     * @return Unit after the factory is registered.
     * @return-zh 工厂注册完成后返回 Unit。
     */
    public static func registerCHIRPlugin(f: () -> CHIRPluginBase): Unit {
        chirPlugins.add(f)
    }
}

/**
 * @description Result returned by the CHIR plugin ABI entry point.
 * @description-zh CHIR 插件 ABI 入口返回的结果。
 * @param data Pointer to serialized package data returned to the compiler.
 * @param-zh data 返回给编译器的序列化包数据指针。
 * @param length Length of serialized package data in bytes.
 * @param-zh length 序列化包数据的字节长度。
 * @param success Whether every registered plugin completed successfully.
 * @param-zh success 所有已注册插件是否都执行成功。
 */
public struct PluginResult {
    /**
     * @description Pointer to serialized package data returned to the compiler.
     * @description-zh 返回给编译器的序列化包数据指针。
     * @type { CPointer<UInt8> }
     */
    public let data: CPointer<UInt8>

    /**
     * @description Length of serialized package data in bytes.
     * @description-zh 序列化包数据的字节长度。
     * @type { Int64 }
     */
    public let length: Int64

    /**
     * @description Whether every registered plugin completed successfully.
     * @description-zh 所有已注册插件是否都执行成功。
     * @type { Bool }
     */
    public let success: Bool

    public init(data: CPointer<UInt8>, length: Int64, success: Bool) {
        this.data = data
        this.length = length
        this.success = success
    }
}

/**
 * @description Executes registered CHIR plugins over serialized package data.
 * @description-zh 基于序列化包数据执行已注册的 CHIR 插件。
 * @param data Pointer to compiler-provided serialized package data.
 * @param-zh data 编译器提供的序列化包数据指针。
 * @param length Length of compiler-provided serialized package data in bytes.
 * @param-zh length 编译器提供的序列化包数据字节长度。
 * @return Serialized package data and execution status.
 * @return-zh 序列化包数据和执行状态。
 */
public func executeCHIRPlugins(data: CPointer<UInt8>, length: Int64): PluginResult {
    let pkg = deserializePackage(data, length)
    var success = true
    for (factory in PluginManager.chirPlugins) {
        success = factory().run(pkg) && success
    }
    let (resultData, resultLength) = serializePackage(pkg)
    return PluginResult(resultData, resultLength, success)
}
