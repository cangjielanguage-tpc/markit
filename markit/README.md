# Markit v2

Markit v2 is a session-based Markdown engine for Cangjie. It is designed for AI-era Markdown: append-only chunk input, byte-safe streaming, stable block emission, AST patches, plugin-owned session state, and writer-based multi-format output.

Full developer documentation lives in [`docs/markit.md`](docs/markit.md). `markit.md` is the summary/homepage, while topic pages live under `docs/getting-started`, `docs/core-concepts`, `docs/api-reference`, `docs/advanced`, `docs/plugins`, `docs/bundles`, and `docs/examples`.

## Quick Start

```cangjie
import markit.*
import markit.bundles.GFMBundle

let parser = Markit(GFMBundle())
let out = parser.parse("# 标题\n\nHello **Markit**.\n")

println(out.toHtml())
println(out.toMarkdown())
println(out.toTypst())
println(out.toJson())
```

`ParseOutput` supports direct strings, `OutputStream` writing, file dump helpers, and SeaJson writer output:

```cangjie
out.writeHtml(stdout)
out.dumpJson("./target", filename: "ast.json")
```

## Streaming AI Output

Use `IncrementalSession` when tokens arrive in chunks. Stable blocks are emitted as soon as they are sealed, while open paragraphs, lists, fences, tables, and i18n blocks remain in the pending tail.

```cangjie
let session = Markit(GFMBundle()).createSession()

let u1 = session.feed("# 标")
let u2 = session.feed("题\n\n第一段")
let u3 = session.feed("继续。\n\n")
let done = session.finalize()

for (fragment in u3.emittedHtmlFragments) {
    println(fragment)
}
for (patch in done.astPatches) {
    println(patch.toString())
}
```

For arbitrary UTF-8 byte chunks, use `feedBytes`. This preserves Unicode correctness when a Chinese character or emoji is split across network chunks.

```cangjie
let session = Markit(GFMBundle()).createSession()
session.feedBytes([0xE4, 0xB8])
session.feedBytes([0xAD, 0xE6, 0x96, 0x87])
session.finalize()
```

## Core Ideas

- `SourceBuffer + SourceSpan`: byte/rune offsets are tracked without making a whole-document `RuneArray` copy.
- `ParseSession`: parser state lives in a session, not in global plugin instances.
- Plugin registration: blocks, inline parsers, renderers, symbol tables, filters, and finalize hooks stay pluggable.
- Stable streaming: sealed blocks can be rendered immediately; pending tails can be patched as later chunks arrive.
- Low default retention: AST nodes keep spans and semantic fields; raw text is materialized only when requested or configured.
- Writer output: HTML, Markdown, Typst, and JSON support direct string APIs and stream/file APIs.

## Built-In Bundles

- `StandardMarkdownBundle`
- `CommonMarkBundle`
- `GFMBundle`

GFM includes tables, task lists, alphabetic lists, math blocks, bare autolinks, footnotes, inline math, strikethrough, relaxed emphasis, CommonMark extensions, and standard Markdown.

## Plugins

Plugins register capabilities through `PluginRegistrar`; plugin-specific mutable state should be registered as session state.

```cangjie
let parser = Markit.empty()
    .use(MyBlockPlugin())
    .use(MyInlinePlugin())
```

This keeps the core small and lets CLI/site/PDF features compose parser behavior through configuration instead of mutating parser internals.

## Verification

Current v2 baseline:

- `cjpm test --no-progress`: `524 passed`, `0 failed`, `0 skipped`.
- Direct parse, incremental string feed, incremental byte feed, and `InputStream` are covered by shared test helpers.
- Compatibility fixtures pass against the documented 0.0.4 baseline differences.

Useful commands:

```bash
cd markit
cjpm test --no-progress
cjpm bench --filter=SharedFixtureBenchmarks
```
