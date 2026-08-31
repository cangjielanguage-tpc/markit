<a id="streaming"></a>
# 流式与增量解析

`IncrementalSession` 是 Markit 的流式解析会话。完整字符串解析、`InputStream`、callbacks、AI streaming、编辑器预览和手动 chunk feed 都建立在同一套 session 行为上。

它做的事情包括：

- 接收字符串或 byte chunk。
- 维护 open block、pending paragraph 和 UTF-8 decoder。
- 在 block 稳定时提交 AST 节点。
- 生成稳定 HTML fragment。
- 记录插件产生的 AST patch。
- 在 `finalize()` 时收尾并返回最终 update。

```cangjie
import markit.Markit

let session = Markit().createSession()

let first = session.feed("# 标")
let second = session.feed("题\n\n段落\n\n")
let finalUpdate = session.finalize()

println(finalUpdate.isFinal)
println(session.toHtml())
```

核心入口：

```cangjie
public func feed(chunk: String): IncrementalUpdate
public func feedBytes(chunk: Array<Byte>): IncrementalUpdate
public func finalize(): IncrementalUpdate
public func snapshot(): DocumentSnapshot
```

## 解析生命周期

一个 session 的生命周期非常明确：

1. `Markit.createSession(options)` 创建独立会话。
2. 调用 `feed(...)` 或 `feedBytes(...)` 输入任意数量的 chunk。
3. 每次 feed 后消费 `IncrementalUpdate`。
4. 输入结束时调用 `finalize()`。
5. 使用 `snapshot()` 或输出 API 读取最终结果。

```cangjie
let parser = Markit()
let session = parser.createSession()

for (line in ["# 标题\n", "\n", "第一段"]) {
    let update = session.feed(line)
    consumeUpdate(update)
}

let done = session.finalize()
consumeUpdate(done)

let snapshot = session.snapshot()
println(snapshot.root.toMarkdown())
```

`finalize()` 后 session 进入结束状态，继续 feed 会抛出 `IllegalArgumentException("Cannot feed after finalize")`。解析下一份文档时，请从同一个 parser 创建新的 session。

## feed

`feed(chunk: String)` 适合输入端已经给出合法 Cangjie `String` 的场景，例如编辑器内容、按行读取、WebSocket 文本消息或 AI SDK 已解码 token。

```cangjie
let session = Markit().createSession()

session.feed("# 标题")
session.feed("\n\n第一段")

let update = session.finalize()
println(update.sealedBlocks.size)
```

`feed` 可以接收任意长度字符串，不要求按行切分。Markit 会在内部用 line scanner 缓存未完成的行：没有换行结尾的 paragraph、fenced code、list、table 和 HTML block 都会保留在 pending/open 状态。

## feedBytes

`feedBytes(chunk: Array<Byte>)` 适合文件、网络、CLI 管道、AI SDK bytes 或任何可能切开 UTF-8 多字节字符的输入。它会缓冲尚未完整的 UTF-8 序列，直到后续 byte 补齐。

```cangjie
let markdown = "# 中文标题\n\n段落含 emoji 🚀\n"
let session = Markit().createSession()

for (byte in markdown.toArray()) {
    session.feedBytes([byte])
}

session.finalize()
println(session.toHtml())
```

非法 UTF-8 会抛出 `IllegalArgumentException("Invalid utf8 byte sequence.")`。如果 `finalize()` 时仍有未补齐 pending bytes，也会抛出异常。

`feed(String)` 与 `feedBytes(Array<Byte>)` 的选择：

| 输入形态 | 推荐入口 |
| --- | --- |
| 已解码文本、按行输入、编辑器字符串 | `feed(chunk: String)` |
| 文件读取、网络读取、AI SDK bytes | `feedBytes(chunk: Array<Byte>)` |
| 可能切开中文、日文、韩文、emoji 等 UTF-8 字符 | `feedBytes(chunk: Array<Byte>)` |
| 一次性完整文档字符串 | `parse(markdown: String)` |
| 标准 `InputStream` | `parse(input: InputStream)` |

