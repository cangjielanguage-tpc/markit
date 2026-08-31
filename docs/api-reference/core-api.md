<a id="api"></a>
# 核心 API

`Markit` 是解析入口，也是插件、bundle、session state 与渲染注册表的组合器。日常使用可以把它理解为一个“解析器配置”：先组合需要的 Markdown 能力，再对每份文档创建独立解析会话。

最常见的路径有三种：

- 一次性解析完整字符串：`parse(markdown: String)`。
- 从 `InputStream` 读取 byte stream：`parse(input: InputStream)`。
- 手动创建 `IncrementalSession`，持续 `feed`/`feedBytes`，最后 `finalize()`。

```cangjie
import markit.Markit

let parser = Markit()
let out = parser.parse("# 标题\n\nHello **Markit**.")

println(out.toHtml())
```

## Markit

```cangjie
public class Markit {
    public init(useStandard!: Bool = true)
    public init(bundle: Bundle)
    public init(plugin: Plugin)

    public static func empty(): Markit

    public func use(plugin: Plugin): Markit
    public func use(bundle: Bundle): Markit

    public func createSession(options!: ParseOptions = ParseOptions()): IncrementalSession

    public func parse(markdown: String): ParseOutput
    public func parse(input: InputStream): ParseOutput

    public func parseWithCallbacks(markdown: String, callbacks: ParseCallbacks): ParseOutput
    public func parseWithCallbacks(input: InputStream, callbacks: ParseCallbacks): ParseOutput
}
```

默认构造 `Markit()` 会启用 Standard Markdown。需要 CommonMark、GFM、i18n、TOC 或自定义能力时，在解析前组合 bundle 和 plugin。

```cangjie
import markit.Markit
import markit.bundles.{CommonMarkBundle, GFMBundle, StandardMarkdownBundle}
import markit.plugins.i18n.I18nPlugin
import markit.plugins.i18n.config.I18nConfig

let standard = Markit()
let commonmark = Markit(CommonMarkBundle())
let gfm = Markit(GFMBundle())

let multilingual = Markit(GFMBundle()).use(I18nPlugin(
    config: I18nConfig(defaultLanguage: "zh", targetLanguage: "en")
))

let custom = Markit.empty()
    .use(StandardMarkdownBundle())
    .use(I18nPlugin())
```

`use(plugin)` 与 `use(bundle)` 返回当前实例，适合 fluent 组合。`Markit` 实例可以复用；每次 `parse(...)` 或 `createSession(...)` 都会创建新的 `ParseSession`、source buffer、symbol tables 和增量状态，因此不同文档之间不会共享 session state。

创建 session、dispatch table、symbol tables 或 render registry 时，内部 registry 会冻结。冻结后继续注册插件会抛出 `IllegalArgumentException`。推荐在应用启动、CLI 初始化或服务 worker 初始化阶段完成组合，然后把 parser 当作只读对象使用。

```cangjie
let parser = Markit(GFMBundle())

let first = parser.parse("# 第一篇")
let second = parser.parse("# 第二篇")
```

## parse API

`parse(markdown: String)` 是最直接的入口。它会创建 session、feed 完整字符串、执行 `finalize()`，并返回 `ParseOutput`。

```cangjie
import markit.Markit
import markit.bundles.GFMBundle

let markdown = """
# API

- [x] 支持 task list
- 表格、脚注、删除线由 GFM bundle 提供
"""

let out = Markit(GFMBundle()).parse(markdown)

println(out.html())
println(out.markdown())
println(out.typst())
println(out.json())
```

`ParseOutput` 保留最终 snapshot、final update、symbol tables 和渲染注册表。它既能读 AST，也能输出多种格式。

| API | 用途 |
| --- | --- |
| `out.root()` | 读取最终 `DocumentNode` 根节点。 |
| `out.snapshot` | 读取 `DocumentSnapshot`，包含 root 与 line index。 |
| `out.finalUpdate` | 读取 `finalize()` 产生的最后一次增量更新。 |
| `out.symbolTables()` | 读取插件注册的 session state。 |
| `out.html()` / `out.toHtml()` | 输出 HTML 字符串。 |
| `out.markdown()` / `out.toMarkdown()` | 输出规范化 Markdown 字符串。 |
| `out.typst()` / `out.toTypst()` | 输出 Typst 字符串。 |
| `out.json()` / `out.toJson()` | 输出 AST JSON 字符串。 |

如果调用方需要 `DocumentNode` 的具体类型，可以在应用边界做一次收窄。

```cangjie
import markit.core.nodes.DocumentNode

let document = (out.root() as DocumentNode).getOrThrow()
println(document.children.size)
```

## InputStream

`parse(input: InputStream)` 适合文件、网络响应、CLI 管道和其他 byte stream。内部会按 byte chunk 读取输入并调用 `feedBytes(...)`，因此中文、日文、韩文、emoji 等 UTF-8 多字节字符可以跨 chunk。

```cangjie
import std.io.ByteBuffer
import markit.Markit

let input = ByteBuffer("# 标题\n\n中文段落".toArray())
let out = Markit().parse(input)

println(out.toHtml())
```

`parse(input)` 使用默认 `ParseOptions`。如果需要自定义 source retention、关闭 HTML fragment、调整预览行为，或者需要实时消费每次 update，请改用 `createSession(options)`。

## IncrementalSession

`createSession(...)` 返回 `IncrementalSession`。它是 Markit 的核心执行单元，负责维护 open block、pending paragraph、UTF-8 decoder、line index、symbol tables、HTML fragments 和 AST patches。

