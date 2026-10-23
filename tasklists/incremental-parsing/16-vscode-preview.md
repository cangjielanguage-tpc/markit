# Task 16：VSCode 增量预览消费端

## 2026-10-23 用户裁剪（当前最高优先级）

用户已明确要求转向产品实现。下文早期方案中“补正式最低版兼容环境”、通用 oracle/计数/benchmark 框架、全面观测/统计矩阵等扩展工作，统一标记 **Deferred by user scope**，不再作为 Task02–16 的前置交付或放行门槛；不把未验证、失败或取消项改写为 Passed。现有 `cjc-version` 声明不提高，实际执行 SDK/命令和缺口照实记录。

保留每项产品改动所需的最小定向真实测试、同配置全量结果对照与同 `-O2` 比较；不要求后继任务接通已延期的大框架。仍遵守第三方 parser 默认不支持增量及安全默认实现、零源码修改兼容、仅有隔离证明才允许局部回退；语法收敛与语义传播分离，Task06 后执行 07-P 真实纵切。SeaJson 1.5.0 + 自实现 Content-Length stdio 的选型不变；预览迁移后退役旧预览开关，保留 `render --page`、append API 和现有源映射/渐进首屏/复制/动画/无白屏刷新。

本轮执行至 **Task16 完成并验证后停止，等待用户验收**；不得自动开始 Task17/18，不提交或推送。该说明优先于下文历史阶段的“只做文档”、扩大框架门槛和 Task16 自动放行 Task17 的记述；产品任务之间原有依赖与文件所有权约束继续适用。

Status: Pending

## Execution Contract

- Depends on: Task 15。
- Unlocks: Task 17。
- Execution: 串行。
- Delegated owner: VSCode扩展与webview子 agent，由协调者指派。
- Scope boundary: 拥有`vscode-extension/src/**`、`media/**`、`test/**`、`package.json`及必要扩展打包配置；输入为Task15真实worker/schema/lifecycle和原生source-map/DOM patch契约，输出为差量预览、交互回归、未来桌面VSIX0.1.0构件和验证记录。该目录当前未跟踪但属于既有工作，实施先保留差异；禁止重写core语法、worker协议、workspace/重型服务或README进度，缺contract退回owner。

## Goal

用单个持久worker和有版本的有序DOM/source-map事务驱动单页预览，保留语言切换、状态spinner、链接与滚动/光标/选择/复制。正常编辑不全源getText、不spawn、不全页HTML/hex传输或reconcile。扩展UI使用英文，未来桌面交付目标为VSIX0.1.0，不代表本轮已产包。

## Current State

- `src/extension.js:261–266`取得contentChanges，却只将其用于webview行重定位，native渲染仍event.document.getText()；:113用getText().length验证selection。
- `src/session.js:123,131`每次spawn CLI、完整写镜像并读HTML；`src/document.js:28,31`解码完整source hex、全量split行offset。
- `media/preview.js:101`全量template parse/outerHTML signature reconcile；:47每次anchors()查询全部anchor、读layout并排序。
- `media/selection.js:24,79,87`硬编码i18n正则、再次解码全源hex、全文TreeWalker映射。该逻辑不能作为插件中立source-map消费端。
- 当前debounce默认120ms，配置若minimum仍100ms，则单debounce已耗尽可见p95≤100ms目标；实施须同时调整默认与schema约束，不能只改调用默认值。

## Follow-Up Work

**新增迁移必做：** 扩展只启动`worker --stdio`，文档选择移入URI协议，不再通过render --page/--preview-stream/--incremental驱动预览；仍保留独立CLI render --page用途。worker自动处理资产缓存，删除扩展对旧flag的拼接/分支。迁移先通过与15真实集成，再由15删除旧flag；若失败修新路径，不能以保留旧预览路径作为最终交付。

初次open逐个消费完整原子事务并展示首屏，后续事务继续补充/修正；保留spinner、状态、滚动与编辑动画。不要等全部文档完成才显示，也不在未commit时应用chunk；每次提交校验URI/source version/epoch及render revision链。

1. session接入worker initialize/open/change/flush/cancel/close与新epoch重启；每扩展host或项目调度按worker能力隔离，复用PID。初次open/resync才getText；正常contentChanges发送rangeOffset/rangeLength/text与document.version，保持所有edit次序。
2. source accepted与render commit分离，16–32ms或自适应debounce仅合并flush。同步修改package schema现minimum100限制、默认值和测试，记录端到端delay；高负载背压不丢edit，取消旧render不能丢source change。
3. webview维护nodeId→DOM、parent/slot/sibling有序索引，按transaction原子apply insert/remove/move/replace/meta/source-map/resourcepatch。错版本/丢chunk发resync，不做whole HTML signature匹配；重复同文节点身份不混淆。消费Task13经Task14/15交接的CodeHL stable line ID、line HTML和source-map delta，以通用render subunit slots实施row级patch，核心无需识别CodeHL；不能把千/万行codeblock的innerHTML整体重置。
   超长纯文本paragraph消费Task04/06 bounded text leaves/versioned payload，支持通用text-splice或render subunit patch；依native map的UTF16界限只替换局部DOM Text range，不能因为原来是一个巨大TextNode就传整段HTML/替换整个paragraph。显式copy/export全文允许按用户请求O(N)，正常edit不触发该路径。
