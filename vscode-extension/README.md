# Markit Preview for VS Code

Edit Markdown on the left and preview the current document on the right with Markit's theme, code highlighting, math, and diagrams. The preview contains only the document body, without website navigation, headers, footers, or a preview toolbar.

## Install and start

1. Install the VSIX with **Extensions: Install from VSIX…**.
2. Open the documentation repository as a trusted workspace folder. The folder must contain both `markit.json` and the source files referenced by its Summary, including paths such as `../../docs`.
3. Run **Markit: Select Executable**, or set `markit.executablePath`. Use a Markit build supporting `render --page` and `--preview-stream true` and keep its complete `assets/` directory next to it. A source build requires Cangjie SDK **1.1.0 or newer**; a working prebuilt executable does not require compilation.
4. Open a Markdown file and run **Markit: Open Preview to the Side**, or click its editor title button.
5. Select the preview language when prompted for that documentation project. Use the language item in the VS Code status bar or **Markit: Switch Preview Language** to switch at any time.

The extension automatically finds the Markdown file's project using the `summary[]` entries in `markit.json` and the Markdown links in their navigation files. Moving to a file in another documentation project switches the preview and restores that project's own language. Language variants such as `markit.en.json` in the same directory belong to the same project. Only an ambiguous file shared by multiple projects requires a project choice. Unlisted Markdown is included when `showDrafts` permits it.

## Project language state

Language choices are stored in `.config/.markit-current-lang.json` under each workspace folder, separately for every documentation project:

```json
{
  "version": 1,
  "projects": {
    "docs/markit.json": { "language": "en" },
    "guide/markit.json": { "language": "zh" }
  }
}
```

This file contains preview preferences, not translated content. Switching a language selects the existing Markit i18n branches; it does not translate documents. Corrupt preference JSON is reported without overwriting it. No preference file is written until a language is chosen.

## Settings

| Setting | Default | Purpose |
| --- | --- | --- |
| `markit.executablePath` | `markit` | Executable path or command on `PATH`. Workspace-relative paths and `${workspaceFolder}` are supported. |
| `markit.environment` | `{}` | Extra process environment, including SDK runtime directories on `PATH` if required. |
| `markit.debounceMs` | `120` | Quiet-period delay for editor changes. Starts are spaced by at least `max(debounceMs, 250)` ms; continuous typing has a `max(debounceMs, 500)` ms wait bound when no render is active. |
| `markit.editEffects` | `true` | Lightweight visual effects on changed preview prose. Disable for instant visual updates; reduced-motion preferences also disable animation. |
| `markit.startupTimeoutMs` | `120000` | Initial build timeout in milliseconds. |

For example, using a local Windows build:

```json
{
  "markit.executablePath": "C:\\Users\\Shawn\\Desktop\\markit\\markit.exe"
}
```

