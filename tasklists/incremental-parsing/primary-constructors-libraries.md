# 仓库自有三个渲染库：主构造写法收敛

Owner：`task05_engine/session_checkpoint`。范围为 `codehl/src`、`mathtex/src`、`mermaid4cj/src` 的仓库维护 `.cj`，及root追加授权的原唯一 `core/session` 四文件；aux4未改。状态：LIBRARIES / SESSION_AND_OVERLOAD_SOURCE_READY，待02正常构建与现有回归，不增加测试/benchmark/大验收。

## 归属与排除

- 三个manifest均声明本仓 `zichexuelan` 的 Markit 构建期库；README分别说明自有Cangjie grammar/token pipeline、typed TeX AST/parser/writers、Cangjie Mermaid parser/layout/SVG实现。src git历史也属于该仓作者（codehl最新 `7f3052a3`，mathtex与mermaid源码初始 `5fe1e9ca`）。
- 逐目录区分upstream资产：**整个** `codehl/assets`（含shiki-upstream、grammar/theme JSON）、`mathtex/assets`（含katex-github-v0.16.47）、`mermaid4cj/assets`（含mermaid-upstream、fixtures、themes）均未修改；这些资产内没有 `.cj`。
- `mermaid4cj/src/layout/dagre` 是README明确的本仓Cangjie迁移实现，并非直接引入的upstream JS；upstream内容另在assets隔离。本轮仅修改此维护中的CJ构造写法，不改算法内容。
- 所有 `target`、vendor/third_party/generated/node_modules路径、工具链及用户stdlib完全排除。没有依赖或manifest变更，没有编码转换、重置用户修改、提交或推送。

## 覆盖

| 模块 | 修改文件 | 转换单构造 | 处理 |
|---|---:|---:|---|
| codehl | 10 | 34 | core、grammar、tokenizer/languages、themes，含两组primary+secondary |
| mathtex | 9 | 29 | typed AST、core、parser、HTML/MathML/Typst writers |
| mermaid4cj | 36 | 132 | models/context、layout（含维护的CJ dagre）、parser、SVG writers、2个原有测试helper |
| 三库合计 | 55 | 195 | 122个纯赋值收敛成员参数，73个保序body |
| session追加 | 4 | 8 | 5个纯成员参数、3个保序body；不碰04 effects、source cache/lifecycle |

- 纯赋值仅在字段与参数**同名、同类型**、每字段恰好一次直接赋值、无其它默认字段initializer/构造逻辑时折叠。成员可见性、let/var、参数顺序、named `!` 与默认表达式均保持原文。
- 复杂构造只改为类内 `ClassName(...)` 主构造命名；原字段声明、body、super调用、分支/分配/异常副作用和初始化顺序保留，不把它们提升到默认参数或成员initializer。
- `codehl.languages.GrammarTokenizer` 三参重载与 `RuleMatch` 五参重载只命名为primary，保留原body；另一个短重载仍为secondary init，签名、body、default与分配顺序均未改，没有合并或引入新委托。依据同仓 `I18nPostProcessor` 一primary+独立赋值secondary在02 whole1实际编译成功的证据，不再仅因多init就跳过整类。
- session追加仅 `parse_session.cj / parse_session_checkpoint.cj / session_patch_queue.cj / session_symbol_table_store.cj`。8个显式构造全部覆盖：`ParseSession`、`SessionSymbolTableStore`、`SessionSymbolTableSandbox` 保序body；checkpoint envelope、syntax envelope、patch link/snapshot、symbol checkpoint共5个纯构造折叠。原无显式init的queue等保持隐式默认，不额外增加构造入口。
- 语法依据为实际只读stdlib `PrimaryCtorDecl`文档示例与 `deriving/Derive.cj`、`unittest/delta_comparison.cj`等现有主构造（含named member参数）；没有修改stdlib，也不声称最低SDK 1.1已实跑。

## 执行与验证

02确认首whole结束且下轮尚未读依赖后，才开放安全短窗。转换先在Temp准备；每文件写前全量SHA256核对原始bytes，匹配后约2秒一次短批落盘并立即SOURCE_READY。所有原始bytes备份在临时工作目录，以防诊断需要精确局部恢复；没有使用checkout/reset覆盖用户内容。

- `git diff --check -- codehl/src mathtex/src mermaid4cj/src`：通过，无whitespace诊断。
- 静态残余init仅上述两组中的2个secondary；session四文件无残余显式init。没有新增测试或验收设施。
- 02统一 whole3 已实际编译成功：`task05-verification/integrated-compile-3.log` 为 `TASK05_WHOLE3_COMPILE_EXIT=0`，包含本轮全部库/session主构造及两组primary+secondary重载写法。现有测试运行结果仍待02统一记录；不将编译成功等同全部库自身测试已运行。
- 同一whole3产物的既有定向回归已运行：`editing-engine-test-3.log` 为39个选中case通过、0 error/fail、exit0（runner另列98未选中skip）；`legacy-anchor-test-1.log` 为9/9通过、0 skip/error/fail、exit0。它们属于Markit消费者回归；未据此声称三个库自身测试全部运行，最终全量由02统一记录。
