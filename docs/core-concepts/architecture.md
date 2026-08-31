<a id="architecture"></a>
# 架构

Markit 的架构围绕 `IncrementalSession` 展开。无论你调用 `Markit().parse(markdown)`、`parse(input)`，还是手动创建 session 做流式解析，最终都会进入同一条解析管线：source 接收输入，line scanner 产出 source line，block pipeline 提交稳定块，inline pipeline 生成行内节点，renderer 输出 HTML/Markdown/Typst/JSON。

```text
Markit
  -> PluginRegistry / PluginRegistrar
  -> RenderRegistry
  -> IncrementalSession
  -> SourceBuffer + Utf8StreamDecoder + LineScanner + LineIndex
  -> continuation-first block pipeline
  -> InlineParserEngine + InlineDispatchTable
  -> DocumentNode / sealed blocks / HTML fragments / AST patches
  -> ParseOutput or IncrementalUpdate
```

这条管线的目标是同时满足两类使用方式：

- **批量解析**：输入已经完整，调用方只关心最终输出。
- **流式解析**：输入持续到来，调用方需要尽快消费稳定内容，并知道尾部是否仍未完成。

## 从 Markit 到 ParseOutput

`Markit.parse(String)` 可以理解成下面的流程：

```text
createSession()
feed(markdown)
finalize()
ParseOutput(snapshot, finalUpdate, symbolTables, renderer)
```

对应代码：

```cangjie
let out = Markit().parse("# 标题\n\n段落")

println(out.toHtml())
println(out.snapshot.nodeCount())
```

`parse(InputStream)` 与 `parseWithCallbacks(InputStream, callbacks)` 也走同一个 session。区别是输入先按 byte chunk 读取，再调用 `feedBytes(...)`；`Utf8StreamDecoder` 会处理跨 chunk 的 UTF-8 多字节字符。

```text
InputStream
  -> read bytes
  -> session.feedBytes(bytes)
  -> Utf8StreamDecoder
  -> LineScanner
  -> block pipeline
```

如果需要自定义 source retention、HTML fragment 或 preview 行为，直接创建 session：

```cangjie
import markit.Markit
import markit.core.session.ParseOptions

let session = Markit().createSession(options: ParseOptions(
    emitHtmlFragments: true,
    emitPreview: true
))

session.feed("# Intro")
let update = session.feed("\n\nHello\n\n")
let finalUpdate = session.finalize()
```

## Session 生命周期

`IncrementalSession` 是解析过程的状态边界。一个 session 对应一段输入流，按顺序经历三种状态：

```text
createSession()
  -> feed / feedBytes, repeated
  -> finalize()
  -> snapshot / render / write / dump
```

在 `feed(...)` 或 `feedBytes(...)` 阶段，session 会：

- 把输入追加到 `SourceBuffer`。
- 把可用文本交给 `LineScanner`，产出完整 `SourceLine`。
- 把每一行记录到 `LineIndex`。
- 尝试延续 open block，或启动新的 block parser。
- 在 block 稳定时提交节点，并生成 `sealedBlocks` 与 `emittedHtmlFragments`。
- 返回 `IncrementalUpdate`，其中包含 pending tail 和 AST patch。

在 `finalize()` 阶段，session 会：

- 检查 UTF-8 decoder 中是否还有未补齐 byte。
- flush 最后一行和 pending paragraph。
- finalize 打开的 continuation block，例如 fenced code、HTML block、math block、footnote definition 或 i18n block。
- 执行 session finalize hooks 与 post finalize hooks。
- drain AST patches。
- 根据 `SourceRetentionMode` 释放可回收 source。

`finalize()` 之后不能再调用 `feed(...)`。此时可以读取 `snapshot()`、`symbolTables()`，或调用 `toHtml()`、`writeHtml(...)`、`dumpJson(...)` 等输出 API。

## ParseSession 内部状态

`ParseSession` 是 `IncrementalSession` 内部使用的解析状态容器。插件 parser、renderer 和 finalize processor 会通过它共享当前解析上下文。

| 状态 | 说明 |
| --- | --- |
| `source` | 保存输入 segment，并根据 retention mode 决定 finalize 后是否释放正文。 |
| `options` | 控制 source retention、HTML fragment emission、pending preview 等行为。 |
| `symbolTables` | 保存插件注册的 session state，例如 reference definitions、footnotes、heading slug registry、i18n state。 |
| `root` | 当前文档根节点，稳定 block 会追加为它的子节点。 |
| `lineIndex` | 记录已处理的 `SourceLine`，用于诊断、定位、snapshot 查询和编辑器集成。 |
| `pendingParagraphLines` | 保存尚未 seal 的 paragraph 尾部。 |
| `patches` | 收集插件或 finalize 阶段产生的 AST patch。 |

