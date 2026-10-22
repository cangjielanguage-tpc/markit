'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const fsp = require('node:fs/promises');
const path = require('node:path');
const os = require('node:os');
const { PreviewSession } = require('../src/session');
const { discover } = require('../src/projects');

const decode = text => text.replace(/&(#x[\da-f]+|#\d+|amp|lt|gt|quot|apos);/gi, (_, value) => value[0] === '#' ? String.fromCodePoint(parseInt(value.slice(value[1].toLowerCase() === 'x' ? 2 : 1), value[1].toLowerCase() === 'x' ? 16 : 10)) : ({ amp: '&', lt: '<', gt: '>', quot: '"', apos: "'" })[value]);

// Layout is intentionally mocked. This exercises the actual selection module's
// text-node/source mapping and lifecycle, not browser pixel geometry.
function selectionHarness(html, language = 'zh') {
  class Element {
    constructor(tag = 'div', text) { this.tagName = tag.toUpperCase(); this.nodeType = text === undefined ? 1 : 3; this.text = text; this.childNodes = []; this.attributes = {}; this.dataset = {}; this.style = {}; this.hidden = false; }
    get textContent() { return this.nodeType === 3 ? this.text : this.childNodes.map(node => node.textContent).join(''); }
    set textContent(text) { this.childNodes = []; this.append(new Element('', text)); }
    get parentElement() { return this.parentNode; }
    get nextElementSibling() { const siblings = this.parentNode?.childNodes || []; return siblings.slice(siblings.indexOf(this) + 1).find(node => node.nodeType === 1); }
    append(...nodes) { for (const node of nodes) { node.parentNode = this; this.childNodes.push(node); } }
    setAttribute(name, value) { this.attributes[name] = value; if (name.startsWith('data-')) this.dataset[name.slice(5).replace(/-([a-z])/g, (_, c) => c.toUpperCase())] = value; }
    removeAttribute(name) { delete this.attributes[name]; }
    matches(selector) { return selector.split(',').some(part => { part = part.trim(); return part.startsWith('[') ? Object.hasOwn(this.attributes, part.slice(1, -1)) : part.startsWith('#') ? (this.attributes.id || this.id) === part.slice(1) : part.startsWith('.') ? (this.attributes.class || '').split(/\s+/).includes(part.slice(1)) : this.tagName.toLowerCase() === part; }); }
    closest(selector) { for (let node = this; node; node = node.parentNode) if (node.nodeType === 1 && node.matches(selector)) return node; }
    querySelectorAll(selector) { return this.childNodes.flatMap(node => [...(node.nodeType === 1 && node.matches(selector) ? [node] : []), ...node.querySelectorAll(selector)]); }
    querySelector(selector) { return this.querySelectorAll(selector)[0]; }
    contains(node) { for (; node; node = node.parentNode) if (node === this) return true; return false; }
    getBoundingClientRect() { return { left: 10, top: 10, width: 100, height: 20 }; }
    set innerHTML(html) {
      this.childNodes = []; const stack = [this];
      for (const token of html.match(/<!--[\s\S]*?-->|<[^>]+>|[^<]+/g) || []) {
        if (token.startsWith('<!--')) continue;
        if (token.startsWith('</')) { if (stack.length > 1) stack.pop(); continue; }
        if (token.startsWith('<')) {
          const tag = /^<([\w-]+)/.exec(token)?.[1]; if (!tag) continue;
          const node = new Element(tag);
          for (const attr of token.matchAll(/([\w-]+)="([^"]*)"/g)) node.setAttribute(attr[1], decode(attr[2]));
          stack.at(-1).append(node);
          if (!/^(?:br|hr|img|input|link|meta|source)$/i.test(tag) && !token.endsWith('/>')) stack.push(node);
        } else stack.at(-1).append(new Element('', decode(token)));
      }
    }
    get value() { return this.textContent; }
  }
  const article = new Element('main'); article.innerHTML = html;
  const body = new Element('body'); body.append(article);
  const callbacks = new Map(), windowCallbacks = new Map(), frames = [], messages = [], highlights = new Map();
  let data = { file: 'doc.md', version: 1, language }, now = 1000, nativeSelection, removals = 0;
  const textNodes = node => node.childNodes.flatMap(child => child.nodeType === 3 ? [child] : textNodes(child));
  const document = { body, head: new Element('head'), hasFocus: () => true, createElement: tag => new Element(tag), addEventListener: (name, callback) => callbacks.set(name, callback), createTreeWalker: node => { const nodes = textNodes(node); let index = -1; return { nextNode() { return ++index < nodes.length; }, get currentNode() { return nodes[index]; } }; }, createRange: () => ({ selectNodeContents(node) { this.startContainer = node; this.endContainer = node; }, setStart(node, offset) { this.startContainer = node; this.startOffset = offset; }, setEnd(node, offset) { this.endContainer = node; this.endOffset = offset; }, collapse() {}, getClientRects() { return [{ left: 10, top: 10, width: 10, height: 20 }]; } }) };
  const context = { window: {}, document, TextDecoder, Uint8Array, Node: { TEXT_NODE: 3 }, NodeFilter: { SHOW_TEXT: 4 }, getComputedStyle: () => ({ visibility: 'visible' }), CSS: { highlights }, Highlight: class extends Array { constructor(...items) { super(...items); } }, performance: { now: () => now }, getSelection: () => nativeSelection, addEventListener: (name, callback) => windowCallbacks.set(name, callback), requestAnimationFrame: callback => { frames.push(callback); return frames.length; } };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../media/selection.js'), 'utf8'), context);
  const selection = context.window.MarkitSelection.create({ article, getData: () => data, postMessage: message => messages.push(message) });
  const nodeFor = text => textNodes(article).find(node => !node.parentElement.closest('script,style') && node.textContent.includes(text));
  function setNative(text, start, end = start) {
    const node = nodeFor(text); assert(node, `missing rendered text ${text}`);
    const offset = node.textContent.indexOf(text);
    nativeSelection = { anchorNode: node, focusNode: node, anchorOffset: offset + start, focusOffset: offset + end, isCollapsed: start === end, getRangeAt: () => ({ startContainer: node, startOffset: offset + Math.min(start, end) }), toString() { return this.anchorNode === this.focusNode ? this.anchorNode?.textContent.slice(Math.min(this.anchorOffset, this.focusOffset), Math.max(this.anchorOffset, this.focusOffset)) || '' : ''; }, removeAllRanges() { removals++; this.anchorNode = this.focusNode = undefined; }, setBaseAndExtent(anchorNode, anchorOffset, focusNode, focusOffset) { Object.assign(this, { anchorNode, anchorOffset, focusNode, focusOffset }); } };
  }
  return {
    selection, article, messages, nodeFor, setNative,
    control: () => new Element('input'),
    fire(name, event = {}) { (callbacks.get(name) || windowCallbacks.get(name))?.(event); },
    flush() { while (frames.length) frames.shift()(); },
    showMessage(message) { selection.show({ file: data.file, version: data.version, ranges: [{ anchor: 0, active: 0 }], ...message }); },
    nativeRemovals() { return removals; },
    nativeRange() { return nativeSelection; },
    replace(html, language) { article.innerHTML = html; data = { ...data, language }; now += 1000; },
    show(anchor, active = anchor) { now += 1000; selection.show({ file: data.file, version: data.version, ranges: [{ anchor, active }] }); },
    ranges() { return highlights.get('markit-selection') || []; },
    caretVisible() { return !body.querySelector('#markit-preview-caret').hidden; },
    select(text, start, end = start) {
      setNative(text, start, end);
      const before = messages.length;
      now += 1000; callbacks.get('selectionchange')(); while (frames.length) frames.shift()();
      assert.equal(messages.length, before + 1, `selection event must map ${text}`);
      return messages.at(-1);
    }
  };
}

function mappedParagraph(source, text) {
  const start = Buffer.byteLength(source.slice(0, source.indexOf(text))), end = start + Buffer.byteLength(text);
  return `<p data-source-start-byte="${start}" data-source-end-byte="${end}">${text}</p><script id="markit-page-markdown-source">${Buffer.from(source).toString('hex')}</script>`;
}

test('selection maps unequal translated offsets bidirectionally and refreshes persistent selection after switch', () => {
  const source = '很长的中文默认段落😀\n\n:::en\nEnglish selected 😀 text\n:::\n';
  const english = 'English selected 😀 text', start = source.indexOf('selected');
  const h = selectionHarness(mappedParagraph(source, '很长的中文默认段落😀'));
  h.show(start, start + 8); assert.equal(h.ranges().length, 0);
  h.selection.suspend(); h.replace(mappedParagraph(source, english), 'en'); h.selection.refresh();
  assert.equal(h.ranges().length, 1); assert.equal(h.ranges()[0].startOffset, 8); assert.equal(h.ranges()[0].endOffset, 16);
  h.show(start); assert.equal(h.caretVisible(), true);
  const picked = h.select('selected', 0, 8); assert.equal(picked.anchor, start); assert.equal(picked.active, start + 8);
  const reverse = h.select('selected', 8, 0); assert.equal(reverse.anchor, start + 8); assert.equal(reverse.active, start);
  const cursor = h.select('selected', 3); assert.equal(cursor.anchor, start + 3); assert.equal(cursor.active, start + 3);
  h.selection.suspend(); h.replace(mappedParagraph(source, english), 'en'); h.selection.refresh({ defer: true }); assert.equal(h.ranges().length, 0);
  h.selection.refresh(); assert.equal(h.caretVisible(), true, 'final reconciliation restores previous editor cursor');
});

test('native drag is not interrupted by editor echo, clear actions are one-shot and stale actions are ignored', () => {
  const source = 'Text selected here', h = selectionHarness(mappedParagraph(source, source));
  h.fire('pointerdown', { button: 0, target: h.nodeFor('selected') });
  h.setNative('selected', 0, 3);
  h.fire('selectionchange'); h.fire('selectionchange'); h.flush();
  assert.equal(h.messages.length, 0, 'do not scroll/reveal editor during native pointer drag');
  h.showMessage({ clearNative: true }); assert.equal(h.nativeRemovals(), 0, 'editor event cannot interrupt active drag');
  h.setNative('selected', 0, 8);
  h.fire('pointerup'); h.fire('selectionchange'); h.flush();
  assert.equal(h.messages.length, 1, 'release and selectionchange coalesce');
  assert.equal(h.messages[0].anchor, 5); assert.equal(h.messages[0].active, 13);
  h.showMessage({ ranges: [{ anchor: 5, active: 13 }], clearNative: false });
  assert.equal(h.nativeRemovals(), 0, 'programmatic echo preserves native copy range');
  h.showMessage({ clearNative: true }); assert.equal(h.nativeRemovals(), 1);
  h.setNative('selected', 1, 5); h.fire('resize'); h.fire('scroll');
  assert.equal(h.nativeRemovals(), 1, 'resize/scroll never replay clearNative');
  h.showMessage({ version: 0, clearNative: true }); h.showMessage({ file: 'old.md', clearNative: true });
  assert.equal(h.nativeRemovals(), 1, 'stale document actions cannot clear selection');
  h.select('selected', 1, 5); assert.equal(h.messages.length, 2, 'keyboard-style selection without pointerdown still syncs');
  h.fire('pointerdown', { button: 0, target: h.nodeFor('selected') }); h.fire('blur');
  h.select('selected', 2, 6); assert.equal(h.messages.length, 3, 'release outside the webview must not leave selection sync suspended');
});

test('background reconciliation restores only unchanged surviving native range boundaries', () => {
  const source = 'Text selected here', h = selectionHarness(mappedParagraph(source, source));
  h.fire('pointerdown', { button: 0, target: h.nodeFor('selected') });
  h.setNative('selected', 8, 1); const snapshot = h.selection.captureNative();
  h.selection.suspend({ preservePointer: true }); h.selection.refresh();
  h.setNative('selected', 0); assert.equal(h.selection.restoreNative(snapshot), true);
  assert.equal(h.nativeRange().anchorOffset, 13); assert.equal(h.nativeRange().focusOffset, 6, 'reverse direction retained');
  h.fire('selectionchange'); h.flush(); assert.equal(h.messages.length, 0, 'background reconciliation keeps drag in progress');
  h.fire('pointerup'); h.flush(); assert.equal(h.messages.length, 1, 'release immediately after patch still syncs final range');
  h.nodeFor('selected').text = 'changed text';
  assert.equal(h.selection.restoreNative(snapshot), false, 'never guess offsets in changed text');
  h.replace(mappedParagraph(source, source), 'en');
  assert.equal(h.selection.restoreNative(snapshot), false, 'same-looking replacement nodes are not original range boundaries');
});

test('Copy uses actual rendered selection and explicit shortcut clipboard payloads, not source Markdown', () => {
  const source = '**中文😀** and *English*';
  const html = `<p data-source-start-byte="0" data-source-end-byte="${Buffer.byteLength(source)}"><strong>中文😀</strong> and <em>English</em></p><script id="markit-page-markdown-source">${Buffer.from(source).toString('hex')}</script>`;
  const h = selectionHarness(html);
  const event = (extra = {}) => ({ target: h.nodeFor('English'), isTrusted: true, key: 'c', ctrlKey: true,
    preventDefault() { this.defaultPrevented = true; }, stopPropagation() { this.stopped = true; }, ...extra });
  h.setNative('English', 7, 0);
  const shortcut = event(); h.fire('keydown', shortcut);
  assert.equal(h.messages.at(-1).type, 'copy-selection'); assert.equal(h.messages.at(-1).text, 'English');
  assert.equal(shortcut.defaultPrevented, true); assert.equal(shortcut.stopped, true);
  const clipboard = new Map(), copy = event({ clipboardData: { setData: (type, text) => clipboard.set(type, text) } });
  h.fire('copy', copy); assert.equal(clipboard.get('text/plain'), 'English'); assert.equal(copy.defaultPrevented, true);
  const en = source.indexOf('English');
  h.showMessage({ clearNative: true, ranges: [{ anchor: en + 7, active: en }, { anchor: 2, active: 6 }] });
  const mirrored = event({ ctrlKey: false, metaKey: true }); h.fire('keydown', mirrored);
  assert.equal(h.messages.at(-1).text, 'English\n中文😀', 'CSS highlights copy rendered multi-range text, preserving Unicode');
  clipboard.clear(); h.fire('copy', event({ clipboardData: { setData: (type, text) => clipboard.set(type, text) } }));
  assert.equal(clipboard.get('text/plain'), 'English\n中文😀');
  const count = h.messages.length;
  for (const extra of [{ target: h.control() }, { isTrusted: false }, { shiftKey: true }, { altKey: true }, { repeat: true }]) {
    const ignored = event(extra); h.fire('keydown', ignored); assert.equal(ignored.defaultPrevented, undefined);
  }
  assert.equal(h.messages.length, count, 'input/browser commands and synthetic events remain untouched');
  h.showMessage({ ranges: [{ anchor: en, active: en }] });
  h.fire('keydown', event()); assert.equal(h.messages.length, count, 'collapsed cursor is not copied');
});

const multilingualSource = '# 中文标题:en{Long English title}:\n\n默认中文段落😀，长度不同。\n\n:::en\nEnglish paragraph with **selected😀** and tail.\n\n> Quoted **nestedEnglish** content.\n\n- List **listEnglish** item.\n:::\n\n:::ja\n日本語の**選択😀**と終わり。\n:::\n';
test('actual native zh/en/ja source maps support translated selection, nested text, switching and stream finalization', { skip: !process.env.MARKIT_TEST_BINARY, timeout: 90000 }, async t => {
  const root = await fsp.mkdtemp(path.join(os.tmpdir(), 'markit-selection-i18n-')); let session;
  t.after(async () => { await session?.dispose(); await fsp.rm(root, { recursive: true, force: true }); });
  await fsp.writeFile(path.join(root, 'markit.json'), JSON.stringify({ title: 'Selection regression', format: 'website', theme: 'arctic', i18n: { default: 'zh', target: 'zh' }, summary: [{ file: 'markit.md', label: 'Docs', showDrafts: false }] }));
  await fsp.writeFile(path.join(root, 'markit.md'), '- [Doc:en{Doc}:](doc.md)\n');
  const file = path.join(root, 'doc.md'); await fsp.writeFile(file, multilingualSource);
  const streamed = new Map(); let body = '', blocks = new Map();
  session = new PreviewSession((await discover(root))[0], { executable: process.env.MARKIT_TEST_BINARY, onPreview: (page, frame) => {
    if (frame.shell) { body = page.body; blocks = new Map(); }
    for (const operation of frame.operations) { if (operation.kind === 'remove') blocks.delete(operation.id); else blocks.set(operation.id, operation.html); }
    if (blocks.size) streamed.set(page.language, body + [...blocks.values()].join(''));
  } });
  await session.start('zh', [], file);
  const h = selectionHarness(session.current.body, 'zh');
  const zh = multilingualSource.indexOf('默认中文'); h.show(zh, zh + 4); assert.equal(h.ranges().length, 1);
  const selected = multilingualSource.indexOf('selected😀'); h.show(selected, selected + 'selected😀'.length); assert.equal(h.ranges().length, 0);
  await session.switchLanguage('en');
  h.selection.suspend(); h.replace(streamed.get('en'), 'en'); h.selection.refresh({ defer: true });
  assert.equal(h.ranges().length, 0, 'streaming defers selection mapping rather than retaining stale language highlights');
  h.selection.suspend(); h.replace(session.current.body, 'en'); h.selection.refresh(); assert.equal(h.ranges().length, 1, 'persisted range survives final reconciliation');
  h.show(zh, zh + 4); assert.equal(h.ranges().length, 0, 'hidden default-language source must not highlight translated content');
  for (const text of ['Long English title', 'selected😀', 'nestedEnglish', 'listEnglish']) {
    const start = multilingualSource.indexOf(text); h.show(start, start + text.length); assert.equal(h.ranges().length, 1, text);
    const result = h.select(text, 0, text.length); assert.equal(result.anchor, start, text); assert.equal(result.active, start + text.length, text);
    const reverse = h.select(text, text.length, 0); assert.equal(reverse.anchor, start + text.length, text); assert.equal(reverse.active, start, text);
    h.show(start + 1); assert.equal(h.caretVisible(), true, `cursor ${text}`);
    const cursor = h.select(text, 1); assert.equal(cursor.anchor, start + 1, text); assert.equal(cursor.active, start + 1, text);
  }
  await session.switchLanguage('ja'); h.selection.suspend(); h.replace(session.current.body, 'ja'); h.selection.refresh();
  const ja = multilingualSource.indexOf('選択😀'); h.show(ja, ja + 4); assert.equal(h.ranges().length, 1);
  const picked = h.select('選択😀', 0, 4); assert.equal(picked.anchor, ja); assert.equal(picked.active, ja + 4);
  await session.switchLanguage('zh'); h.replace(session.current.body, 'zh'); h.selection.refresh(); h.show(zh, zh + 4); assert.equal(h.ranges().length, 1);
});
