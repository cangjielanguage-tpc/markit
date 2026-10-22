'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { discover } = require('../src/projects');
const { PreviewSession } = require('../src/session');
const { sourceCoordinates, projectSource, alignText } = require('../media/selection');

// Exercise the real native coordinates, not an assumed constant language offset.
function assertMapped(body, source, marker, language) {
  const at = body.indexOf(marker);
  assert(at >= 0, `missing ${language} content: ${marker}`);
  const opening = [...body.slice(0, at).matchAll(/<[^>]*data-source-start-byte="(\d+)"[^>]*data-source-end-byte="(\d+)"[^>]*>/g)].at(-1);
  assert(opening, `missing source range for ${marker}`);
  const character = sourceCoordinates(source);
  const start = character(Number(opening[1])), end = character(Number(opening[2]));
  const projected = projectSource(source, start, end, { language });
  const { mapping } = alignText(projected, marker);
  assert.equal(mapping[0]?.start, source.indexOf(marker), `${language} start of ${marker}`);
  assert.equal(mapping.at(-1)?.end, source.indexOf(marker) + marker.length, `${language} end of ${marker}`);
}

test('native i18n source maps stay in original coordinates through streaming and language switches', { skip: !process.env.MARKIT_TEST_BINARY, timeout: 90000 }, async t => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'markit-i18n-maps-'));
  let session;
  t.after(async () => { await session?.dispose(); await fs.rm(root, { recursive: true, force: true, maxRetries: 3 }); });
  const source = [
    '# 中文标题很长😀:en{English heading}:', '', '默认正文汉字😀', '',
    ':::en', 'English paragraph 😀 with **bold**.', '',
    '- English list item', '', '> English quote', '>', '> > Nested English quote', '',
    '```text', 'English code', '```', ':::', '',
    ':::zh', '显式中文块😀', '', '> 中文引用', ':::', '',
    ':::fr', 'Français très différent 😀', ':::', '',
    // Force multiple real feed batches, so assertions cover early operations too.
    ...Array(300).fill(':::en\r\nPadding paragraph.\r\n:::\r\n'), ''
  ].join('\r\n');
  await fs.writeFile(path.join(root, 'markit.json'), JSON.stringify({ title: 'Maps', format: 'website', theme: 'arctic', i18n: { default: 'zh', target: 'zh', summary: { zh: ['Docs'], en: ['Docs'], fr: ['Docs'] } }, summary: [{ file: 'markit.md', label: 'Docs', showDrafts: false }] }));
  await fs.writeFile(path.join(root, 'markit.md'), '- [文档:en{Document}::fr{Document}:](doc.md)\n');
  const file = path.join(root, 'doc.md'); await fs.writeFile(file, source);
  const frames = [];
  session = new PreviewSession((await discover(root))[0], { executable: process.env.MARKIT_TEST_BINARY, startupTimeoutMs: 30000, onPreview: (page, frame) => frames.push({ language: page.language, frame }) });
  const markers = { zh: ['默认正文汉字😀', '显式中文块😀', '中文引用'], en: ['English heading', 'English paragraph 😀', 'English list item', 'English quote', 'Nested English quote', 'English code'], fr: ['Français très différent 😀'] };
  await session.start('zh', [], file);
  for (const language of ['zh', 'en', 'fr', 'zh', 'en']) {
    if (session.language !== language) await session.switchLanguage(language);
    for (const marker of markers[language]) assertMapped(session.current.body, source, marker, language);
  }
  for (const language of Object.keys(markers)) {
    const html = frames.filter(item => item.language === language).flatMap(item => item.frame.operations.map(op => op.html || ''));
    for (const marker of markers[language]) {
      const matching = html.filter(fragment => fragment.includes(marker));
      assert(matching.length, `${language}: ${marker} appears before final reconciliation`);
      // Auto anchors are assigned at finalize. Provisional fragments need not
      // expose selection ranges yet; any range they do expose must be correct.
      for (const fragment of matching) {
        if (fragment.includes('data-source-start-byte=')) assertMapped(fragment, source, marker, language);
      }
    }
  }
});
