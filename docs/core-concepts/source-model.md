<a id="source-model"></a>
# Source Model

Markit 的 source model 负责回答三个问题：

- 输入文本从哪里来，如何在流式场景中累积？
- AST 节点如何定位回原文？
- Unicode 文本如何同时满足解析性能和用户可见位置？

核心原则是：source 以 UTF-8 byte 为主存储，Markdown 结构扫描优先使用 ASCII byte；当需要用户字符语义、offset 输出或 Unicode 测试时，再按需计算 rune。

```text
String chunk / byte chunk / InputStream
  -> SourceBuffer
  -> Utf8StreamDecoder, for byte chunks
  -> LineScanner
  -> SourceLine + SourceSpan
  -> Node.sourceSpan
  -> DocumentSnapshot + LineIndex
```

## 为什么同时保留 byte 和 rune

仓颉 `String` 的大小和下标以 UTF-8 byte 为基础。Markdown 标记大多是 ASCII 字节，例如 `#`、`*`、`[`、`]`、`|`、`` ` ``，因此解析热路径使用 byte 扫描最直接、也最稳定。

但开发者和用户通常关心“第几个字符”，而不是“第几个 UTF-8 byte”。中文、日文、韩文、emoji 和混合文本中，一个 rune 可能占多个 byte。Markit 因此在 `SourceSpan` 中同时记录两套坐标：

- byte offset：适合文件、网络、UTF-8 slice、DOM source map、增量输入统计。
- rune offset：适合用户可见位置、诊断信息、JSON offset、Unicode 测试断言。

示例：

```text
文本: A你🙂
byte offset: 0..8
rune offset: 0..3
```

ASCII `A` 占 1 byte，`你` 占 3 byte，`🙂` 占 4 byte；用户看到的是 3 个 rune。

## SourceBuffer

`SourceBuffer` 保存 session 接收到的 source segment。输入可以来自 `feed(String)`、`feedBytes(Array<Byte>)` 或 `parse(InputStream)`。

```cangjie
public class SourceBuffer {
    public let retentionMode: SourceRetentionMode
    public prop byteSize: Int64

    public func append(chunk: String): Int64
    public func appendBytes(chunk: Array<Byte>): Int64
    public func view(span: SourceSpan): TextView
    public func cursor(span: SourceSpan): Cursor
    public func byteAt(byteOffset: Int64): Byte
    public func slice(startByte: Int64, endByte: Int64): String
    public func materialize(): String
    public func releaseRetainedSource(): Unit
    public func hasRetainedSource(): Bool
    public func retainsFullSource(): Bool
}
```

行为要点：

- `append(chunk: String)` 追加合法字符串 segment，并返回接收的 byte 数。
- `appendBytes(chunk: Array<Byte>)` 会 clone 输入 byte chunk，避免外部修改影响解析。
- `byteAt(...)` 和 parser 的结构扫描路径以 byte 为单位。
- `slice(...)` 与 `materialize()` 会构造字符串，适合调试、输出和少量语义需要，不应放进 parser 热循环。
- `releaseRetainedSource()` 会在 finalize 后按 retention mode 释放 source segment。

## SourceRetentionMode

source retention 控制 finalize 后是否保留原文。默认值是 `Essential`。

```cangjie
public enum SourceRetentionMode <: ToString {
    |None
    |Essential
    |Full
}
```

| 模式 | 行为 | 适合场景 |
| --- | --- | --- |
| `Essential` | 默认模式。finalize hooks 执行后释放完整 source；必要原文由节点或插件显式保留。 | 常规解析、文档构建、AI streaming。 |
| `Full` | finalize 后仍保留完整 source。 | 调试、round-trip、JSON `rawContent` 对比、source map 分析。 |
| `None` | 更积极地避免保留 source。 | 对内存敏感、只需要语义节点和最终输出的场景。 |

默认策略下，AST 节点主要保存语义字段和 `SourceSpan`。如果某类节点在 source 释放后仍必须持有原文，例如 HTML block、HTML inline 或插件自定义结构，parser 或插件应在节点上显式保存必要内容。

## TextView

`TextView` 是 source 上的范围视图，适合把一段 source 传给 parser 或调试工具。切片会产生新的 view，不会复制正文。

```cangjie
public class TextView {
    public let source: SourceBuffer
    public let span: SourceSpan
    public prop byteSize: Int64
    public prop runeSize: Int64

