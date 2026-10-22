'use strict';

function sourceCoordinates(source) {
  const bytes = [0], characters = [0];
  let byte = 0, character = 0;
  for (const value of source) {
    const point = value.codePointAt(0);
    byte += point < 0x80 ? 1 : point < 0x800 ? 2 : point < 0x10000 ? 3 : 4;
    character += value.length;
    bytes.push(byte); characters.push(character);
  }
  return offset => {
    let low = 0, high = bytes.length;
    while (low + 1 < high) { const middle = (low + high) >>> 1; if (bytes[middle] <= offset) low = middle; else high = middle; }
    return characters[low];
  };
}

// This aligns rendered text inside an existing native source span; it does not parse Markdown.
function projectSource(source, start, end, { code = false, language = '', decode = value => value } = {}) {
  let text = '';
  const spans = [], preferred = [];
  const raw = source.slice(start, end);
  if (!code) for (const match of raw.matchAll(/:([a-z][a-z\d-]*)\{([\s\S]*?)\}:/gi)) {
    if (match[1] === language) preferred.push([start + match.index + match[1].length + 2, start + match.index + match[0].length - 2]);
  }
  for (let index = start; index < end;) {
    let width = source.codePointAt(index) > 0xffff ? 2 : 1;
    let value = source.slice(index, index + width);
    if (!code && value === '\\' && /[!"#$%&'()*+,\-./:;<=>?@[\]\\^_`{|}~]/.test(source[index + 1] || '')) {
      width = 2; value = source[index + 1];
    } else if (!code && value === '&') {
      const entity = /^&(?:#x[\da-f]+|#\d+|[a-z][a-z\d]+);/i.exec(source.slice(index, Math.min(end, index + 34)));
      if (entity) { const decoded = decode(entity[0]); if (decoded !== entity[0]) { width = entity[0].length; value = decoded; } }
    }
    text += value;
    for (let unit = 0; unit < value.length; unit++) spans.push({ start: index, end: index + width });
    index += width;
  }
  return { text, spans, preferred };
}

function alignText(projection, text, cursor = 0) {
  const { spans, preferred } = projection;
  let at = projection.text.indexOf(text, cursor);
  if (text.trim()) {
    for (const [start, end] of preferred) {
      let candidate = projection.text.indexOf(text, cursor);
      while (candidate >= 0 && spans[candidate]?.start < start) candidate = projection.text.indexOf(text, candidate + 1);
      if (candidate >= 0 && spans[candidate]?.start < end && spans[candidate + text.length - 1]?.end <= end) { at = candidate; break; }
    }
  }
  if (at >= 0) return { mapping: spans.slice(at, at + text.length), cursor: at + text.length };
  const mapping = Array(text.length).fill(undefined);
  for (const part of text.matchAll(/\S+|\s+/g)) {
    const found = projection.text.indexOf(part[0], cursor);
    if (found < 0) continue;
    for (let index = 0; index < part[0].length; index++) mapping[part.index + index] = spans[found + index];
    cursor = found + part[0].length;
  }
  return { mapping, cursor };
}

if (typeof module !== 'undefined') module.exports = { sourceCoordinates, projectSource, alignText };

if (typeof window !== 'undefined') window.MarkitSelection = {
  create({ article, getData, postMessage }) {
    let records, byNode, blocks, lastSelection, ignoredUntil = 0, frame = 0, pointerSelecting = false, mirroredText = '';
    const decoder = document.createElement('textarea');
    const caret = document.createElement('div');
    caret.id = 'markit-preview-caret'; caret.hidden = true; caret.setAttribute('aria-hidden', 'true');
    document.body.append(caret);
    const style = document.createElement('style');
    style.textContent = `::highlight(markit-selection){background:var(--vscode-editor-selectionBackground,#b4d5fe);color:var(--vscode-editor-selectionForeground,inherit)}[data-markit-cursor]{outline:1px solid var(--vscode-editor-rangeHighlightBorder,#75a6d6);outline-offset:3px}#markit-preview-caret{position:fixed;width:2px;background:var(--vscode-editorCursor-foreground,#2376bc);pointer-events:none;z-index:100}`;
    document.head.append(style);
    function build() {
      if (records) return;
      records = []; byNode = new Map(); blocks = [];
      const hex = article.querySelector('#markit-page-markdown-source')?.textContent || '';
      const source = new TextDecoder().decode(Uint8Array.from(hex.match(/../g) || [], value => parseInt(value, 16)));
      const coordinate = sourceCoordinates(source), states = new Map();
      for (const anchor of article.querySelectorAll('[data-source-start-byte]')) {
        let node = anchor.closest('table') || anchor;
        if (!node.getBoundingClientRect().height && node.nextElementSibling) node = node.nextElementSibling;
        if (node.getBoundingClientRect().height) blocks.push({ node, start: coordinate(Number(anchor.dataset.sourceStartByte)), end: coordinate(Number(anchor.dataset.sourceEndByte)) });
      }
      const walker = document.createTreeWalker(article, NodeFilter.SHOW_TEXT);
      while (walker.nextNode()) {
        const node = walker.currentNode, parent = node.parentElement;
        if (!node.textContent || !parent || parent.closest('script,style,button,svg,math,textarea,.katex,.mermaid,.heading-number,.heading-anchor,.code-tabs,.code-language-label,.link-error')) continue;
        const range = document.createRange(); range.selectNodeContents(node);
        if (![...range.getClientRects()].some(rect => rect.width && rect.height) || getComputedStyle(parent).visibility === 'hidden') continue;
        let block = parent.closest('[data-source-start-byte]');
        const table = parent.closest('table'); if (table?.querySelector('[data-source-start-byte]')) block = table;
        if (!block) continue;
        const anchor = block.matches('[data-source-start-byte]') ? block : block.querySelector('[data-source-start-byte]');
        if (!states.has(block)) {
          const start = coordinate(Number(anchor.dataset.sourceStartByte)), end = coordinate(Number(anchor.dataset.sourceEndByte));
          const projection = projectSource(source, start, end, { code: Boolean(parent.closest('pre')), language: getData().language,
            decode: entity => { decoder.innerHTML = entity; return decoder.value; } });
          states.set(block, { projection, cursor: 0 }); blocks.push({ node: block, start, end });
        }
        const state = states.get(block), aligned = alignText(state.projection, node.textContent, state.cursor);
        state.cursor = aligned.cursor;
        const record = { node, block, mapping: aligned.mapping };
        if (record.mapping.some(Boolean)) { records.push(record); byNode.set(node, record); }
      }
    }
    function clear() {
      mirroredText = '';
      CSS.highlights?.delete('markit-selection'); caret.hidden = true;
      article.querySelectorAll('[data-markit-cursor]').forEach(node => node.removeAttribute('data-markit-cursor'));
    }
    function point(offset) {
      let best, distance = Infinity;
      for (const record of records) for (let index = 0; index < record.mapping.length; index++) {
        const span = record.mapping[index]; if (!span) continue;
        const difference = offset < span.start ? span.start - offset : offset > span.end ? offset - span.end : 0;
        if (difference < distance) { best = { record, index: offset >= span.end ? index + 1 : index, distance: difference }; distance = difference; }
        if (!difference) return best;
      }
      return best;
    }
    function show(message) {
      if (message.version !== getData().version || message.file !== getData().file) return;
      // clearNative is a one-shot action, never replay it on resize/scroll or
      // final reconciliation. A stale editor message must not clear a new page.
      lastSelection = { ...message, clearNative: false };
      if (pointerSelecting) return;
      clear();
      if (message.clearNative && article.contains(getSelection()?.anchorNode)) {
        ignoredUntil = performance.now() + 100; getSelection().removeAllRanges();
      }
      build();
      const ranges = [], selectedText = [];
      for (const selection of message.ranges || []) {
        const start = Math.min(selection.anchor, selection.active), end = Math.max(selection.anchor, selection.active);
        let text = '', previousBlock;
        for (const record of records) {
          let first = -1, last = -1;
          record.mapping.forEach((span, index) => { if (span && span.start < end && span.end > start) { if (first < 0) first = index; last = index + 1; } });
          if (first >= 0) {
            const range = document.createRange(); range.setStart(record.node, first); range.setEnd(record.node, last); ranges.push(range);
            if (text && previousBlock !== record.block) text += '\n';
            text += record.node.textContent.slice(first, last); previousBlock = record.block;
          }
        }
        if (text) selectedText.push(text);
      }
      mirroredText = selectedText.join('\n');
      if (CSS.highlights && typeof Highlight !== 'undefined') CSS.highlights.set('markit-selection', new Highlight(...ranges));
      const active = message.ranges?.[0]?.active;
      if (!Number.isFinite(active)) return;
      const block = blocks.filter(item => item.start <= active && active <= item.end).sort((a, b) => a.end - a.start - (b.end - b.start))[0];
      block?.node.setAttribute('data-markit-cursor', '');
      if (message.ranges[0].anchor !== active) return;
      const position = point(active);
      if (!block || !position || position.distance > 2 || position.record.block !== block.node) return;
      const range = document.createRange(); range.setStart(position.record.node, position.index); range.collapse(true);
      const rect = range.getClientRects()[0];
      if (rect?.height) { caret.style.left = rect.left + 'px'; caret.style.top = rect.top + 'px'; caret.style.height = rect.height + 'px'; caret.hidden = false; }
    }
    function sourcePoint(node, offset, end) {
      if (node.nodeType !== Node.TEXT_NODE) {
        const walker = document.createTreeWalker(node, NodeFilter.SHOW_TEXT), children = [];
        while (walker.nextNode()) if (byNode.has(walker.currentNode)) children.push(walker.currentNode);
        node = end ? children.at(-1) : children[0]; offset = end ? node?.textContent.length : 0;
      }
      const record = byNode.get(node); if (!record) return undefined;
      if (end && offset > 0 && record.mapping[offset - 1]) return record.mapping[offset - 1].end;
      return record.mapping[offset]?.start ?? record.mapping[offset - 1]?.end;
    }
    function previewSelection() {
      if (pointerSelecting || performance.now() < ignoredUntil || !document.hasFocus()) return;
      const selection = getSelection();
      if (!selection?.anchorNode || !article.contains(selection.anchorNode) || !article.contains(selection.focusNode)) return;
      if (selection.anchorNode.parentElement?.closest('button,svg,.katex,.mermaid')) return;
      if (selection.isCollapsed && selection.anchorNode.parentElement?.closest('a')) return;
      build();
      const range = selection.getRangeAt(0), forward = selection.anchorNode === range.startContainer && selection.anchorOffset === range.startOffset;
      const anchor = sourcePoint(selection.anchorNode, selection.anchorOffset, !forward && !selection.isCollapsed);
      const active = sourcePoint(selection.focusNode, selection.focusOffset, forward && !selection.isCollapsed);
      if (!Number.isFinite(anchor) || !Number.isFinite(active)) return;
      postMessage({ type: 'preview-selection', file: getData().file, version: getData().version, anchor, active });
    }
    function copyText(target) {
      if (!document.hasFocus()) return '';
      const element = target?.nodeType === Node.TEXT_NODE ? target.parentElement : target;
      const control = node => node?.closest?.('input,textarea,select,button,[contenteditable]');
      if (control(element) || control(document.activeElement)) return '';
      const native = getSelection();
      if (native?.anchorNode && !native.isCollapsed) {
        if (!article.contains(native.anchorNode) || !article.contains(native.focusNode)) return '';
        return native.toString();
      }
      // CSS Highlight ranges are visible but are not a browser Selection. Copy
      // their rendered text, not Markdown delimiters or hidden language branches.
      if (element && element !== document && element !== document.body && element !== document.documentElement && !article.contains(element)) return '';
      return lastSelection?.file === getData().file && lastSelection?.version === getData().version ? mirroredText : '';
    }
    document.addEventListener('copy', event => {
      if (event.isTrusted === false || event.defaultPrevented || !event.clipboardData) return;
      const text = copyText(event.target); if (!text) return;
      event.clipboardData.setData('text/plain', text); event.preventDefault();
    });
    document.addEventListener('keydown', event => {
      if (event.isTrusted === false || event.defaultPrevented || event.repeat || event.altKey || event.shiftKey ||
          !(event.ctrlKey || event.metaKey) || event.key?.toLowerCase() !== 'c') return;
      const text = copyText(event.target); if (!text || text.length > 16 * 1024 * 1024) return;
      // Desktop VS Code routes Copy through its workbench. Handle this explicit
      // gesture before the window-level forwarding, without changing focus or
      // requiring navigator.clipboard permissions in the sandboxed webview.
      event.preventDefault(); event.stopPropagation();
      postMessage({ type: 'copy-selection', file: getData().file, version: getData().version, generation: getData().generation, renderId: getData().renderId, text });
    });
    function scheduleSelection() {
      if (frame || pointerSelecting) return;
      frame = requestAnimationFrame(() => { frame = 0; previewSelection(); });
    }
    document.addEventListener('selectionchange', scheduleSelection);
    document.addEventListener('pointerdown', event => {
      if (event.button !== 0 || !article.contains(event.target)) return;
      pointerSelecting = true;
      if (ignoredUntil !== Infinity) ignoredUntil = 0;
      clear();
    });
    document.addEventListener('pointerup', () => {
      if (!pointerSelecting) return;
      pointerSelecting = false;
      if (ignoredUntil !== Infinity) ignoredUntil = 0;
      // Do not reveal/scroll the editor while the browser is extending a drag.
      // The final browser range remains native and available for Copy.
      scheduleSelection();
    });
    document.addEventListener('pointercancel', () => { pointerSelecting = false; });
    addEventListener('blur', () => { pointerSelecting = false; });
    document.addEventListener('visibilitychange', () => { if (document.hidden) pointerSelecting = false; });
    addEventListener('scroll', () => { if (lastSelection && !caret.hidden) show(lastSelection); }, { passive: true });
    addEventListener('resize', () => { records = undefined; if (lastSelection) show(lastSelection); });
    function captureNative() {
      const native = getSelection();
      if (!native?.anchorNode || !article.contains(native.anchorNode) || !article.contains(native.focusNode)) return undefined;
      const capture = (node, offset) => ({ node, offset, text: node.nodeType === Node.TEXT_NODE ? node.textContent : undefined,
        before: node.childNodes[offset - 1], after: node.childNodes[offset] });
      return { file: getData().file, anchor: capture(native.anchorNode, native.anchorOffset), focus: capture(native.focusNode, native.focusOffset) };
    }
    function restoreNative(snapshot) {
      if (!snapshot || snapshot.file !== getData().file) return false;
      const survives = point => article.contains(point.node) && (point.node.nodeType === Node.TEXT_NODE
        ? point.node.textContent === point.text && point.offset <= point.node.textContent.length
        : point.node.childNodes[point.offset - 1] === point.before && point.node.childNodes[point.offset] === point.after);
      if (!survives(snapshot.anchor) || !survives(snapshot.focus)) return false;
      const native = getSelection();
      if (!native?.setBaseAndExtent) return false;
      if (native.anchorNode === snapshot.anchor.node && native.anchorOffset === snapshot.anchor.offset &&
          native.focusNode === snapshot.focus.node && native.focusOffset === snapshot.focus.offset) return true;
      // Reused DOM nodes can lose their native range when moved by a patch.
      // Restore only unchanged surviving boundaries, never guess offsets for
      // replaced text or another document. This preserves direction and Copy.
      ignoredUntil = Math.max(ignoredUntil, performance.now() + 100);
      native.setBaseAndExtent(snapshot.anchor.node, snapshot.anchor.offset, snapshot.focus.node, snapshot.focus.offset);
      return true;
    }
    return {
      show, captureNative, restoreNative,
      refresh({ defer = false } = {}) { ignoredUntil = performance.now() + 100; records = undefined; clear(); if (lastSelection && !defer) show(lastSelection); },
      suspend({ preservePointer = false } = {}) { ignoredUntil = Infinity; if (!preservePointer) pointerSelecting = false; clear(); }
    };
  }
};