## finalize

`finalize()` 完成收尾工作，并返回最后一次 `IncrementalUpdate`。它会：

- 完成 UTF-8 decoder 检查。
- flush line scanner 中最后一行。
- 提交 pending paragraph。
- finalize 打开的 continuation block，例如 fenced code、HTML block、math block、table、footnote definition 或 i18n block。
- 执行 session finalize hooks 与 post finalize hooks。
- drain AST patches。
- 根据 source retention 策略释放可回收 source。

```cangjie
let session = Markit().createSession()
session.feed("```cj\nlet x = 1")

let finalUpdate = session.finalize()

println(finalUpdate.isFinal)
println(finalUpdate.sealedBlocks.size)
```

许多插件会在 finalize 阶段完成回补。例如 reference link、footnote、i18n 和 TOC 相关流程可能需要读完整文档后更新先前节点。调用方应始终消费 final update 的 `astPatches`。

## snapshot

`snapshot()` 返回当前 `DocumentSnapshot`，包含 root 和 line index。它不会结束 session，也不会提交 pending tail。

```cangjie
let session = Markit().createSession()
session.feed("# 标题\n\n未结束段落")

let live = session.snapshot()
println(live.root.children.size)

session.finalize()
let finalSnapshot = session.snapshot()
println(finalSnapshot.root.children.size)
```

feed 过程中读取 snapshot 适合结构预览、调试或低频索引刷新。用户界面的实时正文预览更适合使用 `emittedHtmlFragments` 加 `pendingTailState.previewText`，因为 pending tail 还不是稳定 AST 节点。

## IncrementalUpdate

每次 `feed(...)`、`feedBytes(...)` 和 `finalize()` 都返回 `IncrementalUpdate`。

```cangjie
public class IncrementalUpdate {
    public let sealedBlocks: ArrayList<Node>
    public let emittedHtmlFragments: ArrayList<HtmlFragment>
    public let astPatches: ArrayList<AstPatch>
    public let pendingTailState: PendingTailState
    public let bytesAccepted: Int64
    public let bytesCommitted: Int64
    public let isFinal: Bool
}
```

字段语义：

| 字段 | 说明 |
| --- | --- |
| `sealedBlocks` | 本次 update 中稳定提交的 top-level block。 |
| `emittedHtmlFragments` | 本次 sealed block 对应的 HTML 片段，受 `emitHtmlFragments` 控制。 |
| `astPatches` | finalize 或插件产生的 AST patch。 |
| `pendingTailState` | 尚未稳定的尾部状态。 |
| `bytesAccepted` | 本次 feed 接收的 byte 数。 |
| `bytesCommitted` | final update 中提交的 source 总 byte 数。 |
| `isFinal` | 是否来自 `finalize()`。 |

典型消费方式：

```cangjie
func consumeUpdate(update: IncrementalUpdate): Unit {
    for (fragment in update.emittedHtmlFragments) {
        appendStableHtml(fragment.nodeId, fragment.html)
    }

    for (patch in update.astPatches) {
        replaceRenderedNode(patch.nodeId, patch.html)
    }

    if (update.pendingTailState.hasPendingContent()) {
        renderPreview(update.pendingTailState.previewText)
    }
}
```

稳定 block 可以追加到 UI 或索引；pending tail 只应作为临时预览；patch 需要按 `nodeId` 更新已经渲染的内容。

## PendingTailState

```cangjie
public class PendingTailState {
    public let summary: String
    public let openBlockKind: String
    public let pendingParagraphLineCount: Int64
    public let startByteOffset: Int64
    public let endByteOffset: Int64
    public let startRuneOffset: Int64
    public let endRuneOffset: Int64
    public let previewText: String

