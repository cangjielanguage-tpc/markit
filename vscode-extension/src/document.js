'use strict';
const fs = require('node:fs/promises');
const path = require('node:path');
const { inside } = require('./projects');

function elementByClass(html, name) {
  const opening = [...html.matchAll(/<div\b[^>]*class=["']([^"']*)["'][^>]*>/gi)].find(match => match[1].split(/\s+/).includes(name));
  if (!opening) return undefined;
  const tags = /<!--[\s\S]*?-->|<script\b[\s\S]*?<\/script\s*>|<\/?div\b[^>]*>/gi;
  tags.lastIndex = opening.index + opening[0].length;
  let depth = 1, token;
  while ((token = tags.exec(html))) {
    if (/^<script|^<!--/i.test(token[0])) continue;
    depth += /^<\//.test(token[0]) ? -1 : 1;
    if (!depth) return { start: opening.index, end: tags.lastIndex, inner: html.slice(opening.index + opening[0].length, token.index) };
  }
  throw new Error(`Unclosed Markit ${name} container.`);
}

function documentParts(html) {
  const content = elementByClass(html, 'content');
  if (!content) throw new Error('The selected theme does not expose a Markit content container.');
  let body = content.inner;
  const extra = elementByClass(body, 'article-extra');
  if (extra) body = body.slice(0, extra.start) + body.slice(extra.end);
  const source = /<script\b[^>]*id="markit-page-markdown-source"[^>]*>([a-f\d]*)<\/script>/i.exec(body);
  if (!source) throw new Error('Markit did not include its Markdown source map. Update the executable and assets.');
  const markdown = Buffer.from(source[1], 'hex').toString('utf8');
  const offsets = [0];
  let byte = 0;
  for (const line of markdown.split('\n').slice(0, -1)) { byte += Buffer.byteLength(line + '\n'); offsets.push(byte); }
  return { body, markdown, offsets, head: /<head\b[^>]*>([\s\S]*?)<\/head>/i.exec(html)?.[1] || '', bodyClass: /<body\b[^>]*class="([^"]*)"/i.exec(html)?.[1] || '' };
}

async function rewriteResources(fragment, page, toUri) {
  const pattern = /<(img|script|link|source|video|audio)\b[^>]*\b(src|href|poster)=(['"])(.*?)\3[^>]*>/gi;
  let result = '', last = 0;
  for (const match of fragment.matchAll(pattern)) {
    result += fragment.slice(last, match.index); last = match.index + match[0].length;
    let ref = match[4];
    if (!ref || /^(?:[a-z][a-z\d+.-]*:|\/\/|#)/i.test(ref)) { result += match[0]; continue; }
    const split = ref.search(/[?#]/);
    const suffix = split < 0 ? '' : ref.slice(split);
    try { ref = decodeURIComponent(split < 0 ? ref : ref.slice(0, split)); } catch { result += match[0]; continue; }
    const generated = path.resolve(path.dirname(page.outputFile), ref);
    const relative = path.relative(page.output, generated).split(path.sep).join('/');
    let candidates = [];
    if (relative.startsWith('assets/')) candidates.push(path.join(page.assets, relative.slice(7)));
    if (relative.startsWith('public/')) {
      const asset = relative.slice(7);
      candidates.push(path.resolve(path.dirname(page.file), asset), path.resolve(page.input, asset), path.resolve(page.root, asset));
    }
    candidates.push(generated, path.resolve(path.dirname(page.file), ref));
    let replacement;
    for (const candidate of candidates) {
      if (!inside(page.temp, candidate) && !inside(page.root, candidate)) continue;
      try { if ((await fs.stat(candidate)).isFile()) { replacement = await toUri(candidate); break; } } catch { /* Try the original project resource. */ }
    }
    const value = replacement ? String(replacement).replace(/&/g, '&amp;').replace(/"/g, '&quot;') + suffix : match[4];
    result += match[0].replace(match[3] + match[4] + match[3], match[3] + value + match[3]);
  }
  return result + fragment.slice(last);
}

module.exports = { documentParts, rewriteResources, elementByClass };
