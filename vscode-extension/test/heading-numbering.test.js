'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { execFile } = require('node:child_process');
const { promisify } = require('node:util');
const { PreviewSession } = require('../src/session');
const { discover } = require('../src/projects');
const { documentParts } = require('../src/document');
const execute = promisify(execFile);

async function fixture(t) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'markit-heading-test-'));
  t.after(() => fs.rm(root, { recursive: true, force: true, maxRetries: 3 }));
  const put = async (name, text) => { const file = path.join(root, name); await fs.mkdir(path.dirname(file), { recursive: true }); await fs.writeFile(file, text); return file; };
  const config = { title: 'Numbering', format: 'website', theme: 'arctic', heading: { number: { enabled: true, resetFor: 'never', startFrom: [4, 1, 1, 1, 1, 1] } }, i18n: { default: 'zh', target: 'zh', summary: { zh: ['正文', '附录'], en: ['Docs', 'Appendix'] } }, summary: [{ file: 'markit.md', showDrafts: false }, { file: 'appendix.md', showDrafts: false }] };
  const navigation = '- [第一章:en{First}:](chapters/z-first.md)\n- [第二章:en{Second}:](chapters/a-second.md)\n<!-- homepage -->\n# 首页\n';
  await put('markit.json', JSON.stringify(config));
  await put('markit.md', navigation);
  await put('appendix.md', '- [附录:en{Appendix}:](appendix/third.md)\n');
  await put('chapters/z-first.md', '# 第一章:en{First}:\n\n## 第一节:en{First section}:\n');
  const current = await put('chapters/a-second.md', '# 第二章:en{Second}:\n\n## 第二节:en{Second section}:\n');
  const third = await put('appendix/third.md', '# 附录:en{Appendix}:\n');
  const unlisted = await put('unlisted.md', '# 草稿:en{Draft}:\n');
  return { root, put, config, navigation, current, third, unlisted, project: (await discover(root))[0] };
}
function headings(body) { return [...body.matchAll(/<h[1-6]\b[^>]*>[\s\S]*?<\/h[1-6]>/g)].map(match => match[0].replace(/ data-source-(?:start|end)-byte="\d+"/g, '')); }
function numbers(body) { return [...body.matchAll(/data-number="([^"]+)"/g)].map(match => match[1].trim()); }

test('snapshot preserves summary order and appends an isolated fallback after every project menu', async t => {
  const f = await fixture(t), session = new PreviewSession(f.project, {});
  session.temp = path.join(f.root, '.preview'); session.snapshot = path.join(session.temp, 'workspace');
  session.runtimeConfig = path.join(session.snapshot, 'runtime.json'); session.file = f.current; session.language = 'en'; session.buffers = new Map();
  await session.configure();
  assert.equal(session.config.summary.length, 3);
  assert.equal(await fs.readFile(path.join(session.snapshot, session.config.summary[0].file), 'utf8'), f.navigation);
  assert.equal(await fs.readFile(path.join(session.snapshot, session.config.summary[1].file), 'utf8'), '- [附录:en{Appendix}:](appendix/third.md)\n');
  assert.match(await fs.readFile(path.join(session.snapshot, session.config.summary[2].file), 'utf8'), /Preview.*chapters\/a-second\.md/);
});

test('a project without navigation still receives exactly one fallback menu and matching locale labels', async t => {
  const f = await fixture(t);
  await f.put('markit.json', JSON.stringify({ ...f.config, summary: [], i18n: { ...f.config.i18n, summary: { zh: [], en: [] } } }));
  const session = new PreviewSession(f.project, {});
  session.temp = path.join(f.root, '.preview'); session.snapshot = path.join(session.temp, 'workspace');
  session.runtimeConfig = path.join(session.snapshot, 'runtime.json'); session.file = f.unlisted; session.language = 'en'; session.buffers = new Map();
  await session.configure();
  assert.equal(session.config.summary.length, 1);
  assert.deepEqual(session.config.i18n.summary, { zh: ['Preview'], en: ['Preview'] });
  assert.match(await fs.readFile(path.join(session.snapshot, session.config.summary[0].file), 'utf8'), /unlisted\.md/);
});

test('native page preview numbering matches full website summary order in all reset modes and languages', { skip: !process.env.MARKIT_TEST_BINARY, timeout: 90000 }, async t => {
  const f = await fixture(t); let session;
  t.after(() => session?.dispose());
  for (const resetFor of ['never', 'directory', 'always']) {
    const config = { ...f.config, heading: { number: { ...f.config.heading.number, resetFor } } };
    await f.put('markit.json', JSON.stringify(config));
    const frames = [];
    session = new PreviewSession(f.project, { executable: process.env.MARKIT_TEST_BINARY, startupTimeoutMs: 30000, onPreview: (page, frame) => frames.push({ file: page.file, language: page.language, frame }) });
    await session.start('zh', [], f.current);
    for (const language of ['zh', 'en']) {
      if (session.language !== language) await session.switchLanguage(language);
      const nativeConfig = await f.put(`full-${language}.json`, JSON.stringify({ ...config, i18n: { ...config.i18n, target: language } }));
      const output = path.join(f.root, `full-${resetFor}-${language}`);
      await execute(process.env.MARKIT_TEST_BINARY, ['render', '-i', f.root, '-o', output, '-c', nativeConfig, '-j', '1'], { timeout: 30000, maxBuffer: 4 * 1024 * 1024 });
      const expected = documentParts(await fs.readFile(path.join(output, language, 'chapters/a-second.html'), 'utf8'));
      assert.deepEqual(headings(session.current.body), headings(expected.body), `${resetFor}/${language}: final preview equals full site`);
      const expectedFirst = resetFor === 'always' ? '4' : '5';
      assert.equal(numbers(session.current.body)[0], expectedFirst, `${resetFor}/${language}: respects configured start/reset`);
      const streamed = frames.filter(item => item.file === f.current && item.language === language).flatMap(item => item.frame.operations.map(op => op.html || '')).flatMap(headings);
      // Locale-specific slugs are reconciled at finalize; counters must already be correct.
      assert.deepEqual(numbers(streamed.join('')), numbers(expected.body), `${resetFor}/${language}: streamed global numbers`);
    }
    if (resetFor === 'never') {
      await session.selectDocument(f.third);
      assert.equal(numbers(session.current.body)[0], '6', 'switching to a later menu preserves global numbering');
      await session.selectDocument(f.unlisted);
      assert.equal(numbers(session.current.body)[0], '7', 'unlisted page remains previewable after existing project chapters');
    }
    await session.dispose(); session = undefined;
  }
  await f.put('markit.json', JSON.stringify({ ...f.config, summary: [], i18n: { ...f.config.i18n, summary: { zh: [], en: [] } } }));
  session = new PreviewSession(f.project, { executable: process.env.MARKIT_TEST_BINARY, startupTimeoutMs: 30000 });
  await session.start('en', [], f.unlisted);
  assert.equal(numbers(session.current.body)[0], '4', 'a project without navigation still previews a standalone file');
  assert.match(session.current.body, /Draft/);
});
