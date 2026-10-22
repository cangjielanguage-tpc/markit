'use strict';

function byteToLine(offsets, byte) {
  let low = 0, high = offsets.length;
  while (low + 1 < high) { const mid = (low + high) >>> 1; if (offsets[mid] <= byte) low = mid; else high = mid; }
  return low;
}

function rebaseLine(line, changes) {
  for (const edit of [...changes].sort((a, b) => b.startLine - a.startLine || b.startCharacter - a.startCharacter)) {
    const added = (edit.text.match(/\n/g) || []).length;
    if (line > edit.endLine) line += added - (edit.endLine - edit.startLine);
    else if (line > edit.startLine) line = edit.startLine + Math.min(line - edit.startLine, added);
  }
  return Math.max(0, line);
}

function renderedLine(line, batches) {
  for (const batch of [...batches].reverse()) {
    let shift = 0;
    const inverse = [...batch].sort((a, b) => a.startLine - b.startLine || a.startCharacter - b.startCharacter).map(edit => {
      const added = (edit.text.match(/\n/g) || []).length;
      const startLine = edit.startLine + shift;
      shift += added - (edit.endLine - edit.startLine);
      return { startLine, endLine: startLine + added, text: '\n'.repeat(edit.endLine - edit.startLine) };
    });
    line = rebaseLine(line, inverse);
  }
  return line;
}

if (typeof module !== 'undefined') module.exports = { byteToLine, rebaseLine, renderedLine };

