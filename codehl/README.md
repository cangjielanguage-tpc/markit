# codehl

`codehl` 是一个用仓颉实现的构建期代码高亮库，当前主要服务于 Markit/markit-cli：Markdown 里的代码块在编译阶段被预渲染成 HTML，网页运行时不再需要 Shiki。

语法定义来自 VS Code/TextMate grammar JSON，JSON 解析使用 `seajson`。仓颉代码负责 grammar 加载、TextMate 状态机、主题解析、token IR 和 HTML 输出，不把语言语法写死在源码里。

## 当前能力

- 读取 `assets/grammars` 下的 `.tmLanguage.json` 和 VS Code 内置 grammar 资产；内置目录和用户 `grammarDirs` 分开管理，并按文件名、`name`、`scopeName`、`fileTypes` 自动发现语言。
- 支持常见 TextMate 结构：`patterns`、`repository`、`include`、`$self`、`$base`、`begin/end`、`captures`、`beginCaptures/endCaptures`、`contentName`、部分 `while`、外部 scope include、跨行状态保存。
- 内置常用语言别名规范化，例如 `cj` -> `cangjie`、`js` -> `javascript`、`ts` -> `typescript`、`sh/fish/zsh` -> `bash`；实际 grammar 文件由显式配置、用户 grammar 目录或内置 grammar 目录决定，优先级依次降低。
- 支持主题 JSON 加载，已实现 selector specificity、父 scope selector、排除 selector、同分后置覆盖、`fontStyle` reset、scope stack 匹配和样式缓存。
- 输出 token 中间结构 `CodeBlock`，再由 `toHtml()` 或 `writeHtmlTo(StringBuilder)` 渲染 HTML。
- 支持 plain fallback：不认识的语言不会失败，会输出已转义的普通代码块。
- 支持 Markit 需要的行高亮、i18n 行过滤、目标语言过滤、双主题 HTML 片段。
- 已接入 Markit fenced code block：原始代码保留在节点里，高亮结果写入节点属性/meta，HTML writer 再按配置输出。

## API 概览

核心入口是 `codehl.core.Highlighter`：

- `supportsLanguage(lang)`：检查语言是否能从配置或 grammar 目录中解析到 tokenizer。
- `supportsTheme(theme)`：检查主题 JSON 是否可加载。
- `codeToTokens(code, options)`：把代码转换为 `CodeBlock` token IR。
- `highlightBlock(code, options)`：`codeToTokens` 的别名。
- `highlight(code, options)`：直接输出单主题 HTML。
- `highlightPlain(code, options)`：强制输出 escaped plain HTML。
- `highlightDualTheme(code, options)`：输出 light/dark 双主题 wrapper。
- `highlightDualThemeFragments(code, options)`：分别返回 light/dark HTML 片段，供 Markit 写入节点属性。

`HighlightOptions` 支持：

- `lang`
- `classPrefix`
- `highlightLines`
- `i18nLines`
- `targetLang`
- `themeName`
- `theme`

`DualThemeOptions` 支持：

- `lightTheme`
- `darkTheme`
- `lightThemeModel`
- `darkThemeModel`
- `base`

## 中间结构

当前保留 token IR，不是直接拼最终字符串：

- `CodeBlock`：语言、class prefix、代码行、最终 tokenizer state、主题。
- `CodeLine`：原始行号、文本、token spans、是否高亮、是否可见。
- `CodeSpan`：字节范围、主 scope class、完整 scope stack。

`codeToTokens` 可以接收 `initialState`，`CodeBlock.finalState` 可以用于后续分块解析。这是后续增量解析的基础边界；目前 Markit 集成仍按完整代码块渲染。

## Markit 集成

Markit 的代码块渲染采用构建期预渲染：

- Markdown 解析阶段保留原始代码文本和语言信息。
- 开启 `enableCodehl` 时，Markit 调用 `codehl` 生成 light/dark 两份 HTML，并写入 fenced code 节点属性/meta。
- HTML writer 从节点属性输出双主题代码块，主题切换由页面 CSS 控制。
- 关闭 `enableCodehl` 时，不写入高亮属性，HTML writer 输出普通 escaped `<pre><code>`，方便用户自带前端高亮方案。

这个协议让 `markit-cli` 编译 Markdown 时不依赖 Node/Shiki；网页运行时也不加载 Shiki。

## 测试

测试文件拆在 `src/tests` 下，按能力分组：

- `highlighter_tests.cj`：核心 API、plain fallback、双主题 wrapper、writer append。
- `grammar_engine_tests.cj`：TextMate grammar loader/tokenizer 结构能力。
- `regex_adapter_tests.cj`：TextMate/Oniguruma 常见 regex 语义降级。
- `theme_resolver_tests.cj`：主题 selector resolver。
- `language_registry_tests.cj`：语言别名、配置覆盖和 grammar 目录自动发现。
- `shiki_migration_tests.cj`：从 Shiki 上游输入迁移的 golden tests。

常用命令：

```powershell
cjpm test --no-progress --include-tags CoreHighlighter
cjpm test --no-progress --include-tags TextMateGrammar
cjpm test --no-progress --include-tags RegexAdapter
cjpm test --no-progress --include-tags ShikiMigration
cjpm test --no-progress
```

Shiki 上游测试资产可以临时放在本地 `assets/shiki-upstream` 作为迁移参考，但该目录不提交到仓库，也不直接由 `cjpm test` 执行。已解锁的迁移用例使用精确 golden HTML/token 断言，不用 `contains` 做正向测试。

## 当前完成度

按 Markit 文档站和常规 Markdown 代码块场景看，`codehl` 已经基本可用，可以替代原来的 Shiki 运行时路径。

按完整通用高亮库口径，当前完成度约为 82%-84%：

- API/IR/HTML writer：约 82%。
- TextMate grammar engine：约 74%。
- Regex adapter：约 70%。
- Theme resolver：约 82%。
- Markit integration：约 84%。

这个数字不是 Shiki 全库兼容率。它表示当前功能对 Markit 构建期高亮目标的可用程度。

## 未完成边界

下面这些能力还没有承诺完全等价于 Shiki/TextMate/Oniguruma：

- 复杂 embedded grammar 和 injection 场景仍需继续补强，尤其 Vue、HTML 中更复杂的 JS/CSS 嵌入、TSX/JSX 边界。
- 正则适配还不是完整 Oniguruma。当前覆盖了常见 POSIX class、possessive quantifier、atomic group 等降级，但复杂 lookaround、条件表达式、递归/子例程等语义不保证一致。
- TextMate 的部分高级行为还不完整，例如更复杂的 `while` 规则、深层 injection selector、复杂外部 grammar 组合。
- 主题系统支持 VS Code token color 的主要路径，但没有覆盖所有 workbench color、语义 token、transformer、decorations 或 Shiki 插件能力。
- 当前 HTML 输出服务 Markit 代码块协议，不包含 Shiki 的 rehype、markdown-it、twoslash、Monaco、CLI transformer 等生态功能。
- 增量解析已有 state 边界，但还不是完整的编辑器级增量高亮系统。

后续优先级应该放在更多上游 golden case、复杂嵌入语法、regex adapter 差异收敛，以及 Markit example/PDF/website 的回归覆盖上。
