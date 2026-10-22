'use strict';

const fs = require('node:fs/promises');
const path = require('node:path');
const EXCLUDED = new Set(['.git', '.hg', '.svn', 'node_modules', 'target', 'dist', 'tmp', 'temp', '.cache', '.codex', '.agents']);
const STATE_FILE = path.join('.config', '.markit-current-lang.json');
const slash = value => value.split(path.sep).join('/');
function inside(root, file) {
  const relative = path.relative(root, file);
  return relative === '' || (!relative.startsWith(`..${path.sep}`) && relative !== '..' && !path.isAbsolute(relative));
}
const readText = file => fs.readFile(file, 'utf8');
function json(text) { return JSON.parse(text.replace(/^\uFEFF/, '')); }

async function walk(root, visit) {
  for (const item of await fs.readdir(root, { withFileTypes: true })) {
    if (EXCLUDED.has(item.name) || item.isSymbolicLink()) continue;
    const file = path.join(root, item.name);
    if (item.isDirectory()) await walk(file, visit);
    else if (item.isFile()) await visit(file);
  }
}

async function discover(root, read = readText) {
  const groups = new Map();
  await walk(root, async file => {
    if (!/^markit(?:\.[\w-]+)?\.json$/i.test(path.basename(file))) return;
    let config;
    try { config = json(await read(file)); } catch { return; }
    if (!Array.isArray(config.summary) || (config.format && config.format !== 'website')) return;
    const directory = path.dirname(file);
    if (!groups.has(directory)) groups.set(directory, []);
    groups.get(directory).push({ file, config });
  });
  return [...groups.entries()].map(([directory, variants]) => {
    variants.sort((a, b) => (path.basename(a.file) === 'markit.json' ? -1 : 1) - (path.basename(b.file) === 'markit.json' ? -1 : 1) || a.file.localeCompare(b.file));
    const base = variants[0];
    const languages = new Set();
    for (const { config } of variants) {
      languages.add(config.i18n?.default || 'zh');
      languages.add(config.i18n?.target || config.i18n?.default || 'zh');
      Object.keys(config.i18n?.summary || {}).forEach(lang => languages.add(lang));
    }
    return { root, directory, file: base.file, config: base.config, variants, languages: [...languages], id: slash(path.relative(root, base.file)), title: base.config.title || path.basename(directory) };
  });
}

function markdownLinks(text) {
  const links = [];
  // Summary files use normal Markdown links; preserve escaped characters and one nested pair.
  const pattern = /\[[^\]\n]*\]\(\s*(?:<([^>]+)>|((?:\\.|[^()\s]|\([^)]*\))+))(?:\s+["'][^\n]*?["'])?\s*\)/g;
  for (const match of text.matchAll(pattern)) {
    let target = (match[1] || match[2]).replace(/\\([()\s])/g, '$1');
    if (/^[a-z][a-z\d+.-]*:|^\/\//i.test(target)) continue;
    try { target = decodeURIComponent(target.split(/[?#]/)[0]); } catch { continue; }
    if (/\.(md|markdown)$/i.test(target)) links.push(target);
  }
  return links;
}

async function membership(project, file, read = readText) {
  if (!inside(project.root, file)) return 0;
  let score = 0;
  for (const { config, file: configPath } of project.variants) {
    const input = path.resolve(path.dirname(configPath), config.i18n?.routePrefix || '.');
    for (const entry of config.summary) {
      if (!entry.file) continue;
      const summary = path.resolve(input, entry.file);
      if (!inside(project.root, summary)) continue;
      if (path.relative(summary, file) === '') return 100;
      let text;
      try { text = await read(summary); } catch { continue; }
      for (const target of markdownLinks(text.split('<!-- homepage -->')[0])) {
        // Markit resolves Summary links against the input root, not the Summary's directory.
        if (path.relative(path.resolve(input, target), file) === '') return 90;
      }
      if (entry.showDrafts !== false && inside(input, file)) score = Math.max(score, 10 + input.split(path.sep).length);
    }
  }
  return score;
}

async function owners(projects, file, read = readText) {
  const scored = await Promise.all(projects.map(async project => ({ project, score: await membership(project, file, read) })));
  const best = Math.max(0, ...scored.map(item => item.score));
  return scored.filter(item => best > 0 && item.score === best).map(item => item.project);
}

async function savedLanguage(project) {
  try { return json(await readText(path.join(project.root, STATE_FILE))).projects?.[project.id]?.language; }
  catch (error) { if (error.code === 'ENOENT') return undefined; throw error; }
}

async function saveLanguage(project, language) {
  if (!/^[a-z][a-z\d-]*$/i.test(language)) throw new Error('Invalid language code.');
  const file = path.join(project.root, STATE_FILE);
  let state = { version: 1, projects: {} };
  try { state = json(await readText(file)); } catch (error) { if (error.code !== 'ENOENT') throw error; }
  if (!state || typeof state !== 'object' || (state.projects && typeof state.projects !== 'object')) throw new Error(`Invalid language state: ${file}`);
  state.projects = { ...state.projects, [project.id]: { language } };
  await fs.mkdir(path.dirname(file), { recursive: true });
  await fs.writeFile(file, `${JSON.stringify(state, null, 2)}\n`, 'utf8');
}

function configFor(project, language) {
  return project.variants.find(item => item.config.i18n?.target === language) || project.variants.find(item => item.file === project.file);
}

function pagePath(project, file, language) {
  const selected = configFor(project, language);
  const input = path.resolve(path.dirname(selected.file), selected.config.i18n?.routePrefix || '.');
  let relative = slash(path.relative(input, file));
  while (relative.startsWith('../')) relative = relative.slice(3);
  return `${language}/${relative.replace(/\.(md|markdown)$/i, '.html')}`;
}

module.exports = { EXCLUDED, STATE_FILE, inside, slash, json, walk, discover, markdownLinks, membership, owners, savedLanguage, saveLanguage, configFor, pagePath };