if (typeof window !== 'undefined') (() => {
  const vscode = acquireVsCodeApi();
  let data = JSON.parse(document.getElementById('markit-preview-data').textContent);
  const article = document.getElementById('markit-preview-article');
  const selection = window.MarkitSelection?.create({ article, getData: () => data, postMessage: message => vscode.postMessage(message) });
  const effects = window.MarkitEditEffects?.create({ article });
  const original = new WeakMap();
  let suppressedUntil = 0, stableLine = 0, scrollFrame = 0, restoreFrame = 0;
  let edits = [], applying = false, requestedLine, pendingHash;
  let loadedThroughLine = -1, attemptedTarget;
  let acceptedGeneration = data.generation || 0, streamId = data.renderId, acceptContent = true;
  const streamed = new Map();
  const isCurrent = message => (message.generation ?? 0) === acceptedGeneration;
  let updatingTimer;
  function setUpdating(value) {
    const indicator = document.getElementById('markit-preview-updating');
    if (!indicator) return;
    if (!value) {
      clearTimeout(updatingTimer); updatingTimer = undefined;
      indicator.hidden = true;
    } else if (indicator.hidden && updatingTimer === undefined) {
      // Fast renders never flash a badge. Successive updates keep the existing
      // timer/status instead of repeatedly postponing or flickering it.
      updatingTimer = setTimeout(() => { updatingTimer = undefined; indicator.hidden = false; }, 200);
    }
  }
  const isCurrentStatus = message => isCurrent(message) &&
    (message.renderId === undefined || streamId === undefined || message.renderId >= streamId);
  function setLoading(value, more = false) {
    data.loading = value;
    const indicator = document.getElementById('markit-preview-loading');
    indicator.hidden = !value;
    indicator.classList.toggle('progressive', value && more);
    indicator.textContent = more ? 'Loading more…' : 'Loading preview…';
    article.setAttribute('aria-busy', String(value));
  }
  function acknowledge(message) {
    if (message.renderId === undefined || message.batchId === undefined) return;
    // The second frame gives Chromium an opportunity to paint before the parser continues.
    requestAnimationFrame(() => {
      if (isCurrent(message)) vscode.postMessage({ type: 'preview-ack', generation: message.generation, renderId: message.renderId, batchId: message.batchId, file: message.file, viewportHeight: innerHeight });
    });
  }
  function resolveHash() {
    if (!pendingHash) return;
    const target = document.getElementById(pendingHash);
    if (target) { target.scrollIntoView(); pendingHash = undefined; }
  }
  const signature = node => node.nodeType === 1 ? node.outerHTML
    .replace(/\sdata-source-(?:start|end)-byte="[^"]*"/g, '')
    .replace(/\s(?:id|data-anchor-id)="\d+(?:\.\d+)*-(?:block|code|list|table|math)-\d+"/g, '') : node.textContent;
  for (const node of article.childNodes) original.set(node, signature(node));

  function anchors() {
    return [...article.querySelectorAll('[data-source-start-byte]')].map(node => {
      let box = node;
      if (node.tagName === 'TH') box = node.closest('table') || node;
      if (!box.getBoundingClientRect().height && node.nextElementSibling) box = node.nextElementSibling;
      const rect = box.getBoundingClientRect();
      const start = Number(node.dataset.sourceStartByte), end = Number(node.dataset.sourceEndByte);
      return { start: byteToLine(data.offsets, start), end: byteToLine(data.offsets, Math.max(start, end - 1)) + 1,
        top: rect.top + scrollY, height: rect.height };
    }).filter(item => item.height > 0).sort((a, b) => a.start - b.start || (a.end - a.start) - (b.end - b.start));
  }
  function currentLine() {
    const entries = anchors().sort((a, b) => a.top - b.top || b.height - a.height);
    const top = scrollY + 24;
    let best = entries[0], next;
    for (const item of entries) {
      if (item.top <= top) best = item;
      else if (!next) next = item;
    }
    if (!best) return 0;
    if (top > best.top + best.height && next && next.start > best.end) {
      return best.end + (next.start - best.end) * Math.min(1, (top - best.top - best.height) / Math.max(1, next.top - best.top - best.height));
    }
    return best.start + Math.max(0, Math.min(1, (top - best.top) / best.height)) * Math.max(1, best.end - best.start);
  }
  function latestLine() { return edits.reduce((line, batch) => rebaseLine(line, batch), currentLine()); }
  function scrollToLine(line) {
    const entries = anchors();
    let best, next;
    for (const item of entries) {
      if (item.start <= line && (!best || item.start > best.start || (item.start === best.start && item.end < best.end))) best = item;
      if (item.start > line && (!next || item.start < next.start)) next = item;
    }
    let y = 0;
    if (best) {
      if (line < best.end) y = best.top + (line - best.start) / Math.max(1, best.end - best.start) * best.height;
      else if (next) y = best.top + best.height + (next.top - best.top - best.height) * Math.min(1, (line - best.end) / Math.max(1, next.start - best.end));
      else y = best.top + best.height;
    } else if (next) y = next.top;
    suppressedUntil = performance.now() + 100;
    scrollTo({ top: Math.max(0, y - 24), behavior: 'instant' });
    stableLine = line;
    return Boolean(best && line < best.end);
  }
  function updateSourcePositions(oldNode, newNode) {
    if (oldNode.nodeType !== 1) return;
    const oldNodes = [oldNode, ...oldNode.querySelectorAll('[data-source-start-byte]')];
    const newNodes = [newNode, ...newNode.querySelectorAll('[data-source-start-byte]')];
    if (oldNodes.length !== newNodes.length) return;
    newNodes.forEach((node, index) => {
      for (const attribute of ['id', 'data-anchor-id', 'data-source-start-byte', 'data-source-end-byte']) {
        if (node.hasAttribute(attribute)) oldNodes[index].setAttribute(attribute, node.getAttribute(attribute));
      }
    });
  }
  function patch(html) {
    const previousNodes = [...article.childNodes];
    const template = document.createElement('template'); template.innerHTML = html;
    const available = new Map();
    for (const node of article.childNodes) {
      const key = original.get(node) ?? signature(node);
      if (!available.has(key)) available.set(key, []);
      available.get(key).push(node);
    }
    const desired = [...template.content.childNodes].map(node => {
      const key = signature(node);
      const previous = available.get(key)?.shift();
      if (previous) { updateSourcePositions(previous, node); return previous; }
      original.set(node, key); return node;
    });
    // Remove obsolete nodes before choosing the insertion cursor. Otherwise a
    // replaced early block stays at the cursor and every unchanged later node
    // is needlessly moved in front of it (resetting embedded documents/ranges).
    const keep = new Set(desired);
    for (const node of [...article.childNodes]) if (!keep.has(node)) node.remove();
    let cursor = article.firstChild;
    for (const node of desired) {
      if (node === cursor) cursor = cursor.nextSibling;
      else article.insertBefore(node, cursor);
    }
    const previousSet = new Set(previousNodes);
    return desired.flatMap((node, index) => {
      if (previousSet.has(node)) return [];
      const previous = previousNodes[index];
      const previousText = previous?.nodeName === 'P' && !keep.has(previous) && previous.childNodes.length === 1 && previous.firstChild.nodeType === 3 ? previous.textContent : undefined;
      return [{ node, previousText }];
    });
  }
  function store() { vscode.setState({ file: data.file, line: stableLine }); }
  function apply(message) {
    if (!acceptContent || !isCurrent(message) || (message.renderId !== undefined && streamId !== undefined && message.renderId < streamId)) return;
    const sameFile = message.file === data.file;
    const line = sameFile ? (requestedLine ?? latestLine()) : (message.line || 0);
    // Retained nodes provide a pixel anchor for quiet edits; source-line estimates
    // remain the fallback if the visible block itself changed.
    const viewport = message.background && sameFile ? [...article.querySelectorAll('[data-source-start-byte]')]
      .map(node => ({ node, top: node.getBoundingClientRect().top, bottom: node.getBoundingClientRect().bottom }))
      .filter(item => item.bottom > 24).sort((a, b) => Math.abs(a.top - 24) - Math.abs(b.top - 24))[0] : undefined;
    const nativeSelection = message.background && sameFile ? selection?.captureNative?.() : undefined;
    applying = true;
    selection?.suspend({ preservePointer: Boolean(message.background && sameFile) });
    effects?.cancel();
    const changes = patch(message.html); streamed.clear(); loadedThroughLine = -1; attemptedTarget = undefined;
    streamId = message.renderId;
    data = message; edits = []; requestedLine = undefined;
    const classes = [...document.body.classList].filter(name => name.startsWith('vscode-'));
    document.body.className = classes.concat((message.bodyClass || '').split(/\s+/)).filter(Boolean).join(' ');
    document.documentElement.lang = message.language;
    window.MarkitRenderer?.initializeCodeBlocks?.();
    if (viewport && article.contains(viewport.node)) {
      const delta = viewport.node.getBoundingClientRect().top - viewport.top;
      if (delta) { suppressedUntil = performance.now() + 100; scrollTo({ top: scrollY + delta, behavior: 'instant' }); }
      stableLine = line;
    } else scrollToLine(line);
    store(); applying = false;
    if (message.streamStart) requestedLine = line;
    setLoading(Boolean(message.loading));
    setUpdating(false);
    resolveHash();
    selection?.refresh();
    if (nativeSelection) selection?.restoreNative?.(nativeSelection);
    if (message.background && sameFile) effects?.run(changes, message.editEffects !== false);
    document.getElementById('markit-preview-error').hidden = true;
    vscode.postMessage({ type: 'rendered', file: data.file, version: data.version, generation: data.generation, renderId: data.renderId, loading: data.loading });
    acknowledge(message);
  }
  function applyBatch(message) {
    if (!acceptContent || !isCurrent(message) || message.renderId !== streamId || message.file !== data.file) return;
    applying = true;
    selection?.suspend();
    for (const operation of message.operations || []) {
      let range = streamed.get(operation.id);
      if (range && operation.kind !== 'append') {
        let node = range.start.nextSibling;
        while (node && node !== range.end) { const next = node.nextSibling; node.remove(); node = next; }
        if (operation.kind === 'remove') { range.start.remove(); range.end.remove(); streamed.delete(operation.id); continue; }
      }
      if (!range) {
        range = { start: document.createComment('markit-block'), end: document.createComment('/markit-block') };
        article.append(range.start, range.end); streamed.set(operation.id, range);
      }
      const template = document.createElement('template'); template.innerHTML = operation.html || '';
      // Inspect only new/changed nodes, never rescan cumulative DOM just to see
      // whether a far-away editor scroll target has arrived yet.
      for (const anchor of template.content.querySelectorAll('[data-source-end-byte]')) {
        const end = Number(anchor.dataset.sourceEndByte);
        if (Number.isFinite(end)) loadedThroughLine = Math.max(loadedThroughLine, byteToLine(data.offsets, Math.max(0, end - 1)) + 1);
      }
      for (const node of template.content.childNodes) original.set(node, signature(node));
      article.insertBefore(template.content, range.end);
    }
    // Appending below existing blocks leaves the viewport stable. Avoid full-document
    // scans/initialization for each batch; final reconciliation initializes the bundle.
    applying = false;
    selection?.refresh({ defer: true });
    if (message.operations?.some(operation => operation.html)) setLoading(true, true);
    if (requestedLine !== undefined && requestedLine < loadedThroughLine && attemptedTarget !== requestedLine) {
      attemptedTarget = requestedLine;
      if (scrollToLine(requestedLine)) requestedLine = undefined;
      // Hidden/zero-height anchors may not resolve yet. Keep the logical target
      // for final reconciliation, without repeating a full scan every batch.
    }
    resolveHash();
    acknowledge(message);
  }
  addEventListener('message', event => {
    const message = event.data;
    if (message?.type === 'loading' && message.generation >= acceptedGeneration) {
      effects?.cancel();
      streamId = message.generation === acceptedGeneration ? message.renderId : undefined;
      acceptedGeneration = message.generation; acceptContent = true;
      setUpdating(false);
      setLoading(true); document.getElementById('markit-preview-error').hidden = true;
      return;
    }
    if (message?.type === 'background-start' && message.file === data.file && message.generation >= acceptedGeneration &&
        (message.generation > acceptedGeneration || streamId === undefined || message.renderId >= streamId)) {
      effects?.cancel();
      acceptedGeneration = message.generation; streamId = message.renderId; acceptContent = true;
      setUpdating(true);
      document.getElementById('markit-preview-error').hidden = true;
      return;
    }
    if (message?.type === 'content') requestAnimationFrame(() => apply(message));
    else if (message?.type === 'preview-batch') requestAnimationFrame(() => applyBatch(message));
    else if (message?.type === 'editor-selection' && message.file === data.file) selection?.show(message);
    else if (message?.type === 'editor-scroll' && message.file === data.file) {
      // Editor line numbers already refer to the latest source; the new DOM will catch up.
      requestedLine = message.line; attemptedTarget = undefined;
      scrollToLine(renderedLine(message.line, edits)); stableLine = message.line; store();
    } else if (message?.type === 'source-edits' && message.file === data.file) {
      effects?.cancel();
      if (requestedLine !== undefined) requestedLine = rebaseLine(requestedLine, message.changes);
      stableLine = rebaseLine(stableLine, message.changes);
      edits.push(message.changes);
    }
    else if (message?.type === 'cancelled' && isCurrentStatus(message)) { effects?.cancel(); setUpdating(false); setLoading(false); streamId = undefined; acceptContent = false; }
    else if (message?.type === 'error' && isCurrentStatus(message)) {
      effects?.cancel(); setUpdating(false); setLoading(false); streamId = undefined; acceptContent = false;
      const box = document.getElementById('markit-preview-error'); box.textContent = message.message; box.hidden = false;
    }
  });
  addEventListener('scroll', () => {
    if (scrollFrame) return;
    scrollFrame = requestAnimationFrame(() => {
      scrollFrame = 0;
      if (applying || performance.now() < suppressedUntil) return;
      requestedLine = undefined;
      stableLine = latestLine(); store();
      vscode.postMessage({ type: 'preview-scroll', file: data.file, line: stableLine });
    });
  }, { passive: true });
  for (const name of ['wheel', 'touchstart']) addEventListener(name, () => { suppressedUntil = 0; }, { passive: true });
  document.addEventListener('click', event => {
    const tab = event.target.closest?.('.code-tab');
    if (tab) {
      const group = tab.closest('.code-block-group');
      group?.querySelectorAll('.code-tab').forEach(node => node.classList.toggle('active', node === tab));
      group?.querySelectorAll('.code-panel').forEach(node => node.classList.toggle('active', node.dataset.panel === tab.dataset.tab));
    }
    const link = event.target.closest?.('a[href]');
    if (link && link.getAttribute('href').startsWith('#')) {
      try { pendingHash = decodeURIComponent(link.getAttribute('href').slice(1)); } catch { pendingHash = link.getAttribute('href').slice(1); }
      event.preventDefault(); resolveHash();
    } else if (link) {
      event.preventDefault();
      vscode.postMessage({ type: 'open-link', file: data.file, href: link.getAttribute('href'), label: link.textContent });
    }
  });
  const resize = new ResizeObserver(() => {
    if (applying || data.loading || restoreFrame) return;
    restoreFrame = requestAnimationFrame(() => {
      restoreFrame = 0;
      if (!applying) { const latest = stableLine; scrollToLine(renderedLine(latest, edits)); stableLine = latest; }
    });
  });
  resize.observe(article);
  function theme() {
    const dark = document.body.classList.contains('vscode-dark') || document.body.classList.contains('vscode-high-contrast');
    document.documentElement.dataset.theme = dark ? 'dark' : 'light';
  }
  new MutationObserver(theme).observe(document.body, { attributes: true, attributeFilter: ['class'] }); theme();
  const saved = vscode.getState();
  scrollToLine(saved?.file === data.file ? saved.line : (data.line || 0));
  if (data.loading) requestedLine = saved?.file === data.file ? saved.line : (data.line || 0);
  setUpdating(false);
  setLoading(Boolean(data.loading));
  requestAnimationFrame(() => acknowledge(data));
  vscode.postMessage({ type: 'ready', file: data.file, version: data.version, generation: data.generation, renderId: data.renderId, loading: data.loading });
  window.MarkitPreview = { currentLine, scrollToLine, apply };
})();
