'use strict';

const fs = require('node:fs/promises');
const path = require('node:path');
const os = require('node:os');
const { randomUUID } = require('node:crypto');
const { spawn } = require('node:child_process');
const { EventEmitter } = require('node:events');
const { createInterface } = require('node:readline');
const { inside, configFor, pagePath, slash, json, markdownLinks, walk } = require('./projects');
const { documentParts } = require('./document');

class PreviewSession extends EventEmitter {
  constructor(project, options) {
    super();
    this.project = project;
    this.options = options;
    this.token = randomUUID();
    this.closed = false;
    this.pending = Promise.resolve();
    this.renderId = 0;
  }

  start(language, buffers = [], file) {
    this.pending = this.pending.catch(() => {}).then(() => this.initialize(language, buffers, file));
    return this.pending;
  }

  async initialize(language, buffers = [], file) {
    if (!file) throw new Error('A current Markdown document is required.');
    this.buffers = new Map(buffers.map(buffer => [buffer.file, buffer.text]));
    this.file = file;
    this.temp = await fs.mkdtemp(path.join(os.tmpdir(), 'markit-preview-'));
    this.snapshot = path.join(this.temp, 'workspace');
    this.output = path.join(this.temp, 'output');
    this.assets = path.join(this.temp, 'assets');
    this.runtimeConfig = path.join(this.mirror(path.dirname(this.project.file)), `.markit-preview-${this.token}.json`);
    await fs.mkdir(path.dirname(this.runtimeConfig), { recursive: true });
    await this.write(file, await this.source(file));
    await this.switchLanguageNow(language);
  }

  source(file) { return this.buffers.has(file) ? this.buffers.get(file) : fs.readFile(file, 'utf8'); }
  setBuffer(file, text) { if (text === undefined) this.buffers.delete(file); else this.buffers.set(file, text); }

  mirror(file) {
    if (!inside(this.project.root, file)) throw new Error('Preview source must be inside its workspace folder.');
    return path.join(this.snapshot, path.relative(this.project.root, file));
  }

  async write(file, text) {
    if (this.closed || !inside(this.project.root, file)) return;
    const target = this.mirror(file);
    await fs.mkdir(path.dirname(target), { recursive: true });
    if (text === undefined) {
      try { text = await fs.readFile(file); }
      catch (error) { if (error.code === 'ENOENT') { await fs.rm(target, { force: true }); return; } throw error; }
    }
    await this.atomicWrite(target, text);
  }

  async atomicWrite(target, content) {
    const temporary = `${target}.${randomUUID()}.tmp`;
    try {
      await fs.writeFile(temporary, content, typeof content === 'string' ? 'utf8' : undefined);
      await fs.rename(temporary, target);
    } finally { await fs.rm(temporary, { force: true }); }
  }

  async configure() {
    const selected = configFor(this.project, this.language);
    const config = json(await this.source(selected.file));
    this.input = path.resolve(path.dirname(selected.file), config.i18n?.routePrefix || '.');
    const mirrorInput = this.mirror(this.input);
    await fs.mkdir(mirrorInput, { recursive: true });
    const files = new Set([this.file]);
    const entries = [], navigation = [];
    for (const [index, entry] of config.summary.entries()) {
      if (!entry.file) { entries.push(entry); continue; }
      const original = path.resolve(this.input, entry.file);
      const source = await this.source(original);
      const name = `.markit-project-${this.token}-${index}.md`;
      navigation.push({ name, source }); entries.push({ ...entry, file: name });
      for (const link of markdownLinks(source.split('<!-- homepage -->')[0])) {
        const file = path.resolve(this.input, link);
        if (inside(this.project.root, file)) files.add(file);
      }
      if (entry.showDrafts !== false) await walk(this.input, async file => {
        if (/\.(md|markdown)$/i.test(file)) files.add(file);
      });
    }
    // Preserve the project's chapter traversal order: the heading scanner carries
    // numbering across that order. Prepending the selected page made every preview
    // chapter first. A last, separate fallback menu admits unlisted/hidden pages
    // without taking ownership away from any existing project summary.
    const target = encodeURI(slash(path.relative(this.input, this.file))).replace(/\(/g, '%28').replace(/\)/g, '%29');
    const fallback = `.markit-preview-page-${this.token}.md`;
    navigation.push({ name: fallback, source: `- [Preview:${this.language}{Preview}:](${target})\n` });
    entries.push({ file: fallback, label: 'Preview', showDrafts: false });
    for (const entry of navigation) await this.atomicWrite(path.join(mirrorInput, entry.name), entry.source);
    for (const file of files) await this.write(file, await this.source(file));
    this.contextFiles = files;
    this.config = { ...config, format: 'website', toc: false, summary: entries,
      i18n: { ...config.i18n, target: this.language,
        summary: Object.fromEntries(Object.entries(config.i18n?.summary || {}).map(([language, labels]) => [language, [...labels, 'Preview']])) },
      website: { ...config.website,
        chapter: { ...config.website?.chapter, navigation: false },
        statistic: { ...config.website?.statistic, totalTexts: false, spentTime: false } }
    };
    this.fullBuild = true;
    for (const name of ['block', 'list', 'codeBlock', 'table', 'math']) this.config[name] = { ...config[name], autoAnchor: true };
    await this.atomicWrite(this.runtimeConfig, JSON.stringify(this.config));
  }

