<a id="plugins"></a>
# 插件系统

Markit 的语法、渲染和跨文档辅助能力都通过插件注册。插件可以添加 block parser、inline parser、renderer、session state、节点批处理器、节点过滤器和 finalize hook。bundle 则是一组插件的组合，用来提供 Standard、CommonMark、GFM 等能力集合。

```cangjie
public interface Plugin {
    prop name: String
    prop version: String
    func register(registrar: PluginRegistrar): Unit
}

public interface Bundle {
    prop name: String
    prop version: String
    prop plugins: Array<Plugin>
    prop includesStandardMarkdown: Bool
}
```

最小插件只需要实现 `Plugin`，并在 `register(...)` 中声明它提供的能力。

```cangjie
import markit.core.plugin.{Plugin, PluginRegistrar}

public class CalloutPlugin <: Plugin {
    public prop name: String {
        get() { "CalloutPlugin" }
    }

    public prop version: String {
        get() { "1.0.0" }
    }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerContinuationBlockParser(CalloutBlockParser())
        registrar.registerHtmlRenderer("Callout", CalloutHtmlRenderer())
        registrar.registerMarkdownRenderer("Callout", CalloutMarkdownRenderer())
        registrar.registerTypstRenderer("Callout", CalloutTypstRenderer())
    }
}
```

使用插件：

```cangjie
import markit.Markit
import markit.bundles.GFMBundle

let parser = Markit(GFMBundle()).use(CalloutPlugin())
let out = parser.parse(":::note\n重要提示\n:::")

println(out.toHtml())
```

## PluginRegistrar

`PluginRegistrar` 是插件向核心注册能力的唯一入口。

| API | 用途 |
| --- | --- |
| `registerState(key, factory)` | 注册每个 session 独立创建的状态对象。 |
| `registerLeafBlockParser(parser)` | 注册单行即可完成的 block parser。 |
| `registerContinuationBlockParser(parser)` | 注册可跨行保持 open frame 的 block parser。 |
| `registerParagraphBlockParser(parser)` | 注册 paragraph fallback/finalizer。 |
| `registerInlineParser(parser)` | 注册 inline parser。 |
| `registerNodeBatchProcessor(processor)` | 注册节点批处理器。 |
| `registerNodeEmissionFilter(filter)` | 在 top-level block emit 前过滤节点。 |
| `registerHtmlRenderer(kind, renderer)` | 注册 HTML renderer。 |
| `registerMarkdownRenderer(kind, renderer)` | 注册 Markdown renderer。 |
| `registerTypstRenderer(kind, renderer)` | 注册 Typst renderer。 |
| `registerSessionFinalizeProcessor(processor)` | 注册 session finalize 阶段处理器。 |
| `registerPostFinalizeProcessor(processor)` | 注册 AST finalize 后处理器。 |

注册发生在 parser 冻结之前。调用 `createSession()`、`parse(...)` 或任何会创建 dispatch/render registry 的操作后，registry 会冻结，继续注册插件会抛出 `IllegalArgumentException`。

## Session State

插件状态属于 `ParseSession`，不属于插件实例。每次解析都会通过 factory 创建新的 state，因此同一个 `Markit` parser 可以安全复用在多篇文档上。

```cangjie
import markit.core.session.{SessionState, SessionStateKey, SessionStateSnapshot}

class CalloutState <: SessionState {
    public var count: Int64 = 0

    public func reset(): Unit {
        count = 0
    }

    public func snapshot(): SessionStateSnapshot {
        return SessionStateSnapshot("CalloutPlugin.state")
    }
}

public class CalloutPlugin <: Plugin {
    public static let stateKey = SessionStateKey<CalloutState>("CalloutPlugin", "state")

    public prop name: String { get() { "CalloutPlugin" } }
    public prop version: String { get() { "1.0.0" } }

    public func register(registrar: PluginRegistrar): Unit {
        registrar.registerState(CalloutPlugin.stateKey, { => CalloutState() })
    }
}
```

在 parser、renderer 或 finalize processor 中读取状态：

```cangjie
let state = session.symbolTables.get(CalloutPlugin.stateKey)
state.count += 1
```

在应用层读取状态：

```cangjie
let out = parser.parse(markdown)
let state = out.symbolTables().get(CalloutPlugin.stateKey)

println(state.count)
```

也可以用动态名称读取：

```cangjie
let dynamic = out.symbolTables()["CalloutPlugin.state"]
```

`SessionSymbolTableStore["xxx"]` 返回 `?SessionState`，适合插件间弱耦合或调试；类型安全场景优先用 typed key。

