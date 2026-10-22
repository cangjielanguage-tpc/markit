'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { documentParts, elementByClass } = require('../src/document');
const { byteToLine, rebaseLine, renderedLine } = require('../media/preview');

test('extracts document content without website chrome and keeps UTF-8 source positions', () => {
  const source = '# 标题 😀\r\n\r\nParagraph\n';
  const html = `<html><head><title>X</title></head><body class="no-ligatures"><nav class="top-nav"></nav><div class="content"><div class="article-extra"><div>Controls</div></div><h1>Title</h1><script type="application/x-markit-source-hex" id="markit-page-markdown-source" data-encoding="hex">${Buffer.from(source).toString('hex')}</script></div><footer>Next</footer></body></html>`;
  const doc = documentParts(html);
  assert.equal(doc.markdown, source);
  assert.doesNotMatch(doc.body, /Controls|top-nav|<footer>/);
  assert.equal(doc.bodyClass, 'no-ligatures');
  assert.equal(byteToLine(doc.offsets, Buffer.byteLength('# 标题 😀\r\n\r\n')), 2);
  assert.equal(byteToLine(doc.offsets, 0), 0);
  assert.equal(elementByClass('<div class="not-content">Bad</div><div class="content"><div>Good</div></div>', 'content').inner, '<div>Good</div>');
});

test('rebases a reading position through insertions and deletions before the viewport', () => {
  assert.equal(rebaseLine(40.5, [{ startLine: 0, endLine: 0, text: 'A\nB\n' }]), 42.5);
  assert.equal(rebaseLine(40.5, [{ startLine: 5, endLine: 15, text: '' }]), 30.5);
  assert.equal(rebaseLine(10, [{ startLine: 5, endLine: 15, text: 'replacement\n' }]), 6);
  assert.equal(rebaseLine(30, [{ startLine: 0, endLine: 0, text: 'A\n' }, { startLine: 10, endLine: 12, text: '' }]), 29);
  const batches = [[{ startLine: 0, endLine: 0, text: 'A\nB\n' }], [{ startLine: 5, endLine: 15, text: '' }]];
  const latest = batches.reduce((line, changes) => rebaseLine(line, changes), 40.5);
  assert.equal(renderedLine(latest, batches), 40.5, 'editor scroll maps back to the displayed source while rendering');
});