  pageMetadata() {
    return { file: this.file, language: this.language, root: this.project.root, input: this.input,
      outputFile: path.join(this.output, pagePath(this.project, this.file, this.language)),
      output: this.output, temp: this.temp, assets: this.assets };
  }

  async readPage() {
    const outputFile = path.join(this.output, pagePath(this.project, this.file, this.language));
    const parts = documentParts(await fs.readFile(outputFile, 'utf8'));
    return { ...parts, file: this.file, language: this.language, root: this.project.root,
      input: this.input, outputFile, output: this.output, temp: this.temp, assets: this.assets };
  }

  async publish(page) {
    const valid = () => !this.closed && (page.renderId === undefined || page.renderId === this.renderId)
      && page.file === this.file && page.language === this.language;
    if (!valid() || page.markdown !== await this.source(page.file) || !valid()) return;
    const assetKey = JSON.stringify([this.config.theme, this.config.website?.assets]);
    if (assetKey !== this.assetKey) {
      await fs.cp(path.join(this.output, 'assets'), this.assets, { recursive: true });
      if (!valid()) return;
      this.assetKey = assetKey;
    }
    if (!valid() || page.markdown !== await this.source(page.file) || !valid()) return;
    this.current = page;
    this.emit('updated', page);
  }

  cancelRender() {
    this.renderId++;
    this.renderAbort?.abort();
    this.child?.kill();
  }

