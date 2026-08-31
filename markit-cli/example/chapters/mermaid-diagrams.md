# :zh{Mermaid 图表}: :en{Mermaid Diagrams}:

::{:zh{本页用于验证 Mermaid 代码块会在构建期渲染为 SVG，并能进入 PDF 输出。}: :en{This page validates Mermaid code blocks rendered to SVG during build and included in PDF output.}:}:

## :zh{流程图}: :en{Flowchart}:

```mermaid
flowchart LR
    A[Markdown Source] --> B{Markit Parser}
    B -->|code block| C[mermaid4cj]
    C --> D[SVG Asset]
    D --> E[Typst PDF]
```

## :zh{时序图}: :en{Sequence Diagram}:

```mermaid
sequenceDiagram
    autonumber
    participant CLI as markit-cli
    participant M as Markit
    participant R as mermaid4cj
    CLI->>M: render markdown
    M->>R: render Mermaid block
    R-->>M: svg
    M-->>CLI: typst document
```

## :zh{实体关系图}: :en{Entity Relationship Diagram}:

```mermaid
erDiagram
    CUSTOMER ||--o{ ORDER : places
    ORDER ||--|{ LINE_ITEM : contains
    CUSTOMER }|..|{ DELIVERY_ADDRESS : uses
    PRODUCT ||--o{ LINE_ITEM : includes
```

## :zh{类图}: :en{Class Diagram}:

```mermaid
classDiagram
    class Renderer {
        +renderMarkdown(source: String) : Document
        +renderMermaid(source: String) : SvgAsset
    }
    class MermaidRenderer {
        +renderSvg(source: String) : String
        +renderSvgFile(path: String) : Unit
    }
    class SvgAsset {
        +id: String
        +path: String
    }
    Renderer --> MermaidRenderer : delegates
    MermaidRenderer --> SvgAsset : writes
```

## :zh{状态图}: :en{State Diagram}:

```mermaid
stateDiagram-v2
    [*] --> Parsed
    Parsed --> Rendered: native renderer
    Rendered --> Written: save svg
    Written --> [*]
```

## :zh{甘特图}: :en{Gantt Chart}:

```mermaid
gantt
    title Markit nodeless renderer
    dateFormat  YYYY-MM-DD
    section Native assets
    Code highlighting :done, codehl, 2026-01-01, 2026-01-20
    Math rendering    :done, mathtex, after codehl, 10d
    Mermaid SVG       :active, mermaid, after mathtex, 14d
    section Output
    Website bundle    :site, after mermaid, 7d
    PDF export        :pdf, after site, 7d
```

## :zh{饼图}: :en{Pie Chart}:

```mermaid
pie showData
    title Build-time rendered blocks
    "Code" : 45
    "Math" : 30
    "Mermaid" : 25
```

## :zh{思维导图}: :en{Mindmap}:

```mermaid
mindmap
  root((Markit))
    Native rendering
      codehl
      mathtex
      mermaid4cj
    Outputs
      Website
      PDF
    Runtime
      No Shiki
      No Mermaid JS
      No KaTeX JS
```
