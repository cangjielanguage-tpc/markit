<a id="mermaid"></a>
# Mermaid 图表

Markit 的 Mermaid 图表由 `mermaid4cj` 提供。它在构建阶段把 Markdown 中的 Mermaid 代码块渲染为静态 SVG，生成的网站不需要加载 Mermaid JS；PDF/Typst 输出也可以直接引用 SVG 资产。主题颜色按 Mermaid 官方 default/dark 主题语义输出，网站模式下可以同时生成浅色和暗色 SVG。

## 引入 mermaid4cj

`mermaid4cj` 已发布到仓颉中心仓。独立使用 Mermaid SVG 渲染库时，在 `cjpm.toml` 中添加：

```toml
[dependencies]
mermaid4cj = { version = "0.2.0" }
```

## Markdown 写法

````markdown
```mermaid
flowchart LR
    A["Markdown"] --> B["Markit"]
    B --> C["HTML / PDF / Typst"]
```
````

markit-cli 会识别语言为 `mermaid` 的 fenced code block，并在构建阶段生成图表。

## 常用图表示例

### Flowchart

```mermaid
flowchart LR
    A["写 Markdown"] --> B["markit-cli render"]
    B --> C["生成网站"]
    B --> D["生成 Typst / PDF"]
    B --> E["生成 JSON / AST"]
```

flowchart 支持常见方向、节点形状、边标签、子图、class/style 和多目标边：

```mermaid
flowchart TD
    subgraph Build["构建流程"]
        Source[Markdown 源文件] --> Parse{解析成功?}
        Parse -- 是 --> Html[HTML 页面]
        Parse -- 是 --> Pdf[PDF 资产]
        Parse -- 否 --> Error[诊断信息]
    end

    classDef ok fill:#ecfdf5,stroke:#10b981,color:#065f46
    classDef warn fill:#fff7ed,stroke:#f97316,color:#7c2d12
    class Html,Pdf ok
    class Error warn
```

### Sequence Diagram

```mermaid
sequenceDiagram
    participant User as 文档作者
    participant CLI as markit-cli
    participant Core as markit
    participant Site as 静态网站

    User->>CLI: markit render -i docs -o dist
    CLI->>Core: parse Markdown
    Core-->>CLI: AST + rich content
    CLI->>Site: write HTML assets
```

### Class Diagram

```mermaid
classDiagram
    class Markit {
        +parse(markdown)
        +createSession()
    }
    class ParseOutput {
        +toHtml()
        +toMarkdown()
        +toTypst()
    }
    Markit --> ParseOutput
```

### ER Diagram

```mermaid
erDiagram
    CUSTOMER ||--o{ ORDER : places
    ORDER ||--|{ LINE_ITEM : contains
    CUSTOMER }|..|{ DELIVERY_ADDRESS : uses
    PRODUCT ||--o{ LINE_ITEM : includes
```

### Gantt

```mermaid
gantt
    title 文档站发布计划
    dateFormat  YYYY-MM-DD
    section Docs
    信息架构      :done,    a1, 2026-06-01, 2d
    功能页补充    :active,  a2, after a1, 3d
    section Build
    站点生成      :b1, after a2, 1d
    发布校验      :b2, after b1, 1d
```

### Pie

```mermaid
pie showData
    title 文档内容组成
    "指南" : 35
    "API" : 30
    "示例" : 25
    "参考" : 10
```

### Mindmap

```mermaid
mindmap
  root((Markit))
    CLI
      render
      serve
      pdf
    Parser
      CommonMark
      GFM
      i18n
    Rich Content
      codehl
      mathtex
      mermaid4cj
```

### State Diagram

```mermaid
stateDiagram-v2
    [*] --> Draft
    Draft --> Built: render
    Built --> Preview: serve
    Preview --> Published: deploy
    Preview --> Draft: edit
    Published --> [*]
```

## 支持的图表

| 图表 | 状态 | 说明 |
| --- | --- | --- |
| `flowchart` / `graph` | 主力可用 | 支持常见节点、边、子图、class/style 和 Dagre 布局 |
| `sequenceDiagram` | 主力可用 | 支持 participant、alias、activation、note、alt/else/loop 等常见语法 |
| `classDiagram` | 主力可用 | 支持 class、成员、泛型、annotation、namespace 和常见关系 |
| `erDiagram` | 主力可用 | 支持 crow's foot cardinality、实体、属性和关系标签 |
| `gantt` | 主力可用 | 支持 title、section、任务元数据、依赖和基础时间轴 |
| `pie` | 常用子集 | 支持 title、showData、百分比和 legend |
| `mindmap` | 常用子集 | 支持缩进树和常见节点形状 |
| `stateDiagram` | 常用子集 | 支持基础 state、transition 和 composite state |

不支持的 Mermaid 类型会输出稳定的错误 SVG 和诊断信息，避免构建时静默生成错误图。

## 主题输出

网站输出可以生成浅色和暗色两份 SVG，并通过页面主题切换显示。站点主题为浅色时显示 default 主题 SVG；站点主题为暗色，或主题模式为 `auto` 且系统偏好为暗色时，显示 dark 主题 SVG。dark 主题图表会使用深色背景，这是 Mermaid 官方暗色主题的表现方式。

```html
<div class="mk-mermaid-container" data-mermaid4cj="native" data-mermaid4cj-theme="dual">
  <div class="mk-mermaid-diagram mk-mermaid-theme-light">...</div>
  <div class="mk-mermaid-diagram mk-mermaid-theme-dark">...</div>
</div>
```

PDF/Typst 输出通常生成单主题 SVG 文件，由 Typst 直接引用。

## Cangjie API

```cangjie
import mermaid4cj.{MermaidRenderer, MermaidRenderOptions, MermaidTheme}

let result = MermaidRenderer().renderSvg(
    "flowchart TD\nA[Start] --> B[Done]",
    options: MermaidRenderOptions(
        theme: MermaidTheme.Default,
        classPrefix: "mk-mermaid",
        idPrefix: "page-1-mermaid-0"
    )
)

if (result.supported) {
    println(result.svg)
}
```

同一份源码需要输出浅色、暗色或 PDF 资产时，可以先 parse 再多次 render，减少重复扫描。