```cangjie
import markit.Markit
import markit.core.session.ParseOptions
import markit.core.source.SourceRetentionMode

let session = Markit().createSession(options: ParseOptions(
    sourceRetentionMode: SourceRetentionMode.Essential,
    emitHtmlFragments: true,
    emitPreview: true
))

let first = session.feed("# 标")
let second = session.feed("题\n\n段落")
let finalUpdate = session.finalize()
let snapshot = session.snapshot()

println(finalUpdate.isFinal)
println(session.toHtml())
println(snapshot.root.toMarkdown())
```

常用方法：

| API | 说明 |
| --- | --- |
| `feed(chunk: String)` | 输入已经解码完成的字符串 chunk。 |
| `feedBytes(chunk: Array<Byte>)` | 输入 byte chunk，自动处理跨 chunk UTF-8。 |
| `finalize()` | 结束输入，提交剩余 open block 与 pending paragraph。 |
| `snapshot()` | 读取当前文档快照。 |
| `symbolTables()` | 读取本 session 的插件状态。 |
| `renderer()` | 读取本 session 的 render registry。 |
| `toHtml()` / `writeHtml(out)` | 输出当前 AST 的 HTML。 |
| `toMarkdown()` / `writeMarkdown(out)` | 输出当前 AST 的 Markdown。 |
| `toTypst()` / `writeTypst(out)` | 输出当前 AST 的 Typst。 |
| `toJson()` / `writeJson(out)` | 输出当前 AST JSON。 |

`finalize()` 后不能继续 `feed` 或 `feedBytes`。如果需要解析下一份文档，请从同一个 parser 再创建一个 session。

## feed / finalize / snapshot

`feed(chunk: String)` 适合编辑器文本、按行读取、WebSocket 文本消息或 AI SDK 已解码 token。`feedBytes(chunk: Array<Byte>)` 适合文件和网络 bytes，尤其是 chunk 可能切开 UTF-8 字符时。

```cangjie
let session = Markit().createSession()

for (chunk in ["# 标", "题\n\n", "正文"]) {
    let update = session.feed(chunk)
    println(update.pendingTailState.summary)
}

let done = session.finalize()
println(done.bytesCommitted)
```

byte stream 示例：

```cangjie
let bytes = "# 中文标题\n\n段落含 emoji 🚀\n".toArray()
let session = Markit().createSession()
var index: Int64 = 0

while (index < bytes.size) {
    let end = min(index + 64, bytes.size)
    session.feedBytes(bytes[index..end])
    index = end
}

session.finalize()
println(session.toHtml())
```

`finalize()` 会完成 UTF-8 decoder 检查、flush 最后一行、提交 pending paragraph、关闭仍打开的 continuation block、执行 finalize hooks、drain AST patches，并按 `SourceRetentionMode` 释放可回收 source。`snapshot()` 可在 feed 中途调用，用于结构预览；finalize 后的 snapshot 即最终 AST。

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

| 字段 | 说明 |
| --- | --- |
| `sealedBlocks` | 本次 update 中稳定提交的 top-level block。 |
| `emittedHtmlFragments` | 本次 sealed block 对应的 HTML 片段，受 `emitHtmlFragments` 控制。 |
| `astPatches` | 插件或 finalize 阶段产生的 AST 更新。 |
| `pendingTailState` | 尚未稳定的尾部内容，用于临时预览。 |
| `bytesAccepted` | 本次 feed 接收的 byte 数。 |
| `bytesCommitted` | final update 中提交的 source 总 byte 数。 |
| `isFinal` | 是否来自 `finalize()`。 |

稳定 block 可以直接追加到 UI 或索引；pending tail 只适合临时预览；patch 应按 `nodeId` 更新已经渲染过的节点。

## ParseOptions

```cangjie
import markit.core.session.ParseOptions
import markit.core.source.SourceRetentionMode

let options = ParseOptions(
    inputChunkSize: 4096,
    sourceRetentionMode: SourceRetentionMode.Full,
    emitHtmlFragments: true,
    emitPreview: false
)
```

| 字段 | 默认值 | 说明 |
| --- | --- | --- |
| `inputChunkSize` | `8192` | 输入 chunk 大小配置入口。手动 `feedBytes` 时可按该值切分输入。 |
| `sourceRetentionMode` | `Essential` | source 保留策略：`None`、`Essential`、`Full`。 |
| `emitHtmlFragments` | `true` | 是否在每次 update 中生成稳定 HTML fragment。 |
| `emitPreview` | `true` | 是否填充 pending tail 的 `previewText`。 |

source retention 影响节点在 finalize 后能否回读原始 source。渲染 HTML、Markdown、Typst 与 JSON 不依赖完整 source；调试、IDE 定位、格式化工具或需要输出 `rawContent` 的 JSON 场景可以选择 `Full`。

## ParseCallbacks

callbacks 适合在批量入口上消费流式事件，例如服务端推送 HTML fragment、CLI 进度日志、编辑器实时预览或增量索引。

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
        if (tail.hasPendingContent()) {
            println(tail.previewText)
        }
    },
    onFinalize: { snapshot: DocumentSnapshot =>
        println(snapshot.root.children.size)
    }
)

let out = Markit().parseWithCallbacks("# 标题\n\n段落", callbacks)
```

每次 update 的回调顺序是：

1. `onUpdate(update)`
2. `onBlockSealed(node)` for each sealed block
3. `onHtmlFragment(fragment)` for each fragment
4. `onAstPatch(patch)` for each patch
5. `onTailChanged(update.pendingTailState)`

全部输入 finalize 后，会额外调用一次 `onFinalize(snapshot)`。回调中的 `ParseOutput` 仍会在最后返回；如果只需要最终结果，可以忽略中间事件。
