<a id="testing-benchmark"></a>
# 测试与 benchmark

Markit 的测试重点不是只验证“完整字符串能解析”，而是验证同一语法在 direct parse、incremental string feed、incremental byte feed 和 `InputStream` 四种输入模式下行为一致。添加 API、语法或插件能力时，优先用 `ParseModeTestKit` 做跨模式断言。

常用命令：

```bash
cd markit
cjpm test --no-progress
cjpm test --no-progress --include-tags=Streaming
cjpm bench --filter=ParserBenchmarks
cjpm bench --filter=SharedFixtureBenchmarks
cjpm bench --filter=SharedFixtureMemoryBenchmarks
```

## 测试目录

测试入口在 `markit/src/tests`。

| 路径 | 覆盖内容 |
| --- | --- |
| `src/tests/unit/api_tests.cj` | 公共 API、输出方法、callbacks 等基础契约。 |
| `src/tests/unit/streaming` | `feed`、`feedBytes`、pending tail、chunk boundary 和 UTF-8 边界。 |
| `src/tests/unit/source` | `SourceBuffer`、`TextView`、`Cursor`、`SourceSpan` 等 source 模型。 |
| `src/tests/unit/plugins` | Standard、CommonMark、GFM、i18n、TOC 插件语义。 |
| `src/tests/unit/render` | HTML/Markdown/Typst/JSON 输出和 `ParseOutput` 渲染。 |
| `src/tests/unit/property` | offset、chunk boundary、生成输入等属性测试。 |
| `src/tests/benchmark` | 直接解析、增量解析、共享 fixture 和内存压力 benchmark。 |
| `src/tests/utils` | `ParseModeTestKit`、AST 断言和测试输入工具。 |

## ParseModeTestKit

`ParseModeTestKit` 会收集四种解析模式的结果：

- `direct-parse`：`Markit.parse(markdown)`。
- `incremental-string`：`createSession()` 后按字符串 chunk feed。
- `incremental-bytes`：`createSession()` 后按 byte chunk feed。
- `input-stream`：`parseWithCallbacks(input, callbacks)`。

最常用的断言是输出一致：

```cangjie
import markit.Markit
import markit.tests.utils.ParseModeTestKit

ParseModeTestKit.assertHtmlAcrossModes(
    { => Markit() },
    "# 标题\n\n段落",
    "<h1>标题</h1><p>段落</p>"
)
```

也可以断言 Markdown 或 Typst：

```cangjie
ParseModeTestKit.assertMarkdownAcrossModes(
    { => Markit() },
    "# 标题",
    "# 标题\n"
)

ParseModeTestKit.assertTypstAcrossModes(
    { => Markit() },
    "**粗体**",
    "*粗体*"
)
```

需要检查 AST、patch、fragment 或计数时，使用 `assertAcrossModes`。

```cangjie
import markit.tests.utils.{ParseModeResult, ParseModeTestKit}

ParseModeTestKit.assertAcrossModes(
    { => Markit() },
    "- item\n",
    { result: ParseModeResult =>
        if (result.root.children.size != 1) {
            throw IllegalArgumentException("expected one top-level node")
        }
        if (result.finalUpdate.isFinal != true) {
            throw IllegalArgumentException("expected final update")
        }
    }
)
```

自定义 chunk 边界：

```cangjie
import markit.tests.utils.{ParseModeFixture, ParseModeTestKit}

let fixture = ParseModeFixture.withChunks(
    "# 中文标题\n\n段落",
    ["# 中", "文标题\n", "\n段落"],
    [
        "# ".toArray(),
        "中文".toArray(),
        "标题\n\n段落".toArray()
    ]
)

ParseModeTestKit.assertHtmlAcrossModes({ => Markit() }, fixture, expectedHtml)
```

## 插件测试规范

新增插件或扩展语法时，建议至少覆盖：

- direct parse 与 incremental string/byte/InputStream 输出一致。
- HTML、Markdown、Typst 至少各有一个正向断言。
- JSON 或 AST debug tree 覆盖节点字段、children 和 meta。
- Unicode byte/rune offset 在中文、emoji、混合 ASCII 附近正确。
- chunk 在起始标记、结束标记、换行和 UTF-8 字符中间切开时仍然稳定。
- `SourceRetentionMode.Essential` 下 finalize 后仍能输出必要语义。
- callbacks 的 sealed block、HTML fragment、pending tail、AST patch 顺序和数量符合预期。
- 插件注册 session state 后，重复 parse 不共享上一次 session 状态。
- finalize hook 产生 patch 时，final update 必须包含可消费的 patch。

断言应尽量精确。正向测试优先比较完整 HTML/Markdown/Typst/JSON 或固定 AST 路径，不只用 `contains`。`contains` 更适合错误消息、长 HTML 模板或非核心片段。

## Streaming 测试

streaming 测试应主动制造不舒服的边界。推荐为每个复杂语法准备几组 fixture：

