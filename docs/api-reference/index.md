<a id="index"></a>
# API 速查

常用导入：

```cangjie
import markit.{Markit, ParseCallbacks, ParseOutput}
import markit.bundles.{StandardMarkdownBundle, CommonMarkBundle, GFMBundle}
import markit.core.incremental.{AstPatch, HtmlFragment, IncrementalSession, IncrementalUpdate, PendingTailState}
import markit.core.nodes.Node
import markit.core.plugin.{Bundle, Plugin, PluginRegistrar}
import markit.core.session.ParseOptions
import markit.core.source.{Cursor, LineIndex, SourceBuffer, SourceRetentionMode, SourceSpan, TextView}
```

常用输出：

```cangjie
out.toHtml()
out.toMarkdown()
out.toTypst()
out.toJson()
out.toString()

out.writeHtml(stream)
out.writeMarkdown(stream)
out.writeTypst(stream)
out.writeJson(stream)
out.writeJson(jsonWriter)
out.write(stream)

out.dumpHtml(path, filename: "doc.html")
```

常用流式：

```cangjie
let session = Markit().createSession()
let update = session.feed("# title\n")
let byteUpdate = session.feedBytes("# 中文\n".toArray())
let finalUpdate = session.finalize()
let snapshot = session.snapshot()
```

常用 snapshot：

```cangjie
snapshot.root
snapshot.nodeCount()
snapshot.nodeById(1)
snapshot.nodesInByteRange(0, 32)
snapshot.lineAt(0)
snapshot.stableHash()
```

常用插件 state：

```cangjie
let state = out.symbolTables().get(MyPlugin.stateKey)
let dynamic = out.symbolTables()["MyPlugin.state"]
```
