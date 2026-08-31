# mermaid4cj

`mermaid4cj` 是一个用仓颉实现的构建期 Mermaid 渲染库，主要服务于 Markit/markit-cli。

它在 Markdown 编译阶段把支持的 Mermaid 图表渲染成静态 SVG。网站页面不需要加载 Mermaid JS；PDF/Typst 输出也可以直接引用生成好的 SVG 资产。

当前目标不是完整复制 Mermaid 的全部图表生态，而是覆盖 Markit 文档中最常用的图表类型，并在不支持的语法边界上给出确定的诊断和错误 SVG，避免静默渲染成错误结果。

## Public API

Import from the package root:

```cangjie
import mermaid4cj.{
    MermaidRenderer,
    MermaidRenderOptions,
    MermaidHtmlOptions,
    MermaidHtmlThemeMode,
    MermaidTheme
}
```

### SVG string

用于直接获取 SVG 字符串，适合 HTML 内联或调用方自行管理写入。

```cangjie
let result = MermaidRenderer().renderSvg(
    "flowchart TD\nA[Start] --> B[Done]",
    options: MermaidRenderOptions(
        theme: MermaidTheme.Default,
        classPrefix: "mk-mermaid",
        idPrefix: "page-1-mermaid-0",
        title: Some("Build flow")
    )
)

if (result.supported) {
    let svg = result.svg
}
```

### Parse once, render multiple times

同一份 Mermaid 源码需要渲染多个变体时，可以先 parse 再 render，避免重复扫描源码。

```cangjie
let renderer = MermaidRenderer()
let parsed = renderer.parseFlowchart(source)

let light = renderer.renderFlowchartSvg(
    parsed,
    options: MermaidRenderOptions(theme: MermaidTheme.Default, idPrefix: "diagram-light")
)
let dark = renderer.renderFlowchartSvg(
    parsed,
    options: MermaidRenderOptions(theme: MermaidTheme.Dark, idPrefix: "diagram-dark")
)
```

### SVG stream

调用方已有 `OutputStream` 时可以直接写流。

```cangjie
MermaidRenderer().renderSvgToStream(source, out)
```

### SVG file

用于 `markit-cli` 生成 Typst/PDF 资产，父目录会自动创建。

```cangjie
let result = MermaidRenderer().renderSvgFileWithTheme(
    source,
    Path("assets/typst/page-mermaid-0.svg"),
    "dark-plus",
    options: MermaidRenderOptions(idPrefix: "page-mermaid-0")
)
```

便捷主题名规则：

- `"dark"`、`"dark-plus"`、`"night"` 输出暗色 SVG
- 其他值输出默认浅色 SVG

PDF 资产通常使用单主题 SVG。网站输出建议使用下面的双主题 HTML 协议。

## Markit HTML API

`renderMarkitHtml` 返回包含静态 SVG 的 HTML wrapper，不需要浏览器端 Mermaid runtime。

```cangjie
let html = MermaidRenderer().renderMarkitHtml(
    source,
    options: MermaidHtmlOptions(
        themeMode: MermaidHtmlThemeMode.Dual,
        classPrefix: "mk-mermaid",
        idPrefix: "page-1-mermaid-0",
        title: Some("Build flow")
    )
).html
```

双主题输出结构：

```html
<div class="mk-mermaid-container mermaid4cj-container"
     data-mermaid4cj="native"
     data-mermaid4cj-theme="dual">
  <div class="mk-mermaid-diagram mk-mermaid-theme-light">...</div>
  <div class="mk-mermaid-diagram mk-mermaid-theme-dark">...</div>
</div>
```

双主题内联 SVG 会使用不同的确定性 marker ID：

- `{idPrefix}-light_flowchart-v2-pointEnd`
- `{idPrefix}-light_flowchart-v2-pointStart`
- `{idPrefix}-light_flowchart-v2-circleEnd`
- `{idPrefix}-light_flowchart-v2-circleStart`
- `{idPrefix}-light_flowchart-v2-crossEnd`
- `{idPrefix}-light_flowchart-v2-crossStart`
- `{idPrefix}-dark_flowchart-v2-pointEnd`
- `{idPrefix}-dark_flowchart-v2-pointStart`
- `{idPrefix}-dark_flowchart-v2-circleEnd`
- `{idPrefix}-dark_flowchart-v2-circleStart`
- `{idPrefix}-dark_flowchart-v2-crossEnd`
- `{idPrefix}-dark_flowchart-v2-crossStart`

这样同一个页面同时存在浅色/暗色两份 SVG 时不会发生 ID 冲突。

也支持单主题输出：

```cangjie
MermaidHtmlOptions(themeMode: MermaidHtmlThemeMode.Light)
MermaidHtmlOptions(themeMode: MermaidHtmlThemeMode.Dark)
```

只有需要可见源码或调试 fallback UI 时才建议设置 `includeSource: true`。

## Theme Class Protocol

网站可以使用下面的 CSS 协议切换明暗主题：

```cangjie
let css = MermaidRenderer.markitThemeCss(classPrefix: "mk-mermaid")
```

等价 CSS：

```css
.mk-mermaid-diagram.mk-mermaid-theme-dark { display: none; }
html[data-theme="dark"] .mk-mermaid-diagram.mk-mermaid-theme-light { display: none; }
html[data-theme="dark"] .mk-mermaid-diagram.mk-mermaid-theme-dark { display: block; }
html[data-theme="light"] .mk-mermaid-diagram.mk-mermaid-theme-light { display: block; }
html[data-theme="light"] .mk-mermaid-diagram.mk-mermaid-theme-dark { display: none; }
```