    public func hasPendingContent(): Bool
}
```

`PendingTailState` 用于 UI 预览和流结束前的状态判断：

- 打开的 fenced code、HTML block、math block、table、footnote definition、i18n block 等会设置 `openBlockKind`。
- 未 seal 的 paragraph 会设置 `openBlockKind = "Paragraph"` 和 `pendingParagraphLineCount`。
- offset 同时提供 byte/rune 两套坐标。
- `previewText` 受 `ParseOptions.emitPreview` 控制。

```cangjie
let update = session.feed("```cj\nlet x = 1")

if (update.pendingTailState.hasPendingContent()) {
    println(update.pendingTailState.openBlockKind)
    println(update.pendingTailState.previewText)
}
```

如果实时预览成本较高，可以把 `emitPreview` 设为 `false`，只保留 pending 状态和 offset。

```cangjie
import markit.core.session.ParseOptions

let session = Markit().createSession(options: ParseOptions(emitPreview: false))
```

## HtmlFragment

```cangjie
public class HtmlFragment {
    public let nodeId: Int64
    public let sourceSpan: SourceSpan
    public let html: String
    public let stable: Bool
}
```

HTML fragment 是已经稳定的 top-level block 输出。fragment 携带 `nodeId` 与 `sourceSpan`，前端可以把它映射到 DOM 节点、虚拟列表项、服务端推送事件或增量索引记录。

```cangjie
let update = session.feed("# 标题\n\n段落\n\n")

for (fragment in update.emittedHtmlFragments) {
    appendStableHtml(fragment.nodeId, fragment.html)
}
```

如果 `ParseOptions.emitHtmlFragments` 为 `false`，`emittedHtmlFragments` 会为空，但 AST、snapshot 和最终输出仍然可用。

```cangjie
let session = Markit().createSession(options: ParseOptions(
    emitHtmlFragments: false
))
```

## AstPatch

```cangjie
public enum AstPatchKind {
    | InsertNode
    | ReplaceNode
    | UpdateNode
    | UpdateNodeMeta
    | RemoveNode
}

public class AstPatch {
    public let kind: AstPatchKind
    public let parentNodeId: Int64
    public let nodeId: Int64
    public let sourceSpan: SourceSpan
    public let node: ?Node
    public let html: String
    public let markdown: String
    public let typst: String
}
```

patch 用于表达“已有节点需要被更新”。reference link、footnote、i18n 等能力可以在后续输入或 finalize 阶段补充信息，再通过 patch 更新先前节点。调用方通常按 `nodeId` 找到当前 DOM 或当前 AST，并用 patch 中的新 HTML/Markdown/Typst 替换对应输出。

```cangjie
for (patch in update.astPatches) {
    match (patch.kind) {
        case ReplaceNode => replaceRenderedNode(patch.nodeId, patch.html)
        case RemoveNode => removeRenderedNode(patch.nodeId)
        case _ => updateRenderedNode(patch.nodeId, patch.html)
    }
}
```

## InputStream 与 chunk

`parse(input: InputStream)` 内部读取 byte chunk 并调用 `feedBytes(...)`。paragraph、fenced code、list、table、HTML block、math block、footnote definition、i18n block 和插件 session state 都会跨 chunk 保留。

```cangjie
import std.io.ByteBuffer
import markit.Markit

let input = ByteBuffer("# 标题\n\n段落".toArray())
let out = Markit().parse(input)

println(out.toHtml())
```

如果需要控制 chunk 大小、实时消费每次 update，或在同一输入流中挂接自定义 backpressure，请手动创建 session。

```cangjie
let session = Markit().createSession()
let bytes = "# 中文标题\n\n段落\n".toArray()
var index: Int64 = 0

while (index < bytes.size) {
    let end = min(index + 64, bytes.size)
    let update = session.feedBytes(bytes[index..end])
    consumeUpdate(update)
    index = end
}

