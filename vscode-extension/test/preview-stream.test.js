'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');

// A deliberately small DOM harness tests protocol/lifecycle and node operations,
// not Chromium layout, actual paint timing or VS Code integration.
function harness(bootstrap = {}) {
  let anchorScans = 0, retainedMoves = 0, effectsCancels = 0;
  const effectsRuns = [];
  class Node {
    constructor(text = '', type = 1) { this.nodeType = type; this.textContent = text; this.childNodes = []; this.dataset = {}; this.hidden = false; this.attributes = {}; this.classes = new Set(); this.classList = { toggle: (key, on) => on ? this.classes.add(key) : this.classes.delete(key), contains: key => this.classes.has(key), [Symbol.iterator]: () => this.classes.values() }; }
    get outerHTML() { return this.textContent; }
    get firstChild() { return this.childNodes[0]; }
    get nextSibling() { if (!this.parentNode) return null; return this.parentNode.childNodes[this.parentNode.childNodes.indexOf(this) + 1] || null; }
    append(...nodes) { for (const node of nodes) this.insertBefore(node, null); }
    insertBefore(node, cursor) { if (node.parentNode === this) retainedMoves++; if (node.nodeType === 11) { for (const child of [...node.childNodes]) this.insertBefore(child, cursor); return; } node.remove(); const index = cursor ? this.childNodes.indexOf(cursor) : this.childNodes.length; this.childNodes.splice(index, 0, node); node.parentNode = this; }
    remove() { if (this.parentNode) { const siblings = this.parentNode.childNodes; siblings.splice(siblings.indexOf(this), 1); this.parentNode = null; } }
    querySelectorAll(selector) {
      if (this.isArticle && selector === '[data-source-start-byte]') anchorScans++;
      if (selector === '[data-source-end-byte]') return this.childNodes.filter(node => node.dataset.sourceEndByte !== undefined);
      return [];
    }
    setAttribute(key, value) { this.attributes[key] = value; }
    hasAttribute(key) { return Object.hasOwn(this.attributes, key); }
    getAttribute(key) { return this.attributes[key]; }
  }
  const elements = new Map(['markit-preview-article', 'markit-preview-error', 'markit-preview-updating', 'markit-preview-loading', 'markit-preview-data'].map(key => [key, new Node()]));
  elements.get('markit-preview-data').textContent = JSON.stringify({ file: 'a.md', generation: 1, renderId: 10, batchId: 1, offsets: [0], language: 'en', loading: true, ...bootstrap });
  elements.get('markit-preview-article').isArticle = true;
  const callbacks = new Map(), frames = [], messages = [], selectionRefreshes = [], timers = new Map();
  let timerId = 0;
  const document = { getElementById: id => elements.get(id), body: new Node(), documentElement: new Node(), addEventListener: (name, callback) => callbacks.set(name, callback), createComment: text => new Node(text, 8), createElement: name => { const node = new Node(); if (name === 'template') { node.content = new Node('', 11); Object.defineProperty(node, 'innerHTML', { set(html) { if (html) { for (const fragment of (bootstrap.separateBlocks ? html.match(/<p\b[^>]*>[\s\S]*?<\/p>|<iframe\b[^>]*>[\s\S]*?<\/iframe>|<img\b[^>]*>/g) || [html] : [html])) { const child = new Node(fragment); if (bootstrap.proseNodes && /^<p>[^<]*<\/p>$/.test(fragment)) { child.nodeName = 'P'; child.textContent = fragment.slice(3, -4); child.childNodes.push(new Node(child.textContent, 3)); Object.defineProperty(child, 'outerHTML', { value: fragment }); } const end = /data-source-end-byte="(\d+)"/.exec(html); if (end) child.dataset.sourceEndByte = end[1]; node.content.append(child); } } } }); } return node; } };
  const context = { setTimeout: callback => { timers.set(++timerId, callback); return timerId; }, clearTimeout: id => timers.delete(id), document, window: { MarkitEditEffects: { create: () => ({ run: (changes, enabled) => effectsRuns.push({ changes, enabled }), cancel: () => effectsCancels++ }) }, MarkitSelection: { create: () => ({ suspend() {}, refresh(options) { selectionRefreshes.push(options); } }) } }, acquireVsCodeApi: () => ({ postMessage: message => messages.push(message), setState() {}, getState() {} }), addEventListener: (name, callback) => callbacks.set(name, callback), requestAnimationFrame: callback => { frames.push(callback); return frames.length; }, ResizeObserver: class { observe() {} }, MutationObserver: class { observe() {} }, performance: { now: () => 0 }, scrollY: 0, scrollTo() {}, innerHeight: 800 };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../media/preview.js'), 'utf8'), context);
  const flush = () => { while (frames.length) frames.shift()(); };
  const send = (message, drain = true) => { callbacks.get('message')({ data: message }); if (drain) flush(); };
  flush();
  return { elements, messages, send, flush, effectsRuns, effectsCancels: () => effectsCancels, runTimers: () => { const pending = [...timers.values()]; timers.clear(); pending.forEach(callback => callback()); }, selectionRefreshes, moves: () => retainedMoves, scans: () => anchorScans, text: () => elements.get('markit-preview-article').childNodes.filter(node => node.nodeType === 1).map(node => node.textContent).join('') };
}

