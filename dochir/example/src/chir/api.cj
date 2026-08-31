package dochir_example.chir

import std.collection.ArrayList
import std.deriving.*

internal func stub<T>(): T {
    throw Exception("declaration mirror")
}

/**
 * @description Represents package-level visibility carried by CHIR definitions.
 * @description-zh 表示 CHIR 定义携带的包级可见性。
 */
@Derive[Equatable]
public enum AccessLevel <: ToString {
    /**
     * @description Package-internal visibility.
     * @description-zh 包内可见性。
     */
    | Internal
    /**
     * @description Protected visibility.
     * @description-zh 受保护可见性。
     */
    | Protected
    /**
     * @description Public visibility.
     * @description-zh 公开可见性。
     */
    | Public

    /**
     * @description Returns the source-level visibility keyword.
     * @description-zh 返回源码级可见性关键字。
     * @return Text form of the access level.
     * @return-zh 访问级别的文本形式。
     */
    public func toString(): String {
        match (this) {
            case Internal => "internal"
            case Protected => "protected"
            case Public => "public"
        }
    }
}

/**
 * @description Describes arithmetic overflow behavior attached to numeric CHIR operations.
 * @description-zh 描述数值 CHIR 操作关联的算术溢出行为。
 */
@Derive[Equatable]
public enum OverflowStrategy <: ToString {
    /**
     * @description No arithmetic overflow strategy applies.
     * @description-zh 不适用算术溢出策略。
     */
    | NA
    /**
     * @description Wraps on arithmetic overflow.
     * @description-zh 发生算术溢出时按环绕规则处理。
     */
    | Wrapping
    /**
     * @description Throws on arithmetic overflow.
     * @description-zh 发生算术溢出时抛出异常。
     */
    | Throwing
    /**
     * @description Saturates on arithmetic overflow.
     * @description-zh 发生算术溢出时按饱和规则处理。
     */
    | Saturating
    /**
     * @description Reserved for future overflow strategies.
     * @description-zh 预留给未来的溢出策略。
     */
    | ...

    /**
     * @description Returns the overflow strategy name.
     * @description-zh 返回溢出策略名称。
     * @return Text form of the overflow strategy.
     * @return-zh 溢出策略的文本形式。
     */
    public func toString(): String {
        match (this) {
            case NA => "NA"
            case Wrapping => "Wrapping"
            case Throwing => "Throwing"
            case Saturating => "Saturating"
            case _ => "Unknown"
        }
    }
}

/**
 * @description Describes unary operation kinds used by unary expressions.
 * @description-zh 描述一元表达式使用的一元操作类型。
 */
@Derive[Equatable]
public enum UnaryExprKind <: ToString {
    /**
     * @description Numeric negation operation.
     * @description-zh 数值取负操作。
     */
    | Neg
    /**
     * @description Logical negation operation.
     * @description-zh 逻辑非操作。
     */
    | Not
    /**
     * @description Bitwise complement operation.
     * @description-zh 按位取反操作。
     */
    | BitNot
    /**
     * @description Reserved for future unary operation kinds.
     * @description-zh 预留给未来的一元操作类型。
     */
    | ...

    /**
     * @description Returns the unary operation kind name.
     * @description-zh 返回一元操作类型名称。
     * @return Text form of the unary operation kind.
     * @return-zh 一元操作类型的文本形式。
     */
    public func toString(): String {
        match (this) {
            case Neg => "Neg"
            case Not => "Not"
            case BitNot => "BitNot"
            case _ => "Unknown"
        }
    }
}

/**
 * @description Describes binary operation kinds used by binary expressions.
 * @description-zh 描述二元表达式使用的二元操作类型。
 */
@Derive[Equatable]
public enum BinaryExprKind <: ToString {
    /**
     * @description Addition operation.
     * @description-zh 加法操作。
     */
    | Add
    /**
     * @description Subtraction operation.
     * @description-zh 减法操作。
     */
    | Sub
    /**
     * @description Multiplication operation.
     * @description-zh 乘法操作。
     */
    | Mul
    /**
     * @description Division operation.
     * @description-zh 除法操作。
     */
    | Div
    /**
     * @description Remainder operation.
     * @description-zh 求余操作。
     */
    | Mod
    /**
     * @description Exponentiation operation.
     * @description-zh 幂运算操作。
     */
    | Exp
    /**
     * @description Left shift operation.
     * @description-zh 左移操作。
     */
    | LShift
    /**
     * @description Right shift operation.
     * @description-zh 右移操作。
     */
    | RShift
    /**
     * @description Bitwise AND operation.
     * @description-zh 按位与操作。
     */
    | BitAnd
    /**
     * @description Bitwise OR operation.
     * @description-zh 按位或操作。
     */
    | BitOr
    /**
     * @description Bitwise XOR operation.
     * @description-zh 按位异或操作。
     */
    | BitXor
    /**
     * @description Less-than comparison.
     * @description-zh 小于比较操作。
     */
    | LT
    /**
     * @description Greater-than comparison.
     * @description-zh 大于比较操作。
     */
    | GT
    /**
     * @description Less-than-or-equal comparison.
     * @description-zh 小于等于比较操作。
     */
    | LE
    /**
     * @description Greater-than-or-equal comparison.
     * @description-zh 大于等于比较操作。
     */
    | GE
    /**
     * @description Equality comparison.
     * @description-zh 相等比较操作。
     */
    | Equal
    /**
     * @description Inequality comparison.
     * @description-zh 不等比较操作。
     */
    | NotEqual
    /**
     * @description Logical AND operation.
     * @description-zh 逻辑与操作。
     */
    | And
    /**
     * @description Logical OR operation.
     * @description-zh 逻辑或操作。
     */
    | Or
    /**
     * @description Reserved for future binary operation kinds.
     * @description-zh 预留给未来的二元操作类型。
     */
    | ...

    /**
     * @description Returns the binary operation kind name.
     * @description-zh 返回二元操作类型名称。
     * @return Text form of the binary operation kind.
     * @return-zh 二元操作类型的文本形式。
     */
    public func toString(): String {
        return "BinaryExprKind"
    }
}

/**
 * @description Controls expression traversal performed by CHIR visitors.
 * @description-zh 控制 CHIR 访问器遍历表达式时的行为。
 */
@Derive[Equatable]
public enum IRActionMode {
    /**
     * @description Continue expression traversal.
     * @description-zh 继续表达式遍历。
     */
    | Continue
    /**
     * @description Stop expression traversal.
     * @description-zh 停止表达式遍历。
     */
    | Stop
    /**
     * @description Skip traversal of the current expression's children.
     * @description-zh 跳过当前表达式的子节点遍历。
     */
    | Skip
    /**
     * @description Reserved for future expression traversal actions.
     * @description-zh 预留给未来的表达式遍历动作。
     */
    | ...
}

/**
 * @description Controls type traversal performed by type visitors.
 * @description-zh 控制类型访问器遍历类型时的行为。
 */
public enum TypeActionMode {
    /**
     * @description Continue type traversal.
     * @description-zh 继续类型遍历。
     */
    | CONTINUE
    /**
     * @description Skip traversal of the current type's children.
     * @description-zh 跳过当前类型的子节点遍历。
     */
    | SKIP
    /**
     * @description Stop type traversal.
     * @description-zh 停止类型遍历。
     */
    | STOP
}

/**
 * @description Specifies where a CHIRBuilder inserts newly created expressions.
 * @description-zh 指定 CHIRBuilder 插入新表达式的位置。
 */
public enum InsertPosition {
    /**
     * @description Insert at the end of a block.
     * @description-zh 插入到基本块末尾。
     */
    | AtEnd(Block)
    /**
     * @description Insert at the start of a block.
     * @description-zh 插入到基本块开头。
     */
    | AtStart(Block)
    /**
     * @description Insert before an existing expression.
     * @description-zh 插入到已有表达式之前。
     */
    | Before(Expression)
    /**
     * @description Insert after an existing expression.
     * @description-zh 插入到已有表达式之后。
     */
    | After(Expression)
    /**
     * @description Reserved for future insertion positions.
     * @description-zh 预留给未来的插入位置。
     */
    | ...
}

/**
 * @description Represents a line and column pair in a source file.
 * @description-zh 表示源文件中的行列位置。
 * @param line One-based source line.
 * @param-zh line 从 1 开始的源码行号。
 * @param column One-based source column.
 * @param-zh column 从 1 开始的源码列号。
 */
public struct Position <: ToString {
    /**
     * @description One-based source line.
     * @description-zh 以 1 为起始的源码行号。
     * @type { Int64 }
     */
    public let line: Int64

    /**
     * @description One-based source column.
     * @description-zh 以 1 为起始的源码列号。
     * @type { Int64 }
     */
    public let column: Int64

    public init(line: Int64, column: Int64) {
        this.line = line
        this.column = column
    }

    /**
     * @description Returns whether this position points at a real source location.
     * @description-zh 返回此位置是否指向真实源码位置。
     * @return true when both line and column are positive.
     * @return-zh 当行号和列号都为正数时返回 true。
     */
    public func isValid(): Bool {
        return line > 0 && column > 0
    }

    /**
     * @description Renders this position as a debug suffix.
     * @description-zh 将此位置格式化为调试后缀。
     * @return Text containing line and column.
     * @return-zh 包含行号和列号的文本。
     */
    public func toString(): String {
        return "-${line}-${column}"
    }
}

/**
 * @description Stores a source file span associated with a CHIR declaration or expression.
 * @description-zh 保存 CHIR 声明或表达式关联的源文件范围。
 * @param filePath Source file path.
 * @param-zh filePath 源文件路径。
 * @param start Start position of the source span.
 * @param-zh start 源码范围的起始位置。
 * @param end End position of the source span.
 * @param-zh end 源码范围的结束位置。
 */
public class DebugLocation <: ToString {
    /**
     * @description Source file path.
     * @description-zh 源文件路径。
     * @type { String }
     */
    public let filePath: String

    /**
     * @description Start position of the source span.
     * @description-zh 源码范围的起始位置。
     * @type { Position }
     */
    public let start: Position

    /**
     * @description End position of the source span.
     * @description-zh 源码范围的结束位置。
     * @type { Position }
     */
    public let end: Position

    public init(filePath: String, start: Position, end: Position) {
        this.filePath = filePath
        this.start = start
        this.end = end
    }

    /**
     * @description Creates an invalid location placeholder.
     * @description-zh 创建无效位置占位值。
     * @return Debug location whose file path and positions are empty.
     * @return-zh 文件路径和位置均为空的调试位置。
     */
    public static func invalid(): DebugLocation {
        return DebugLocation("", Position(0, 0), Position(0, 0))
    }

    /**
     * @description Returns whether this location points at a real source span.
     * @description-zh 返回此位置是否指向真实源码范围。
     * @return true when file path, start, and end are valid.
     * @return-zh 当文件路径、起始位置和结束位置都有效时返回 true。
     */
    public func isValid(): Bool {
        return !filePath.isEmpty() && start.isValid() && end.isValid()
    }

    /**
     * @description Renders this location as file and source positions.
     * @description-zh 将此位置格式化为文件路径和源码位置。
     * @return Text form suitable for locating a declaration.
     * @return-zh 适合定位声明的文本形式。
     */
    public func toString(): String {
        return filePath + start.toString() + end.toString()
    }
}

/**
 * @description Base class for every CHIR type node.
 * @description-zh 所有 CHIR 类型节点的基类。
 */
public abstract class Type <: ToString {
    /**
     * @description Returns the type after removing all reference wrappers.
     * @description-zh 返回移除所有引用包装后的类型。
     * @return The unwrapped type.
     * @return-zh 去除引用包装后的类型。
     */
    public open func stripAllRefs(): Type {
        return this
    }

    /**
     * @description Returns the display name of this type.
     * @description-zh 返回此类型的显示名称。
     * @return Text form of the type.
     * @return-zh 类型的文本形式。
     */
    public open func toString(): String {
        return "Type"
    }
}

/**
 * @description Base class for built-in type nodes.
 * @description-zh 内置类型节点的基类。
 */