  async render({ background = false } = {}) {
    if (this.closed) return;
    // Snapshot the presentation mode for this render, never infer it from later edits.
    background = Boolean(background && !this.foregroundPending && this.current?.file === this.file && this.current.language === this.language);
    const renderId = ++this.renderId;
    this.renderAbort?.abort();
    const abort = new AbortController();
    this.renderAbort = abort;
    const valid = () => !this.closed && this.renderId === renderId;
    await this.stopChild();
    if (!valid()) return;
    if (!background) this.foregroundPending = true;
    this.emit('rendering', { file: this.file, language: this.language, renderId, background });
    const expected = await fs.readFile(this.mirror(this.file), 'utf8');
    if (!valid()) return;
    const args = ['render', '-i', this.snapshot, '-o', this.output, '-c', this.runtimeConfig,
      '--page', this.mirror(this.file), '--preview-stream', 'true'];
    if (!this.fullBuild) args.push('--incremental', 'true');
    const child = spawn(this.options.executable, args, {
      cwd: this.snapshot, env: { ...process.env, ...this.options.environment }, windowsHide: true, shell: false,
      stdio: ['pipe', 'pipe', 'pipe']
    });
    this.child = child;
    let timedOut = false, batchId = 0, previewPage;
    const timer = setTimeout(() => { timedOut = true; abort.abort(); child.kill(); }, this.options.startupTimeoutMs || 120000);
    const output = chunk => this.emit('log', chunk.toString().replace(/\x1b\[[0-9;]*[A-Za-z]/g, ''));
    child.stderr.on('data', output);
    // Install close/error handlers before consuming stdout, including spawn failure.
    const completion = new Promise((resolve, reject) => {
      child.once('error', failure => { abort.abort(); reject(failure); });
      child.once('close', (code, signal) => { abort.abort(); resolve({ code, signal }); });
    });
    completion.catch(() => {});
    child.stdin.on('error', () => {}); // EPIPE on cancellation is expected.
    try {
      const lines = createInterface({ input: child.stdout, crlfDelay: Infinity });
      for await (const line of lines) {
        if (!valid()) break;
        if (!line.startsWith('MARKIT_PREVIEW\t')) { output(line + '\n'); continue; }
        const frame = JSON.parse(line.slice('MARKIT_PREVIEW\t'.length));
        if (frame.type !== 'preview' || !Array.isArray(frame.operations)) throw new Error('Invalid Markit preview stream frame.');
        if (frame.shell !== undefined) {
          previewPage = { ...documentParts(frame.shell), ...this.pageMetadata(), renderId };
          if (previewPage.markdown !== expected) throw new Error('Markit returned a stale preview source map.');
          // Assets may still be in the build output until final publish copies them.
          previewPage.assets = path.join(this.output, 'assets');
        }
        if (!previewPage) throw new Error('Markit preview stream omitted its shell.');
        if (expected !== await this.source(this.file)) { this.cancelRender(); break; }
        if (background) {
          // Keep the last coherent DOM/source map visible. Do not accumulate frames
          // or make edit renders depend on a webview painting provisional content.
          child.stdin.write('ack\n');
          continue;
        }
        // Cancellation must not wait for a hidden/disposed webview's acknowledgement.
        const presented = await new Promise((resolve, reject) => {
          const canceled = () => resolve();
          if (abort.signal.aborted) { resolve(); return; }
          abort.signal.addEventListener('abort', canceled, { once: true });
          Promise.resolve(this.options.onPreview?.(previewPage, { ...frame, shell: frame.shell === undefined ? undefined : true, renderId, batchId: ++batchId }))
            .then(resolve, reject).finally(() => abort.signal.removeEventListener('abort', canceled));
        });
        if (presented === false) this.cancelRender();
        if (!valid()) break;
        child.stdin.write('ack\n');
      }
      const { code, signal } = await completion;
      if (!valid()) return;
      if (timedOut) throw new Error('Timed out rendering the current Markdown document. See Markit Preview output.');
      if (code !== 0) throw new Error(`Markit exited (${signal || code}). Update Markit to a version supporting --preview-stream. See the Markit Preview output channel.`);
      const page = await this.readPage();
      if (!valid()) return;
      if (page.markdown !== expected) throw new Error('Markit returned a stale Markdown source map.');
      this.fullBuild = false;
      await this.publish({ ...page, renderId, background });
      if (this.current?.renderId === renderId) this.foregroundPending = false;
    } catch (failure) {
      child.kill();
      await completion.catch(() => {});
      if (valid()) throw failure;
    } finally {
      clearTimeout(timer);
      if (this.child === child) this.child = undefined;
    }
  }

  selectDocument(file) {
    this.pending = this.pending.catch(() => {}).then(() => this.selectDocumentNow(file));
    return this.pending;
  }

  async selectDocumentNow(file) {
    if (this.closed) return;
    if (this.file === file && this.current?.file === file && this.current.language === this.language && this.current.markdown === await this.source(file)) {
      this.current = { ...this.current, renderId: this.renderId };
      return;
    }
    const ticket = this.renderId;
    this.file = file;
    const source = await this.source(file);
    await this.write(file, source);
    await this.configure();
    if (!this.closed && ticket === this.renderId) await this.render({ background: true });
  }

  switchLanguage(language) {
    this.pending = this.pending.catch(() => {}).then(() => this.switchLanguageNow(language));
    return this.pending;
  }

  async switchLanguageNow(language) {
    if (!/^[a-z][a-z\d-]*$/i.test(language)) throw new Error('Invalid language code.');
    this.cancelRender();
    const ticket = this.renderId;
    await this.stopChild();
    if (this.closed || ticket !== this.renderId) return;
    this.language = language;
    await this.configure();
    if (!this.closed && ticket === this.renderId) await this.render();
  }

  update(file, text) {
    this.setBuffer(file, text);
    this.pending = this.pending.catch(() => {}).then(async () => {
      if (this.closed) return;
      const configChanged = this.project.variants.some(item => item.file === file);
      if (file === this.file) {
        const source = await this.source(file);
        if (!this.foregroundPending && this.current?.markdown === source && this.current.file === file && this.current.language === this.language) {
          // A newer edit can cancel B and revert to already-rendered A. Settle
          // the advanced render generation even though no native work is needed,
          // so the webview clears Updating… and its pending source-edit rebases.
          if (this.current.renderId !== this.renderId) await this.publish({ ...this.current, renderId: this.renderId, background: true });
          return;
        }
        await this.write(file, source);
        await this.render({ background: true });
      } else if (configChanged || /^markit(?:\.[\w-]+)?\.md$/i.test(path.basename(file))) {
        for (const variant of this.project.variants) variant.config = json(await this.source(variant.file));
        await this.configure();
        await this.render({ background: true });
      } else if (this.contextFiles?.has(file)) {
        await this.write(file, await this.source(file));
        await this.render({ background: true });
      }
    });
    return this.pending;
  }

  async stopChild() {
    const child = this.child;
    if (!child || !child.pid || child.exitCode !== null || child.signalCode !== null) return;
    await new Promise(resolve => { child.once('close', resolve); child.kill(); });
  }

  dispose() {
    if (!this.disposal) {
      this.closed = true;
      this.cancelRender();
      this.disposal = this.cleanup();
    }
    return this.disposal;
  }

  async cleanup() {
    this.closed = true;
    await this.stopChild();
    await this.pending.catch(() => {});
    if (this.temp && inside(os.tmpdir(), this.temp) && path.basename(this.temp).startsWith('markit-preview-')) {
      await fs.rm(this.temp, { recursive: true, force: true, maxRetries: 3, retryDelay: 200 });
    }
  }
}

module.exports = { PreviewSession };
