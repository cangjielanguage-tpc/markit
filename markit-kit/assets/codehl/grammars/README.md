# codehl grammar assets

本目录保存 `codehl` 运行时加载的 TextMate / VS Code grammar JSON。

命名规则：

- Project-owned grammars can live as `<id>.tmLanguage.json` in this directory.
- VS Code built-in grammars live under `vscode/<extension>/syntaxes/` with their upstream file names preserved.
- 运行时入口由 `LanguageRegistry` 的语言白名单决定。
- 语言别名也集中维护在 `LanguageRegistry`，不要散落到调用侧。

当前来源：

- `cangjie.tmLanguage.json`: Markit/Cangjie grammar.
- `antlr.tmLanguage.json`: Markit ANTLR4 grammar.
- `vscode/**/syntaxes/*.json`: copied from `microsoft/vscode` built-in extensions.

当前白名单覆盖的主要语言：

- `cangjie` / `cj`
- `antlr4` / `antlr` / `g4`
- `json`
- `jsonc`
- `jsonl` / `ndjson`
- `bash` / `sh` / `shell`
- `markdown` / `md`
- `html`
- `xml`
- `xsl` / `xslt`
- `yaml` / `yml`
- `javascript` / `js`
- `typescript` / `ts`
- `python` / `py`
- `java`
- `c`
- `cpp`
- `csharp` / `cs`
- `css`
- `php`
- `powershell`
- `ruby`
- `rust`
- `go`
- `sql`
- and other common VS Code built-in grammar entries mapped in `LanguageRegistry`.

后续新增语言时，先放 grammar JSON，再更新 `LanguageRegistry` 白名单，最后补 loader/tokenizer golden test。