If VS Code has not inherited the Cangjie SDK environment, launch it from an SDK shell or supply the required environment through `markit.environment`. Prebuilt Markit releases are available from [GitHub Releases](https://github.com/cangjielanguage-tpc/markit/releases).

## Live preview behavior

- Project Markdown sources and navigation files are mirrored into an isolated temporary workspace to preserve smart links, cross-document headings, and numbering. Existing summary traversal order and heading start/reset settings are retained; unlisted preview pages are added only after the project chapters. Source Markdown and project configurations are never automatically saved or rewritten. Images and binary assets are not copied into that snapshot.
- VS Code editor events trigger `markit render --page` for the current document after a short debounce. Markit scans the project's heading context, renders only the requested page, and reuses shared output assets on subsequent edits. No Markit file watcher or HTTP preview server is started. Rapid changes are coalesced, and stale render results are not displayed. Only one edit update runs at a time; while it runs, only the latest pending value per changed file is retained. A trailing update runs after completion (subject to the debounce/throttle), rather than repeatedly killing and spawning a renderer. Source files outside the configuration directory are supported when they are inside the workspace folder.
- Configurations are previewed as websites; `format: "pdf"`, `"typst"`, and `"markdown"` configurations are not chosen as website projects.
- Changing languages re-renders only the current document. Closing the panel stops any active render process and removes its temporary files.
- Editor and preview scrolling are synchronized using source byte spans mapped to Markdown lines. The reading position is rebased through insertions and deletions before the viewport, rather than restored as a scroll percentage.
- Editor cursors and selections highlight their corresponding rendered text. Clicking or selecting preview text updates the visible Markdown editor without moving keyboard focus. Native preview selections and source-synchronized text highlights support Ctrl/Cmd+C and context-menu copy as plain text; controls keep their normal copy behavior. Mouse drags remain native and copyable; synchronization waits for pointer release, and preview-origin editor echoes do not clear the browser range. Matching uses native block spans and visible text; markup without visible text, diagrams, and formulas use block positioning rather than a fabricated character match. Selection messages from an older source version are ignored until the updated preview is ready. Translated `:::language` blocks and nested blockquotes retain original-document byte coordinates (including stripped indentation and CRLF); this requires rebuilding the native CLI, not only reinstalling the extension. During progressive loading, selection highlights are deferred and restored on final reconciliation.
- The status bar icon spins during initial loading and document/language switches. Ordinary same-document edits update in the background without a loading animation.
- Optional edit effects animate changed prose entirely inside the webview; they do not add native renders, change parser behavior, or constitute incremental Markdown parsing. Set `markit.editEffects` to `false` to disable them. Reduced-motion preferences are honored.
- Render updates patch the existing document body and preserve unchanged DOM nodes. The webview and shared resources stay loaded, avoiding full-page refreshes. Images and other local resources are read from the original project.
- The preview follows the active Markdown editor. Links to other Markdown pages open their source in the editor; external HTTP links open in the browser. Language changes remain available through VS Code commands and the status bar.
- Project discovery excludes `.git`, `node_modules`, `target`, `dist`, `tmp`, `temp`, `.cache`, `.codex`, and `.agents`. Keep documentation sources outside these directories.
- Render time depends on the current page and the native executable; DOM patching avoids a page reload while compilation runs. Errors are shown in the preview and the **Markit Preview** output channel.

## Development

From `vscode-extension/`:

```sh
npm install
npm test
npm run package
```

Set `MARKIT_TEST_BINARY` to a working native Markit executable to include the end-to-end test for single-document rendering, unsaved content, an external-to-input source directory, assets, and language switching. Set `MARKIT_TEST_CHROMIUM` to a Chromium executable, with Playwright available to Node, to opt into real mouse/clipboard tests (`test/selection-chromium.test.js`). These require browser IPC permissions; the cloud sandbox can block Chromium even when installed. The VSIX is written to the repository's ignored `target/` directory. This package is a local preview extension and is not published automatically.

### Progressive first load

Use the matching CLI build with `render --page … --preview-stream true` support.
The preview keeps **one append-parser session** per render: it feeds the first
4 KiB, then 16 KiB batches, and publishes sealed blocks before the whole page is
parsed/rendered. These are conservative byte budgets, **not a measured screenful**.
Fences, lists, tables, Unicode and references keep their parser state across feeds;
later semantic patches replace the affected top-level block. The completed normal
HTML reconciles finalization hooks and is the authoritative result.

An accessible loading animation appears immediately on open/switch and remains
below the growing article until final completion. Errors stop it and show an error;
reduced-motion preferences disable spinning. Switching documents or closing the
preview cancels the previous process and ignores its stale messages.

The preview-only CLI protocol consists of newline-delimited JSON frames prefixed
with `MARKIT_PREVIEW\t`. Each frame contains `operations` (`append`, `replace`,
`remove`, with a stable node `id`), consumed/total byte counts, and an initial
`shell` containing theme metadata and the source map. Other stdout lines remain
logs. The CLI waits for `ack\n` on stdin after each frame. The extension acknowledges
after the webview applies/paints a foreground batch, limiting in-flight work to one batch. For a background edit it validates and acknowledges frames without replacing the visible article, then patches only the completed result.
A successful process exit and validated final HTML, not 100% input consumption,
mark completion. Normal CLI rendering is unchanged without this flag.

This is first-load streaming, not arbitrary-edit incremental parsing: edits still
start a new render session. Once the same document/language has a completed preview, edits keep that preview visible until the next coherent result is ready. A small nonblocking “Updating…” corner badge appears only after 200 ms and clears when the update settles; it never covers or clears the article. Unchanged DOM nodes, their native selection and the retained viewport anchor are preserved where possible; edited/replaced text may necessarily change its selection. Failed background renders retain the prior content and report an error. Project snapshot preparation and the existing full
project heading scan still run first to preserve smart links/global numbering.
A single enormous unclosed block may not produce sealed content until its end;
a byte budget does not impose a hard CPU or DOM-size limit on such a block.

### Icon source

`media/logo.svg` is the editable transparent blue **m** / green downward-arrow icon.
`media/logo.png` is its 256×256 RGBA package-compatible raster; the extension manifest continues to reference PNG.

### Edit effects

With `markit.editEffects` enabled, completed background edits compare retained blocks and the changed grapheme span of simple plain-text paragraphs. Only added/changed text receives a visual typewriter reveal, theme-aware caret, and colored particles. The real final text is committed immediately: overlays never replace source text, alter source mappings, or delay copy correctness. This is a render diff, not incremental Markdown editing/parsing.

Effects handle at most four changed blocks and 256 changed graphemes, with at most 320 glyph masks and 72 particles. Typing lasts at most 2.4 seconds plus a 450 ms particle fade. Complex inline markup, code, math, diagrams, unsafe backgrounds, large diffs, and active text selections skip effects; deletions update immediately without typing. Reduced motion or disabling the setting skips animation. New edits, selection, pointer/keyboard input, scrolling, resizing, and page disposal cancel it immediately.
