# 自有插件主构造函数写法整理

范围：`markit/src/plugins/**/*.cj`，盘点共 227 个源文件；目录为 anchor、commonmark、gfm、i18n、standard、toc 和根导出文件。未发现 vendor、thirdparty、生成物目录。只整理构造写法，不包含插件增量算法；不修改 Task 05 核心、session 或测试文件。

## 语法与约束

本机实际编译器为 `1.3.0-alpha.20260920003052 (cjnative)`。主构造函数使用类型体内同名构造函数，例如 `public Config(public let enabled!: Bool = false) {}`，不是在 class 声明后加参数列表。

只读参考：本机 stdlib `libs/std/deriving/impl/parse_utils.cj` 的 `Mark(let markedAt: Int64)` 与 `parseDerive.cj` 的 private 成员形参样板；该清单不作为当前 binary 的版本对应证明。[官方语法说明](https://docs.cangjie-lang.cn/docs/0.53.18/Spec/source_zh_cn/Chapter_02_Types%28zh%29.html)说明成员形参及普通形参的顺序、可见性与同名构造函数语法。

保持参数顺序、命名参数标记、默认值、可见性、let/var、重载、super 与副作用顺序。无法在保持这些语义的前提下压缩时保留显式初始化体。共享构建由 02 单独串行执行；不新增测试设施。

## 第一批：9 个纯配置类型

9 个纯配置类型将同序字段声明与 `this.field = field` 合并为 public let 成员形参；没有 super、校验、克隆或其他副作用：

- `anchor/auto_anchor_config.cj`：AutoAnchorConfig
- `commonmark/block/html_block/html_block_config.cj`：HtmlBlockConfig
- `commonmark/inline/html_inline/html_inline_config.cj`：HtmlInlineTagPairingConfig
- `gfm/block/table/table_config.cj`：TableConfig
- `standard/block/fenced_code_block/fenced_code_block_config.cj`：FencedCodeBlockConfig
- `standard/block/heading/heading_closable_config.cj`：HeadingClosableConfig
- `standard/block/heading/heading_slug_config.cj`：HeadingSlugConfig（struct）
- `standard/block/list/list_config.cj`：ListConfig
- `standard/inline/link/link_config.cj`：LinkConfig

已逐文件读回，public 访问、字段类型、named/default 与原赋值次序保持一致。I18nConfig 的校验及 HeadingNumberingConfig 的校验/数组构造不压缩为成员形参，第二批保留其显式执行体。


## 第二批：已完成并 SOURCE_READY

02 确认整编尚未启动且无 compiler 后，在独占 plugins 的安全窗一次落盘。第二批 92 文件、108 类型：50 类型将纯同序直接赋值合并为成员形参，58 类型只把 init 改为同名主构造函数，完整保留初始化体。写入前确认所有源文件仍与准备快照相同，写后逐文件读回一致；未启动独立 build/test。

总计转换 101 文件、117 类型（59 成员形参、58 显式执行体），其余 126 文件没有需转换的显式构造函数。仅 I18nPostProcessor 的第二个 init 重载保留，参数、可见性和执行体均不变。FootnoteDefinition 的 content/number 保持 public var；private 字段仍是 private 成员形参。

未将以下执行体压缩为成员形参，以保持 super 调用、校验/派生计算、字段访问和副作用次序；它们仍已使用同名主构造写法：

- 父类调用及其后字段/metadata/raw 初始化：`HTMLBlockNode`, `CommonMarkAutolinkNode`, `EntityReferenceNode`, `HTMLInlineNode`, `AlphabeticListItemNode`, `AlphabeticListNode`, `MathBlockNode`, `TableCellNode`, `TableNode`, `TableRowNode`, `TaskListItemNode`, `TaskListNode`, `AutolinkNode`, `FootnoteDefinitionNode`, `FootnoteReferenceNode`, `InlineMathNode`, `StrikethroughNode`, `I18nBlockNode`, `I18nInlineNode`, `UniversalBlockNode`, `UniversalInlineNode`, `BlockquoteNode`, `DividerNode`, `FencedCodeBlockNode`, `HeadingNode`, `OrderedListItemNode`, `OrderedListNode`, `UnorderedListItemNode`, `UnorderedListNode`, `ParagraphNode`, `BoldNode`, `HardBreakNode`, `ImageNode`, `InlineCodeNode`, `ItalicNode`, `LinkNode`, `SoftBreakNode`, `TocItem`, `TocNode`。
- 校验、派生字段、集合追加或参数顺序：`HTMLBlockState`, `AlphabeticListBlockState`, `AlphabeticListItemData`, `MathBlockState`, `TableState`, `TaskListBlockState`, `TaskListItemData`, `FootnoteDefinitionState`, `I18nBlockState`, `I18nConfig`, `I18nPlugin`, `I18nSessionState`, `FencedCodeBlockState`, `HeadingNumberingConfig`, `HeadingSessionState`, `ListBlockState`, `ListItemData`, `LinkPlugin`, `SmartHeadingLinkResolver`。

插件源码保持冻结。02 的普通整编包含两批，最终 `task05-verification/integrated-compile-3.log` 中 `TASK05_WHOLE3_COMPILE_EXIT=0`；主 owner 已修复早期 nested fresh 及 legacy anchor 差异。随后 `task01-baseline/task05-full-console-2/summary.json` 实际记录 27/27 包 exit 0、692 passed / 0 skipped / 0 error / 0 failed；`task05-verification/legacy-comparison-2/versus-frozen01.json` 的 148 条固定 legacy 记录 differences 为空。上述证据已只读核实，仅背书当时冻结的产品与插件写法；不背书之后新增的旧 helper style 或 Task06 产品改动。未增加测试设施、SDK 门槛或额外验收阶段。
