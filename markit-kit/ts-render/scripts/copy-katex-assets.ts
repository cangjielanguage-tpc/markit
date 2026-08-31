/**
 * Copy KaTeX CSS and fonts used by mathtex HTML output.
 * This does not build any Markdown/runtime rendering script.
 */

import { existsSync, mkdirSync, cpSync, readdirSync, readFileSync, writeFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const assetsJsDir = join(__dirname, '../../assets/js');
const assetsCssDir = join(__dirname, '../../assets/css');
const assetsFontsDir = join(assetsCssDir, 'fonts');

// 确保输出目录存在
for (const d of [assetsJsDir, assetsCssDir, assetsFontsDir]) {
  if (!existsSync(d)) {
    mkdirSync(d, { recursive: true });
  }
}

console.log('Preparing KaTeX assets...');

async function buildAll() {
  // 1. Copy KaTeX CSS and fonts used by mathtex HTML output.
  console.log('   Copying KaTeX CSS and fonts...');
  try {
    const katexCssSrc = join(__dirname, '../node_modules/katex/dist/katex.min.css');
    const katexCssDest = join(assetsCssDir, 'katex.min.css');
    if (!existsSync(katexCssSrc)) {
      console.error('   ❌ katex.min.css not found at:', katexCssSrc);
      process.exit(1);
    }
    let css = readFileSync(katexCssSrc, 'utf-8');
    // Within @font-face src lists, drop non-woff2 url() entries.
    // Pattern: url(fonts/X.ttf) format('truetype') or url(fonts/X.woff) format('woff')
    css = css.replace(/,\s*url\(fonts\/[^)]+\.(?:ttf|woff)\)\s*format\('(?:truetype|woff)'\)/g, '');
    writeFileSync(katexCssDest, css, 'utf-8');
    console.log('   ✅ katex.min.css copied (woff2-only)');

    // Copy only woff2 fonts
    const fontsSrcDir = join(__dirname, '../node_modules/katex/dist/fonts');
    const woff2Files = readdirSync(fontsSrcDir).filter((f) => f.endsWith('.woff2'));
    for (const f of woff2Files) {
      cpSync(join(fontsSrcDir, f), join(assetsFontsDir, f));
    }
    console.log(`   ✅ ${woff2Files.length} KaTeX woff2 fonts copied`);
  } catch (error) {
    console.error('   ❌ Failed to copy KaTeX CSS/fonts');
    console.error(error);
    process.exit(1);
  }

  console.log('KaTeX assets prepared successfully');
}

buildAll().catch(error => {
  console.error('❌ Build failed:', error);
  process.exit(1);
});