这些状态让 Markit 可以在流式输入中保持上下文：链接定义可以晚于引用出现，脚注可以在文档尾部解析，i18n 过滤可以等结构稳定后再处理。

## Block Pipeline

块解析采用 continuation-first 设计。它优先照顾已经打开的块，再尝试启动新块。

```text
for each SourceLine:
  if there is an open continuation block:
    continueBlock(...)
    Open -> wait for next line
    Closed -> finalize block
    ClosedAndReprocess -> finalize block, then dispatch current line again

  if line is blank:
    flush pending paragraph

  if line starts a continuation block:
    flush pending paragraph
    open frame

  if line matches a leaf block:
    flush pending paragraph
    emit node

  otherwise:
    append line to pending paragraph
```

这种顺序对流式解析很重要。比如 AI 正在输出代码围栏时，围栏内部的 `#`、`|`、`- [ ]` 都只是代码内容，不应该被重新分派成 heading、table 或 task list。只有 continuation block 关闭后，后续行才会回到普通 block 分派。

常见 block 类型：

- leaf block：heading、divider、单行结构等可以立即解析的块。
- continuation block：fenced code、HTML block、math block、footnote definition、i18n block 等需要跨行维护状态的块。
- paragraph：没有匹配其他 block 时进入 pending paragraph，在空行、block boundary 或 EOF 时 seal。

## Inline Pipeline

行内解析由 `InlineParserEngine` 与 `InlineDispatchTable` 负责。block parser 先确定块级结构，再把需要解析行内内容的文本交给 inline pipeline。

```text
text + SourceSpan
  -> InlineDispatchTable candidates by starting byte
  -> InlineParser.parse(...)
  -> InlineParseResult(node, consumedBytes, consumedRunes)
  -> child nodes appended to parent block
```

Markit 使用起始 byte 做 dispatch：例如 `*`、`_`、`` ` ``、`[`、`!`、`<`、`$` 等标记可以直接落入对应候选 parser，普通文本则按字节快速前进。每个 parser 同时返回消耗的 byte 与 rune 数量，保证 `SourceSpan` 在 Unicode 文本中仍能准确推进。

## Registry 与 Dispatch Table

插件先向 `PluginRegistry` 注册能力，`Markit.createSession()` 再为本次解析创建 dispatch table 与 render registry。

```text
Bundle / Plugin
  -> register block parsers
  -> register inline parsers
  -> register renderers
  -> register state / symbol tables
  -> register filters and finalize processors
  -> create session-specific tables
```

这个过程带来两点好处：

- 热路径紧凑：block parser 按行首 byte 分桶，inline parser 按起始 byte 分派，不需要每个位置都尝试全部 parser。
- 能力可组合：Standard、CommonMark、GFM、i18n、TOC 和业务插件都可以注册自己的 parser、renderer 和 state。

Renderer 也按 node kind 注册。同一棵 AST 可以输出 HTML、Markdown、Typst 和 JSON；插件只需要为自己的 node kind 补充对应 renderer。

## IncrementalUpdate

每次 `feed(...)`、`feedBytes(...)` 和 `finalize()` 都会返回 `IncrementalUpdate`：

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

字段使用方式：

- `sealedBlocks`：本次稳定提交的 top-level block，适合结构化 UI、日志和增量索引。
- `emittedHtmlFragments`：本次提交 block 对应的 HTML，适合前端直接追加稳定内容。
- `astPatches`：对已有节点的替换或删除，适合 reference、footnote、i18n 等需要后发修正的能力。
- `pendingTailState`：未完成尾部状态，适合 AI streaming 预览和“是否仍在代码块内”的判断。
- `bytesAccepted` / `bytesCommitted`：用于输入统计、进度和调试。
- `isFinal`：判断 update 是否来自 `finalize()`。

## AI Streaming 数据流

在 AI 场景中，推荐把 UI 分成稳定内容区和预览区：

```text
AI token or byte stream
  -> session.feed(textChunk) or session.feedBytes(byteChunk)
  -> append update.emittedHtmlFragments to stable content
  -> render update.pendingTailState.previewText as temporary preview
  -> apply update.astPatches by nodeId
  -> session.finalize() when stream ends
```

这样做的价值是：

- 稳定 block 可以立即显示，减少等待完整回答的时间。
- 未闭合的 fenced code、table、math block、footnote 或 i18n block 不会提前变成最终 HTML。
- 中文、日文、韩文和 emoji 可以安全跨 byte chunk。
- 后发定义和 finalize processor 可以通过 AST patch 修正已有渲染。

Markit 的架构把这些机制放在同一个 session 中，而不是在 UI 层反复猜测 Markdown 尾部是否完整。