public abstract class BuiltinType <: Type {
    /**
     * @description Registers an extension definition for this built-in type.
     * @description-zh 为此内置类型登记一个扩展定义。
     * @param extendDef Extension definition to attach.
     * @param-zh extendDef 要关联的扩展定义。
     * @return Unit after the extension is recorded.
     * @return-zh 扩展记录完成后返回 Unit。
     */
    public open func addExtend(extendDef: ExtendDef): Unit {}

    /**
     * @description Collects super types introduced by extension definitions.
     * @description-zh 收集扩展定义引入的父类型。
     * @param visited Pairs already visited during recursive traversal.
     * @param-zh visited 递归遍历期间已访问过的配对。
     * @return Class-like types available through extensions.
     * @return-zh 可通过扩展获得的类或接口类型。
     */
    public func getSuperTypesRecusively(
        visited!: ArrayList<(Type, Type)> = ArrayList<(Type, Type)>()
    ): Array<ClassLikeType> {
        return Array<ClassLikeType>()
    }
}

/**
 * @description Base class for numeric built-in types.
 * @description-zh 数值内置类型的基类。
 */
public abstract class NumericType <: BuiltinType {}

/**
 * @description Represents the Bool type.
 * @description-zh 表示 Bool 类型。
 */
public class BoolType <: BuiltinType {
    /**
     * @description Creates a Bool type value.
     * @description-zh 创建 Bool 类型值。
     */
    public init() {}

    /**
     * @description Returns a Bool type value.
     * @description-zh 返回 Bool 类型值。
     * @return Bool type value.
     * @return-zh Bool 类型值。
     */
    public static func get(): BoolType {
        return BoolType()
    }

    /**
     * @description Returns the source spelling of the Bool type.
     * @description-zh 返回 Bool 类型在源码中的写法。
     * @return The string `Bool`.
     * @return-zh 字符串 `Bool`。
     */
    public override func toString(): String {
        return "Bool"
    }
}

/**
 * @description Represents the Unit type.
 * @description-zh 表示 Unit 类型。
 */
public class UnitType <: BuiltinType {
    /**
     * @description Creates a Unit type value.
     * @description-zh 创建 Unit 类型值。
     */
    public init() {}

    /**
     * @description Returns a Unit type value.
     * @description-zh 返回 Unit 类型值。
     * @return Unit type value.
     * @return-zh Unit 类型值。
     */
    public static func get(): UnitType {
        return UnitType()
    }

    /**
     * @description Returns the source spelling of the Unit type.
     * @description-zh 返回 Unit 类型在源码中的写法。
     * @return The string `Unit`.
     * @return-zh 字符串 `Unit`。
     */
    public override func toString(): String {
        return "Unit"
    }
}

/**
 * @description Represents the Nothing type.
 * @description-zh 表示 Nothing 类型。
 */
public class NothingType <: BuiltinType {
    /**
     * @description Creates a Nothing type value.
     * @description-zh 创建 Nothing 类型值。
     */
    public init() {}

    /**
     * @description Returns a Nothing type value.
     * @description-zh 返回 Nothing 类型值。
     * @return Nothing type value.
     * @return-zh Nothing 类型值。
     */
    public static func get(): NothingType {
        return NothingType()
    }
}

/**
 * @description Represents the Rune type.
 * @description-zh 表示 Rune 类型。
 */
public class RuneType <: BuiltinType {
    /**
     * @description Creates a Rune type value.
     * @description-zh 创建 Rune 类型值。
     */
    public init() {}

    /**
     * @description Returns a Rune type value.
     * @description-zh 返回 Rune 类型值。
     * @return Rune type value.
     * @return-zh Rune 类型值。
     */
    public static func get(): RuneType {
        return RuneType()
    }
}

/**
 * @description Represents the CString type used by C interop.
 * @description-zh 表示 C 互操作使用的 CString 类型。
 */
public class CStringType <: BuiltinType {
    /**
     * @description Creates a CString type value.
     * @description-zh 创建 CString 类型值。
     */
    public init() {}

    /**
     * @description Returns a CString type value.
     * @description-zh 返回 CString 类型值。
     * @return CString type value.
     * @return-zh CString 类型值。
     */
    public static func get(): CStringType {
        return CStringType()
    }
}

/**
 * @description Represents a fixed-width integer type.
 * @description-zh 表示固定宽度整数类型。
 * @param bits Number of bits used by the integer.
 * @param-zh bits 整数使用的位数。
 * @param signed Whether the integer is signed.
 * @param-zh signed 整数是否有符号。
 */
public class IntType <: NumericType {
    /**
     * @description Number of bits used by the integer.
     * @description-zh 整数使用的位数。
     * @type { Int64 }
     */
    public let bits: Int64

    /**
     * @description Whether the integer is signed.
     * @description-zh 表示整数是否有符号。
     * @type { Bool }
     */
    public let signed: Bool

    public init(bits: Int64, signed: Bool) {
        this.bits = bits
        this.signed = signed
    }

    /**
     * @description Returns the signed 32-bit integer type.
     * @description-zh 返回有符号 32 位整数类型。
     * @return Int32 type value.
     * @return-zh Int32 类型值。
     */
    public static func getInt32(): IntType { return IntType(32, true) }

    /**
     * @description Returns the signed 64-bit integer type.
     * @description-zh 返回有符号 64 位整数类型。
     * @return Int64 type value.
     * @return-zh Int64 类型值。
     */
    public static func getInt64(): IntType { return IntType(64, true) }

    /**
     * @description Returns the unsigned 32-bit integer type.
     * @description-zh 返回无符号 32 位整数类型。
     * @return UInt32 type value.
     * @return-zh UInt32 类型值。
     */
    public static func getUInt32(): IntType { return IntType(32, false) }

    /**
     * @description Returns the unsigned 64-bit integer type.
     * @description-zh 返回无符号 64 位整数类型。
     * @return UInt64 type value.
     * @return-zh UInt64 类型值。
     */
    public static func getUInt64(): IntType { return IntType(64, false) }
}

/**
 * @description Represents a floating-point type.
 * @description-zh 表示浮点类型。
 * @param bits Number of bits used by the floating-point value.
 * @param-zh bits 浮点值使用的位数。
 */
public class FloatType <: NumericType {
    /**
     * @description Number of bits used by the floating-point value.
     * @description-zh 浮点值使用的位数。
     * @type { Int64 }
     */
    public let bits: Int64

    public init(bits: Int64) {
        this.bits = bits
    }

    /**
     * @description Returns the 32-bit floating-point type.
     * @description-zh 返回 32 位浮点类型。
     * @return Float32 type value.
     * @return-zh Float32 类型值。
     */
    public static func getFloat32(): FloatType { return FloatType(32) }

    /**
     * @description Returns the 64-bit floating-point type.
     * @description-zh 返回 64 位浮点类型。
     * @return Float64 type value.
     * @return-zh Float64 类型值。
     */
    public static func getFloat64(): FloatType { return FloatType(64) }
}

/**
 * @description Represents a boxed type Box<T>.
 * @description-zh 表示装箱类型 Box<T>。
 * @param baseType Type stored inside the box.
 * @param-zh baseType Box 中存放的类型。
 */
public class BoxType <: Type {
    /**
     * @description Type stored inside the box.
     * @description-zh Box<T> 中存放的类型。
     * @type { Type }
     */
    public let baseType: Type

    public init(baseType: Type) {
        this.baseType = baseType
    }

    /**
     * @description Creates a boxed type for the supplied base type.
     * @description-zh 为给定基础类型创建 Box<T> 类型。
     * @param baseType Type stored inside the box.
     * @param-zh baseType Box 中存放的类型。
     * @return Box type value.
     * @return-zh Box 类型值。
     */
    public static func get(baseType: Type): BoxType {
        return BoxType(baseType)
    }
}

/**
 * @description Represents a C pointer type CPointer<T>.
 * @description-zh 表示 C 指针类型 CPointer<T>。
 * @param elementType Type pointed to by the pointer.
 * @param-zh elementType 指针指向的类型。
 */
public class CPointerType <: BuiltinType {
    /**
     * @description Type pointed to by the pointer.
     * @description-zh 指针指向的类型。
     * @type { Type }
     */
    public let elementType: Type

    public init(elementType: Type) {
        this.elementType = elementType
    }

    /**
     * @description Creates a C pointer type for the supplied element type.
     * @description-zh 为给定元素类型创建 C 指针类型。
     * @param elementType Type pointed to by the pointer.
     * @param-zh elementType 指针指向的类型。
     * @return C pointer type value.
     * @return-zh C 指针类型值。
     */
    public static func get(elementType: Type): CPointerType {
        return CPointerType(elementType)
    }
}

/**
 * @description Represents a raw array type.
 * @description-zh 表示 RawArray 类型。
 * @param elementType Element type stored in the raw array.
 * @param-zh elementType RawArray 中存放的元素类型。
 */
public class RawArrayType <: BuiltinType {
    /**
     * @description Element type stored in the raw array.
     * @description-zh RawArray 中存放的元素类型。
     * @type { Type }
     */
    public let elementType: Type

    public init(elementType: Type) {
        this.elementType = elementType
    }

    /**
     * @description Creates a raw array type for the supplied element type.
     * @description-zh 为给定元素类型创建 RawArray 类型。
     * @param elementType Element type stored in the raw array.
     * @param-zh elementType RawArray 中存放的元素类型。
     * @return Raw array type value.
     * @return-zh RawArray 类型值。
     */
    public static func get(elementType: Type): RawArrayType {
        return RawArrayType(elementType)
    }
}

/**
 * @description Represents a fixed-length VArray type.
 * @description-zh 表示固定长度 VArray 类型。
 * @param elementType Element type stored in the VArray.
 * @param-zh elementType VArray 中存放的元素类型。
 * @param size Compile-time VArray length.
 * @param-zh size 编译期确定的 VArray 长度。
 */
public class VArrayType <: BuiltinType {
    /**
     * @description Element type stored in the VArray.
     * @description-zh VArray 中存放的元素类型。
     * @type { Type }
     */
    public let elementType: Type

    /**
     * @description Compile-time VArray length.
     * @description-zh 编译期确定的 VArray 长度。
     * @type { UInt64 }
     */
    public let size: UInt64

    public init(elementType: Type, size: UInt64) {
        this.elementType = elementType
        this.size = size
    }

    /**
     * @description Creates a fixed-length VArray type.
     * @description-zh 创建固定长度 VArray 类型。
     * @param elementType Element type stored in the VArray.
     * @param-zh elementType VArray 中存放的元素类型。
     * @param size Compile-time VArray length.
     * @param-zh size 编译期确定的 VArray 长度。
     * @return VArray type value.
     * @return-zh VArray 类型值。
     */
    public static func get(elementType: Type, size: UInt64): VArrayType {
        return VArrayType(elementType, size)
    }
}

/**
 * @description Represents a tuple type.
 * @description-zh 表示元组类型。
 * @param elementTypes Tuple element types in order.
 * @param-zh elementTypes 按顺序排列的元组元素类型。
 */
public class TupleType <: BuiltinType {
    /**
     * @description Tuple element types in order.
     * @description-zh 元组元素类型，按顺序排列。
     * @type { Array<Type> }
     */
    public let elementTypes: Array<Type>

    public init(elementTypes: Array<Type>) {
        this.elementTypes = elementTypes
    }

    /**
     * @description Creates a tuple type.
     * @description-zh 创建元组类型。
     * @param elementTypes Tuple element types in order.
     * @param-zh elementTypes 按顺序排列的元组元素类型。
     * @return Tuple type value.
     * @return-zh 元组类型值。
     */
    public static func get(elementTypes: Array<Type>): TupleType {
        return TupleType(elementTypes)
    }
}

/**
 * @description Represents a function type.
 * @description-zh 表示函数类型。
 * @param paramTypes Parameter types in declaration order.
 * @param-zh paramTypes 按声明顺序排列的参数类型。
 * @param returnType Function return type.
 * @param-zh returnType 函数的返回类型。
 * @param isCFunc Whether the function uses the C calling convention.
 * @param-zh isCFunc 函数是否使用 C 调用约定。
 */
public class FuncType <: Type {
    /**
     * @description Parameter types in declaration order.
     * @description-zh 按声明顺序排列的参数类型。
     * @type { Array<Type> }
     */
    public let paramTypes: Array<Type>

