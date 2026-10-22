'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { changedGraphemes, createEditEffects } = require('../media/edit-effects');

test('changed substring planning preserves grapheme and UTF-16 boundaries', () => {
  assert.deepEqual(changedGraphemes('same', 'same'), []);
  const diff = changedGraphemes('前👨‍👩‍👧‍👦e\u0301后', '前旧后');
  assert.deepEqual(diff.map(item => item.segment), ['👨‍👩‍👧‍👦', 'e\u0301']);
  assert.equal(diff[0].index, 1); assert.equal(diff.at(-1).end, '前👨‍👩‍👧‍👦e\u0301'.length);
  assert.deepEqual(changedGraphemes('ac', 'abc'), [], 'pure deletion has no invented typing');
});

function harness(text = 'Hello there') {
  class Element {
    constructor() { this.children = []; this.style = {}; this.attributes = {}; }
    append(node) { this.children.push(node); node.parent = this; }
    remove() { if (this.parent) this.parent.children.splice(this.parent.children.indexOf(this), 1); }
    setAttribute(key, value) { this.attributes[key] = value; }
  }
  const body = new Element(), listeners = new Map(), frames = new Map(), ranges = [];
  let sequence = 0;
  const motion = { matches: false, addEventListener(name, listener) { this.listener = listener; }, removeEventListener() {} };
  const node = { nodeName: 'P', childNodes: [{ nodeType: 3 }], parentElement: null };
  node.firstChild = node.childNodes[0];
  Object.defineProperty(node, 'textContent', { get: () => text, set() { throw new Error('Source text mutated'); } });
  const selection = { isCollapsed: true };
  const environment = { innerHeight: 800, innerWidth: 900,
    document: { body, createElement: () => new Element(), createRange() { let start, end; return { setStart(_, value) { start = value; }, setEnd(_, value) { end = value; }, getClientRects() { ranges.push([start, end]); return [{ left: start * 8, right: end * 8, top: 0, bottom: 20, width: (end - start) * 8, height: 20 }]; } }; } },
    getComputedStyle: () => ({ backgroundColor: 'rgb(24, 30, 40)', backgroundImage: 'none', direction: 'ltr', writingMode: 'horizontal-tb' }),
    getSelection: () => selection, matchMedia: () => motion,
    addEventListener: (name, callback) => listeners.set(name, callback), removeEventListener: name => listeners.delete(name),
    requestAnimationFrame: callback => { frames.set(++sequence, callback); return sequence; }, cancelAnimationFrame: id => frames.delete(id)
  };
  const effects = createEditEffects({ article: { contains: candidate => candidate === node }, environment });
  const tick = time => { const pending = [...frames.values()]; frames.clear(); pending.forEach(callback => callback(time)); };
  return { node, body, listeners, frames, ranges, motion, environment, selection, effects, tick };
}

test('typewriter masks only changed graphemes; source DOM stays correct and animation terminates', () => {
  const h = harness();
  assert.equal(h.effects.run([{ node: h.node, previousText: 'Hello old' }]), true);
  assert.equal(h.node.textContent, 'Hello there');
  assert.deepEqual(h.ranges, [[6, 7], [7, 8], [8, 9], [9, 10], [10, 11]]);
  const overlay = h.body.children[0];
  assert.equal(overlay.attributes['aria-hidden'], 'true');
  assert.match(overlay.style.cssText, /pointer-events:none/);
  h.tick(0); h.tick(120); assert.equal(overlay.children.filter(node => /background:rgb/.test(node.style.cssText)).length, 4);
  h.tick(3000); assert.equal(h.body.children.length, 0); assert.equal(h.frames.size, 0);
  assert.equal(h.node.textContent, 'Hello there');
});

test('effects cancel on interaction, new update, reduced motion and disposal', () => {
  const h = harness();
  for (const event of ['pointerdown', 'keydown', 'scroll', 'resize', 'selectionchange', 'visibilitychange', 'pagehide']) {
    h.effects.run([{ node: h.node }]); h.listeners.get(event)();
    assert.equal(h.body.children.length, 0); assert.equal(h.frames.size, 0);
  }
  h.effects.run([{ node: h.node }]); h.effects.run([{ node: h.node }], false); assert.equal(h.body.children.length, 0);
  h.effects.run([{ node: h.node }]); h.motion.matches = true; h.motion.listener(); assert.equal(h.body.children.length, 0);
  assert.equal(h.effects.run([{ node: h.node }]), false);
  h.effects.dispose(); assert.equal(h.listeners.size, 0);
});

test('selection, complex content, unsafe backgrounds and large edits skip effects', () => {
  const h = harness(); h.selection.isCollapsed = false;
  assert.equal(h.effects.run([{ node: h.node }]), false);
  h.selection.isCollapsed = true; h.node.nodeName = 'PRE'; assert.equal(h.effects.run([{ node: h.node }]), false);
  h.node.nodeName = 'P'; h.environment.getComputedStyle = () => ({ backgroundImage: 'linear-gradient(red, blue)' });
  assert.equal(h.effects.run([{ node: h.node }]), false);
  const large = harness('x'.repeat(257)); assert.equal(large.effects.run([{ node: large.node }]), false);
  assert.equal(large.body.children.length, 0);
});


test('particle budget and missing grapheme support fail safely', t => {
  const h = harness('x'.repeat(256));
  h.effects.run([{ node: h.node }]); h.tick(0); h.tick(2400);
  assert(h.body.children[0].children.length <= 73, 'at most 72 particles plus one caret');
  h.tick(2850); assert.equal(h.body.children.length, 0);
  const original = Intl.Segmenter;
  try { Intl.Segmenter = undefined; assert.deepEqual(changedGraphemes('e\u0301👨‍👩‍👧‍👦'), []); }
  finally { Intl.Segmenter = original; }
});