## Block 插件

block parser 负责把行级结构变成 top-level block 或 block tree。Markit 提供三类 block parser。

### LeafBlockParser

`LeafBlockParser` 适合 heading、divider 等单行即可完成的 block。

```cangjie
public interface LeafBlockParser {
    prop name: String
    prop ownerPlugin: String
    prop priority: Int64
    prop startBytes: Array<Byte>
    prop acceptsAnyNonBlank: Bool

    func tryParse(session: ParseSession, line: String): ?Node
}
```

`BlockDispatchTable` 按当前行第一个非空 byte 查找 `startBytes` bucket，并按 `priority` 从小到大尝试 parser。`acceptsAnyNonBlank` parser 会附加到所有非空行候选中。

适用场景：

- ATX heading：以 `#` 开头，当前行即可完成。
- thematic break：以 `-`、`*`、`_` 开头，当前行即可完成。
- 自定义短指令：例如 `@toc`、`!include file.md`。

### ContinuationBlockParser

`ContinuationBlockParser` 适合 fenced code、blockquote、list、table、HTML block、math block、footnote definition、i18n block 等跨行结构。

```cangjie
public interface ContinuationBlockParser {
    prop name: String
    prop ownerPlugin: String
    prop priority: Int64
    prop startBytes: Array<Byte>

    func tryStart(session: ParseSession, line: String): ?BlockFrame
    func continueBlock(session: ParseSession, frame: BlockFrame, line: String): ContinueResult
    func finalize(session: ParseSession, frame: BlockFrame): Node
}
```

`tryStart(...)` 识别起始行并返回 `BlockFrame`。frame 内的 `BlockState` 保存跨行状态，例如开头缩进、围栏标记、累计行、表格列信息或语言标记。

`ContinueResult`：

- `Open`：继续保持当前 frame。
- `Closed`：关闭并提交当前 block。
- `ClosedAndReprocess`：关闭当前 block，然后把当前行重新交给 block pipeline。

当输入结束时，仍打开的 continuation block 会在 `finalize()` 中调用 parser 的 `finalize(...)`，因此插件要保证未闭合输入也能生成稳定节点。

### ParagraphBlockParser

`ParagraphBlockParser` 是 paragraph fallback/finalizer。默认 Standard bundle 会注册 paragraph parser，负责把未被其他 block parser 消费的行合并成 paragraph，并触发 inline parsing。

```cangjie
public interface ParagraphBlockParser {
    prop name: String
    prop ownerPlugin: String

    func canStart(session: ParseSession, line: String): Bool
    func normalizeLine(session: ParseSession, line: String): String
    func finalize(
        session: ParseSession,
        lines: ArrayList<SourceLine>,
        sourceSpan: SourceSpan,
        termination: ParagraphTermination
    ): Node
}
```

自定义 paragraph parser 应保持谨慎：它会影响几乎所有普通文本。只有在需要重写 paragraph 行归一化、特殊软换行规则或全局 paragraph 节点类型时才建议注册。

## Inline 插件

inline parser 在 paragraph、heading、table cell 等文本容器中运行，用于解析 emphasis、link、image、inline code、autolink、inline math、i18n inline 等结构。

```cangjie
public interface InlineParser {
    prop name: String
    prop ownerPlugin: String
    prop priority: Int64
    prop startBytes: Array<Byte>

    func tryParse(
        session: ParseSession,
        input: String,
        baseSpan: SourceSpan
    ): ?InlineParseResult
}

public class InlineParseResult {
    public let node: Node
    public let consumedBytes: Int64
    public let consumedRunes: Int64
}
```

inline dispatch 同样按起始 byte 和 priority 工作。parser 需要准确返回 consumed byte 和 consumed rune，保证中文、emoji 等多字节文本的 offset 正确。

```cangjie
public func tryParse(
    session: ParseSession,
    input: String,
    baseSpan: SourceSpan
): ?InlineParseResult {
    if (!input.startsWith("++")) {
        return None
    }

    // 找到结束标记后创建节点，并返回实际消耗的 byte/rune。
    return Some(InlineParseResult(node, consumedBytes, consumedRunes))
}
```

inline parser 只应消费自己识别的结构。无法识别时返回 `None`，让后续 parser 或普通文本逻辑处理。

## Render 插件

渲染由 `RenderRegistry` 管理。插件为各自 node kind 注册 HTML、Markdown 和 Typst renderer。