    /**
     * @description Function return type.
     * @description-zh 函数的返回类型。
     * @type { Type }
     */
    public let returnType: Type

    /**
     * @description Whether the function uses the C calling convention.
     * @description-zh 表示该函数是否使用 C 调用约定。
     * @type { Bool }
     */
    public let isCFunc: Bool

    public init(paramTypes: Array<Type>, returnType: Type, isCFunc!: Bool = false) {
        this.paramTypes = paramTypes
        this.returnType = returnType
        this.isCFunc = isCFunc
    }

    /**
     * @description Creates a function type.
     * @description-zh 创建函数类型。
     * @param paramTypes Parameter types in declaration order.
     * @param-zh paramTypes 按声明顺序排列的参数类型。
     * @param returnType Function return type.
     * @param-zh returnType 函数的返回类型。
     * @param isCFunc Whether the function uses the C calling convention.
     * @param-zh isCFunc 函数是否使用 C 调用约定。
     * @return Function type value.
     * @return-zh 函数类型值。
     */
    public static func get(paramTypes: Array<Type>, returnType: Type, isCFunc!: Bool = false): FuncType {
        return FuncType(paramTypes, returnType, isCFunc: isCFunc)
    }
}

/**
 * @description Represents a reference type.
 * @description-zh 表示引用类型。
 * @param baseType Referenced type.
 * @param-zh baseType 被引用的类型。
 */
public class RefType <: Type {
    /**
     * @description Referenced type.
     * @description-zh 被引用的类型。
     * @type { Type }
     */
    public let baseType: Type

    public init(baseType: Type) {
        this.baseType = baseType
    }

    /**
     * @description Creates a reference type for the supplied base type.
     * @description-zh 为给定的基础类型创建引用类型。
     * @param baseType Referenced type.
     * @param-zh baseType 被引用的类型。
     * @return Reference type value.
     * @return-zh 引用类型值。
     */
    public static func get(baseType: Type): RefType {
        return RefType(baseType)
    }
}

/**
 * @description Represents a generic type parameter.
 * @description-zh 表示泛型类型参数。
 * @param srcCodeName Source spelling of the generic parameter.
 * @param-zh srcCodeName 泛型参数在源码中的写法。
 * @param upperBounds Upper-bound constraints for the parameter.
 * @param-zh upperBounds 该参数的上界约束。
 */
public class GenericType <: Type {
    /**
     * @description Source spelling of the generic parameter.
     * @description-zh 泛型参数在源码中的写法。
     * @type { String }
     */
    public let srcCodeName: String

    /**
     * @description Upper-bound constraints for the parameter.
     * @description-zh 该参数的上界约束。
     * @type { Array<Type> }
     */
    public let upperBounds: Array<Type>

    public init(srcCodeName: String, upperBounds!: Array<Type> = Array<Type>()) {
        this.srcCodeName = srcCodeName
        this.upperBounds = upperBounds
    }
}

/**
 * @description Base class for user-defined type definitions.
 * @description-zh 用户自定义类型定义的基类。
 * @param identifier Compiler-internal identifier for the definition.
 * @param-zh identifier 定义在编译器内部使用的标识符。
 * @param srcCodeName Source name written by the user.
 * @param-zh srcCodeName 用户在源码中写下的名称。
 * @param packageName Package that owns the definition.
 * @param-zh packageName 拥有该定义的包。
 */
public abstract class CustomTypeDef <: ToString {
    /**
     * @description Compiler-internal identifier for the definition.
     * @description-zh 该定义在编译器内部使用的标识符。
     * @type { String }
     */
    public let identifier: String

    /**
     * @description Source name written by the user.
     * @description-zh 用户在源码中写下的名称。
     * @type { String }
     */
    public let srcCodeName: String

    /**
     * @description Package that owns the definition.
     * @description-zh 拥有该定义的包。
     * @type { String }
     */
    public let packageName: String

    /**
     * @description Generic type parameters declared by this definition.
     * @description-zh 该定义声明的泛型类型参数。
     * @type { Array<GenericType> }
     */
    public let genericTypeParams: Array<GenericType>

    public init(identifier: String, srcCodeName: String, packageName!: String = "") {
        this.identifier = identifier
        this.srcCodeName = srcCodeName
        this.packageName = packageName
        this.genericTypeParams = Array<GenericType>()
    }

    /**
     * @description Returns whether this definition is public API.
     * @description-zh 返回该定义是否为公共 API。
     * @return true when the definition is publicly visible.
     * @return-zh 当该定义公开可见时返回 true。
     */
    public open func isPublic(): Bool { return true }

    /**
     * @description Returns whether this definition was imported from another package.
     * @description-zh 返回该定义是否从其他包导入。
     * @return true when the definition is imported.
     * @return-zh 当该定义从其他包导入时返回 true。
     */
    public open func isImported(): Bool { return false }

    /**
     * @description Returns the source name for this definition.
     * @description-zh 返回该定义的源码名称。
     * @return Source-level type name.
     * @return-zh 源码层面的类型名称。
     */
    public open func toString(): String { return srcCodeName }
}

/**
 * @description Base class for instantiated user-defined types.
 * @description-zh 已实例化用户自定义类型的基类。
 * @param def Type definition being instantiated.
 * @param-zh def 被实例化的类型定义。
 * @param genericTypeArgs Concrete generic arguments for this type use.
 * @param-zh genericTypeArgs 本次类型使用中的具体泛型实参。
 */
public abstract class CustomType <: Type {
    /**
     * @description Type definition being instantiated.
     * @description-zh 被实例化的类型定义。
     * @type { CustomTypeDef }
     */
    public let def: CustomTypeDef

    /**
     * @description Concrete generic arguments for this type use.
     * @description-zh 本次类型使用中的具体泛型实参。
     * @type { Array<Type> }
     */
    public let genericTypeArgs: Array<Type>

    public init(def: CustomTypeDef, genericTypeArgs!: Array<Type> = Array<Type>()) {
        this.def = def
        this.genericTypeArgs = genericTypeArgs
    }
}

/**
 * @description Defines a class or interface.
 * @description-zh 定义类或接口。
 * @param identifier Compiler-internal identifier for the class or interface.
 * @param-zh identifier 类或接口在编译器内部使用的标识符。
 * @param srcCodeName Source name written by the user.
 * @param-zh srcCodeName 用户在源码中写下的名称。
 * @param isClass Whether this definition represents a class instead of an interface.
 * @param-zh isClass 该定义是否表示类而不是接口。
 */
public class ClassLikeDef <: CustomTypeDef {
    /**
     * @description Whether this class-like definition represents an annotation type.
     * @description-zh 表示该 class-like 定义是否代表注解类型。
     * @type { Bool }
     */
    public let isAnnotation: Bool

    /**
     * @description Instance member variables declared by this class-like definition.
     * @description-zh 该 class-like 定义声明的实例成员变量。
     * @type { Array<MemberVar> }
     */
    public let instanceVars: Array<MemberVar>

    /**
     * @description Static variables declared by this class-like definition.
     * @description-zh 该 class-like 定义声明的静态变量。
     * @type { Array<GlobalVar> }
     */
    public let staticVars: Array<GlobalVar>

    /**
     * @description Methods and constructors declared by this class-like definition.
     * @description-zh 该 class-like 定义声明的方法和构造函数。
     * @type { Array<Function> }
     */
    public let methods: Array<Function>

    /**
     * @description Instantiated type for this class-like definition.
     * @description-zh 该 class-like 定义对应的实例化类型。
     * @type { ClassLikeType }
     */
    public prop classType: ClassLikeType {
        get() { return ClassLikeType(this) }
    }

    /**
     * @description Optional superclass of this class definition.
     * @description-zh 该类定义的可选父类。
     * @type { ?ClassLikeType }
     */
    public mut prop superClass: ?ClassLikeType {
        get() { return None }
        set(value) {}
    }

    /**
     * @description Interfaces implemented by this class-like definition.
     * @description-zh 该 class-like 定义实现的接口。
     * @type { Array<ClassLikeType> }
     */
    public prop implementedInterfaceTypes: Array<ClassLikeType> {
        get() { return Array<ClassLikeType>() }
    }

    public init(identifier: String, srcCodeName: String, isClass!: Bool = true) {
        super(identifier, srcCodeName)
        this.isAnnotation = false
        this.instanceVars = Array<MemberVar>()
        this.staticVars = Array<GlobalVar>()
        this.methods = Array<Function>()
    }

    /**
     * @description Returns whether this definition represents a class.
     * @description-zh 返回该定义是否表示类。
     * @return true for classes and false for interfaces.
     * @return-zh 类返回 true，接口返回 false。
     */
    public func isClass(): Bool { return true }

    /**
     * @description Returns whether this class is abstract.
     * @description-zh 返回该类是否为抽象类。
     * @return true when the abstract modifier is present.
     * @return-zh 当存在 abstract 修饰符时返回 true。
     */
    public func isAbstract(): Bool { return false }

    /**
     * @description Returns whether this class is open for inheritance.
     * @description-zh 返回该类是否开放继承。
     * @return true when the open modifier is present.
     * @return-zh 当存在 open 修饰符时返回 true。
     */
    public func isOpen(): Bool { return false }

    /**
     * @description Returns whether this class-like definition is sealed.
     * @description-zh 返回该 class-like 定义是否为 sealed。
     * @return true when the sealed modifier is present.
     * @return-zh 当存在 sealed 修饰符时返回 true。
     */
    public func isSealed(): Bool { return false }

    /**
     * @description Sets whether this class is abstract.
     * @description-zh 设置该类是否为抽象类。
     * @param enable true to mark the class abstract.
     * @param-zh enable 传入 true 表示将类标记为 abstract。
     * @return Unit after the flag is updated.
     * @return-zh 标志更新完成后返回 Unit。
     */
    public func setAbstract(enable: Bool): Unit {}

    /**
     * @description Sets whether this class is open for inheritance.
     * @description-zh 设置该类是否开放继承。
     * @param enable true to mark the class open.
     * @param-zh enable 传入 true 表示将类标记为 open。
     * @return Unit after the flag is updated.
     * @return-zh 标志更新完成后返回 Unit。
     */
    public func setOpen(enable: Bool): Unit {}

    /**
     * @description Sets whether this class-like definition is sealed.
     * @description-zh 设置该 class-like 定义是否为 sealed。
     * @param enable true to mark the class-like definition sealed.
     * @param-zh enable 传入 true 表示将类或接口定义标记为 sealed。
     * @return Unit after the flag is updated.
     * @return-zh 标志更新完成后返回 Unit。
     */
    public func setSealed(enable: Bool): Unit {}
}

/**
 * @description Represents an instantiated class or interface type.
 * @description-zh 表示已实例化的类或接口类型。
 * @param classLikeDef Class or interface definition being instantiated.
 * @param-zh classLikeDef 被实例化的类或接口定义。
 * @param genericTypeArgs Concrete generic arguments for this type use.
 * @param-zh genericTypeArgs 本次类型使用中的具体泛型实参。
 */
public class ClassLikeType <: CustomType {
    /**
     * @description Class or interface definition being instantiated.
     * @description-zh 被实例化的类或接口定义。
     * @type { ClassLikeDef }
     */
    public let classLikeDef: ClassLikeDef

    public init(classLikeDef: ClassLikeDef, genericTypeArgs!: Array<Type> = Array<Type>()) {
        super(classLikeDef, genericTypeArgs: genericTypeArgs)
        this.classLikeDef = classLikeDef
    }

    /**
     * @description Creates an instantiated class-like type.
     * @description-zh 创建已实例化的 class-like 类型。
     * @param def Class or interface definition.
     * @param-zh def 类或接口定义。
     * @param genericTypeParams Concrete generic arguments.
     * @param-zh genericTypeParams 具体泛型实参。
     * @return Class-like type value.
     * @return-zh 类或接口类型值。
     */
    public static func get(def: ClassLikeDef, genericTypeParams: Array<Type>): ClassLikeType {
        return ClassLikeType(def, genericTypeArgs: genericTypeParams)
    }
}

/**
 * @description Defines a struct.
 * @description-zh 定义结构体。
 * @param identifier Compiler-internal identifier for the struct.
 * @param-zh identifier 结构体在编译器内部使用的标识符。
 * @param srcCodeName Source name written by the user.
 * @param-zh srcCodeName 用户在源码中写下的名称。
 */
