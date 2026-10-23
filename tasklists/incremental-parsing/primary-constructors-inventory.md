# 自有仓颉源码主构造函数盘点

更新：2026-10-23。Owner：`task05_engine/source_lifecycle`。本项随产品正常编译回归实施，是纯写法整理，不是新增阻塞阶段；不为它创建重复测试或大型验收设施。

## 统计范围与口径

只读扫描仓库中的自有 `.cj` 源码；排除 `.git/.agents/.codex`、所有 `target`、`node_modules`、`.cache/.cjpm/tmp/test_result`、`tasklists` 证据与草稿、`libs` 内 vendored/第三方源码、`dochir/build-script-cache` 和 `.dochir` 生成物。`dochir/example/src/chir/api.cj` 明确含 `declaration mirror`，单列保留，不算自有实现转换范围。外部 stdlib 不进入统计或转换。

剔除这些缓存/依赖前的粗扫描为 1,018 个 `.cj`；剔除后的自有扫描为 **744 个文件**。下表“类型/普通 init”是字面入口计数（约 1,172/587），不是 AST 证明或可机械替换的数量；注释、宏 quote、声明镜像和当前并行编辑会影响粗计数。足够确定所有权即可实施，不继续为精确总数扩大研究。

| 自有分区 | `.cj` 文件数 | 类型入口 | 普通 init 入口 | 可转换候选/保留重点 | 所有权建议/当前状态 |
|---|---:|---:|---:|---|---|
| `markit/src/**`（含 tests） | 442 | 639 | 304 | render、inline、值配置、payload 与测试记录；Task05 热区禁止外人改 | 继续按下方独占表执行 |
| `markit-kit/**` | 53 | 86 | 23 | models/config/renderers 中值构造优先；processor 的 GlobalContext、默认值、重载与副作用保序 | 本 owner 已完成 17 文件/22 类型，SOURCE_READY；正常 kit 编译待 02 排程 |
| `markit-cli/**` | 9 | 8 | 1 | 主要是空 `kit_hooks` 构造，收益很小；不为凑数量改默认构造 | root 已分配 `task_a_review` |
| `commandline/**` | 36 | 45 | 9 | terminal 三个纯值构造；macros 内 quote 生成代码单独审查 | root 已分配 `task_a_review` |
| `codehl/**` | 19 | 45 | 36 | CodeLine/CodeBlock/options 等值模型；加载器/状态派生构造保序 | root 后续分派 |
| `mathtex/**` | 65 | 84 | 29 | 数学 AST/box 值模型；继承与布局派生初始化不能盲移 | root 后续分派 |
| `mermaid4cj/**` | 60 | 175 | 132 | 图模型/配置值类较多；renderer/parser 有状态构造单独保序 | root 后续分派 |
| `dochir/src/**` | 21 | 42 | 25 | DocParam/DocTag 等模型；插件/文档生成上下文保序 | root 已分配 `task_a_review` |
| `dochir/example/**`（不含 CHIR mirror） | 4 | 6 | 3 | `plugin/manager/api.cj` 是 API 演示/镜像语境，继承与声明文档结构保留优先 | 先保留，不改变示例要展示的声明意义 |
| `fswatch/**` | 33 | 36 | 22 | 事件/选项值记录可选；平台 watcher/资源句柄构造保留副作用 | root 已分配 `task_a_review` |
| `live-server/**` | 1 | 3 | 3 | 请求/配置等值记录；server 资源创建顺序保持 | root 已分配 `task_a_review` |
| `benchmarks/nodeless-render-cj/**` | 1 | 3 | 0 | 没有普通 init 入口，无需强加主构造 | 保留 |

## 当前独占与保护范围

| 范围 | 唯一 owner / 规则 |
|---|---|
| `core/block`、`core/incremental`、`markit.cj` | Task05 main；产品与写法一起做 |
| `core/session` | session checkpoint owner / Task05 明确分工；不交给风格代理并改 |
| `core/source` | source lifecycle owner；本轮产品验证冻结，后续只有明确安全窗才改 |
| `nodes/persistent_node`、`document/persistent_document` | Task04 storage owner |
| `core/editing`、`plugin_registry/plugin_registrar`、runtime shared contract | Task02 唯一串行 owner |
| Task05 测试、Task02/03/04 定向新测试 | 原测试 owner，不能由其他代理批量转换 |
| `markit/src/plugins/**/*.cj` | `task_a_review`；227 个自有文件，无额外 vendor/generated 子目录；已转换 101 文件/117 类型并 SOURCE_READY（59 成员形参、58 显式 body；唯一剩余 init 为 I18nPostProcessor 第二重载），见 [插件记录](primary-constructors-plugins.md) |
| `core/render`、`parse_callbacks.cj`、`parse_output.cj`、bundles、DSL | root 已分配 Task04；优先 7 个 render 值构造与顶层结果/回调记录 |
| `core/inline` | 留给 Task06 唯一 owner，避免同一内核重复改写 |
| 下方 7 个非热测试文件 | 本 owner 已转换，SOURCE_READY 冻结，02 下一正常 whole 编译覆盖 |
| `markit-kit` 全自有文件 | 本 owner 已在 02 正式安全窗实施并重新 SOURCE_READY 冻结；见下方实际记录 |

## 已实际转换：7 个文件 / 7 个类型

