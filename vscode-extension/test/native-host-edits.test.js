'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const os = require('node:os');
const vm = require('node:vm');
const { PreviewSession } = require('../src/session');
const projects = require('../src/projects');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function until(predicate, label) { for (let i = 0; i < 600; i++) { if (predicate()) return; await delay(25); } throw new Error(`Timed out: ${label}`); }

test('actual native session and extension host retain one webview shell through dirty edits, save and refocus', { skip: !process.env.MARKIT_TEST_BINARY, timeout: 60000 }, async t => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'markit-host-native-'));
  const file = path.join(root, 'chapter.md');
  const original = '# 标题:en{Title}:\n\n' + 'Original paragraph 😀.\n\n'.repeat(350);
  await fs.writeFile(file, original);
  await fs.writeFile(path.join(root, 'markit.md'), '- [章节:en{Chapter}:](chapter.md)\n');
  await fs.writeFile(path.join(root, 'markit.json'), JSON.stringify({ title: 'Host', format: 'website', theme: 'arctic', i18n: { default: 'zh', target: 'zh' }, summary: [{ file: 'markit.md', showDrafts: false }] }));
  let text = original, receive, change, focus, disk, panel, html = '';
  const shells = [], optionWrites = [], messages = [], logs = [], sessions = [], commands = new Map();
  const noop = () => ({ dispose() {} });
  const uri = value => ({ fsPath: value, scheme: 'file', toString: () => `file://${value}` });
  const document = { uri: uri(file), languageId: 'markdown', version: 1, isDirty: false, getText: () => text, lineAt: () => ({ text: '' }), offsetAt: pos => pos, positionAt: offset => offset };
  const editor = { document, selections: [{ anchor: 0, active: 0 }], visibleRanges: [{ start: { line: 0, character: 0 } }] };
  const ack = message => { if (message.batchId !== undefined) queueMicrotask(() => receive({ type: 'preview-ack', generation: message.generation, renderId: message.renderId, batchId: message.batchId })); };
  class Session extends PreviewSession { constructor(...args) { super(...args); sessions.push(this); } }
  const vscode = {
    StatusBarAlignment: { Right: 1 }, ViewColumn: { Beside: 2 }, TextEditorSelectionChangeKind: { Keyboard: 1, Mouse: 2, Command: 3 },
    Uri: { file: uri, joinPath: (base, ...parts) => uri(path.join(base.fsPath || String(base), ...parts)) },
    window: { activeTextEditor: undefined, visibleTextEditors: [editor], createOutputChannel: () => ({ append: line => logs.push(line), appendLine: line => logs.push(line), show() {} }), createStatusBarItem: () => ({ show() {}, hide() {} }),
      createWebviewPanel() {
        const webview = { cspSource: 'webview:', asWebviewUri: value => value, postMessage: async message => { messages.push(message); ack(message); return true; }, onDidReceiveMessage(callback) { receive = callback; return noop(); } };
        Object.defineProperty(webview, 'options', { get: () => optionWrites.at(-1)?.value || {}, set(value) { optionWrites.push({ value, key: JSON.stringify({ ...value, localResourceRoots: value.localResourceRoots.map(item => item.toString()) }) }); } });
        Object.defineProperty(webview, 'html', { get: () => html, set(value) { html = value; shells.push(value); const bootstrap = /id="markit-preview-data" type="application\/json">([\s\S]*?)<\/script>/.exec(value); if (bootstrap) ack(JSON.parse(bootstrap[1])); } });
        panel = { visible: true, webview, onDidDispose: noop, onDidChangeViewState: noop, reveal() {} }; return panel;
      }, onDidChangeActiveTextEditor(callback) { focus = callback; return noop(); }, onDidChangeTextEditorVisibleRanges: noop, onDidChangeTextEditorSelection: noop },
    workspace: { isTrusted: true, workspaceFolders: [{ uri: uri(root) }], textDocuments: [document], getConfiguration: () => ({ get: (name, fallback) => name === 'executablePath' ? process.env.MARKIT_TEST_BINARY : name === 'debounceMs' ? 5 : fallback }), onDidChangeTextDocument(callback) { change = callback; return noop(); }, onDidChangeWorkspaceFolders: noop, onDidChangeConfiguration: noop,
      createFileSystemWatcher: () => ({ onDidCreate: noop, onDidDelete: noop, onDidChange(callback) { disk = callback; return noop(); } }) },
    commands: { registerCommand(name, callback) { commands.set(name, callback); return noop(); } }
  };
  const module = { exports: {} };
  vm.runInNewContext(await fs.readFile(path.join(__dirname, '../src/extension.js'), 'utf8'), { module, require: name => name === 'vscode' ? vscode : name === './session' ? { PreviewSession: Session } : name === './projects' ? { ...projects, savedLanguage: async () => 'zh' } : name.startsWith('.') ? require(path.resolve(__dirname, '../src', name)) : require(name), setTimeout, clearTimeout, console });
  module.exports.activate({ subscriptions: [], extensionUri: uri(path.resolve(__dirname, '..')) });
  t.after(async () => { await module.exports.deactivate(); await fs.rm(root, { recursive: true, force: true }); });
  vscode.window.activeTextEditor = editor;
  await commands.get('markit.preview')();
  await until(() => messages.some(message => message.type === 'content' && !message.loading), 'initial final content');
  const initialShells = shells.length, initialOptions = optionWrites.length, firstSession = sessions[0];
  for (let edit = 1; edit <= 3; edit++) {
    messages.length = 0; text = original.replace('Original', `EDIT_${edit}`); document.version++; document.isDirty = true;
    change({ document, contentChanges: [{ range: { start: { line: 2, character: 0 }, end: { line: 2, character: 8 } }, text: `EDIT_${edit}` }] });
    await until(() => messages.some(message => message.type === 'content' && message.html.includes(`EDIT_${edit}`)), `edit ${edit}`);
    assert.equal(shells.length, initialShells, 'editing must not reload the webview HTML');
    assert.equal(sessions.length, 1, 'editing must not recreate native session');
    assert.equal(messages.some(message => message.type === 'loading' || message.type === 'preview-batch'), false, 'no progressive shell/batches for an edit');
    assert(messages.filter(message => message.type === 'content').every(message => message.background && !message.loading));
  }
  await fs.writeFile(file, text); document.isDirty = false; await disk(document.uri); await delay(30); await firstSession.pending;
  focus(editor); await delay(100);
  assert.equal(shells.length, initialShells, 'save/refocus must not recreate webview HTML');
  assert.equal(sessions.length, 1);
  assert.equal(new Set(optionWrites.map(write => write.key)).size, 1, 'resource roots/options stay semantically identical across edits');
  assert.equal(optionWrites.length, initialOptions, 'edits/refocus must not invoke VS Code reload-capable content-options setter');
  t.diagnostic(`webview HTML assignments after load: ${shells.length - initialShells}; redundant option writes after load: ${optionWrites.length - initialOptions}`);
  assert.equal(logs.some(line => line.includes('[error]')), false, logs.join(''));
});