public class StructDef <: CustomTypeDef {
    /**
     * @description Instance member variables declared by this struct.
     * @description-zh 该 struct 声明的实例成员变量。
     * @type { Array<MemberVar> }
     */
    public let instanceVars: Array<MemberVar>

    /**
     * @description Static variables declared by this struct.
     * @description-zh 该 struct 声明的静态变量。
     * @type { Array<GlobalVar> }
     */
    public let staticVars: Array<GlobalVar>

    /**
     * @description Methods and constructors declared by this struct.
     * @description-zh 该 struct 声明的方法和构造函数。
     * @type { Array<Function> }
     */
    public let methods: Array<Function>

    /**
     * @description Instantiated type for this struct definition.
     * @description-zh 该 struct 定义对应的实例化类型。
     * @type { StructType }
     */
    public prop structType: StructType {
        get() { return StructType(this) }
    }

    public init(identifier: String, srcCodeName: String) {
        super(identifier, srcCodeName)
        this.instanceVars = Array<MemberVar>()
        this.staticVars = Array<GlobalVar>()
        this.methods = Array<Function>()
    }
}

/**
 * @description Represents an instantiated struct type.
 * @description-zh 表示已实例化的结构体类型。
 * @param structDef Struct definition being instantiated.
 * @param-zh structDef 被实例化的结构体定义。
 * @param genericTypeArgs Concrete generic arguments for this type use.
 * @param-zh genericTypeArgs 本次类型使用中的具体泛型实参。
 */
public class StructType <: CustomType {
    /**
     * @description Struct definition being instantiated.
     * @description-zh 被实例化的 struct 定义。
     * @type { StructDef }
     */
    public let structDef: StructDef

    public init(structDef: StructDef, genericTypeArgs!: Array<Type> = Array<Type>()) {
        super(structDef, genericTypeArgs: genericTypeArgs)
        this.structDef = structDef
    }

    /**
     * @description Creates an instantiated struct type.
     * @description-zh 创建已实例化的 struct 类型。
     * @param def Struct definition.
     * @param-zh def 结构体定义。
     * @param genericTypeParams Concrete generic arguments.
     * @param-zh genericTypeParams 具体泛型实参。
     * @return Struct type value.
     * @return-zh 结构体类型值。
     */
    public static func get(def: StructDef, genericTypeParams: Array<Type>): StructType {
        return StructType(def, genericTypeArgs: genericTypeParams)
    }
}

/**
 * @description Defines an enum.
 * @description-zh 定义枚举。
 * @param identifier Compiler-internal identifier for the enum.
 * @param-zh identifier 枚举在编译器内部使用的标识符。
 * @param srcCodeName Source name written by the user.
 * @param-zh srcCodeName 用户在源码中写下的名称。
 */
public class EnumDef <: CustomTypeDef {
    /**
     * @description Constructors declared by this enum.
     * @description-zh 该 enum 声明的构造器。
     * @type { Array<EnumCtorInfo> }
     */
    public let constructors: Array<EnumCtorInfo>

    /**
     * @description Instance member variables declared by this enum.
     * @description-zh 该 enum 声明的实例成员变量。
     * @type { Array<MemberVar> }
     */
    public let instanceVars: Array<MemberVar>

    /**
     * @description Static variables declared by this enum.
     * @description-zh 该 enum 声明的静态变量。
     * @type { Array<GlobalVar> }
     */
    public let staticVars: Array<GlobalVar>

    /**
     * @description Methods declared by this enum.
     * @description-zh 该 enum 声明的方法。
     * @type { Array<Function> }
     */
    public let methods: Array<Function>

    /**
     * @description Instantiated type for this enum definition.
     * @description-zh 该 enum 定义对应的实例化类型。
     * @type { EnumType }
     */
    public prop enumType: EnumType {
        get() { return EnumType(this) }
    }

    public init(identifier: String, srcCodeName: String) {
        super(identifier, srcCodeName)
        this.constructors = Array<EnumCtorInfo>()
        this.instanceVars = Array<MemberVar>()
        this.staticVars = Array<GlobalVar>()
        this.methods = Array<Function>()
    }
}

/**
 * @description Represents an instantiated enum type.
 * @description-zh 表示已实例化的枚举类型。
 * @param enumDef Enum definition being instantiated.
 * @param-zh enumDef 被实例化的枚举定义。
 * @param genericTypeArgs Concrete generic arguments for this type use.
 * @param-zh genericTypeArgs 本次类型使用中的具体泛型实参。
 */
public class EnumType <: CustomType {
    /**
     * @description Enum definition being instantiated.
     * @description-zh 被实例化的 enum 定义。
     * @type { EnumDef }
     */
    public let enumDef: EnumDef

    public init(enumDef: EnumDef, genericTypeArgs!: Array<Type> = Array<Type>()) {
        super(enumDef, genericTypeArgs: genericTypeArgs)
        this.enumDef = enumDef
    }

    /**
     * @description Creates an instantiated enum type.
     * @description-zh 创建已实例化的 enum 类型。
     * @param def Enum definition.
     * @param-zh def 枚举定义。
     * @param genericTypeParams Concrete generic arguments.
     * @param-zh genericTypeParams 具体泛型实参。
     * @return Enum type value.
     * @return-zh 枚举类型值。
     */
    public static func get(def: EnumDef, genericTypeParams: Array<Type>): EnumType {
        return EnumType(def, genericTypeArgs: genericTypeParams)
    }
}

/**
 * @description Describes one enum constructor.
 * @description-zh 描述一个枚举构造器。
 * @param srcCodeName Constructor name written in source.
 * @param-zh srcCodeName 源码中写下的构造器名称。
 * @param funcType Constructor function type.
 * @param-zh funcType 构造器的函数类型。
 */
public class EnumCtorInfo {
    /**
     * @description Constructor name written in source.
     * @description-zh 构造器在源码中的名称。
     * @type { String }
     */
    public let srcCodeName: String

    /**
     * @description Constructor function type.
     * @description-zh 构造器的函数类型。
     * @type { FuncType }
     */
    public let funcType: FuncType

    public init(srcCodeName: String, funcType: FuncType) {
        this.srcCodeName = srcCodeName
        this.funcType = funcType
    }
}

/**
 * @description Defines an extension block.
 * @description-zh 定义扩展块。
 * @param identifier Compiler-internal identifier for the extension.
 * @param-zh identifier 扩展在编译器内部使用的标识符。
 * @param extendedType Type extended by this block.
 * @param-zh extendedType 此扩展块所扩展的类型。
 */
public class ExtendDef <: CustomTypeDef {
    /**
     * @description Type extended by this block.
     * @description-zh 该扩展块所扩展的类型。
     * @type { Type }
     */
    public let extendedType: Type

    /**
     * @description Interfaces implemented by this extension.
     * @description-zh 该 extend 实现的接口。
     * @type { Array<ClassLikeType> }
     */
    public let implementedInterfaceTypes: Array<ClassLikeType>

    /**
     * @description Methods declared by this extension.
     * @description-zh 该 extend 声明的方法。
     * @type { Array<Function> }
     */
    public let methods: Array<Function>

    public init(identifier: String, extendedType: Type) {
        super(identifier, identifier)
        this.extendedType = extendedType
        this.implementedInterfaceTypes = Array<ClassLikeType>()
        this.methods = Array<Function>()
    }
}

/**
 * @description Describes a member variable.
 * @description-zh 描述成员变量。
 * @param name Source-level member name.
 * @param-zh name 源码层面的成员名称。
 * @param ty Member type.
 * @param-zh ty 成员的类型。
 */
public class MemberVar {
    /**
     * @description Source-level member name.
     * @description-zh 源码层面的成员名称。
     * @type { String }
     */
    public let name: String

    /**
     * @description Member type.
     * @description-zh 成员的类型。
     * @type { Type }
     */
    public let ty: Type

    /**
     * @description Source location for the member declaration.
     * @description-zh 成员声明在源码中的位置。
     * @type { DebugLocation }
     */
    public let location: DebugLocation

    public init(name: String, ty: Type) {
        this.name = name
        this.ty = ty
        this.location = DebugLocation.invalid()
    }

    /**
     * @description Returns whether this member is public API.
     * @description-zh 返回该成员是否为公共 API。
     * @return true when the member is publicly visible.
     * @return-zh 当该成员公开可见时返回 true。
     */
    public func isPublic(): Bool { return true }

    /**
     * @description Returns whether this member is read-only.
     * @description-zh 返回该成员是否只读。
     * @return true when the member is declared as let.
     * @return-zh 当该成员声明为 let 时返回 true。
     */
    public func isReadOnly(): Bool { return true }
}

/**
 * @description Base class for global values such as functions and global variables.
 * @description-zh 函数和全局变量等全局值的基类。
 * @param identifier Compiler-internal identifier for the value.
 * @param-zh identifier 值在编译器内部使用的标识符。
 * @param srcCodeName Source name written by the user.
 * @param-zh srcCodeName 用户在源码中写下的名称。
 * @param packageName Package that owns the value.
 * @param-zh packageName 拥有该值的包。
 * @param valueType Static type of the value.
 * @param-zh valueType 值的静态类型。
 */
public abstract class GlobalValue <: Value {
    /**
     * @description Compiler-internal identifier for the value.
     * @description-zh 该值在编译器内部使用的标识符。
     * @type { String }
     */
    public let identifier: String

    /**
     * @description Source name written by the user.
     * @description-zh 用户在源码中写下的名称。
     * @type { String }
     */
    public let srcCodeName: String

    /**
     * @description Package that owns the value.
     * @description-zh 拥有该值的包。
     * @type { String }
     */
    public let packageName: String

    public init(identifier: String, srcCodeName: String, packageName!: String = "", valueType!: Type = TypeMirror.any()) {
        super(valueType)
        this.identifier = identifier
        this.srcCodeName = srcCodeName
        this.packageName = packageName
    }

    /**
     * @description Returns whether this global value is public API.
     * @description-zh 返回该全局值是否为公开 API。
     * @return true when the value is publicly visible.
     * @return-zh 当该值公开可见时返回 true。
     */
    public func isPublic(): Bool { return true }

    /**
     * @description Returns whether this value was imported from another package.
     * @description-zh 返回该值是否从其他 Package 导入。
     * @return true when the value is imported.
     * @return-zh 当该值从其他包导入时返回 true。
     */
    public func isImported(): Bool { return false }

    /**
     * @description Returns whether this value was inserted by the compiler.
     * @description-zh 返回该值是否由编译器插入。
     * @return true when the compiler synthesized the value.
     * @return-zh 当该值由编译器合成时返回 true。
     */
    public func isCompilerAdd(): Bool { return false }

    /**
     * @description Returns whether this value is a member method.
     * @description-zh 返回该值是否为成员方法。
     * @return true when the value belongs to a type definition.
     * @return-zh 当该值属于某个类型定义时返回 true。
     */
    public func isMemberMethod(): Bool { return false }
}

/**
 * @description Represents a global variable.
 * @description-zh 表示全局变量。
 * @param identifier Compiler-internal identifier for the variable.
 * @param-zh identifier 变量在编译器内部使用的标识符。
 * @param srcCodeName Source name written by the user.
 * @param-zh srcCodeName 用户在源码中写下的名称。
 * @param ty Static type of the variable.
 * @param-zh ty 变量的静态类型。
 */
public class GlobalVar <: GlobalValue {
    public init(identifier: String, srcCodeName: String, ty: Type) {
        super(identifier, srcCodeName, valueType: ty)
    }

    /**
     * @description Returns whether this global variable is static.
     * @description-zh 返回该全局变量是否为 static。
     * @return true when the variable is static.
     * @return-zh 当该变量为 static 时返回 true。
     */
    public func isStatic(): Bool { return false }

    /**
     * @description Returns whether this global variable is const.
     * @description-zh 返回该全局变量是否为 const。
     * @return true when the variable is const.
     * @return-zh 当该变量为 const 时返回 true。
     */
    public func isConst(): Bool { return false }

    /**
     * @description Returns whether this global variable is read-only.
     * @description-zh 返回该全局变量是否为只读。
     * @return true when the variable is declared as let.
     * @return-zh 当该变量声明为 let 时返回 true。
     */
    public func isReadOnly(): Bool { return true }
}

