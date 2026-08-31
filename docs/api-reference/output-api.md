<a id="parse-output"></a>
# ParseOutput 与输出

`ParseOutput` 是完整解析和流式 finalize 后的统一结果对象。它持有最终 `DocumentSnapshot`、`finalUpdate`、本次解析的 session state，以及和当前 parser 匹配的 `RenderRegistry`。应用层可以用它读取 AST，也可以把同一棵文档树输出为 HTML、Markdown、Typst、JSON 或 AST debug tree。

```cangjie
import markit.Markit
import markit.bundles.GFMBundle

let out = Markit(GFMBundle()).parse("# 中文标题\n\n段落 with **bold**")

let root = out.root()
let snapshot = out.snapshot
let finalUpdate = out.finalUpdate
let tables = out.symbolTables()
```

## 字符串输出

最常用的输出方式是直接拿字符串。短文档、测试断言、模板拼接和 CLI 小文件输出都适合这种方式。

```cangjie
let html = out.html()
let markdown = out.markdown()
let typst = out.typst()
let json = out.json()
let tree = out.toString()

let sameHtml = out.toHtml()
let sameMarkdown = out.toMarkdown()
let sameTypst = out.toTypst()
let sameJson = out.toJson()
```

| API | 说明 |
| --- | --- |
| `html()` / `toHtml()` | 渲染 HTML 字符串。 |
| `markdown()` / `toMarkdown()` | 输出规范化 Markdown 字符串。 |
| `typst()` / `toTypst()` | 输出 Typst 字符串。 |
| `json()` / `toJson()` | 输出 AST JSON 字符串。 |
| `toString()` | 输出 AST debug tree，适合调试和结构测试。 |

HTML、Markdown 和 Typst 都通过当前 session 的 `RenderRegistry` 渲染，因此自定义插件注册的 renderer 会自动参与输出。JSON 由节点树直接写出，包含节点类型、offset、节点字段、children 和 meta。

## 输出到 OutputStream

大文档、CLI、HTTP response 或文件服务场景可以直接写入 `OutputStream`，避免先构造完整字符串。

```cangjie
import std.io.ByteBuffer
import markit.Markit

let out = Markit().parse("# 标题\n\n段落")

let html = ByteBuffer()
let markdown = ByteBuffer()
let typst = ByteBuffer()
let json = ByteBuffer()
let tree = ByteBuffer()

out.writeHtml(html)
out.writeMarkdown(markdown)
out.writeTypst(typst)
out.writeJson(json)
out.write(tree)
```

对应关系：

| API | 输出内容 |
| --- | --- |
| `writeHtml(out)` | HTML。 |
| `writeMarkdown(out)` | Markdown。 |
| `writeTypst(out)` | Typst。 |
| `writeJson(out)` | AST JSON。 |
| `write(out)` | AST debug tree。 |

`IncrementalSession` 在 `finalize()` 后也提供同名 API，适合流式解析结束后直接写出最终文档。

```cangjie
let session = Markit().createSession()
session.feed("# 标题\n\n段落")
session.finalize()

session.writeHtml(html)
session.writeMarkdown(markdown)
session.writeTypst(typst)
session.writeJson(json)
```

`ParseOutput.writeHtml(...)` 会使用 `ParseOutput` 保存的 render registry；`IncrementalSession.writeHtml(...)` 会使用 session root 已附加的 render hooks。两者都能输出插件 renderer 生成的内容。

## 输出到文件

文件输出适合文档站构建、示例生成和调试快照。目标目录不存在时会自动创建目录；默认文件名按格式设置，也可以通过命名参数指定。

```cangjie
let out = Markit().parse("# 标题\n\n段落")

out.dump("./dist", filename: "tree.txt")
out.dumpHtml("./dist", filename: "doc.html")
out.dumpMarkdown("./dist", filename: "doc.md")
out.dumpTypst("./dist", filename: "doc.typ")
out.dumpJson("./dist", filename: "doc.json")
```

`IncrementalSession` 也支持同名 dump API：