| 边界 | 示例 |
| --- | --- |
| 行边界 | `"# 标题"` 与 `"\n\n段落"` 分开 feed。 |
| byte 边界 | 中文或 emoji 的 UTF-8 bytes 被拆成多个 chunk。 |
| open block | fenced code、HTML block、math block 未闭合时 finalize。 |
| reprocess | continuation block 关闭后当前行重新进入 block pipeline。 |
| pending paragraph | 没有空行结束的 paragraph 在 finalize 时提交。 |
| patch | reference、footnote、i18n 在文档后半段更新前半段节点。 |

callbacks 测试可以只记录 update，不需要在回调里做复杂断言。

```cangjie
import markit.{Markit, ParseCallbacks}
import markit.core.incremental.IncrementalUpdate

var updateCount: Int64 = 0
var finalSeen = false

let callbacks = ParseCallbacks(
    onUpdate: { update: IncrementalUpdate =>
        updateCount += 1
        if (update.isFinal) {
            finalSeen = true
        }
    }
)

Markit().parseWithCallbacks("# 标题\n\n段落", callbacks)
```

## Output 测试

输出 API 需要同时覆盖字符串、stream、文件和 SeaJson writer。

```cangjie
import std.io.ByteBuffer
import seajson.JsonWriter

let out = Markit().parse("# 标题")

let html = ByteBuffer()
out.writeHtml(html)

let writer = JsonWriter(initialCapacity: 1024)
out.writeJson(writer)
let json = writer.close()
```

建议对输出类测试覆盖：

- `html()` 与 `toHtml()` 等价。
- `markdown()` 与 `toMarkdown()` 等价。
- `typst()` 与 `toTypst()` 等价。
- `json()` 与 `toJson()` 等价。
- `writeHtml` 等 stream API 与字符串输出一致。
- `dumpHtml` 等文件 API 创建目标目录并写入正确内容。
- `writeJson(JsonWriter)` 输出合法 JSON，且包含插件节点字段。

## Benchmark 入口

benchmark 文件位于 `src/tests/benchmark`。

| Benchmark | 用途 |
| --- | --- |
| `ParserBenchmarks` | 快速观察 direct parse、incremental lines、incremental bytes 的热路径。 |
| `SharedFixtureBenchmarks` | 使用共享 fixture 对 Standard、CommonMark、GFM、i18n、大 fenced code、深列表、大表格做吞吐观察。 |
| `SharedFixtureMemoryBenchmarks` | 使用自定义 `GCFreedBytes` measurement 观察 Cangjie managed heap 压力。 |

运行示例：

```bash
cjpm bench --filter=ParserBenchmarks
cjpm bench --filter=SharedFixtureBenchmarks
cjpm bench --filter=SharedFixtureMemoryBenchmarks
```

benchmark 基线记录在 `markit/src/tests/benchmark/BENCHMARK_BASELINE.md`。新增高风险解析逻辑、renderer 或 session state 后，建议同时跑对应 benchmark，并把结果与基线做人工比较。

## 解读 benchmark

读取 benchmark 时要区分这些成本：

- parser 构造成本：bundle 和插件注册。`SharedFixtureBenchmarks` 中 parser 作为字段复用，通常不计入单次操作。
- session 创建成本：每次 parse 或 incremental run 都会创建新的 session、source buffer 和 symbol tables。
- parse 成本：block/inline pipeline、source span、session state、AST 构建。
- render 成本：HTML/Markdown/Typst writer、escape、renderer dispatch。
- patch/finalize 成本：reference、footnote、i18n、TOC 或后处理器的整树操作。
- GC freed bytes：managed heap 压力的观测值。

`SharedFixtureMemoryBenchmarks` 使用自定义 `GCFreedBytes` measurement。每个 benchmark operation 构建 parse/render 结果，只返回一个小 marker，然后显式执行 `std.runtime.gc(heavy: true)`。measurement 报告 GC 释放的 Cangjie managed heap bytes。

`GCFreedBytes` 是 managed heap 分配压力的实用代理，不是进程峰值 RSS，也不是 native allocation。需要追踪峰值内存时，应额外接入平台级进程内存采样。

## 性能回归排查

当 benchmark 变慢时，先确认变化来自哪里：

- parse-only 变慢，优先看 parser dispatch、inline parser、source span 和 session state。
- parse-and-html 变慢但 parse-only 正常，优先看 renderer、HTML escape 和字符串拼接。
- incremental bytes 变慢，优先看 UTF-8 decoder、line scanner 和 chunk 数量。
- i18n 或 footnote benchmark 变慢，优先看 finalize hook、patch 生成和整树遍历。
- memory benchmark 上升，优先看临时 `ArrayList`、`StringBuilder`、重复 substring 和 JSON/render 中间对象。

性能修复也需要保留跨模式测试。速度变快但 streaming 边界不稳定，仍然是行为回归。