/**
 * @description Represents a function parameter.
 * @description-zh 表示函数参数。
 * @param srcCodeName Parameter name written in source.
 * @param-zh srcCodeName 源码中写下的参数名称。
 * @param ty Static type of the parameter.
 * @param-zh ty 参数的静态类型。
 */
public class Parameter <: Value {
    /**
     * @description Parameter name written in source.
     * @description-zh 源码中编写的参数名。
     * @type { String }
     */
    public let srcCodeName: String

    public init(srcCodeName: String, ty: Type) {
        super(ty)
        this.srcCodeName = srcCodeName
    }
}

/**
 * @description Represents a CHIR function.
 * @description-zh 表示 CHIR 函数。
 * @param funcType Source-level function type.
 * @param-zh funcType 源码层面的函数类型。
 * @param identifier Compiler-internal identifier for the function.
 * @param-zh identifier 函数在编译器内部使用的标识符。
 * @param srcCodeName Source name written by the user.
 * @param-zh srcCodeName 用户在源码中写下的名称。
 * @param packageName Package that owns the function.
 * @param-zh packageName 拥有该函数的包。
 */
public class Function <: GlobalValue {
    /**
     * @description Source-level function type.
     * @description-zh 源码层面的函数类型。
     * @type { FuncType }
     */
    public let funcSrcCodeType: FuncType

    /**
     * @description Generic type parameters declared by the function.
     * @description-zh 函数声明的泛型类型参数。
     * @type { Array<GenericType> }
     */
    public let genericTypeParams: Array<GenericType>

    /**
     * @description Value parameters declared by the function.
     * @description-zh 函数声明的值参数。
     * @type { Array<Parameter> }
     */
    public let parameters: Array<Parameter>

    /**
     * @description Optional function body.
     * @description-zh 可选的函数体。
     * @type { ?BlockGroup }
     */
    public prop body: ?BlockGroup {
        get() { return None }
    }

    public init(funcType: FuncType, identifier: String, srcCodeName: String, packageName: String) {
        super(identifier, srcCodeName, packageName: packageName)
        this.funcSrcCodeType = funcType
        this.genericTypeParams = Array<GenericType>()
        this.parameters = Array<Parameter>()
    }

    /**
     * @description Initializes an empty function body.
     * @description-zh 初始化空函数体。
     * @return Unit after the body is initialized.
     * @return-zh 函数体初始化完成后返回 Unit。
     */
    public func initBody(): Unit {}

    /**
     * @description Returns whether this function is a static member method.
     * @description-zh 返回该函数是否为 static 成员方法。
     * @return true for static member methods.
     * @return-zh 静态成员方法返回 true。
     */
    public func isStaticMemberMethod(): Bool { return false }

    /**
     * @description Returns whether this function is an instance member method.
     * @description-zh 返回该函数是否为实例成员方法。
     * @return true for instance member methods.
     * @return-zh 实例成员方法返回 true。
     */
    public func isInstanceMemberMethod(): Bool { return false }

    /**
     * @description Returns whether this function is abstract.
     * @description-zh 返回该函数是否为 abstract。
     * @return true when the abstract modifier is present.
     * @return-zh 当存在 abstract 修饰符时返回 true。
     */
    public func isAbstract(): Bool { return false }

    /**
     * @description Returns whether this function is open for overriding.
     * @description-zh 返回该函数是否开放给重写。
     * @return true when the open modifier is present.
     * @return-zh 当存在 open 修饰符时返回 true。
     */
    public func isOpen(): Bool { return false }
}

/**
 * @description Represents a package and its top-level CHIR declarations.
 * @description-zh 表示包及其顶层 CHIR 声明。
 * @param name Package name.
 * @param-zh name 包名称。
 * @param accessLevel Package visibility.
 * @param-zh accessLevel 包的可见性。
 */
public class Package {
    /**
     * @description Package name.
     * @description-zh Package 名称。
     * @type { String }
     */
    public let name: String

    /**
     * @description Package visibility.
     * @description-zh Package 可见性。
     * @type { AccessLevel }
     */
    public let accessLevel: AccessLevel

    /**
     * @description Class and interface definitions in this package.
     * @description-zh 该 Package 中的类和接口定义。
     * @type { Array<ClassLikeDef> }
     */
    public prop classDefs: Array<ClassLikeDef> { get() { return Array<ClassLikeDef>() } }

    /**
     * @description Struct definitions in this package.
     * @description-zh 该 Package 中的结构体定义。
     * @type { Array<StructDef> }
     */
    public prop structDefs: Array<StructDef> { get() { return Array<StructDef>() } }

    /**
     * @description Enum definitions in this package.
     * @description-zh 该 Package 中的枚举定义。
     * @type { Array<EnumDef> }
     */
    public prop enumDefs: Array<EnumDef> { get() { return Array<EnumDef>() } }

    /**
     * @description Extension definitions in this package.
     * @description-zh 该 Package 中的扩展定义。
     * @type { Array<ExtendDef> }
     */
    public prop extendDefs: Array<ExtendDef> { get() { return Array<ExtendDef>() } }

    /**
     * @description Top-level variables in this package.
     * @description-zh 该 Package 中的顶层变量。
     * @type { Array<GlobalVar> }
     */
    public prop globalVars: Array<GlobalVar> { get() { return Array<GlobalVar>() } }

    /**
     * @description Top-level functions in this package.
     * @description-zh 该 Package 中的顶层函数。
     * @type { Array<Function> }
     */
    public prop functions: Array<Function> { get() { return Array<Function>() } }

    public init(name: String, accessLevel: AccessLevel) {
        this.name = name
        this.accessLevel = accessLevel
    }

    /**
     * @description Adds a class or interface definition to this package.
     * @description-zh 向该 Package 添加类或接口定义。
     * @param identifier Compiler-internal identifier for the definition.
     * @param-zh identifier 定义在编译器内部使用的标识符。
     * @param srcCodeName Source name written by the user.
     * @param-zh srcCodeName 用户在源码中写下的名称。
     * @param isClass Whether to create a class instead of an interface.
     * @param-zh isClass 是否创建类而不是接口。
     * @return Newly created class-like definition.
     * @return-zh 新创建的类或接口定义。
     */
    public func addClass(identifier: String, srcCodeName: String, isClass!: Bool = true): ClassLikeDef {
        return ClassLikeDef(identifier, srcCodeName, isClass: isClass)
    }

    /**
     * @description Adds a struct definition to this package.
     * @description-zh 向该 Package 添加结构体定义。
     * @param identifier Compiler-internal identifier for the struct.
     * @param-zh identifier 结构体在编译器内部使用的标识符。
     * @param srcCodeName Source name written by the user.
     * @param-zh srcCodeName 用户在源码中写下的名称。
     * @return Newly created struct definition.
     * @return-zh 新创建的结构体定义。
     */
    public func addStruct(identifier: String, srcCodeName: String): StructDef {
        return StructDef(identifier, srcCodeName)
    }

    /**
     * @description Adds an enum definition to this package.
     * @description-zh 向该 Package 添加枚举定义。
     * @param identifier Compiler-internal identifier for the enum.
     * @param-zh identifier 枚举在编译器内部使用的标识符。
     * @param srcCodeName Source name written by the user.
     * @param-zh srcCodeName 用户在源码中写下的名称。
     * @return Newly created enum definition.
     * @return-zh 新创建的枚举定义。
     */
    public func addEnum(identifier: String, srcCodeName: String): EnumDef {
        return EnumDef(identifier, srcCodeName)
    }

    /**
     * @description Adds an extension definition to this package.
     * @description-zh 向该 Package 添加扩展定义。
     * @param identifier Compiler-internal identifier for the extension.
     * @param-zh identifier 扩展在编译器内部使用的标识符。
     * @param extendedType Type extended by the new definition.
     * @param-zh extendedType 新定义要扩展的类型。
     * @return Newly created extension definition.
     * @return-zh 新创建的扩展定义。
     */
    public func addExtend(identifier: String, extendedType: Type): ExtendDef {
        return ExtendDef(identifier, extendedType)
    }

    /**
     * @description Adds a function to this package.
     * @description-zh 向该 Package 添加函数。
     * @param funcType Source-level function type.
     * @param-zh funcType 源码层面的函数类型。
     * @param identifier Compiler-internal identifier for the function.
     * @param-zh identifier 函数在编译器内部使用的标识符。
     * @param srcCodeName Source name written by the user.
     * @param-zh srcCodeName 用户在源码中写下的名称。
     * @param packageName Package that owns the function.
     * @param-zh packageName 拥有该函数的包。
     * @return Newly created function.
     * @return-zh 新创建的函数。
     */
    public func addFunction(funcType: FuncType, identifier: String, srcCodeName: String, packageName: String): Function {
        return Function(funcType, identifier, srcCodeName, packageName)
    }

    /**
     * @description Dumps the package for debugging.
     * @description-zh 转储该 Package 以便调试。
     * @return Unit after dumping.
     * @return-zh 转储完成后返回 Unit。
     */
    public func dump(): Unit {}
}

/**
 * @description Base class for every CHIR value.
 * @description-zh 所有 CHIR 值的基类。
 * @param ty Static type of the value.
 * @param-zh ty 值的静态类型。
 */
public abstract class Value <: ToString {
    /**
     * @description Static type of the value.
     * @description-zh 该值的静态类型。
     * @type { Type }
     */
    public let ty: Type

    public init(ty: Type) {
        this.ty = ty
    }

    /**
     * @description Returns the display name of this value.
     * @description-zh 返回该 Value 的显示名称。
     * @return Text form of the value.
     * @return-zh 值的文本形式。
     */
    public open func toString(): String {
        return "Value"
    }
}

/**
 * @description Base class for local values.
 * @description-zh 局部值的基类。
 * @param name Source-level local name.
 * @param-zh name 源码层面的局部名称。
 * @param ty Static type of the value.
 * @param-zh ty 值的静态类型。
 */
public class LocalVar <: Value {
    /**
     * @description Source-level local name.
     * @description-zh 源码层面的局部名称。
     * @type { String }
     */
    public let name: String

    public init(name: String, ty: Type) {
        super(ty)
        this.name = name
    }
}

/**
 * @description Base class for literal values.
 * @description-zh Literal 值的基类。
 * @param ty Static type of the literal.
 * @param-zh ty 字面量的静态类型。
 */
public abstract class LiteralValue <: Value {
    public init(ty: Type) {
        super(ty)
    }
}

/**
 * @description Represents a Bool literal value.
 * @description-zh 表示 Bool Literal 值。
 */
public class BoolLiteral <: LiteralValue {
    /**
     * @description Creates a Bool literal.
     * @description-zh 创建 Bool Literal。
     * @param value Literal Bool value.
     * @param-zh value Bool 字面量值。
     */
    public init(value: Bool) { super(BoolType.get()) }

    /**
     * @description Creates a Bool literal.
     * @description-zh 创建 Bool Literal。
     * @param value Literal Bool value.
     * @param-zh value Bool 字面量值。
     * @return Bool literal value.
     * @return-zh Bool 字面量值。
     */
    public static func get(value: Bool): BoolLiteral { return BoolLiteral(value) }
}

/**
 * @description Represents an integer literal value.
 * @description-zh 表示整数 Literal 值。
 */
public class IntLiteral <: LiteralValue {
    /**
     * @description Creates an integer literal.
     * @description-zh 创建整数 Literal。
     * @param ty Integer type of the literal.
     * @param-zh ty 字面量的整数类型。
     * @param value Literal integer value.
     * @param-zh value 整数字面量值。
     */
    public init(ty: IntType, value: Int64) { super(ty) }

    /**
     * @description Creates an integer literal.
     * @description-zh 创建整数 Literal。
     * @param ty Integer type of the literal.
     * @param-zh ty 字面量的整数类型。
     * @param value Literal integer value.
     * @param-zh value 整数字面量值。
     * @return Integer literal value.
     * @return-zh 整数字面量值。
     */
    public static func get(ty: IntType, value: Int64): IntLiteral { return IntLiteral(ty, value) }
}

/**
 * @description Represents a floating-point literal value.
 * @description-zh 表示浮点 Literal 值。
 */