宿主页需要设置 `html[data-theme="light"]` 或 `html[data-theme="dark"]`。Markit 网站主题切换器已经使用这个形态。

## Support Matrix

状态说明：

- `主力可用`：已有 dedicated AST/parser/SVG writer，覆盖 Markit 文档主力语法，并有上游语义迁移测试。
- `常用子集`：已有 dedicated AST/parser/SVG writer，可以用于常见文档图，但仍缺少 Mermaid 官方完整语义或布局 parity。
- `不支持`：返回 `supported: false`、诊断信息和稳定错误 SVG。

| Diagram kind | Status | Notes |
| --- | --- | --- |
| `flowchart` / `graph` | 主力可用 | Dedicated parser，迁移 Dagre/graphlib 布局，支持常见节点、边、子图、class/style、markdown string 等用法。 |
| `sequenceDiagram` | 主力可用 | Dedicated parser/writer。支持 participant/alias、常见箭头、activation、note、title、autonumber、alt/else/loop 等文档常用语法；复杂官方 renderer/svgDraw 细节仍未承诺完全 parity。 |
| `classDiagram` | 主力可用 | Dedicated parser/writer。支持 class 定义、成员、泛型、annotation、namespace、常见关系和关系标签；复杂布局和长尾语义仍按边界诊断。 |
| `erDiagram` | 主力可用 | Dedicated parser/writer。支持 crow's foot cardinality、实体别名、属性、PK/UK/comment、关系标签、方向声明；复杂官方布局细节仍未完全迁移。 |
| `gantt` | 主力可用 | Dedicated parser/writer。支持 title/section、任务元数据、状态、milestone、after/until 依赖和基础时间轴渲染；复杂日期轴和官方渲染细节仍未完整迁移。 |
| `pie` | 常用子集 | Dedicated parser/writer。支持 title/showData、数值校验、百分比和 legend；长尾渲染细节仍未承诺 Mermaid 全 parity。 |
| `mindmap` | 常用子集 | Dedicated parser/layout/writer。支持缩进树、常见节点形状、icon/class、section/edge class；布局是原生实现，不等价于 Mermaid 的 `cose-bilkent` 完整布局引擎。 |
| `stateDiagram` / `stateDiagram-v2` | 常用子集 | Dedicated parser/writer。支持基础 state、transition、composite state、direction；choice/fork/join/notes 仍会诊断为不支持。 |
| Other Mermaid kinds | 不支持 | 返回 `supported: false`、诊断信息和稳定错误 SVG。 |

### Flowchart Boundary

`flowchart` 当前覆盖 Markit 文档中的主力场景：

- `graph` / `flowchart`
- `flowchart-v2` / `flowchart-elk` are accepted as flowchart aliases
- directions: `TD`, `TB`, `BT`, `LR`, `RL`, plus Mermaid aliases `>`, `<`, `^`, `v`
- common nodes: rectangle, rounded, circle, stadium, diamond, subroutine, database/cylinder, document, cloud, delay, brace, text, and many Mermaid node-data shape aliases
- edges: open, point, circle, cross, thick, dotted, and point double-ended variants such as `---`, `-->`, `--o`, `--x`, `==>`, `-.->`, `<-->`, `<==>`, `<-.->`
- edge IDs: `A e1@--> B`
- chained edges: `A-->B-->C`
- multiple targets: `A --> B & C`
- edge labels: `-->|label|`, `-- label -->`, `-. label .->`
- basic `classDef`, `class`, and `style` for `fill`, `stroke`, `color`
- comments beginning with `%%`
- pure SVG text labels for Typst/PDF compatibility
- deterministic fallback SVG for unsupported diagrams

## Markit Integration

Markit 的 Mermaid 代码块由 `mermaid4cj` 在构建期渲染：

- 网站输出使用 `renderMarkitHtml`，默认写入 light/dark 两份静态 SVG，由页面主题 class/data attribute 切换显示。
- PDF/Typst 输出使用单主题 SVG 文件，Typst 直接引用该 SVG。
- 生成的网站不加载 Mermaid JS。
- 不支持的 Mermaid 图会保留稳定错误 SVG 和诊断信息，避免构建期静默失败。

## Verification

常用验证命令：

```powershell
cd mermaid4cj
cjpm test --no-progress

cd ..\markit-cli
cjpm build --skip-script -V
.\target\release\bin\main.exe render -i .\example -o ..\target\example-mermaid-pdf
```

最近一次完整验证状态：

- `mermaid4cj`: full test suite passed。
- `markit-cli` example PDF 可以生成 `target/example-mermaid-pdf/zh/merged.pdf`。

## Known Boundaries

下面这些能力还没有承诺和 Mermaid 官方完全等价：

- 所有 Mermaid 图类型的完整支持。
- sequence/class/ER/gantt/pie/mindmap/state 的所有长尾语法和视觉细节。
- Mermaid 官方 renderer 的精确 DOM/SVG 结构 parity。
- mindmap 官方 `cose-bilkent` 布局引擎的完整等价实现。
- stateDiagram 的 choice/fork/join/notes。
- 浏览器交互特性、点击回调、外部 JS 初始化、动态布局。
