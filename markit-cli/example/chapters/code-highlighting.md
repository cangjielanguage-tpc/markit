# :zh{代码高亮}: :en{Code Highlighting}:

::{本章专门放代码块，用来验证 Typst 导出的代码区域结构。}:

:::zh
## Cangjie 示例

下面的代码块包含导入、函数、字符串、注释和控制流。
:::

:::en
## Cangjie Sample

The following block includes imports, a function, strings, comments, and control flow.
:::

```cangjie
import markit.{Markit}
import markit.bundles.GFMBundle

main(): Int64 {
    // Create parser
    let markit = Markit().use(GFMBundle())
    let result = markit.parse("# Hello World\n\nThis is **Markit**.")

    if (result.success) {
        println(result.document.toHtml())
    }

    return 0
}

class B <: A {
    var x = 5 // xxx

    func f(x!: Int32 = 7) { // xxx
    }
}

class Derived1 <: Base { var age: UInt8 = 18 }

// Compile with cjc --init-overflow staurating test.cj
// this files'x name is test.cj

@OverflowWrapping
func test2(x: Int8, y: Int8) {
    let z = x + y // xxxx
}

func test3(x: Int8, y: Int8) {
    let z = x + y // the be
}

func g() {
    let x: C // ok, find p.C
    let y: p.C // ok
    let name = "cj"
    let message = "hello ${name}, ${Result.Ok(1)}"
    var bool1 = false
    var bool2 = true
    bool2 &&= bool1
}

var res4 = a |> g<Int32>
let res = a |> obj
let compose = f ~> objB
let compose2 = f<Int32> ~> objB
let compose3 = f ~> objB<Int32>
```

:::zh
## Cangjie 最小复现

下面这个例子专门用于检查类型名、浮点字面量和普通变量名在比较表达式中的高亮是否一致。
:::

:::en
## Cangjie Minimal Repro

The block below is used to verify whether type names, floating literals, and plain variable identifiers are highlighted consistently inside a comparison expression.
:::

```cangjie
let x = Float64
var y = 3.14
var z = x < y // z = false
```

:::zh
## Cangjie 类型声明与递归类型

下面这个例子用于检查类型别名、enum、struct、泛型参数和递归类型在声明位置的高亮是否一致。
:::

:::en
## Cangjie Type Declarations and Recursive Types

The block below is used to verify whether type aliases, enums, structs, generic parameters, and recursive types are highlighted consistently in declaration positions.
:::

```cangjie
type Type1 = (Int64) -> Type1
type Type2 = (Int64, Type2)

enum TimeUnit2 {
    Day | Month | Year
}

type Time = TimeUnit2

enum Option<T> {
    Some<T> | None
}

enum TimeUnit3<T1, T2> {
    Pair(T1, T2)
}

enum TimeUnit5 {
    | TwoUnit(TimeUnit5, TimeUnit5)
}

class C<U> <: B & I1<U> & I2 where U <: A {}
extend <T> Foo<T> <: I1 & I2 & I3 {}
extend<T> Foo<T> <: I4 where T <: I1 & I2 & I3 {}

struct TimeTree {
    let value: Int64
    let children: Array<TimeTree>
}
```

:::zh
## Cangjie 枚举构造器与模式匹配

下面这个例子用于检查枚举构造器在声明位置，以及 `case` 模式匹配里的高亮是否一致。
:::

:::en
## Cangjie Enum Constructors and Pattern Matching

The block below is used to verify whether enum constructors are highlighted consistently in declaration positions and in `case` patterns.
:::

```cangjie
enum E {
    | mkE
    | mkE()
    | B(Bool)
}
```

```cangjie
match (value) {
    case mkE => 0
    case mkE() => 1
    case B(flag) => if (flag) { 2 } else { 3 }
}

let time4 = Year
```

:::zh
## Cangjie 限定访问与调用

下面这个例子用于检查 `Xxx.Yyy`、`Xxx.Yyy()`、泛型构造器调用，以及尾随 lambda 调用的高亮是否正确。
:::

:::en
## Cangjie Qualified Access and Calls

The block below is used to verify whether `Xxx.Yyy`, `Xxx.Yyy()`, generic constructor calls, and trailing-lambda calls are highlighted consistently.
:::

```cangjie
let a = Result.Ok
let b = Result.Ok(1)
let c = TimeUnit3.Pair(1, 2)
let d = Rect<Int32>(11)
let e = Result.Ok<Int32>(1)
let f1 = Option<(Int64) -> Int64>.None
let t1 = Option<(Int64, Int64, Int64)>.None
let opt = Option<Bool>.None
let opInt32_2 = Option<Int32>.None // the type of 'opInt32_2' is 'Option<Int32>'
let expr = p.A
let y: p.C
let number = x.getOrThrow { Exception("None") }
match (value) {
    case Result.Ok(payload) => payload
    case Result.Err() => 0
    case TimeUnit3.Pair(left, right) => left + right
    case TimeUnit5.TwoUnit(left, right) => left
    case Option<Bool>.Some(value) => value
    case Option<Bool>.None => false
}
```

```cangjie
match (tree) {
    case TimeUnit5.TwoUnit(TimeUnit5.TwoUnit(left, right), leaf) => left
    case Result.Ok(Result.Ok(inner)) => inner
    case Result.Err(Result.Err(code)) => code
    case Option<Bool>.Some(Option<Bool>.Some(value)) => value
    case Option<Bool>.Some(Option<Bool>.None) => false
}
```

```cangjie
match (broken) {
    case x | x => 0
    case Some(x) | Some(x) => x
    case x: Int64 | x: String => x
    case Year(y) | Month(y, _) => y
    case Year(y) where y > x => y
    case Some(v) => Some(v.b)
    case None => None<U1>
}
```

```cangjie
while (let Some(1) | Some(a) <- x) { break }
while (let Option.Some(1) | Option.Some(a) <- x) { break }
```

:::zh
## ANTLR4 示例

这个例子应该能验证 grammar、rule、token 和字符串字面量的高亮。
:::

:::en
## ANTLR4 Sample

This example should validate grammar, rules, tokens, and string literal highlighting.
:::

```antlr4
grammar Hello;

document
  : greeting EOF
  ;

greeting
  : HELLO name=IDENTIFIER
  ;

HELLO: 'hello';
IDENTIFIER: [a-zA-Z_][a-zA-Z_0-9]*;
WS: [ \t\r\n]+ -> skip;
```

## :zh{相关链接}: :en{Related Links}:

- [概览](../README.md)
- [版式检查](layout-checks.md)