function batch(operations, overrides = {}) { return { type: 'preview-batch', file: 'a.md', generation: 1, renderId: 10, batchId: 2, consumedBytes: 4096, operations, ...overrides }; }

test('progressive operations append/replace/remove while bottom loading persists through every batch', () => {
  const h = harness(), spinner = h.elements.get('markit-preview-loading');
  assert.equal(spinner.hidden, false);
  assert.equal(spinner.textContent, 'Loading preview…');
  h.send(batch([{ id: 1, kind: 'append', html: '<p>First</p>' }]));
  assert.equal(h.text(), '<p>First</p>');
  assert.equal(spinner.hidden, false); assert.equal(spinner.classList.contains('progressive'), true);
  assert.equal(spinner.textContent, 'Loading more…');
  assert.equal(h.selectionRefreshes.at(-1).defer, true, 'append invalidates selection lazily without rebuilding all text');
  h.send(batch([], { batchId: 3 }));
  assert.equal(spinner.hidden, false); assert.equal(spinner.textContent, 'Loading more…');
  h.send(batch([{ id: 1, kind: 'replace', html: '<p>Reference corrected</p>' }, { id: 2, kind: 'append', html: '<p>Second</p>' }], { batchId: 4 }));
  assert.equal(h.text(), '<p>Reference corrected</p><p>Second</p>');
  h.send(batch([{ id: 1, kind: 'remove', html: '' }], { batchId: 5 }));
  assert.equal(h.text(), '<p>Second</p>');
  h.send({ type: 'content', file: 'a.md', generation: 1, html: '<p>Final</p>', offsets: [0], language: 'en', loading: false });
  assert.equal(h.text(), '<p>Final</p>'); assert.equal(spinner.hidden, true);
  assert.equal(h.messages.filter(message => message.type === 'preview-ack').length, 5);
});

test('switch rejects queued old document batches; cancellation and errors clear loading', () => {
  const h = harness(), spinner = h.elements.get('markit-preview-loading');
  h.send(batch([{ id: 1, kind: 'append', html: '<p>Old</p>' }]));
  h.send({ type: 'loading', file: 'b.md', generation: 2 });
  h.send(batch([{ id: 2, kind: 'append', html: '<p>STALE</p>' }]));
  assert.equal(h.text(), '<p>Old</p>');
  h.send({ type: 'content', file: 'b.md', generation: 2, renderId: 11, batchId: 1, html: '', offsets: [0], language: 'en', streamStart: true, loading: true });
  h.send(batch([{ id: 1, kind: 'append', html: '<p>New</p>' }], { file: 'b.md', generation: 2, renderId: 11 }));
  assert.equal(h.text(), '<p>New</p>');
  h.send({ type: 'error', generation: 1, message: 'stale failure' }); assert.equal(spinner.hidden, false);
  h.send({ type: 'error', generation: 2, message: 'failed' });
  assert.equal(spinner.hidden, true); assert.equal(h.elements.get('markit-preview-error').textContent, 'failed');
  h.send({ type: 'loading', file: 'b.md', generation: 3 }); assert.equal(spinner.hidden, false);
  h.send({ type: 'cancelled', generation: 3 }); assert.equal(spinner.hidden, true);
});


