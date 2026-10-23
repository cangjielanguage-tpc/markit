# Task01 legacy 基线与旧式扩展 fixture

状态：两份新源码已安装、实际编译并运行。37 个 fixture 的 148 条四模式记录已完整验证；本子任务5个案例通过，细节与剩余缺口见 [实际报告](report.md)。Task01整体及Task02放行仍由协调者审查全部子任务证据决定。

## 文件所有权

- `markit/src/tests/utils/editing_legacy_fixture.cj`：30 内置插件输入、明确 bundle/config、旧式第三方 notice 插件源码、独立 ID/坐标不变量。
- `markit/src/tests/unit/editing_legacy_baseline_test.cj`：四模式真实输出记录、边界案例与不变量自测。
- 本目录：暂存代码、命令日志、原始观察和归纳脚本。协调者拥有 Task01 主文件、README 状态和公共验证记录。

## 兼容 fixture 约定

`EditingLegacyNoticePlugin` 是使用当前公开 `Plugin`、`LeafBlockParser`、`ParseSession.createTextNode` 接口的完整第三方扩展。它注册两个实际识别并消费输入的 parser；不是空插件。源码没有编辑能力声明或编辑协议依赖。编译与 parse/append 通过后冻结源码 SHA-256；Task02 必须保持该文件逐字节不改。

两个 parser 名为 `isolated-candidate` 与 `unknown-effects-candidate`，名称只作为后继测试目标标识，**不构成当前隔离证明或增量能力声明**。同 plugin 混合 parser 编辑能力须由 Task02 新增外部适配 fixture 验证，不能为了适配新协议修改此旧源码。

| 后继变体 | 当前状态 | 必需证据 |
|---|---|---|
| 两 parser 均无编辑声明 | 本机1.3.0-alpha四模式实测通过；正式1.1.0未验证 | 源码已冻结，后续零源码修改可编译、注册、解析、追加 |
| 一 parser 支持、一 parser 不支持 | 未接入；当前接口无编辑能力字段 | Task02 独立 wrapper/新 fixture 表达逐 parser 能力 |
| 缺 probe/restore/effects/codec 各 facet | 未接入 | Task02 typed 能力诊断；不以一个 bool 冒充全部能力 |
| 已证明边界、状态、语义隔离 | 未接入，无证明 | Task02/17 明确隔离证据后才允许单位完整解析 |
| 未知全局副作用 | 未接入，不假定局部安全 | Task17 默认整会话回退，显式 strict 原子拒绝 |

## 观察边界

每个 `EDITING_LEGACY_RESULT` 保存当前模式的 HTML/Markdown/Typst/AST JSON/tree、emitted HTML、更新/封块/patch 数与独立不变量输出。原始记录保留全部差异，不预设四模式相等。update/patch 数随分块不同是 legacy 观察，不能据此推断编辑工作量。运行 `cjpm test --no-progress --include-tags=EditingOracle --show-all-output` 时保留输出（本机 `cjpm test --help` 已确认支持该选项，exit 0）；日志归纳：`python summarize_legacy.py <actual-test-log>`，要求精确37组/148条真实记录，每组完整4模式，缺组、多组、重复模式或无真实记录时失败。`summarizer-selftest.json` 是显式 synthetic 截断负例的拒绝证据，不是生产解析通过证据。

当前 c510aee 已修正 quote/i18n synthetic source 的部分映射，测试精确保护 `prefix\n\n> 甲😀\n` 中文/emoji叶节点 byte 10..17、rune 10..12、rawContent，四模式均通过。独立坐标不变量使用当前 scanner 的 CRLF 单 terminator rune 约定。HTML protected tag 的重复 ID2 已在四模式实测确认，保留[精准基线](known-corrections.md)并交 Task04/08 纠正，不能把错误 ID 当兼容语义。