public class FloatLiteral <: LiteralValue {
    /**
     * @description Creates a floating-point literal.
     * @description-zh 创建浮点 Literal。
     * @param ty Floating-point type of the literal.
     * @param-zh ty 字面量的浮点类型。
     * @param value Literal floating-point value.
     * @param-zh value 浮点字面量值。
     */
    public init(ty: FloatType, value: Float64) { super(ty) }

    /**
     * @description Creates a floating-point literal.
     * @description-zh 创建浮点 Literal。
     * @param ty Floating-point type of the literal.
     * @param-zh ty 字面量的浮点类型。
     * @param value Literal floating-point value.
     * @param-zh value 浮点字面量值。
     * @return Floating-point literal value.
     * @return-zh 浮点字面量值。
     */
    public static func get(ty: FloatType, value: Float64): FloatLiteral { return FloatLiteral(ty, value) }
}

/**
 * @description Represents a Rune literal value.
 * @description-zh 表示 Rune Literal 值。
 */
public class RuneLiteral <: LiteralValue {
    /**
     * @description Creates a Rune literal.
     * @description-zh 创建 Rune Literal。
     * @param value Literal Rune value.
     * @param-zh value Rune 字面量值。
     */
    public init(value: Rune) { super(RuneType.get()) }

    /**
     * @description Creates a Rune literal.
     * @description-zh 创建 Rune Literal。
     * @param value Literal Rune value.
     * @param-zh value Rune 字面量值。
     * @return Rune literal value.
     * @return-zh Rune 字面量值。
     */
    public static func get(value: Rune): RuneLiteral { return RuneLiteral(value) }
}

/**
 * @description Represents a String literal value.
 * @description-zh 表示 String Literal 值。
 */
public class StringLiteral <: LiteralValue {
    /**
     * @description Creates a String literal.
     * @description-zh 创建 String Literal。
     * @param value Literal String value.
     * @param-zh value String 字面量值。
     */
    public init(value: String) { super(CStringType.get()) }

    /**
     * @description Creates a String literal.
     * @description-zh 创建 String Literal。
     * @param value Literal String value.
     * @param-zh value String 字面量值。
     * @return String literal value.
     * @return-zh String 字面量值。
     */
    public static func get(value: String): StringLiteral { return StringLiteral(value) }
}

/**
 * @description Represents the Unit literal value.
 * @description-zh 表示 Unit Literal 值。
 */
public class UnitLiteral <: LiteralValue {
    /**
     * @description Creates the Unit literal.
     * @description-zh 创建 Unit Literal。
     */
    public init() { super(UnitType.get()) }

    /**
     * @description Creates the Unit literal.
     * @description-zh 创建 Unit Literal。
     * @return Unit literal value.
     * @return-zh Unit 字面量值。
     */
    public static func get(): UnitLiteral { return UnitLiteral() }
}

/**
 * @description Represents a null literal with an explicit type.
 * @description-zh 表示带显式类型的 null Literal。
 */
public class NullLiteral <: LiteralValue {
    /**
     * @description Creates a null literal with an explicit type.
     * @description-zh 创建带显式类型的 null Literal。
     * @param ty Static type of the null literal.
     * @param-zh ty null 字面量的静态类型。
     */
    public init(ty: Type) { super(ty) }

    /**
     * @description Creates a null literal with an explicit type.
     * @description-zh 创建带显式类型的 null Literal。
     * @param ty Static type of the null literal.
     * @param-zh ty null 字面量的静态类型。
     * @return Null literal value.
     * @return-zh null 字面量值。
     */
    public static func get(ty: Type): NullLiteral { return NullLiteral(ty) }
}

/**
 * @description Base class for CHIR expressions.
 * @description-zh CHIR 表达式的基类。
 * @param ty Static type of the expression.
 * @param-zh ty 表达式的静态类型。
 */
public abstract class Expression <: Value {
    /**
     * @description Basic block that owns this expression.
     * @description-zh 拥有该表达式的 Block。
     * @type { Block }
     */
    public prop owner: Block {
        get() { return Block() }
    }

    public init(ty: Type) {
        super(ty)
    }
}

/**
 * @description Represents a basic block containing an ordered expression list.
 * @description-zh 表示包含有序表达式列表的基本块。
 */
public class Block {
    /**
     * @description Ordered expressions contained in the block.
     * @description-zh Block 中按顺序保存的表达式。
     * @type { Array<Expression> }
     */
    public prop exprs: Array<Expression> {
        get() { return Array<Expression>() }
    }

    /**
     * @description Creates an empty basic block.
     * @description-zh 创建空基本块。
     */
    public init() {}

    /**
     * @description Inserts an expression at the requested index.
     * @description-zh 在指定索引处插入表达式。
     * @param expr Expression to insert.
     * @param-zh expr 要插入的表达式。
     * @param index Zero-based insertion index.
     * @param-zh index 从 0 开始的插入索引。
     * @return Unit after the expression is inserted.
     * @return-zh 表达式插入完成后返回 Unit。
     */
    public func insertExpr(expr: Expression, index: Int64): Unit {}
}

/**
 * @description Represents a group of related basic blocks with one entry block.
 * @description-zh 表示一组拥有同一个入口块的相关基本块。
 */
public class BlockGroup {
    /**
     * @description Entry block for this block group.
     * @description-zh 该 BlockGroup 的入口 Block。
     * @type { Block }
     */
    public let entryBlock: Block

    /**
     * @description Creates a block group with one entry block.
     * @description-zh 创建包含一个入口 Block 的 BlockGroup。
     */
    public init() {
        this.entryBlock = Block()
    }

    /**
     * @description Appends a new block to this block group.
     * @description-zh 向该 BlockGroup 追加新的 Block。
     * @return Newly appended block.
     * @return-zh 新追加的基本块。
     */
    public func appendBlock(): Block {
        return Block()
    }
}

/**
 * @description Base visitor for walking CHIR expressions and blocks.
 * @description-zh 用于遍历 CHIR 表达式和基本块的访问器基类。
 */
public abstract class CHIRVisitor {
    /**
     * @description Creates a CHIR visitor.
     * @description-zh 创建 CHIR visitor。
     */
    public init() {}

    /**
     * @description Visits one expression.
     * @description-zh 访问一个表达式。
     * @param expr Expression being visited.
     * @param-zh expr 正在访问的表达式。
     * @return Traversal action for this expression.
     * @return-zh 此表达式对应的遍历动作。
     */
    public open func visit(expr: Expression): IRActionMode { return IRActionMode.Continue }

    /**
     * @description Visits one basic block.
     * @description-zh 访问一个基本块。
     * @param block Block being visited.
     * @param-zh block 正在访问的基本块。
     * @return Traversal action for this block.
     * @return-zh 此基本块对应的遍历动作。
     */
    public open func visit(block: Block): IRActionMode { return IRActionMode.Continue }
}

/**
 * @description Stores a function-like signature name, type, and generic parameters.
 * @description-zh 保存类函数签名的名称、类型和泛型参数。
 */
public class FuncSigInfo <: ToString {
    /**
     * @description Logical name of the symbol.
     * @description-zh 符号的逻辑名称。
     * @type { String }
     */
    public let name: String

    /**
     * @description Function type for the signature.
     * @description-zh 签名对应的函数类型。
     * @type { FuncType }
     */
    public let ty: FuncType

    /**
     * @description Generic type parameters in declaration order.
     * @description-zh 按声明顺序排列的泛型类型参数。
     * @type { Array<GenericType> }
     */
    public let genericTypeParams: Array<GenericType>

    /**
     * @description Builds a signature view from a display name, function type, and generic parameters.
     * @description-zh 根据显示名称、函数类型和泛型参数构造签名视图。
     * @param name Logical name of the symbol.
     * @param-zh name 符号的逻辑名称。
     * @param ty Function type for the signature.
     * @param-zh ty 签名对应的函数类型。
     * @param genericTypeParams Generic type parameters in declaration order.
     * @param-zh genericTypeParams 按声明顺序排列的泛型类型参数。
     */
    public init(name: String, ty: FuncType, genericTypeParams!: Array<GenericType> = Array<GenericType>()) {
        this.name = name
        this.ty = ty
        this.genericTypeParams = genericTypeParams
    }

    /**
     * @description Returns the signature name.
     * @description-zh 返回签名名称。
     * @return Single-line textual form of this signature.
     * @return-zh 此签名的单行文本形式。
     */
    public func toString(): String {
        return name
    }
}

/**
 * @description Captures arguments, type arguments, and receiver information for a function call.
 * @description-zh 捕获函数调用的实参、类型实参和接收者信息。
 */
public class FuncCallContext {
    /**
     * @description Argument values passed to the call.
     * @description-zh 传给调用的实参值。
     * @type { Array<Value> }
     */
    public let args: Array<Value>

    /**
     * @description Type arguments used by a generic call.
     * @description-zh 泛型调用使用的类型实参。
     * @type { Array<Type> }
     */
    public let typeArgs: Array<Type>

    /**
     * @description Optional receiver value for member calls.
     * @description-zh 成员调用的可选接收者 Value。
     * @type { ?Value }
     */
    public let thisArg: ?Value

    /**
     * @description Creates a function-call context.
     * @description-zh 创建函数 call context。
     * @param args Argument values passed to the call.
     * @param-zh args 传给调用的实参值。
     * @param typeArgs Type arguments used by a generic call.
     * @param-zh typeArgs 泛型调用使用的类型实参。
     * @param thisArg Optional receiver value for member calls.
     * @param-zh thisArg 成员调用的可选接收者值。
     */
    public init(args: Array<Value>, typeArgs: Array<Type>, thisArg: ?Value) {
        this.args = args
        this.typeArgs = typeArgs
        this.thisArg = thisArg
    }
}

/**
 * @description Captures receiver, signature, and argument context for an invoke call.
 * @description-zh 捕获 invoke 调用的接收者、签名和实参上下文。
 */
public class InvokeCallContext {
    /**
     * @description Receiver value for the invocation.
     * @description-zh invoke 调用使用的接收者值。
     * @type { Value }
     */
    public let receiver: Value

    /**
     * @description Resolved function signature.
     * @description-zh 已解析的函数签名。
     * @type { FuncSigInfo }
     */
    public let sig: FuncSigInfo

    /**
     * @description Argument and type-argument context for the invocation.
     * @description-zh invoke 调用的实参和类型实参上下文。
     * @type { FuncCallContext }
     */
    public let callContext: FuncCallContext

    /**
     * @description Creates an invoke-call context.
     * @description-zh 创建 invoke 调用上下文。
     * @param receiver Receiver value for the invocation.
     * @param-zh receiver invoke 调用使用的接收者值。
     * @param sig Resolved function signature.
     * @param-zh sig 已解析的函数签名。
     * @param callContext Argument and type-argument context for the invocation.
     * @param-zh callContext 此次 invoke 的实参和类型实参上下文。
     */
    public init(receiver: Value, sig: FuncSigInfo, callContext: FuncCallContext) {
        this.receiver = receiver
        this.sig = sig
        this.callContext = callContext
    }
}

/**
 * @description Allocates storage for a value of the given type.
 * @description-zh 为给定类型的值分配存储。
 */
public class Allocate <: Expression { public init(ty: Type) { super(RefType.get(ty)) }; public static func create(ty: Type): Allocate { return Allocate(ty) } }

/**
 * @description Allocates storage on a path that may branch to exceptional control flow.
 * @description-zh 在可能分支到异常控制流的路径上分配存储。
 */
public class TryAllocate <: Expression { public init(ty: Type) { super(RefType.get(ty)) } }

/**
 * @description Represents a binary operation over two operands.
 * @description-zh 表示作用于两个操作数的二元运算。
 */
public class BinaryExpression <: Expression { public mut prop overflow: OverflowStrategy { get() { return OverflowStrategy.NA } set(value) {} }; public init(kind: BinaryExprKind, leftOp: Value, rightOp: Value) { super(leftOp.ty) }; public static func create(kind: BinaryExprKind, leftOp: Value, rightOp: Value): BinaryExpression { return BinaryExpression(kind, leftOp, rightOp) } }

/**
 * @description Represents a binary operation with normal and exceptional successors.
 * @description-zh 表示带正常和异常后继的二元运算。
 */