4. 删除预览热路径全MD hex、完整HTML文件读回及资源正则重写链；初始shell可完整构造，正常patch只渲染受影响片段。资源URI按可信workspace/temp路径和版本处理，保留CSP、workspace trust、本地链接与原有访问边界。
5. 原生source-map按块维护DOM text↔原文UTF16区间和版本，消费positiondelta，不自写i18n/entity/Markdown语法regex。生成字符、隐藏语言、代码高亮span、表格/公式fallback有明确定位规则。selection长度用已知version长度/文档end offset，避免全文getText。
6. 增量layout索引+ResizeObserver/image load失效，scroll/光标/选中用二分/局部查询；保留双向滚动echo抑制、native selection、caret、复制source/可见文本、code tabs/展开状态，未变DOM保持互动状态。只初始化改变的code/math/mermaid单元；未改code行DOM、选择和滚动锚点保留，行号/highlight/i18n仅变化时走meta/source-map delta，不能在client重新拼整个code HTML。
7. 单页只展示当前文档内容，不带网站sidebar、header/footer、全站navigation；状态栏与spinner显示语言/渲染/失败，英文按钮/通知/配置描述。打开Markdown自动检测其所属文档项目，仅有真实归属歧义才提示确认，不先要求用户手工选项目。多个项目的语言分别持久化在各项目配置并支持热切换；文档切换自动采用所属项目语言，保留本地page链接。
8. 添加worker stub/协议测试、webview DOM patch测试、source-map选择/滚动测试和真实native集成；多个root/文档目录的Markdown自动归属、共享页真实歧义才确认、各项目配置独立持久语言/热切换、多doc切换/乱序render/取消/重启/close、CSP/资源链接和dirty/disk事件均覆盖。按现有依赖生成桌面VSIX0.1.0并检查内容与可安装性，未获发布授权不上传市场。

## Acceptance

- **迁移/首屏门槛：** 实际spawn/参数spy仅见worker --stdio，无旧两个flag或render --page预览调用；延迟后部渲染时前部完整事务先可见，后续commit继续补齐，版本切换/取消/重启不混入旧结果，动画/滚动/状态保留。证据交15清除旧入口及17独立复验。

- 普通edit spies证明getText(full)=0、spawn=0、fullHTML reconcile=0、full sourcehex bytes=0；初次open/显式resync例外标记清晰。
- 对每个commit检查URI/version/epoch和transaction完整性，过期结果不能覆盖当前文档；cancel不漏source、断worker后可恢复且有英文错误/状态提示。
- 未变节点DOM引用和code tabs/选择/scroll状态保持，重复文本节点不会误复用；有序move/insert/remove准确。
- 千/万行fence中间改单表达式，row级patch仅改真实受影响行；未改行DOM引用保持、未join整个code literal/HTML、未重置整pre/code innerHTML。native和webview计数共同证明端到端行增量，不能只证明tokenizer少调用。
- 超长纯文本paragraph改单字符，使用native UTF16 map的text-splice/有界render subunit，传输/拼接字节和DOM Text range替换随变更范围而非整paragraph增长；无整literal/HTML materialize、整paragraph重建。显式全文copy/export性能单列，不作为正常编辑必经。
- native source-map覆盖中文/emoji/CRLF、synthetic嵌套、i18n/HTML/entity/代码/表格；无语法识别regex残留用于编辑边界或source定位。
- 单页无侧栏/网站头底，英文UI及spinner可见；滚动、光标、选中、复制、跨页本地链接、语言切换与原有trust/CSP通过回归。
- 多root/多文档目录直接打开Markdown自动归属，不要求预选项目；单一归属不弹选择器，真实歧义才确认。各项目语言写入各自配置、热切换且重开保持，切换文档/项目不串语言或覆盖其他项目配置。
- 默认debounce16–32ms或自适应且minimum100限制已解除；可见延迟分段测量，不能把120ms等待从计时中偷偷扣除。
- 未来桌面VSIX0.1.0产包、manifest/内容和安装证据齐全；不声称本轮方案已产包，不未经授权发布。把实际test/build/package命令和版本交Task17。

## Verification Record

- 本轮仅调查现有扩展源码并编写方案，未实现/打包/安装VSIX。
- 未来按`vscode-extension/package.json`实际scripts执行测试与打包；新增WorkerClient/DOMPatch/SourceMap用例为拟新增，不能把计划名称当现有命令。
- 当前`test/session.test.js` native集成受`MARKIT_TEST_BINARY`条件控制；未来须显式配置真实worker binary并报告skip，不能把skip算通过。
