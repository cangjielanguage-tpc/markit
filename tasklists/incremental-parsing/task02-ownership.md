# Task02 产品接口与并行所有权（2026-10-23）

用户已取消补最低版本兼容与通用测试框架扩展；以下是产品接口实现，保留最小定向测试、fresh结果对照与同-O2时间比较。现有1.3.0-alpha为实际测试工具链，不声称正式1.1.0兼容通过。

| Owner | 独占可变文件 |
|---|---|
| task02_contracts | `markit/src/core/editing/*.cj`公共值/Source/Tree抽象契约；`02-plugin-contracts.md`；Task02交接/验证记录 |
| legacy_fixtures | `core/block/{leaf_block_parser,continuation_block_parser,paragraph_block_parser}.cj`、`core/inline/inline_parser.cj`、独立`tests/unit/editing_parser_capability_test.cj` |
| oracle_tools | `core/nodes/node.cj`的lossless hook、新`core/nodes/node_codec.cj`、`core/session/session_state.cj`、独立`tests/unit/typed_codec_test.cj` |
| perf_baseline | `core/plugin/editing_capability_plan.cj`、`core/plugin/{plugin_registry,plugin_registrar}.cj`、`markit.cj`、独立`tests/unit/editing_capability_plan_test.cj` |

## 首版共享API

`markit.core.editing`已提供`EditingPolicy(Compat/Strict)`、`EditingFallbackScope(NoFallback/IsolatedUnit/Session/Rejected)`、`ParserIsolationProof`（syntax/state/semantic边界全部为真且非空evidence才verified）、`IncrementalParserFacet`、`IncrementalCheckpoint`、`IncrementalStatePayload`、`IncrementalReadDependency`、`EditingVersionState`。

`IncrementalCheckpoint`必须携带documentId/owner/sourceVersion，构造时clone payload；恢复provider必须拒绝其他文档，即使owner/version/上下文相同。版本重基/映射策略由05明确，不能默认跨文档恢复。

四类既有parser统一增加带安全默认体的`supportsIncremental: Bool=false`、`incrementalFacet: ?IncrementalParserFacet=None`、`incrementalIsolation: ?ParserIsolationProof=None`。不新增旧parser必须实现的抽象方法。safe方法provider只由显式facet提供；仅设置bool不构成可用编辑能力。

Runtime plan按真实注册parser逐个读取以上三属性：enabled+完整facet可增量；disabled/缺facet仅在proof.verified时选择IsolatedUnit，否则Session；Strict必须在任何source/state/ID/patch变更前返回Rejected/明确诊断。所有内置暂未适配能力显式Pending，不能将fallback计成完成。批量parse不创建编辑历史/读依赖/effects记录，编辑计划以独立显式API按需构建，不增加batch热路径。

所有共享编译与test binary运行由task02_contracts串行安排；各owner先实现并报告源码ready，不自行并发cjpm写target。不提前实现03的rope或04的持久树。

## 03/04接口与隔离交接

- 03独占未来`core/source/editable_*.cj`、rope/坐标/映射实现与其独立测试，引用已冻结`core/editing/editable_source_contracts.cj`，不得改公共契约、node/存储或parser。Source版本只读；旧版本保持可用；批量编辑采用原版本坐标、升序互不重叠。UTF-8半字符/UTF-16代理对内部切点及过期版本原子拒绝；**原始byte/rune/线性UTF-16坐标允许单独删除CR或LF、跨叶join/split**，不能将注释误解为禁止合法CRLF编辑。line和UTF-16 column均为零起点；line/column不能表示CRLF中间点，不将其伪装成可往返的行列坐标。
- 同一原始位置的多个零长度插入按输入数组顺序拼接；零插入位于非空替换内部视为重叠，非空范围必须互不重叠。相同start处零插入在非空替换之前排列，表示插在替换文本之前；end处插入在替换文本之后。空edits数组返回当前版本、不分配新版本；非空合法batch仅递增一次版本（包括文本碰巧相同的显式编辑）。
- 04独占未来`core/document/persistent_*.cj`、`core/nodes/persistent_*.cj`、owner effects存储与其独立测试，引用`core/editing/editing_tree_contracts.cj`。公共协议仅opaque typed payload，typed legacy桥在`core/nodes/node_codec.cj`；不得改03源实现或共享契约。
- NodeCodec.clone是显式lossless原型/按需legacy桥，当前memoized整图复制不是编辑热路径。03/04/05不得每次普通编辑调用整树clone来冒充持久复用，需在04的真实存储中实现共享/局部替换。
- sourceVersion已ack后领先parse/render是合法状态；取消计算不回滚accepted source。严格能力拒绝发生于source版本、node ID、状态及patch变更前。
- 共同接口缺口由02 owner串行处理；03/04不能各自修改同一协议或引入source↔nodes↔editing包环。只有root审阅02最小实际测试和契约后才放行03/04，本说明不是提前启动授权。