- `markit/src/tests/generators/block_generators.cj`：`BlockGenerators`。
- `markit/src/tests/generators/inline_generators.cj`：`InlineGenerators`。
- `markit/src/tests/generators/markdown_generator.cj`：`MarkdownGenerator`，保留 named 参数和原默认表达式。
- `markit/src/tests/generators/test_case.cj`：`TestCase`，三个字段仍为 public let，description 的 named 默认值不变。
- `markit/src/tests/utils/parse_mode_test_kit.cj`：只改 `ParseModeResult` 的十二字段值构造；`ParseModeFixture` 的两种重载与派生 chunk 逻辑保留。
- `markit/src/tests/benchmark/shared_fixture_benchmarks.cj`：`ChunkedBenchmarkInputStream`，两个字段仍 private let，offset 仍 private var、初值 0。
- `markit/src/tests/benchmark/shared_memory_benchmarks.cj`：同名独立测试 helper，保持相同访问性与可变性。

这些修改逐个读过定义和使用方式；没有盲目全仓正则替换。字段赋值本来不带调用、校验或副作用；参数顺序、默认值、public 构造可见性和字段 let/var 均保留。`GeneratorConfig` 的三构造重载暂保留给后续明确委派，不能把重载合并成一个默认参数构造来改变调用面。

## 已实际转换：markit-kit 17 个文件 / 22 个类型

在 02 确认上一正常 whole 编译已结束、授予安全写窗后实施；目前重新冻结，未启动自己的编译进程。

14 个成员形参主构造：

- `builders/multi_language_builder.cj`：`MultiLanguageBuilder`，保留 private let、named defaults 与原参数顺序。
- `config/multi_config_loader.cj`：`MultiConfigLoadResult`、`ValidationResult`，构造仍 private、字段仍 public let。
- `models/file_tree_node.cj`、`models/page_info.cj`：`FileTreeNode`、`PageInfo`；children 集合仍在原 body 中创建，位于参数字段赋值之后。
- `processors/preview_stream.cj`、`processors/typst_processor.cj`：`PreviewOperation`、`TypstAssetInfo`。
- `renderers/markdown_renderer.cj`：`ParsedFileInfo`、`MergedTypstHeadingLabel`、`MergedTypstRewritePlan`。
- `scanners/heading_state_scanner.cj`、`services/search_index_builder.cj`：`ScanResult`、`SearchIndexSection`；SearchIndexSection 的六个字段保持 public var。
- `themes/file_theme_loader.cj`、`utils/reading_statistics.cj`：`FileTheme`、`ReadingStatistics`；FileTheme 构造和字段均仍 private。

8 个保留显式字段与完整 body、只将主构造名称由 init 改为类型名的类型：`SiteNavigation`、`SiteStructure`、`MarkdownProcessor`、`TypstProcessor`、`TypstAssetState`、`WebsiteProcessor`、`NoopKitHookSink`、`ProcessedFileResult`。GlobalContext 读取、派生路径、集合创建及异常触发点的相对顺序均未移动。`ProcessedFileResult` 成功构造为 primary，失败重载仍为普通 init；两个签名及字段赋值保持原样，没有合并重载。

扫描剩余 `init` 只命中 `processors/parallel_processor.cj` 中的失败重载。其余 36 个文件没有应转换的显式构造；`@Derive`/宏生成调用面与默认成员初始化不通过新增构造强行改写。该批 `git diff --check` 通过，diffstat 为 40 insertions / 160 deletions；实际编译验证等待 02 对 kit 及当前稳定依赖的正常构建排程，不能由 markit 包的 whole 结果代替。

## 剩余可立即调度的具体候选

- Core render：`html_writer`、`text_writer`、`markdown_renderer`、`typst_renderer`、`render_registry` 的 writer/registration 值构造。`HtmlConfig` 的空 init 不需要机械转换。
- Core inline（06 owner）：`inline_dispatch_table` 中 dispatch result、`inline_parse_result`、`inline_parser_engine` 的三个纯值构造。
- Markit-kit：`models/file_tree_node`、`models/page_info`、`config/multi_config_loader` 两个结果类、`processors/preview_stream` 的片段值类、`renderers/markdown_renderer` 三个记录类、`services/search_index_builder`、`utils/reading_statistics`。
- Markit-kit 需保留行为：`processors/parallel_processor` 有成功/失败重载；`typst_processor`、`website_processor` 读取全局配置并派生路径；`multi_language_builder` 初始化顺序与并行参数不能改变。
- commandline：`terminal/interactive_form`、`unix_terminal_backend`、`windows_terminal_backend` 的参数存储。菜单状态有校验，terminal 获取 stdin/stdout 等资源顺序不改；macro quote 不是独立实体类，不直接套文本转换。
- codehl：`core/code_block`、`line_options`、`options` 的数据类。mathtex/mermaid 先从模型/配置切分，parser/render 状态拥有者保留原初始化顺序。

## 语法与验证边界

采用实际仓颉的类型同名成员主构造，不采用其他语言的 class-header 构造写法。Task04 已给出本机 stdlib 的 `Mark(let markedAt: Int64)` 与 `private DeriveInputParser(private let it: ..., private let logger: ...)` 示例；Task02 统一验证实际 SDK 语法，不由各代理重复造 probe/并行编译。可参考[官方类说明](https://docs.cangjie-lang.cn/docs/0.53.13/user_manual/source_zh_cn/class_and_interface/class.html)，实际当前 SDK 仍以本轮编译为准，不声明 1.1 兼容通过。

- 上述 7 文件 `git diff --check`：通过。
- 7 文件已给 root 与 02 明确 SOURCE_READY，当前无继续写入；由下一正常 whole 编译和既有回归覆盖，不新增风格测试设施。
- 当前尚未收到该批正常 whole 的完成结果；不会拿此前旧源码的通过结果替新版背书。
- 没有修改 README、共享 verification-log、第三方库或外部 stdlib；没有 commit/push。

## Source follow-up

The Task06 source-only primary-constructor cleanup is tracked in [primary-constructors-source.md](primary-constructors-source.md). Prepared scope: 11 files / 23 types, including 17 member-parameter folds. Source writes wait for the build owner's short safe window; normal Task06 regression covers the cleanup.