```cangjie
let session = Markit().createSession()
session.feed("# 标题\n\n段落")
session.finalize()

session.dumpHtml("./dist", filename: "preview.html")
session.dumpJson("./dist", filename: "preview.json")
```

文件输出是最终结果输出，不会替代流式事件。如果需要一边解析一边推送局部 HTML，请消费 `IncrementalUpdate.emittedHtmlFragments`。

## SeaJson JsonWriter

Markit 使用 SeaJson 写出 AST JSON。`writeJson(w: JsonWriter)` 会把节点树写入已有 writer，适合复用 writer 配置、嵌入更大的 JSON 结构，或减少中间字符串对象。

```cangjie
import seajson.JsonWriter
import markit.Markit

let out = Markit().parse("# 标题")
let writer = JsonWriter(initialCapacity: 4096)

out.writeJson(writer)
let json = writer.close()
```

节点也支持直接写 JSON：

```cangjie
let root = out.root()

let nodeWriter = JsonWriter(initialCapacity: 4096)
root.writeJson(nodeWriter)
let nodeJson = nodeWriter.close()
```

`writeJson(w)` 返回同一个 writer，因此也可以在调用链中继续写入后续内容。

```cangjie
let writer = JsonWriter(initialCapacity: 8192)
out.writeJson(writer)
let payload = writer.close()
```

## JSON 结构

JSON 输出字段来自 `Node.writeJson(...)`。通用字段包括：

| 字段 | 说明 |
| --- | --- |
| `type` | 节点类型，例如 `DocumentNode`、`HeadingNode`、`ParagraphNode`。 |
| `startOffset` / `endOffset` | rune offset，适合编辑器和用户可见字符定位。 |
| `startByteOffset` / `endByteOffset` | byte offset，适合 source buffer、文件切片和协议传输。 |
| `children` | 子节点数组。 |
| `meta` | 插件写入的字符串、整数或布尔元信息。 |

不同节点会写入自己的字段。例如 heading 会包含标题级别和 slug，link/image 会包含目标地址，table cell 会包含对齐信息。插件节点应通过覆写 `writeJsonFields(...)` 暴露稳定字段，通过 `meta` 暴露跨插件或渲染相关标记。

当 `ParseOptions.sourceRetentionMode` 为 `Full` 时，节点 JSON 可能包含 `rawContent`，方便调试原始切片。常规渲染和 AST 传输通常不需要完整 source。

## 输出格式选择

| 场景 | 推荐 API |
| --- | --- |
| 页面渲染 | `toHtml()` 或 `writeHtml(out)`。 |
| Markdown 格式化、回写、合并 | `toMarkdown()` 或 `writeMarkdown(out)`。 |
| Typst/PDF 管线 | `toTypst()` 或 `writeTypst(out)`。 |
| AST 调试、索引、跨进程传输 | `toJson()`、`writeJson(out)` 或 `writeJson(writer)`。 |
| 单元测试定位结构 | `toString()`。 |
| 大文档或服务端响应 | 优先使用 stream / writer API。 |
| 流式 UI | 使用 `IncrementalUpdate.emittedHtmlFragments`，最终再用 `toHtml()` 校准完整输出。 |

## 输出与插件

输出层完全依赖注册表。插件只要为自己的 node kind 注册 HTML、Markdown 和 Typst renderer，就会自动接入 `ParseOutput`、`IncrementalSession`、`Node.toHtml()` 与 writer API。

```cangjie
public func register(registrar: PluginRegistrar): Unit {
    registrar.registerHtmlRenderer("Callout", CalloutHtmlRenderer())
    registrar.registerMarkdownRenderer("Callout", CalloutMarkdownRenderer())
    registrar.registerTypstRenderer("Callout", CalloutTypstRenderer())
}
```

没有注册 renderer 的节点会回退为 literal 或 children 输出。面向用户的插件应尽量补齐三种文本输出；即使插件主要服务 HTML，也建议提供 Markdown/Typst 的可读降级。