```cangjie
public interface HtmlRenderer {
    prop ownerPlugin: String
    func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit
}

public interface MarkdownRenderer {
    prop ownerPlugin: String
    func writeMarkdown(node: Node, out: TextWriter, registry: RenderRegistry): Unit
}

public interface TypstRenderer {
    prop ownerPlugin: String
    func writeTypst(node: Node, out: TextWriter, registry: RenderRegistry): Unit
}
```

HTML writer：

```cangjie
public interface HtmlWriter {
    func text(value: String): Unit
    func raw(value: String): Unit
}
```

- `text(...)` 会 HTML escape。
- `raw(...)` 直接写入，用于插件明确生成的标签或可信 HTML。

Markdown/Typst writer：

```cangjie
public interface TextWriter {
    func write(value: String): Unit
}
```

renderer 应使用 registry 渲染子节点，避免绕过其他插件的输出逻辑。

```cangjie
class CalloutHtmlRenderer <: HtmlRenderer {
    public prop ownerPlugin: String { get() { "CalloutPlugin" } }

    public func writeHtml(node: Node, out: HtmlWriter, registry: RenderRegistry): Unit {
        out.raw("<aside class=\"callout\">")
        for (child in node.children) {
            registry.writeHtml(child, out)
        }
        out.raw("</aside>")
    }
}
```

输出层同时支持字符串 writer 和 stream writer。`ParseOutput.toHtml()`、`writeHtml(out)`、`Node.toHtml()` 都会走同一套 renderer。

## Node Batch 与 Emission Filter

`NodeBatchProcessor` 在 block tree 构建后处理一批节点。适合需要看相邻节点或重排节点的能力，例如 heading 编号、表格样式识别、批量归一化。

```cangjie
public interface NodeBatchProcessor {
    prop ownerPlugin: String
    func process(session: ParseSession, nodes: ArrayList<Node>): ArrayList<Node>
}
```

`NodeEmissionFilter` 在 top-level block emit 前决定节点是否进入最终文档。适合隐藏定义节点、按语言过滤节点或把某些辅助节点保留在 session state 中。

```cangjie
public interface NodeEmissionFilter {
    prop ownerPlugin: String
    func accept(session: ParseSession, node: Node): Bool
}
```

过滤器返回 `false` 后，该节点不会出现在 root children 中，也不会产生 HTML fragment。

## Finalize Hooks

插件可以注册两个 finalize 阶段处理器。

```cangjie
registrar.registerSessionFinalizeProcessor({ session: ParseSession =>
    // 仍可访问 ParseSession、symbol tables 和 patch queue。
})

registrar.registerPostFinalizeProcessor({ root: Node, tables: SessionSymbolTableStore =>
    // AST 已经完成，可做整树后处理。
})
```

常见用途：

- reference link、footnote 等在完整文档可见后回补节点。
- i18n 根据目标语言过滤或替换节点。
- TOC、heading、table 等能力在最终 AST 上写入 meta。
- 通过 patch queue 通知流式调用方替换已经输出的节点。

如果 finalize hook 修改了已经 emit 过的节点，应通过 session patch queue 产生 `AstPatch`，让 streaming UI 能同步更新。

## Bundle

bundle 是插件数组。它让用户用一个对象启用一组能力。

```cangjie
public class DocsBundle <: Bundle {
    public prop name: String { get() { "DocsBundle" } }
    public prop version: String { get() { "1.0.0" } }
    public prop includesStandardMarkdown: Bool { get() { true } }

    public prop plugins: Array<Plugin> {
        get() {
            return [
                CalloutPlugin(),
                TabsPlugin(),
                BadgePlugin()
            ]
        }
    }
}
```

当 bundle 已经包含 Standard Markdown 能力时，把 `includesStandardMarkdown` 设为 `true`。这样用户从默认 `Markit()` 切换到该 bundle 时，不会重复注册 Standard 插件。

```cangjie
let parser = Markit(DocsBundle())
```

## 设计建议

插件作者可以按这条线拆分职责：

- block parser 只负责识别块结构和构建节点。
- inline parser 只消费自己明确识别的标记。
- session state 保存跨行、跨节点、跨 finalize 阶段的信息。
- renderer 只负责输出，不修改 AST。
- finalize processor 做需要全局信息的收尾。
- JSON 字段通过节点的 `writeJsonFields(...)` 暴露，渲染相关标记放入 `meta`。

优先补齐 direct parse、incremental string feed、incremental byte feed 和 `InputStream` 四种模式的测试。插件只在普通 parse 下正确还不够；Markit 的核心价值之一就是同一语法在流式边界下仍然稳定。
