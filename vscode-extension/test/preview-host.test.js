'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { EventEmitter } = require('node:events');

const turn = () => new Promise(resolve => setImmediate(resolve));

test('hidden retained webview cancels pending ACK and resumes only when visible', async t => {
  const commands = new Map(), sessions = [];
  const subscriptions = [];
  const project = { root: '/workspace', file: '/workspace/markit.json', id: 'docs', title: 'Docs', languages: ['en'] };
  const document = { uri: { scheme: 'file', fsPath: '/workspace/page.md', toString: () => 'file:///workspace/page.md' }, languageId: 'markdown', version: 1, isDirty: false, getText: () => 'selectable preview text', offsetAt: position => position, positionAt: offset => offset, lineAt: () => ({ text: '' }) };
  let panel, receive, viewState, selectionChanged, visibleRangesChanged, status, textChanged;
  const posted = [], clipboard = [];
  const noop = () => ({ dispose() {} });
  class Session extends EventEmitter {
    constructor(project, options) { super(); this.project = project; this.options = options; this.renderId = 0; this.config = {}; this.token = 'test'; this.temp = '/tmp/test'; this.pending = Promise.resolve(); this.renders = 0; this.cancellations = 0; sessions.push(this); }
    source() { return ''; }
    async start(language, buffers, file) { this.file = file; this.language = language; await this.render(); }
    async selectDocument() { await this.render(); }
    async render() {
      this.renders++; const renderId = ++this.renderId; this.child = {};
      this.emit('rendering', { language: 'en' });
      const page = { file: this.file, language: 'en', renderId, markdown: '', body: '', head: '', offsets: [0], assets: '/tmp/assets', root: '/workspace', temp: '/tmp/test' };
      const shown = await this.options.onPreview(page, { type: 'preview', shell: true, operations: [], renderId, batchId: 1 });
      if (shown !== false && renderId === this.renderId) this.current = page;
      this.child = undefined;
    }
    cancelRender() { this.cancellations++; this.renderId++; this.child = undefined; }
    async dispose() { this.cancelRender(); }
  }
  const vscode = {
    env: { clipboard: { writeText: async text => { clipboard.push(text); } } },
    StatusBarAlignment: { Right: 1 }, ViewColumn: { Beside: 2 },
    TextEditorSelectionChangeKind: { Keyboard: 1, Mouse: 2, Command: 3 }, TextEditorRevealType: { Default: 0 },
    Selection: class { constructor(anchor, active) { this.anchor = anchor; this.active = active; } },
    Uri: { file: file => ({ fsPath: file, toString: () => file }), joinPath: (uri, ...parts) => ({ toString: () => `${uri}/${parts.join('/')}` }) },
    window: {
      activeTextEditor: undefined, visibleTextEditors: [], createOutputChannel: () => ({ append() {}, appendLine() {}, show() {} }), createStatusBarItem: () => (status = { show() {}, hide() {} }),
      createWebviewPanel() {
        panel = { visible: true, active: true, webview: { html: '', cspSource: 'webview:', options: {}, asWebviewUri: uri => uri, postMessage: async message => { posted.push(message); return true; }, onDidReceiveMessage(callback) { receive = callback; return noop(); } }, onDidDispose: noop, onDidChangeViewState(callback) { viewState = callback; return noop(); }, reveal() { this.visible = true; viewState(); } };
        return panel;
      }, onDidChangeActiveTextEditor: noop, onDidChangeTextEditorVisibleRanges(callback) { visibleRangesChanged = callback; return noop(); }, onDidChangeTextEditorSelection(callback) { selectionChanged = callback; return noop(); }
    },
    workspace: { isTrusted: true, workspaceFolders: [{ uri: { scheme: 'file', fsPath: '/workspace' } }], textDocuments: [document], getConfiguration: () => ({ get: (name, fallback) => fallback }), onDidChangeTextDocument(callback) { textChanged = callback; return noop(); }, onDidChangeWorkspaceFolders: noop, onDidChangeConfiguration: noop, createFileSystemWatcher: () => ({ onDidCreate: noop, onDidChange: noop, onDidDelete: noop }) },
    commands: { registerCommand(name, callback) { commands.set(name, callback); return noop(); } }
  };
  const projects = { EXCLUDED: new Set(), discover: async () => [project], owners: async () => [project], savedLanguage: async () => 'en', inside: () => true };
  const module = { exports: {} };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../src/extension.js'), 'utf8'), { module, require: name => name === 'vscode' ? vscode : name === './session' ? { PreviewSession: Session } : name === './document' ? { rewriteResources: async html => html } : name === './projects' ? projects : name.startsWith('./') ? require(path.join(__dirname, '../src', name)) : require(name), setTimeout, clearTimeout, console });
  module.exports.activate({ subscriptions, extensionUri: 'extension:' });
  t.after(() => module.exports.deactivate());
  vscode.window.activeTextEditor = { document };
  const opening = commands.get('markit.preview')();
  for (let index = 0; index < 10 && !panel?.webview.html.includes('markit-preview-data'); index++) await turn();
  assert.equal(sessions[0].renders, 1);
  panel.visible = false; viewState();
  await opening;
  assert(sessions[0].cancellations >= 1);
  assert.equal(sessions[0].current, undefined, 'hidden frame was not acknowledged as painted');
  await turn(); assert.equal(sessions[0].renders, 1, 'no hidden restart loop');
  panel.visible = true; viewState();
  for (let index = 0; index < 10 && sessions[0].renders < 2; index++) await turn();
  assert.equal(sessions[0].renders, 2);
  // Explicit ACK completes resumed render; generation increments from 1 to 2.
  receive({ type: 'preview-ack', generation: 2, renderId: sessions[0].renderId, batchId: 1 });
  await turn(); await turn();
  assert(sessions[0].current);
  await t.test('exact preview-origin Command echoes preserve native selection and do not scroll the preview', () => {
    let assignments = 0;
    const editor = { document, selections: [{ anchor: 0, active: 0 }], visibleRanges: [{ start: { line: 0, character: 0 } }],
      set selection(value) { assignments++; this.selections = [value]; selectionChanged({ textEditor: this, selections: this.selections, kind: 3 }); },
      revealRange() { visibleRangesChanged({ textEditor: this }); }
    };
    vscode.window.visibleTextEditors = [editor];
    posted.length = 0;
    receive({ type: 'preview-selection', file: document.uri.fsPath, version: 1, anchor: 2, active: 8 });
    assert.equal(assignments, 1);
    assert.equal(posted.filter(message => message.type === 'editor-selection').at(-1).clearNative, false);
    assert.equal(posted.filter(message => message.type === 'editor-scroll').length, 0);
    // A genuine editor command is not an echo simply because its kind is Command.
    editor.selections = [{ anchor: 3, active: 9 }]; selectionChanged({ textEditor: editor, selections: editor.selections, kind: 3 });
    assert.equal(posted.at(-1).clearNative, true);
    selectionChanged({ textEditor: editor, selections: editor.selections, kind: 2 });
    assert.equal(posted.at(-1).clearNative, true);
    receive({ type: 'preview-selection', file: document.uri.fsPath, version: 0, anchor: 1, active: 4 });
    assert.equal(assignments, 1, 'stale page cannot alter editor selection');
  });
  await t.test('explicit preview copy writes exact rendered text and rejects unrelated or malformed messages', async () => {
    const message = { type: 'copy-selection', file: document.uri.fsPath, version: document.version, generation: 2, renderId: sessions[0].renderId, text: 'English\n中文😀' };
    receive(message); await turn(); assert.equal(clipboard.length, 0, 'queued but unacknowledged content cannot grant clipboard authority');
    receive({ ...message, type: 'rendered', loading: false });
    receive(message); await turn(); assert.equal(clipboard.at(-1), message.text);
    document.version++; receive(message); await turn();
    assert.equal(clipboard.at(-1), message.text, 'currently displayed snapshot remains copyable while source advances');
    const count = clipboard.length;
    for (const invalid of [{ ...message, file: '/other.md' }, { ...message, version: document.version + 1 }, { ...message, renderId: message.renderId + 1 }, { ...message, text: 7 }, { ...message, text: '' }]) receive(invalid);
    panel.visible = false; receive(message); panel.visible = true;
    panel.active = false; receive(message); panel.active = true;
    receive({ ...message, version: document.version });
    await turn(); assert.equal(clipboard.length, count, 'inactive preview and not-yet-presented source versions cannot copy');
    document.version--;
  });
  await t.test('same-page background render never replaces the webview shell or announces visible loading', async () => {
    const current = sessions[0], shell = panel.webview.html;
    posted.length = 0;
    const renderId = ++current.renderId; current.child = {};
    current.emit('rendering', { language: 'en', renderId, background: true });
    assert.equal(panel.webview.html, shell);
    assert.equal(posted.at(-1).type, 'background-start');
    assert.equal(posted.some(message => message.type === 'loading'), false);
    assert.doesNotMatch(status.text, /spin/);
    current.current = { ...current.current, renderId, background: true, body: '<p>Quiet edit</p>' };
    current.emit('updated'); await turn(); await turn();
    assert.equal(panel.webview.html, shell);
    const final = posted.find(message => message.type === 'content');
    assert(final); assert.equal(final.editEffects, true); assert.equal(final.background, true); assert.equal(final.loading, false);
    assert.doesNotMatch(status.text, /spin/, 'pending native child does not leak into quiet final status');
    current.child = undefined;
  });

  await t.test('hidden edits and work queued behind foreground tasks cannot start hidden renderers', async () => {
    const current = sessions[0], updates = [];
    current.setBuffer = () => {};
    current.update = async (file, text) => { updates.push([file, text]); };
    const change = () => textChanged({ document, contentChanges: [{ range: { start: { line: 0, character: 0 }, end: { line: 0 } }, text: 'new' }] });
    const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
    change(); panel.visible = false; viewState();
    await wait(160); assert.equal(updates.length, 0, 'debounced edit stays paused while hidden');
    panel.visible = true; viewState(); await wait(20);
    assert.equal(updates.length, 1, 'latest hidden edit resumes once visible');
    let release;
    current.pending = new Promise(resolve => { release = resolve; });
    change(); await wait(270); // Scheduler started, but native foreground queue is blocked.
    panel.visible = false; viewState(); release(); await turn(); await turn();
    assert.equal(updates.length, 1, 'visibility is rechecked after awaiting native queue');
    panel.visible = true; viewState(); await wait(270);
    assert.equal(updates.length, 2, 'canceled queued edit is retained for reveal');
  });

});
