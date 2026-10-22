'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { sourceCoordinates, projectSource, alignText } = require('../media/selection');

test('maps native UTF-8 source spans to VS Code UTF-16 offsets', () => {
  const source = '中😀\r\nText';
  const character = sourceCoordinates(source);
  assert.equal(character(Buffer.byteLength('中')), 1);
  assert.equal(character(Buffer.byteLength('中😀')), 3);
  assert.equal(character(Buffer.byteLength('中😀\r\n')), 5);
});

test('aligns selections across Markdown formatting, escaped pipes, entities, and emoji', () => {
  const source = 'Hello **中文😀** and a\\|b &amp; c';
  const projection = projectSource(source, 0, source.length, { decode: entity => entity === '&amp;' ? '&' : entity });
  const first = alignText(projection, 'Hello ');
  const second = alignText(projection, '中文😀', first.cursor);
  const third = alignText(projection, ' and a|b & c', second.cursor);
  assert.equal(second.mapping[0].start, source.indexOf('中文'));
  assert.equal(second.mapping.at(-1).end, source.indexOf('😀') + 2);
  assert.equal(source.slice(third.mapping[6].start, third.mapping[6].end), '\\|');
  assert.equal(source.slice(third.mapping[9].start, third.mapping[9].end), '&amp;');
});

test('prefers the current language branch and keeps code entities literal', () => {
  const source = 'Foo:en{Foo}:';
  const mapped = alignText(projectSource(source, 0, source.length, { language: 'en' }), 'Foo');
  assert.equal(mapped.mapping[0].start, source.lastIndexOf('Foo'));
  const code = '&amp;';
  assert.equal(projectSource(code, 0, code.length, { code: true, decode: () => '&' }).text, code);
});
