# Task01 实测语义基线与基础设施纠错表

更新：2026-10-23。观察来自当前本机已编译测试的 [148 条原始输出](observations.json) 和 [严格归纳](summary.json)，不是按历史文档推定。生产源码未修改。

| 分类 / 最小实际输入 | 模式与实测结果 | 影响与预期 | 后继任务 |
|---|---|---|---|
| 必须纠正：`before <code>protected</code> after\n` | 四模式均由独立遍历检出重复 ID `2`；最终 HTML 都是 `<p>before <code>protected</code> after</p>`；坐标轴检查无错 | `HTMLInlinePlugin.pairTags` 的 container 与 protected child 共用 opening ID。输出相同不能证明身份有效。应保留文字/结构/HTML，同时以唯一分配的 child ID 替代；修正时必须精确迁移本 baseline 断言，不全局忽略 ID | 04 唯一身份设施；08 HTMLInline typed 适配；17 强不变量 |
| 已修映射须保护：`prefix\n\n> 甲😀\n` | 四模式叶 Text 字面/源片段均为 `甲😀`，byte `10..17`，rune `10..12`；无重复 ID、无坐标轴错误 | 这是 c510aee 已修复行为，不能照旧文档再次当成现存零起点缺陷。03/07 的新映射必须保留它 | 03 组合映射；07 quote 适配 |
| 不变量负例：人为构造 `TextNode(1, SourceSpan(1,3,0,2), "bc")`，源 `abcd` | 独立坐标检查准确检出 1 个错误；额外构造 ID1 child 后检出重复 ID；测试通过 | 这是显式 synthetic 检测器自测，不是生产 bug 计数 | 02/03/04 复用同类验收 |
| 不变量负例：人为构造 span byte/rune 都为 `0..2`、literal `bc`，源 `abcd` | 坐标轴合法（0 个轴错误），但 opt-in `literalSliceMatches` 返回 false | 证明轴一致不等于映射正确。仅对已知未变源文字的叶节点启用 slice 相等；不能把 entity/synthetic 内容一概当原文 | 03 provenance 与 mapping |
| 保持既有最终语义：`[name][id]\n\n[id]: /target` | 四模式最终 HTML 都是 `<p><a href="/target">name</a></p>`，各有 1 个 AST patch；三种流模式 emittedHtml 仍为 href 空字符串，direct 的 emittedHtml 是最终 HTML | 这是实际 finalizer/patch 观察，不能只拼 fragment 判等，也不能丢失最后 patch。不得将这些 patch 数当编辑局部性计数。带尾换行的 ReferenceLinkPlugin fixture 有同类差异 | 07 reference、12 派生语义、15/16 原子 patch 消费 |
| 保持既有语义并登记流式输出缺口：`# section\n\nparagraph\n`，`Standard.blockAutoAnchor=true` | 四模式最终 HTML 都有 heading/source 属性与段落 `id="1-block-1"`；三种流模式 emittedHtml 为 `<h1 id="section">section</h1><p>paragraph</p>` 且 astPatches=0，direct emittedHtml 则含最终属性 | 最终输出正确不代表现有 fragment 链完整表达 AutoAnchor 派生属性。保留最终锚点语义，后继 worker/renderer 必须用显式事务/依赖更新补齐，不能声称此 legacy fragment 已满足新预览协议 | 12 AutoAnchor 有序派生、15/16 renderer/协议 |
| 保持 CRLF 契约：`甲😀\r\n\r\n正文` | 四模式最终 HTML `<p>甲😀</p><p>正文</p>`，当前坐标轴检查无错；string chunks 切在 CR/LF 之间，byte feed 每次单 byte | 当前 scanner 将 CRLF 记为一个 terminator rune，同时保留两个源 byte；后续不能用物理 rune 总数擅改此观察。UTF-16 编辑协议需由02/03明确换算 | 02 坐标契约；03 索引 |

上述 37 个 fixture 的最终 HTML/Markdown/Typst/AST JSON/tree 在四模式下全都逐字符串一致；stream fragment 明确有 3 组差异（ReferenceLinkPlugin、AutoAnchorPlugin、edge-3），原始输出未标准化或删除任何 span/ID 证据。其余未覆盖输入仍须后续全矩阵验收，不能推广为所有既有行为完全一致。