public class TryBinaryExpression <: Expression { public mut prop overflow: OverflowStrategy { get() { return OverflowStrategy.NA } set(value) {} }; public init(kind: BinaryExprKind, leftOp: Value, rightOp: Value, normal: Block, err: Block) { super(leftOp.ty) } }

/**
 * @description Branches to one of two target blocks based on a condition value.
 * @description-zh 根据条件值分支到两个目标基本块之一。
 */
public class Branch <: Expression { public init(condition: Value, trueTarget: Block, falseTarget: Block) { super(UnitType.get()) } }

/**
 * @description Wraps a literal value as a CHIR expression.
 * @description-zh 将字面量值包装为 CHIR expression。
 */
public class Constant <: Expression { public init(val: LiteralValue) { super(val.ty) }; public static func create(val: LiteralValue): Constant { return Constant(val) } }

/**
 * @description Carries source-debug information through the expression stream.
 * @description-zh 在 expression 流中携带源码调试信息。
 */
public class Debug <: Expression { public init(location: Value, srcCodeName: String) { super(UnitType.get()) } }

/**
 * @description Terminates execution of the current control-flow path.
 * @description-zh 终止当前控制流路径的执行。
 */
public class Exit <: Expression { public init() { super(UnitType.get()) }; public static func create(): Exit { return Exit() } }

/**
 * @description Reads a field by structural path.
 * @description-zh 按结构路径读取字段。
 */
public class Field <: Expression { public init(value: Value, path: ArrayList<UInt64>) { super(value.ty) } }

/**
 * @description Reads a field by source-level field names.
 * @description-zh 按源码层字段名读取字段。
 */
public class FieldByName <: Expression { public init(value: Value, fieldNames: ArrayList<String>) { super(value.ty) } }

/**
 * @description Applies a callable value using a function-call context.
 * @description-zh 使用函数调用上下文调用可调用值。
 */
public class Apply <: Expression { public init(callee: Value, funcCallCtx: FuncCallContext) { super(UnitType.get()) } }

/**
 * @description Applies a callable value with normal and exceptional successors.
 * @description-zh 调用可调用值，并指定正常和异常后继。
 */
public class TryApply <: Expression { public init(callee: Value, funcCallCtx: FuncCallContext, normal: Block, err: Block) { super(UnitType.get()) } }

/**
 * @description Calls a compiler intrinsic returning the given type.
 * @description-zh 调用返回给定类型的编译器 intrinsic。
 */
public class Intrinsic <: Expression { public init(retTy: Type) { super(retTy) } }

/**
 * @description Calls a compiler intrinsic with normal and exceptional successors.
 * @description-zh 调用带正常和异常后继的编译器 intrinsic。
 */
public class TryIntrinsic <: Expression { public init(retTy: Type) { super(retTy) } }

/**
 * @description Invokes a resolved function signature.
 * @description-zh 执行已解析函数签名的 invoke 调用。
 */
public class Invoke <: Expression { public init(retTy: Type, callContext: InvokeCallContext) { super(retTy) } }

/**
 * @description Invokes a resolved function signature with normal and exceptional successors.
 * @description-zh 执行带正常和异常后继的已解析函数签名 invoke 调用。
 */
public class TryInvoke <: Expression { public init(retTy: Type, callContext: InvokeCallContext, normal: Block, err: Block) { super(retTy) } }

/**
 * @description Gets an aggregate element by field name.
 * @description-zh 按字段名获取聚合值元素。
 */
public class GetElementByName <: Expression { public init(location: Value, fieldNames: ArrayList<String>) { super(location.ty) } }

/**
 * @description Gets an aggregate element by field index path.
 * @description-zh 按字段索引路径获取聚合值元素。
 */
public class GetElementRef <: Expression { public init(location: Value, path: ArrayList<UInt64>) { super(location.ty) } }

/**
 * @description Reads the current exception object.
 * @description-zh 读取当前异常对象。
 */
public class GetException <: Expression { public init(retTy: Type) { super(retTy) } }

/**
 * @description Instantiates a generic function value with concrete type arguments.
 * @description-zh 使用具体类型实参实例化泛型函数值。
 */
public class GetInstantiateValue <: Expression { public init(value: Function, instantiateTypes: ArrayList<Type>) { super(value.ty) } }

/**
 * @description Reads runtime type information from a value.
 * @description-zh 从值中读取运行时类型信息。
 */
public class GetRTTI <: Expression { public init(value: Value) { super(value.ty) } }

/**
 * @description Reads runtime type information for a static type.
 * @description-zh 读取静态类型的运行时类型信息。
 */
public class GetRTTIStatic <: Expression { public init(rttiType: Type) { super(rttiType) } }

/**
 * @description Transfers control to a target block.
 * @description-zh 将控制流转移到目标基本块。
 */
public class GoTo <: Expression { public init(target: Block) { super(UnitType.get()) } }

/**
 * @description Tests whether a value is an instance of a target type.
 * @description-zh 测试某个值是否为目标类型的实例。
 */
public class InstanceOf <: Expression { public init(srcVal: Value, targetTy: Type) { super(BoolType.get()) } }

/**
 * @description Creates a function value from a lowered lambda body.
 * @description-zh 根据降级后的 lambda 函数体创建函数值。
 */
public class Lambda <: Expression { public init(ty: FuncType, mangledName: String, srcName: String, genericTypeParams: ArrayList<GenericType>) { super(ty) } }

/**
 * @description Loads a value from a location.
 * @description-zh 从位置加载值。
 */
public class Load <: Expression { public init(location: Value) { super(location.ty) } }

/**
 * @description Branches to one of several target blocks using integer case values.
 * @description-zh 根据整数 case 值分支到多个目标基本块之一。
 */
public class MultiBranch <: Expression { public init(condition: Value, defaultBlock: Block, targets: ArrayList<Block>, caseValues: ArrayList<UInt64>) { super(UnitType.get()) } }

/**
 * @description Converts a numeric value to another numeric type.
 * @description-zh 将数值转换为另一种数值类型。
 */
public class NumericCast <: Expression { public init(srcVal: Value, dstTy: Type, overflow: OverflowStrategy) { super(dstTy) } }

/**
 * @description Converts a numeric value with normal and exceptional successors.
 * @description-zh 转换数值，并指定正常和异常后继。
 */
public class TryNumericCast <: Expression { public init(srcVal: Value, dstTy: Type, normal: Block, err: Block) { super(dstTy) } }

/**
 * @description Raises an exception value.
 * @description-zh 抛出异常值。
 */
public class RaiseException <: Expression { public init(value: Value) { super(UnitType.get()) } }

/**
 * @description Allocates raw array storage.
 * @description-zh 分配 raw array 存储。
 */
public class RawArrayAllocate <: Expression { public init(elementType: Type, size: Value) { super(RawArrayType.get(elementType)) } }

/**
 * @description Allocates raw array storage with normal and exceptional successors.
 * @description-zh 分配 raw array 存储，并指定正常和异常后继。
 */
public class TryRawArrayAllocate <: Expression { public init(elementType: Type, size: Value, normal: Block, err: Block) { super(RawArrayType.get(elementType)) } }

/**
 * @description Initializes raw array storage with one repeated value.
 * @description-zh 使用一个重复值初始化 raw array 存储。
 */
public class RawArrayInitByValue <: Expression { public init(memory: Value, size: Value, initVal: Value) { super(UnitType.get()) } }

/**
 * @description Initializes raw array storage from literal element values.
 * @description-zh 用字面量元素值初始化 raw array 存储。
 */
public class RawArrayLiteralInit <: Expression { public init(memory: Value, elements: ArrayList<Value>) { super(UnitType.get()) } }

/**
 * @description Starts a concurrent task and returns its handle or result value.
 * @description-zh 启动并发任务，并返回其句柄或结果值。
 */
public class Spawn <: Expression { public init(retTy: Type, value: Value) { super(retTy) } }

/**
 * @description Starts a concurrent task with normal and exceptional successors.
 * @description-zh 启动并发任务，并指定正常和异常后继。
 */
public class TrySpawn <: Expression { public init(retTy: Type, value: Value, normal: Block, err: Block) { super(retTy) } }

/**
 * @description Stores a value into a location.
 * @description-zh 将值存入位置。
 */
public class Store <: Expression { public init(value: Value, location: Value) { super(UnitType.get()) } }

/**
 * @description Stores a value into an aggregate element selected by field name.
 * @description-zh 将值存入按字段名选中的聚合值元素。
 */
public class StoreElementByName <: Expression { public init(value: Value, location: Value, fieldNames: ArrayList<String>) { super(UnitType.get()) } }

/**
 * @description Stores a value into an aggregate element selected by field index path.
 * @description-zh 将值存入按字段索引路径选中的聚合值元素。
 */
public class StoreElementRef <: Expression { public init(value: Value, location: Value, path: ArrayList<UInt64>) { super(UnitType.get()) } }

/**
 * @description Builds a tuple expression from element values.
 * @description-zh 构建由元素值组成的 tuple expression。
 */
public class Tuple <: Expression { public init(elements: ArrayList<Value>) { super(TupleType.get(Array<Type>())) } }

/**
 * @description Boxes a value into a destination type.
 * @description-zh 将值装箱为目标类型。
 */
public class Box <: Expression { public init(srcVal: Value, dstTy: Type) { super(dstTy) } }

/**
 * @description Performs a statically checked type cast.
 * @description-zh 执行静态检查的类型转换。
 */
public class StaticCast <: Expression { public init(srcVal: Value, dstTy: Type) { super(dstTy) } }

/**
 * @description Casts a value to a concrete runtime type.
 * @description-zh 将值转换为具体运行时类型。
 */
public class CastToConcrete <: Expression { public init(srcVal: Value, targetType: Type) { super(targetType) } }

/**
 * @description Casts a value to a generic target type.
 * @description-zh 将值转换为泛型目标类型。
 */
public class CastToGeneric <: Expression { public init(srcVal: Value, targetType: Type) { super(targetType) } }

/**
 * @description Unboxes a boxed value as a reference.
 * @description-zh 将装箱值拆箱为引用。
 */
public class UnboxToRef <: Expression { public init(srcVal: Value, dstTy: Type) { super(RefType.get(dstTy)) } }

/**
 * @description Unboxes a boxed value as a plain value.
 * @description-zh 将装箱值拆箱为普通值。
 */
public class UnboxToValue <: Expression { public init(srcVal: Value, dstTy: Type) { super(dstTy) } }

/**
 * @description Represents a unary operation over one operand.
 * @description-zh 表示作用于一个操作数的一元运算。
 */
public class UnaryExpression <: Expression { public mut prop overflow: OverflowStrategy { get() { return OverflowStrategy.NA } set(value) {} }; public init(kind: UnaryExprKind, op: Value) { super(op.ty) } }

/**
 * @description Represents a unary operation with normal and exceptional successors.
 * @description-zh 表示带正常和异常后继的一元运算。
 */
public class TryUnaryExpression <: Expression { public init(op: Value, normal: Block, err: Block) { super(op.ty) } }

/**
 * @description Builds a fixed-length VArray value.
 * @description-zh 构建定长 VArray 值。
 */
public class VArrayBuilder <: Expression { public init(retTy: Type, size: Value, initVal: Value, initFunc: Value) { super(retTy) } }

/**
 * @description Represents a VArray literal expression.
 * @description-zh 表示 VArray 字面量 expression。
 */
public class VArrayExpr <: Expression { public init(elements: ArrayList<Value>) { super(VArrayType.get(TypeMirror.any(), 0)) } }

/**
 * @description Builds CHIR expressions and inserts them into a target block.
 * @description-zh 构建 CHIR 表达式并插入目标基本块。
 * @param parent Block that receives created expressions.
 * @param-zh parent 接收新建表达式的基本块。
 * @param position Insertion point for created expressions.
 * @param-zh position 新建表达式的插入位置。
 */
public class CHIRBuilder {
    /**
     * @description Creates a builder that appends to the given block.
     * @description-zh 创建向给定基本块末尾追加的 builder。
     * @param parent Block that receives created expressions.
     * @param-zh parent 接收新建表达式的基本块。
     */
    public init(parent: Block) {}