consumeUpdate(session.finalize())
```

chunk 大小不影响最终 AST，但会影响 update 数量、fragment 粒度和回调频率。UI streaming 通常选择较小 chunk 以提升响应速度；批量导入和 CLI 任务通常选择较大 chunk 以降低调度开销。

## Callbacks

`ParseCallbacks` 是结构化流式事件层。它可以配合 `parseWithCallbacks(markdown, callbacks)` 或 `parseWithCallbacks(input, callbacks)` 使用。

```cangjie
import markit.{Markit, ParseCallbacks}
import markit.core.document.DocumentSnapshot
import markit.core.incremental.{AstPatch, HtmlFragment, IncrementalUpdate, PendingTailState}
import markit.core.nodes.Node

let callbacks = ParseCallbacks(
    onUpdate: { update: IncrementalUpdate =>
        println("update final=${update.isFinal}")
    },
    onBlockSealed: { node: Node =>
        println("sealed ${node.kind}")
    },
    onHtmlFragment: { fragment: HtmlFragment =>
        println(fragment.html)
    },
    onAstPatch: { patch: AstPatch =>
        println("patch node=${patch.nodeId}")
    },
    onTailChanged: { tail: PendingTailState =>
        println(tail.summary)
    },
    onFinalize: { snapshot: DocumentSnapshot =>
        println(snapshot.root.toHtml())
    }
)

let out = Markit().parseWithCallbacks("# 标题\n\n段落", callbacks)
```

每次 update 的回调顺序：

1. `onUpdate(update)`
2. `onBlockSealed(node)` for each sealed block
3. `onHtmlFragment(fragment)` for each fragment
4. `onAstPatch(patch)` for each patch
5. `onTailChanged(update.pendingTailState)`

全部 finalize 完成后额外调用一次 `onFinalize(snapshot)`。callbacks 不会改变最终 `ParseOutput`，只是让调用方在解析过程中获得结构化事件。

## AI streaming 集成

AI 输出通常具备这些特点：chunk 不固定、可能切开 UTF-8 字符、代码围栏或表格可能尚未闭合、reference/footnote/i18n 等信息可能需要回补先前节点。推荐把稳定内容和预览内容分区处理。

```text
AI byte/token stream
  -> session.feedBytes(bytes) 或 session.feed(textChunk)
  -> append update.emittedHtmlFragments
  -> inspect update.pendingTailState for preview
  -> apply update.astPatches
  -> session.finalize() on stream end
```

```cangjie
import markit.Markit
import markit.bundles.GFMBundle

let session = Markit(GFMBundle()).createSession()

for (chunk in aiChunks) {
    let update = session.feed(chunk)
    for (fragment in update.emittedHtmlFragments) {
        appendToUi(fragment.html)
    }
    if (update.pendingTailState.hasPendingContent()) {
        renderPreview(update.pendingTailState.previewText)
    }
    for (patch in update.astPatches) {
        applyPatch(patch.nodeId, patch.html)
    }
}

let finalUpdate = session.finalize()
consumeUpdate(finalUpdate)
```

集成建议：

- 将 `emittedHtmlFragments` 追加到稳定内容区。
- 将 `pendingTailState.previewText` 渲染到临时预览区。
- 收到 `astPatches` 时按 `nodeId` 更新已渲染节点。
- 在流结束时调用 `finalize()`，并消费最后一次 update。
- 对超长会话使用 writer / stream API，减少一次性大字符串分配。

## 常见边界

流式解析最容易出错的地方通常是边界，而不是单个语法本身。建议在集成层显式覆盖这些情况：

- chunk 在 `\n` 前后切开。
- chunk 在中文、emoji 等 UTF-8 字符中间切开。
- fenced code、HTML block、math block 没有显式闭合。
- list/table 在空行、缩进和段落之间切换。
- reference link、footnote 或 i18n 在文档后半部分更新前半部分节点。
- callbacks 中既消费 fragment 又消费 final update，避免漏掉 finalize patch。
