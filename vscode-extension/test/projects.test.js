'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { discover, owners, saveLanguage, savedLanguage, markdownLinks, pagePath, STATE_FILE } = require('../src/projects');

async function fixture(t) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'markit-project-test-'));
  t.after(() => fs.rm(root, { recursive: true, force: true, maxRetries: 3 }));
  const put = async (name, content) => { const file = path.join(root, name); await fs.mkdir(path.dirname(file), { recursive: true }); await fs.writeFile(file, content); return file; };
  for (const dir of ['guide', 'reference']) {
    await put(`${dir}/markit.json`, JSON.stringify({ title: dir, format: 'website', i18n: { default: 'zh', target: 'zh', summary: { zh: ['Home', 'Docs'], en: ['Home', 'Docs'] } }, summary: [{ home: true }, { file: 'markit.md', showDrafts: false }] }));
    await put(`${dir}/markit.md`, `# Guide\n- [Chapter](../chapters/${dir}.md)\n<!-- homepage -->\n# Welcome\n`);
    await put(`chapters/${dir}.md`, '# Chapter');
  }
  return { root, put };
}

test('automatically identifies Summary membership across multiple projects and outside input directories', async t => {
  const { root, put } = await fixture(t);
  await put('guide/markit.en.json', JSON.stringify({ format: 'website', i18n: { target: 'en' }, summary: [{ file: 'markit.md', showDrafts: false }] }));
  await put('pdf/markit.json', JSON.stringify({ format: 'pdf', summary: [{ file: '../guide/markit.md' }] }));
  const projects = await discover(root);
  assert.equal(projects.length, 2, 'language variants form one project, PDF configs are excluded');
  assert.deepEqual((await owners(projects, path.join(root, 'chapters/guide.md'))).map(item => item.title), ['guide']);
  assert.deepEqual((await owners(projects, path.join(root, 'chapters/reference.md'))).map(item => item.title), ['reference']);
  assert.equal((await owners(projects, path.join(root, 'unlisted.md'))).length, 0);
  assert.equal((await owners(projects, path.join(root, 'guide/markit.md')))[0].title, 'guide');
  const project = projects.find(item => item.title === 'guide');
  assert.equal(pagePath(project, path.join(root, 'chapters/guide.md'), 'en'), 'en/chapters/guide.html');
});

test('separate language choices survive project rediscovery without overwriting other projects', async t => {
  const { root } = await fixture(t);
  const projects = await discover(root);
  const guide = projects.find(item => item.title === 'guide');
  const reference = projects.find(item => item.title === 'reference');
  await saveLanguage(guide, 'en'); await saveLanguage(reference, 'zh');
  for (const project of await discover(root)) assert.equal(await savedLanguage(project), project.title === 'guide' ? 'en' : 'zh');
  await saveLanguage(guide, 'ja');
  assert.equal(await savedLanguage(reference), 'zh');
  assert.equal(JSON.parse(await fs.readFile(path.join(root, STATE_FILE))).projects['guide/markit.json'].language, 'ja');
});

test('shared files remain ambiguous and unsaved Summary buffers change membership', async t => {
  const { root } = await fixture(t);
  const projects = await discover(root);
  const file = path.join(root, 'chapters/shared.md');
  const read = async source => source.endsWith('markit.md') ? '- [Shared](../chapters/shared.md)' : fs.readFile(source, 'utf8');
  assert.equal((await owners(projects, file, read)).length, 2);
});

test('Summary links decode filenames and ignore external links and non-Markdown resources', () => {
  assert.deepEqual(markdownLinks('- [A](chapter%20one.md#section)\n- [B](<folder/two words.markdown>)\n- [C](https://example.com/a.md)\n- [D](image.png)\n- [E](part(1).md)'), ['chapter one.md', 'folder/two words.markdown', 'part(1).md']);
});

test('invalid persisted language JSON is reported rather than overwritten', async t => {
  const { root, put } = await fixture(t);
  const project = (await discover(root))[0];
  await put(STATE_FILE, '{broken');
  await assert.rejects(saveLanguage(project, 'en'), SyntaxError);
  assert.equal(await fs.readFile(path.join(root, STATE_FILE), 'utf8'), '{broken');
});
