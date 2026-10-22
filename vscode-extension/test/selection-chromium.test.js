'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const http = require('node:http');

// Opt-in real DOM/input test. The VS Code host is a protocol stub: host unit
// tests separately verify that preview-origin editor echoes set clearNative=false.
// Run with MARKIT_TEST_CHROMIUM=/usr/bin/chromium and Playwright available to Node.
test('Chromium native mouse drag survives editor echoes, supports copy and locale refresh', { skip: !process.env.MARKIT_TEST_CHROMIUM, timeout: 30000 }, async t => {
  const { chromium } = require('playwright');
  const script = await fs.readFile(process.env.MARKIT_TEST_SELECTION_SOURCE || path.join(__dirname, '../media/selection.js'), 'utf8');
  const source = '默认中文选区。\n\n:::en\nEnglish selectable passage for native mouse drag.\n:::\n';
  const paragraph = (text, id) => {
    const start = Buffer.byteLength(source.slice(0, source.indexOf(text)));
    return `<p id="${id}" data-source-start-byte="${start}" data-source-end-byte="${start + Buffer.byteLength(text)}">${text}</p><script id="markit-page-markdown-source" type="application/octet-stream">${Buffer.from(source).toString('hex')}</script>`;
  };
  const en = paragraph('English selectable passage for native mouse drag.', 'text');
  const zh = paragraph('默认中文选区。', 'text');
  const legacy = Boolean(process.env.MARKIT_TEST_LEGACY_SELECTION_ECHO);
  const server = http.createServer((request, response) => {
    response.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
    response.end(`<!doctype html><meta charset="utf-8"><style>body{margin:30px;font:20px monospace}p{white-space:nowrap}main{min-height:500px}</style><main>${en}</main><script>${script}</script><script>
      const article = document.querySelector('main');
      let data = { file: 'doc.md', version: 1, language: 'en' };
      window.messages = []; window.copyEvents = [];
      window.bridge = MarkitSelection.create({ article, getData: () => data, postMessage(message) {
        messages.push(message);
        if (message.type === 'copy-selection') { void navigator.clipboard.writeText(message.text); return; }
        setTimeout(() => bridge.show({ file: message.file, version: message.version,
          ranges: [{ anchor: message.anchor, active: message.active }], clearNative: ${legacy} }), 0);
      } });
      document.addEventListener('copy', () => copyEvents.push(getSelection().toString()));
      window.switchLanguage = () => { bridge.suspend(); article.innerHTML = ${JSON.stringify(zh).replace(/</g, '\\u003c')}; data = { ...data, language: 'zh' }; bridge.refresh(); };
      window.sourceOffset = ${JSON.stringify(source.indexOf('English selectable'))};
    </script>`);
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const browser = await chromium.launch({ executablePath: process.env.MARKIT_TEST_CHROMIUM, headless: true, args: ['--no-sandbox'] });
  t.after(() => browser.close());
  const context = await browser.newContext({ permissions: ['clipboard-read', 'clipboard-write'], viewport: { width: 1100, height: 700 } });
  const page = await context.newPage();
  await page.goto(`http://127.0.0.1:${server.address().port}`);
  const position = async offset => page.evaluate(offset => {
    const node = document.querySelector('#text').firstChild;
    const range = document.createRange(); range.setStart(node, offset); range.setEnd(node, offset);
    const rect = range.getBoundingClientRect(); return { x: rect.x, y: rect.y + rect.height / 2 };
  }, offset);
  const start = await position(0), middle = await position(8), end = await position(26);
  await page.mouse.move(start.x, start.y); await page.mouse.down();
  await page.mouse.move(middle.x, middle.y, { steps: 8 }); await page.waitForTimeout(150);
  assert.equal(await page.evaluate(() => getSelection().toString()), 'English ', 'native range remains during a paused drag');
  assert.equal(await page.evaluate(() => messages.length), 0, 'do not round-trip partial pointer selection to the editor');
  await page.mouse.move(end.x, end.y, { steps: 12 }); await page.waitForTimeout(150);
  assert.equal(await page.evaluate(() => getSelection().toString()), 'English selectable passage', 'drag extends original range');
  await page.mouse.up(); await page.waitForTimeout(150);
  assert.equal(await page.evaluate(() => getSelection().toString()), 'English selectable passage', 'host echo must not clear completed range');
  const message = await page.evaluate(() => messages.at(-1));
  assert.equal(message.anchor, source.indexOf('English selectable'));
  assert.equal(message.active, source.indexOf('English selectable') + 26);
  await page.keyboard.press('Control+c');
  assert.equal(await page.evaluate(() => navigator.clipboard.readText()), 'English selectable passage', 'native clipboard receives selected text');
  assert.equal(await page.evaluate(() => messages.at(-1).type), 'copy-selection', 'explicit shortcut uses the host clipboard bridge');
  await page.evaluate(() => document.execCommand('copy'));
  assert.equal(await page.evaluate(() => copyEvents.at(-1)), 'English selectable passage', 'context-menu/Copy command still uses the native copy event');
  await page.evaluate(() => { dispatchEvent(new Event('resize')); dispatchEvent(new Event('scroll')); });
  assert.equal(await page.evaluate(() => getSelection().toString()), 'English selectable passage', 'layout refresh must not replay clearNative');
  await page.evaluate(() => {
    bridge.show({ file: 'doc.md', version: 1, ranges: [{ anchor: sourceOffset, active: sourceOffset }], clearNative: true });
    if (getSelection().rangeCount) throw new Error('genuine editor action should clear old browser range');
    const node = document.querySelector('#text').firstChild, range = document.createRange();
    range.setStart(node, 0); range.setEnd(node, 8); getSelection().addRange(range);
    dispatchEvent(new Event('resize'));
  });
  assert.equal(await page.evaluate(() => getSelection().toString()), 'English ', 'clearNative is consumed once, not replayed on layout');
  await page.waitForTimeout(150);
  const click = await position(3); await page.mouse.click(click.x, click.y); await page.waitForTimeout(150);
  const collapsed = await page.evaluate(() => messages.at(-1));
  assert.equal(collapsed.anchor, source.indexOf('English selectable') + 3); assert.equal(collapsed.active, collapsed.anchor);
  await page.evaluate(() => switchLanguage()); await page.waitForTimeout(150);
  const zhStart = await position(0), zhEnd = await position(4);
  await page.mouse.move(zhStart.x, zhStart.y); await page.mouse.down(); await page.mouse.move(zhEnd.x, zhEnd.y, { steps: 12 }); await page.mouse.up(); await page.waitForTimeout(150);
  assert.equal(await page.evaluate(() => getSelection().toString()), '默认中文');
  const translated = await page.evaluate(() => messages.at(-1)); assert.equal(translated.anchor, 0); assert.equal(translated.active, 4);
  assert.equal(await page.evaluate(() => document.hasFocus()), true, 'preview retains browser focus');
});