    /**
     * @description Creates a builder with an explicit insertion position.
     * @description-zh 创建使用显式插入位置的 builder。
     * @param position Insertion point for created expressions.
     * @param-zh position 新建表达式的插入位置。
     */
    public init(position: InsertPosition) {}

    /**
     * @description Creates an allocation expression at the current insertion point.
     * @description-zh 在当前插入点创建分配 expression。
     * @param ty Type to allocate.
     * @param-zh ty 要分配的类型。
     * @return Allocation expression.
     * @return-zh 分配表达式。
     */
    public func createAllocate(ty: Type): Allocate { return Allocate(ty) }

    /**
     * @description Creates a normal function call expression.
     * @description-zh 创建普通函数调用 expression。
     * @param callee Callable value to invoke.
     * @param-zh callee 要调用的可调用值。
     * @param funcCallCtx Arguments and receiver for the call.
     * @param-zh funcCallCtx 此次调用的实参和接收者。
     * @return Apply expression.
     * @return-zh Apply 表达式。
     */
    public func createApply(callee: Value, funcCallCtx: FuncCallContext): Apply { return Apply(callee, funcCallCtx) }

    /**
     * @description Creates an addition expression with overflow metadata.
     * @description-zh 创建带溢出元数据的加法 expression。
     * @param leftOp Left operand.
     * @param-zh leftOp 左操作数。
     * @param rightOp Right operand.
     * @param-zh rightOp 右操作数。
     * @param overflow Overflow behavior for the operation.
     * @param-zh overflow 此运算的溢出行为。
     * @return Binary expression for addition.
     * @return-zh 表示加法的二元表达式。
     */
    public func createBinaryAdd(leftOp: Value, rightOp: Value, overflow: OverflowStrategy): BinaryExpression { return BinaryExpression(BinaryExprKind.Add, leftOp, rightOp) }

    /**
     * @description Creates a subtraction expression with overflow metadata.
     * @description-zh 创建带溢出元数据的减法 expression。
     * @param leftOp Left operand.
     * @param-zh leftOp 左操作数。
     * @param rightOp Right operand.
     * @param-zh rightOp 右操作数。
     * @param overflow Overflow behavior for the operation.
     * @param-zh overflow 此运算的溢出行为。
     * @return Binary expression for subtraction.
     * @return-zh 表示减法的二元表达式。
     */
    public func createBinarySub(leftOp: Value, rightOp: Value, overflow: OverflowStrategy): BinaryExpression { return BinaryExpression(BinaryExprKind.Sub, leftOp, rightOp) }

    /**
     * @description Creates a multiplication expression with overflow metadata.
     * @description-zh 创建带溢出元数据的乘法 expression。
     * @param leftOp Left operand.
     * @param-zh leftOp 左操作数。
     * @param rightOp Right operand.
     * @param-zh rightOp 右操作数。
     * @param overflow Overflow behavior for the operation.
     * @param-zh overflow 此运算的溢出行为。
     * @return Binary expression for multiplication.
     * @return-zh 表示乘法的二元表达式。
     */
    public func createBinaryMul(leftOp: Value, rightOp: Value, overflow: OverflowStrategy): BinaryExpression { return BinaryExpression(BinaryExprKind.Mul, leftOp, rightOp) }

    /**
     * @description Creates a division expression with overflow metadata.
     * @description-zh 创建带溢出元数据的除法 expression。
     * @param leftOp Left operand.
     * @param-zh leftOp 左操作数。
     * @param rightOp Right operand.
     * @param-zh rightOp 右操作数。
     * @param overflow Overflow behavior for the operation.
     * @param-zh overflow 此运算的溢出行为。
     * @return Binary expression for division.
     * @return-zh 表示除法的二元表达式。
     */
    public func createBinaryDiv(leftOp: Value, rightOp: Value, overflow: OverflowStrategy): BinaryExpression { return BinaryExpression(BinaryExprKind.Div, leftOp, rightOp) }

    /**
     * @description Creates an equality comparison expression.
     * @description-zh 创建相等比较 expression。
     * @param leftOp Left operand.
     * @param-zh leftOp 左操作数。
     * @param rightOp Right operand.
     * @param-zh rightOp 右操作数。
     * @return Binary expression for equality comparison.
     * @return-zh 表示相等比较的二元表达式。
     */
    public func createBinaryEqual(leftOp: Value, rightOp: Value): BinaryExpression { return BinaryExpression(BinaryExprKind.Equal, leftOp, rightOp) }

    /**
     * @description Creates a conditional branch expression.
     * @description-zh 创建条件分支 expression。
     * @param condition Boolean condition value.
     * @param-zh condition 布尔条件值。
     * @param trueTarget Target block reached when condition is true.
     * @param-zh trueTarget 条件为 true 时到达的目标基本块。
     * @param falseTarget Target block reached when condition is false.
     * @param-zh falseTarget 条件为 false 时到达的目标基本块。
     * @return Branch expression.
     * @return-zh Branch 表达式。
     */
    public func createBranch(condition: Value, trueTarget: Block, falseTarget: Block): Branch { return Branch(condition, trueTarget, falseTarget) }

    /**
     * @description Creates a constant expression from a literal value.
     * @description-zh 由字面量值创建常量 expression。
     * @param val Literal value to wrap.
     * @param-zh val 要包装的字面量值。
     * @return Constant expression.
     * @return-zh Constant 表达式。
     */
    public func createConstant(val: LiteralValue): Constant { return Constant(val) }

    /**
     * @description Creates an exit expression.
     * @description-zh 创建 exit expression。
     * @return Exit expression.
     * @return-zh Exit 表达式。
     */
    public func createExit(): Exit { return Exit() }

    /**
     * @description Creates an invoke expression for a resolved function signature.
     * @description-zh 为已解析的函数签名创建 invoke expression。
     * @param retTy Return type of the invocation.
     * @param-zh retTy 此次调用的返回类型。
     * @param callContext Receiver, signature, and argument context.
     * @param-zh callContext 接收者、函数签名和实参上下文。
     * @return Invoke expression.
     * @return-zh Invoke 表达式。
     */
    public func createInvoke(retTy: Type, callContext: InvokeCallContext): Invoke { return Invoke(retTy, callContext) }

    /**
     * @description Creates a lambda expression.
     * @description-zh 创建 lambda expression。
     * @param ty Function type of the lambda.
     * @param-zh ty lambda 的函数类型。
     * @param mangledName Compiler-internal function name.
     * @param-zh mangledName 编译器内部函数名。
     * @param srcName Source-level lambda name.
     * @param-zh srcName 源码层面的 lambda 名称。
     * @param genericTypeParams Generic parameters captured by the lambda.
     * @param-zh genericTypeParams lambda 捕获的泛型参数。
     * @return Lambda expression.
     * @return-zh Lambda 表达式。
     */
    public func createLambda(ty: FuncType, mangledName: String, srcName: String, genericTypeParams!: Array<GenericType> = Array<GenericType>()): Lambda { return Lambda(ty, mangledName, srcName, ArrayList<GenericType>.of(genericTypeParams)) }

    /**
     * @description Creates a load expression.
     * @description-zh 创建 load expression。
     * @param location Location to read from.
     * @param-zh location 要读取的位置。
     * @return Load expression.
     * @return-zh Load 表达式。
     */
    public func createLoad(location: Value): Load { return Load(location) }

    /**
     * @description Creates a store expression.
     * @description-zh 创建 store expression。
     * @param value Value to write.
     * @param-zh value 要写入的值。
     * @param location Location to write into.
     * @param-zh location 要写入的位置。
     * @return Store expression.
     * @return-zh Store 表达式。
     */
    public func createStore(value: Value, location: Value): Store { return Store(value, location) }

    /**
     * @description Creates a tuple expression.
     * @description-zh 创建 tuple expression。
     * @param elements Tuple element values.
     * @param-zh elements 元组元素值。
     * @return Tuple expression.
     * @return-zh Tuple 表达式。
     */
    public func createTuple(elements: Array<Value>): Tuple { return Tuple(ArrayList<Value>.of(elements)) }

    /**
     * @description Creates a unary negation expression.
     * @description-zh 创建一元取负 expression。
     * @param op Operand to negate.
     * @param-zh op 要取负的操作数。
     * @param overflow Overflow behavior for the operation.
     * @param-zh overflow 此运算的溢出行为。
     * @return Unary expression for negation.
     * @return-zh 表示取负的一元表达式。
     */
    public func createUnaryNeg(op: Value, overflow: OverflowStrategy): UnaryExpression { return UnaryExpression(UnaryExprKind.Neg, op) }

    /**
     * @description Creates a throwing-aware function call expression.
     * @description-zh 创建可处理抛出路径的函数调用 expression。
     * @param callee Callable value to invoke.
     * @param-zh callee 要调用的可调用值。
     * @param funcCallCtx Arguments and receiver for the call.
     * @param-zh funcCallCtx 此次调用的实参和接收者。
     * @param normal Target block reached on normal completion.
     * @param-zh normal 正常完成时到达的目标基本块。
     * @param err Target block reached on exceptional completion.
     * @param-zh err 异常完成时到达的目标基本块。
     * @return TryApply expression.
     * @return-zh TryApply 表达式。
     */
    public func createTryApply(callee: Value, funcCallCtx: FuncCallContext, normal: Block, err: Block): TryApply { return TryApply(callee, funcCallCtx, normal, err) }

    /**
     * @description Creates a throwing-aware invoke expression.
     * @description-zh 创建可处理抛出路径的 invoke expression。
     * @param retTy Return type of the invocation.
     * @param-zh retTy 此次调用的返回类型。
     * @param callContext Receiver, signature, and argument context.
     * @param-zh callContext 接收者、函数签名和实参上下文。
     * @param normal Target block reached on normal completion.
     * @param-zh normal 正常完成时到达的目标基本块。
     * @param err Target block reached on exceptional completion.
     * @param-zh err 异常完成时到达的目标基本块。
     * @return TryInvoke expression.
     * @return-zh TryInvoke 表达式。
     */
    public func createTryInvoke(retTy: Type, callContext: InvokeCallContext, normal: Block, err: Block): TryInvoke { return TryInvoke(retTy, callContext, normal, err) }
}

/**
 * @description Checked exception for invalid CHIR construction or inconsistent IR state.
 * @description-zh 表示无效 CHIR 构造或 IR 状态不一致的受检异常。
 * @param message Human-readable error text.
 * @param-zh message 人类可读的错误文本。
 */
public class CHIRException <: Exception {
    /**
     * @description Creates an empty CHIR exception.
     * @description-zh 创建空的 CHIR 异常。
     */
    public init() { super() }

    /**
     * @description Creates a CHIR exception with a message.
     * @description-zh 创建带消息的 CHIR 异常。
     * @param message Human-readable error text.
     * @param-zh message 人类可读的错误文本。
     */
    public init(message: String) { super(message) }
}

/**
 * @description Deserializes a package from binary CHIR data.
 * @description-zh 从二进制 CHIR 数据反序列化包。
 * @param root Pointer to serialized CHIR bytes.
 * @param-zh root 指向序列化 CHIR 字节的指针。
 * @param length Number of bytes in the serialized buffer.
 * @param-zh length 序列化缓冲区中的字节数。
 * @return Deserialized package.
 * @return-zh 反序列化后的包。
 */
public func deserializePackage(root: CPointer<UInt8>, length: Int64): Package {
    return Package("mirror", AccessLevel.Public)
}

/**
 * @description Serializes a package into binary CHIR data.
 * @description-zh 将包序列化为二进制 CHIR 数据。
 * @param pkg Package to serialize.
 * @param-zh pkg 要序列化的包。
 * @return Pointer and byte length for the serialized package.
 * @return-zh 序列化包的指针和字节长度。
 */
public func serializePackage(pkg: Package): (CPointer<UInt8>, Int64) {
    return (CPointer<UInt8>(), 0)
}

/**
 * @description Releases shared serialization memory.
 * @description-zh 释放共享的序列化内存。
 * @return Unit after serialization memory has been released.
 * @return-zh 释放序列化内存后返回 Unit。
 */
public func freeSerializedMemory(): Unit {}

internal class TypeMirror {
    static func any(): Type {
        return UnitType.get()
    }
}
