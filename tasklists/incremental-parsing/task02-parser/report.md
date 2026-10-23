# Task02 parser 能力产品代码

状态：源码 ready；共享编译与测试由 Task02 owner 串行调度，尚未在本子任务声明通过。

## 实际改动

- `LeafBlockParser`、`ContinuationBlockParser`、`ParagraphBlockParser`、`InlineParser` 各新增带默认 getter 的三项产品属性：`supportsIncremental=false`、`incrementalFacet=None`、`incrementalIsolation=None`。
- 四类接口共25行新增（含import/注释），不改变现有语法方法、签名或调度逻辑，也不要求旧 parser 新增任何抽象成员。
- provider 必须通过显式 `IncrementalParserFacet` 提供；默认不制造 checkpoint、restore、effect rollback 或隔离证明。仅 bool=true 不等于有完整能力；实际选择/拒绝由独立 runtime plan 消费属性完成。
- 所有新增类型依赖指向通用 `markit.core.editing`，未引入插件名称/Markdown marker 到生产核心。

## 最小定向测试

新 `editing_parser_capability_test.cj`，tag `EditingContracts`，共4个测试：

1. 实际 Heading/Blockquote/Paragraph/Bold 注册出的四类 parser 均继承 false/None/None；现有 parser 实现无需修改。
2. 同一真实小插件的两个 parser 分别声明 false/true，两条语法均能 parse/append；true 不自动产生 facet/proof。
3. 显式不完整 facet 保持所有关键能力 false、没有隔离证明，不能用空成功操作伪装完整支持。
4. 已冻结旧式第三方源码零修改仍可注册、parse、分片 append/finalize，输出保持；不追加旧基线设施或 SDK 测试。

完整 provider、compat 单位/整会话 fallback 与 strict 拒绝的路径由 runtime-plan owner 的产品测试负责，本文件不把能力声明测试当作真实编辑执行通过。

## 当前验证

- 四个产品文件 `git diff --check`：exit 0。
- 修改范围与ready时SHA-256见 [source-ready.json](source-ready.json)。
- 无独立 cjpm 构建进程，避免与共享 target 冲突；等待 owner 实际编译/定向测试反馈。
- 未改旧 baseline fixture、生产 grammar、registry/runtime/codec/source/shared contracts 或 README。未提交推送。
