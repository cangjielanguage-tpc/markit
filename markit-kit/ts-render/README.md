# Markit TypeScript Renderer

This package builds the browser UI bundle used by `markit-cli` websites.

It does not perform syntax highlighting, math rendering, or Mermaid rendering in the browser:

- code blocks are rendered by Markit/codehl during HTML generation, then switched by CSS/theme state in the browser
- math HTML is rendered by Markit/mathtex, while this package only copies KaTeX CSS and fonts used by that output
- Mermaid HTML/SVG is rendered by Markit/mermaid4cj before the browser sees the page

The browser bundle is still needed for site interaction such as navigation, search, theme switching, language switching, back-to-top controls, math copy helpers, and Mermaid SVG zoom/pan UI.

## Build

```bash
npm install
npm run build:prod
```

The build creates:

- `assets/js/markit.bundle.js`
- `assets/css/katex.min.css`
- KaTeX `.woff2` fonts under `assets/css/fonts/`

## Source Layout

```text
src/
├── code-blocks/        # Code block theme display helpers
├── renderer/           # Theme, navigation, Mermaid viewer, UI widgets
├── search/             # Search functionality
├── language-switcher/  # Language switching UI
├── scripts/            # Build-time asset copy helpers
└── index.ts            # Main entry point
```