    public func cursor(): Cursor
    public func slice(startByteDelta: Int64, endByteDelta: Int64, startRuneDelta!: Int64 = 0, endRuneDelta!: Int64 = 0): TextView
    public func toString(): String
}
```

`toString()` 会调用 source slice，属于按需路径。解析器通常应优先使用 `Cursor` 或已有行文本，只有在确实需要 materialize 文本时才调用它。

## Cursor

`Cursor` 用于在 `TextView` 内扫描。它支持 byte 级移动，也支持按需 rune 解码。

```cangjie
public class Cursor {
    public func bytePosition(): Int64
    public func runePosition(): Int64
    public func atEnd(): Bool
    public func checkpoint(): CursorCheckpoint
    public func restore(checkpoint: CursorCheckpoint): Unit
    public func peekByte(): ?Byte
    public func advanceByte(): ?Byte
    public func peekRune(): ?Rune
    public func advanceRune(): ?Rune
}
```

推荐用法：

- 扫描 Markdown 标记时使用 `peekByte()` / `advanceByte()`。
- 处理用户文本、Unicode 分类或显示位置时使用 `peekRune()` / `advanceRune()`。
- parser 需要试探匹配时，用 `checkpoint()` 和 `restore(...)` 回退。

`Cursor` 会检查 UTF-8 宽度和 view 边界，避免从多字节字符中间读取 rune。

## SourceLine 与 LineIndex

`LineScanner` 把连续输入切成 `SourceLine`。它支持跨 chunk 拼接一行，识别 LF 和 CRLF，并把 CRLF 视为一个换行事件。

```cangjie
public class LineIndex {
    public prop size: Int64
    public func lineAt(index: Int64): SourceLine
    public func lines(): ArrayList<SourceLine>
    public func findByByteOffset(byteOffset: Int64): ?SourceLine
}
```

每个 `SourceLine` 包含：

- 行文本，不包含换行符。
- `SourceSpan`，通常覆盖行内容本身。
- `terminated`，表示这行是否由换行符结束。

`IncrementalSession` 处理每个 `SourceLine` 时会把它记录到 `ParseSession.lineIndex`。`DocumentSnapshot` 携带同一个索引，因此调用方可以按行号或 byte offset 回查 source line，用于诊断、编辑器定位和增量渲染。

## SourceSpan

`SourceSpan` 是节点定位的基础结构。

```cangjie
public struct SourceSpan {
    public let startByte: Int64
    public let endByte: Int64
    public let startRune: Int64
    public let endRune: Int64

    public static func empty(): SourceSpan
    public func merge(other: SourceSpan): SourceSpan
    public func slice(startByteDelta: Int64, endByteDelta: Int64, startRuneDelta: Int64, endRuneDelta: Int64): SourceSpan
}
```

约定：

- `startByte` / `endByte` 是半开区间，覆盖 UTF-8 byte 范围。
- `startRune` / `endRune` 是半开区间，覆盖 rune 范围。
- block 节点 span 通常覆盖语义内容，不一定包含换行符。
- 父节点 span 通常由子节点或多行内容 `merge(...)` 得到。

对于插件作者，最重要的是：创建节点时要让 byte 和 rune 同步推进。inline parser 的返回值中同时包含 `consumedBytes` 与 `consumedRunes`，就是为了避免 Unicode 文本中的 offset 漂移。

## Node 与 rawContent

`Node` 是 AST 的通用基类，专用节点在插件中继承它。

```cangjie
public open class Node {
    public let id: Int64
    public let kind: String
    public var sourceSpan: SourceSpan
    public var literal: String
    public var level: Int64
    public var slug: String
    public var info: String
    public var parent: ?Node
    public let children: ArrayList<Node>