test('deferred content cannot overwrite a newer same-document render or a terminal error', () => {
  const h = harness();
  const stale = { type: 'content', file: 'a.md', generation: 1, renderId: 10, html: '<p>OLD FINAL</p>', offsets: [0], language: 'en', loading: false };
  h.send(stale, false);
  h.send({ type: 'loading', file: 'a.md', generation: 1, renderId: 11 });
  assert.equal(h.text(), '');
  assert.equal(h.elements.get('markit-preview-loading').hidden, false);
  h.send({ ...stale, renderId: 11 }, false);
  h.send({ type: 'error', generation: 1, message: 'render failed' });
  assert.equal(h.text(), '');
  assert.equal(h.elements.get('markit-preview-error').hidden, false);
});


test('far-away scroll target does not rescan accumulated DOM on every append', () => {
  const h = harness({ line: 1000, offsets: Array.from({ length: 1002 }, (_, index) => index * 10) });
  const before = h.scans();
  for (let index = 1; index <= 20; index++) h.send(batch([{ id: index, kind: 'append', html: `<p data-source-end-byte="${index * 10}">Part</p>` }], { batchId: index + 1 }));
  assert.equal(h.scans(), before, 'no full anchor scan before target source range arrives');
  h.send(batch([{ id: 21, kind: 'append', html: '<p data-source-end-byte="10020">Target</p>' }]));
  assert.equal(h.scans(), before + 1, 'one scan when target range arrives');
  h.send(batch([{ id: 22, kind: 'append', html: '<p data-source-end-byte="10030">Later</p>' }]));
  assert.equal(h.scans(), before + 1, 'unresolved/hidden target waits for final reconciliation without repeated scans');
});

test('background edit leaves old article and loading state untouched until one coherent final patch', () => {
  const h = harness({ loading: false }), spinner = h.elements.get('markit-preview-loading');
  h.send({ type: 'content', file: 'a.md', generation: 1, renderId: 10, html: '<p>Visible old content</p>', offsets: [0], language: 'en', loading: false });
  h.send({ type: 'background-start', file: 'a.md', generation: 1, renderId: 11 });
  assert.equal(h.text(), '<p>Visible old content</p>'); assert.equal(spinner.hidden, true);
  h.send({ type: 'content', file: 'a.md', generation: 1, renderId: 10, html: '<p>STALE</p>', offsets: [0], language: 'en', loading: false });
  assert.equal(h.text(), '<p>Visible old content</p>');
  h.send({ type: 'content', file: 'a.md', generation: 1, renderId: 11, html: '<p>New coherent content</p>', offsets: [0], language: 'en', loading: false, background: true });
  assert.equal(h.text(), '<p>New coherent content</p>'); assert.equal(spinner.hidden, true);
  h.send({ type: 'background-start', file: 'a.md', generation: 1, renderId: 12 });
  h.send({ type: 'error', generation: 1, message: 'background failed' });
  assert.equal(h.text(), '<p>New coherent content</p>'); assert.equal(spinner.hidden, true);
});


test('editing or deleting an earlier block never detaches unchanged trailing content', () => {
  const h = harness({ loading: false, separateBlocks: true });
  const send = html => h.send({ type: 'content', file: 'a.md', generation: 1, renderId: 10, html, offsets: [0], language: 'en', loading: false, background: true });
  send('<p>Old text</p><iframe src="embedded.html"></iframe><img src="image.png"><p>Tail</p>');
  const retained = h.elements.get('markit-preview-article').childNodes.slice(1);
  const before = h.moves();
  send('<p>New text</p><iframe src="embedded.html"></iframe><img src="image.png"><p>Tail</p>');
  assert.equal(h.moves(), before, 'reused iframe/image/text must not be moved to reconcile one changed paragraph');
  assert.deepEqual(h.elements.get('markit-preview-article').childNodes.slice(1), retained);
  send('<iframe src="embedded.html"></iframe><img src="image.png"><p>Tail</p>');
  assert.equal(h.moves(), before, 'deleting a paragraph must not detach its following siblings');
  assert.deepEqual(h.elements.get('markit-preview-article').childNodes, retained);
});