    public func addChild(child: Node): Unit
    public func rawContent(): String
    public func stableHash(): Int64
}
```

节点保存语义字段、children、meta 和 `SourceSpan`。`rawContent()` 的返回策略是：

- 如果节点有显式 raw content override，优先返回 override。
- 如果 source 仍保留，则按 `sourceSpan` slice。
- 否则回退到 `literal`。

这意味着默认低内存路径下，finalize 后普通节点不一定还能 materialize 原文。需要原文语义的节点应在解析阶段显式保存必要内容。

## DocumentSnapshot

`DocumentSnapshot` 是一次解析完成后的可查询视图。它包含根节点、line index、node id 索引和前序节点列表。

```cangjie
public class DocumentSnapshot {
    public let root: Node
    public let lineIndex: LineIndex

    public func nodeCount(): Int64
    public func nodeById(id: Int64): ?Node
    public func nodesInByteRange(startByte: Int64, endByte: Int64): ArrayList<Node>
    public func lineAt(index: Int64): SourceLine
    public func stableHash(): Int64
}
```

常见用途：

- 用 `nodeById(...)` 将 AST patch 映射回 UI 节点。
- 用 `nodesInByteRange(...)` 找到与某段 source 相交的节点。
- 用 `lineAt(...)` 或 `lineIndex.findByByteOffset(...)` 做诊断定位。
- 用 `stableHash()` 做增量渲染缓存 key 或测试断言。它不是加密 hash。

## Unicode 策略

开发 Markit parser 或接入流式输入时，请记住这些规则：

- `String.size` 是 byte 长度。
- `String[index]` 是 byte 访问。
- `String.runes()` 适合按需遍历用户字符。
- `String.toRuneArray()` 会分配完整 rune 数组，不应放在解析热路径。
- `feed(String)` 适合输入端已经提供合法字符串 chunk 的场景。
- `feedBytes(Array<Byte>)` 适合文件、网络、AI SDK 或任意可能切开 UTF-8 多字节字符的 byte stream。
- `LineScanner` 识别 LF 和 CRLF；CRLF 会作为一个换行事件推进 rune offset。
- JSON 中会同时输出 rune offset 与 byte offset，方便用户定位和系统定位同时成立。

### feedBytes 的边界处理

`feedBytes(...)` 会先进入 `Utf8StreamDecoder`。如果一个 UTF-8 多字节字符被切在 chunk 边界，decoder 会暂存不完整 byte，等后续 chunk 补齐后再产出字符串。

```cangjie
let markdown = "# 中文🙂\n"
let session = Markit().createSession()

for (byte in markdown.toArray()) {
    session.feedBytes([byte])
}

session.finalize()
println(session.toHtml())
```

行为要点：

- 多字节字符可以被切在任意 byte 边界。
- 非法 UTF-8 会抛出 `IllegalArgumentException("Invalid utf8 byte sequence.")`。
- `finalize()` 时如果 decoder 中仍有未补齐 byte，也会抛出异常。

## 低内存使用建议

大文档和 AI streaming 场景中，source model 的低内存价值主要来自三点：

- AST 节点保存语义字段和 span，不默认复制整段原文。
- 稳定 HTML 可以通过 `emittedHtmlFragments` 或 `writeHtml(out)` 流式消费。
- finalize 后 `Essential` 和 `None` 模式会释放可回收 source。

推荐实践：

- 只需要最终输出时，使用 `writeHtml`、`writeMarkdown`、`writeTypst` 或 `writeJson`。
- 需要 UI streaming 时，消费 `emittedHtmlFragments`，把 `pendingTailState.previewText` 放在临时预览区。
- 需要调试 source 或对比 raw content 时，把 `sourceRetentionMode` 设置为 `SourceRetentionMode.Full`。
- 编写插件时，只为真正需要原文语义的节点保存 raw content override。