test('quiet updating badge is render-scoped and never obscures retained content', () => {
  const h = harness({ loading: false }), badge = h.elements.get('markit-preview-updating');
  const start = (renderId, generation = 1) => h.send({ type: 'background-start', file: 'a.md', generation, renderId });
  const final = renderId => h.send({ type: 'content', file: 'a.md', generation: 1, renderId, html: '<p>Retained</p>', offsets: [0], language: 'en', loading: false, background: true });
  final(10); start(11);
  assert.equal(badge.hidden, true, 'fast renders do not flash a badge');
  final(11); h.runTimers(); assert.equal(badge.hidden, true, 'completion cancels delayed badge');
  start(12); start(13); h.runTimers();
  assert.equal(badge.hidden, false); assert.equal(h.text(), '<p>Retained</p>');
  assert.equal(h.elements.get('markit-preview-loading').hidden, true);
  final(11);
  h.send({ type: 'error', generation: 1, renderId: 11, message: 'stale' });
  h.send({ type: 'cancelled', generation: 1, renderId: 11 });
  assert.equal(badge.hidden, false, 'old completion/error/cancel cannot dismiss newer update');
  final(13); assert.equal(badge.hidden, true);
  start(14); h.runTimers(); h.send({ type: 'error', generation: 1, renderId: 14, message: 'failed' });
  assert.equal(badge.hidden, true); assert.equal(h.text(), '<p>Retained</p>');
  start(15); h.runTimers(); h.send({ type: 'cancelled', generation: 1, renderId: 15 });
  assert.equal(badge.hidden, true);
  start(16); h.send({ type: 'loading', generation: 2, renderId: 17 });
  h.runTimers();
  assert.equal(badge.hidden, true, 'foreground switch cancels delayed background status');
  start(15); assert.equal(badge.hidden, true, 'old generation cannot resurrect badge');
});


test('edit effects receive only final background changed nodes and honor settings/cancellation', () => {
  const h = harness({ loading: false, separateBlocks: true, proseNodes: true });
  const final = (html, background, editEffects = true) => h.send({ type: 'content', file: 'a.md', generation: 1, renderId: 10, html, offsets: [0], language: 'en', loading: false, background, editEffects });
  final('<p>Old</p><p>Retained</p>', false); assert.equal(h.effectsRuns.length, 0);
  const retained = h.elements.get('markit-preview-article').childNodes[1];
  final('<p>New</p><p>Retained</p>', true);
  assert.equal(h.effectsRuns.length, 1); assert.equal(h.effectsRuns[0].changes.length, 1);
  assert.equal(h.effectsRuns[0].changes[0].node.textContent, 'New');
  assert.equal(h.effectsRuns[0].changes[0].previousText, 'Old');
  assert.equal(h.elements.get('markit-preview-article').childNodes[1], retained);
  final('<p>Newer</p><p>Retained</p>', true, false); assert.equal(h.effectsRuns.at(-1).enabled, false);
  const before = h.effectsCancels();
  h.send({ type: 'source-edits', file: 'a.md', changes: [] }); assert.equal(h.effectsCancels(), before + 1);
  h.send(batch([{ id: 1, kind: 'append', html: '<p>Streaming</p>' }]));
  assert.equal(h.effectsRuns.length, 2, 'provisional batches never animate');
  h.send({ type: 'background-start', file: 'a.md', generation: 1, renderId: 11 });
  assert.equal(h.effectsCancels(), before + 2);
  h.send({ type: 'content', file: 'a.md', generation: 1, renderId: 11, html: '<p>Switch</p>', offsets: [0], language: 'zh', loading: false, background: false });
  assert.equal(h.effectsRuns.length, 2, 'foreground language switches do not animate');
});
