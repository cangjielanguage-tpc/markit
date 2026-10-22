'use strict';

const vscode = require('vscode');
const fs = require('node:fs/promises');
const path = require('node:path');
const { randomBytes } = require('node:crypto');
const { PreviewSession } = require('./session');
const { EditScheduler } = require('./edit-scheduler');
const { rewriteResources } = require('./document');
const { EXCLUDED, STATE_FILE, inside, discover, owners, savedLanguage, saveLanguage, markdownLinks, configFor, pagePath } = require('./projects');

const escape = value => String(value).replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]);
const loadingStyle = `#markit-preview-loading{position:fixed;top:12px;right:16px;z-index:100;display:flex;align-items:center;gap:8px;padding:8px 12px;border-radius:6px;background:var(--vscode-editor-background,#fff);color:var(--vscode-editor-foreground,#333);box-shadow:0 1px 6px #8884;font:13px sans-serif}#markit-preview-loading[hidden]{display:none}#markit-preview-loading.progressive{position:static;width:max-content;max-width:90%;margin:12px auto 28px}#markit-preview-loading:before{content:'';width:14px;height:14px;border:2px solid currentColor;border-right-color:transparent;border-radius:50%;animation:markit-spin .8s linear infinite}@keyframes markit-spin{to{transform:rotate(360deg)}}@media(prefers-reduced-motion:reduce){#markit-preview-loading:before{animation:none}}`;
const updatingStyle = '#markit-preview-updating{position:fixed;right:16px;bottom:12px;z-index:98;padding:4px 8px;border-radius:4px;background:var(--vscode-editor-background,#fff);color:var(--vscode-descriptionForeground,#666);font:12px sans-serif;pointer-events:none}#markit-preview-updating[hidden]{display:none}';
const updatingMarkup = '<div id="markit-preview-updating" role="status" aria-live="polite" aria-atomic="true" hidden>Updating…</div>';
const loadingMarkup = '<div id="markit-preview-loading" role="status" aria-live="polite">Loading preview…</div>';
function loadingShell() { return `<!doctype html><html><head><meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline';"><style>${loadingStyle}</style></head><body aria-busy="true">${loadingMarkup}</body></html>`; }
let shutdown;

function activate(context) {
  const output = vscode.window.createOutputChannel('Markit Preview');
  const status = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 80);
  status.command = 'markit.selectLanguage';
  let panel, session, activeProject, lastDocument, projects, scanning;
  let sequence = Promise.resolve(), generation = 0, stateWrites = Promise.resolve();
  let editScheduler, editEpoch = 0;
  function cancelEdits() { editEpoch++; editScheduler?.dispose(); editScheduler = undefined; }
  const ambiguous = new Map();
  let stopped = false, viewRevision = 0, shellKey, resourceKey, echoUntil = 0, requestedFile, loadingPending = false, resumeHidden = false;
  const previewAcks = new Map();
  const selectionEchoes = new WeakMap();
  let presentedCopySource;
  const copyPublications = new Map();
  const copySourceKey = message => JSON.stringify([message.file, message.version, message.generation, message.renderId]);
  function registerCopySource(payload) {
    const source = { file: payload.file, version: payload.version, generation: payload.generation, renderId: payload.renderId };
    copyPublications.set(copySourceKey(source), source);
    while (copyPublications.size > 4) copyPublications.delete(copyPublications.keys().next().value);
  }
  function selectionKey(editor, selections = editor.selections) {
    return JSON.stringify([editor.document.uri.fsPath, editor.document.version, selections.map(selection => [editor.document.offsetAt(selection.anchor), editor.document.offsetAt(selection.active)])]);
  }
  function cancelPresentation() { for (const finish of previewAcks.values()) finish(false); previewAcks.clear(); }
  function ackKey(message) { return `${message.generation}:${message.renderId}:${message.batchId}`; }
  function waitForPresentation(message) {
    const key = ackKey(message);
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => { previewAcks.delete(key); reject(new Error('Preview webview did not acknowledge rendering. Reopen the preview to retry.')); }, 120000);
      previewAcks.set(key, value => { clearTimeout(timer); previewAcks.delete(key); resolve(value); });
    });
  }
  function loading(file) {
    loadingPending = true;
    cancelPresentation();
    if (!panel) return;
    if (shellKey) void panel.webview.postMessage({ type: 'loading', file, generation, renderId: session?.renderId });
    else panel.webview.html = loadingShell();
  }

  function cancelLoading() {
    loadingPending = false;
    cancelPresentation();
    if (!panel) return;
    if (shellKey) void panel.webview.postMessage({ type: 'cancelled', generation, renderId: session?.renderId });
    else panel.webview.html = '<!doctype html><html><body><p>Preview canceled.</p></body></html>';
  }

  const read = async file => vscode.workspace.textDocuments.find(doc => doc.uri.scheme === 'file' && doc.uri.fsPath === file)?.getText() ?? fs.readFile(file, 'utf8');
  const buffers = root => vscode.workspace.textDocuments.filter(doc => doc.uri.scheme === 'file' && doc.isDirty && inside(root, doc.uri.fsPath)).map(doc => ({ file: doc.uri.fsPath, text: doc.getText() }));
  function error(error) {
    if (error?.name === 'AbortError') return;
    loadingPending = false;
    cancelPresentation();
    output.appendLine(`[error] ${error.message || error}`);
    status.text = '$(warning) Markit'; status.tooltip = String(error.message || error); status.command = 'markit.showLogs'; status.show();
    if (panel && !session) {
      shellKey = undefined;
      const nonce = randomBytes(18).toString('hex');
      panel.webview.html = `<!doctype html><html><head><meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'nonce-${nonce}';"></head><body><h2>Markit preview could not start</h2><p>${escape(error.message || error)}</p><p>The executable needs its complete assets directory and a working runtime environment.</p><button id="binary">Select Executable</button> <button id="logs">Show Logs</button><script nonce="${nonce}">const vscode=acquireVsCodeApi();document.querySelector('#binary').onclick=()=>vscode.postMessage({type:'executable'});document.querySelector('#logs').onclick=()=>vscode.postMessage({type:'logs'});</script></body></html>`;
    } else panel?.webview.postMessage({ type: 'error', generation, renderId: session?.renderId, message: String(error.message || error) });
  }
  function queue(task) {
    sequence = sequence.catch(error).then(async () => { if (!stopped) await task(); }).catch(error);
    return sequence;
  }
  async function index() {
    if (projects) return projects;
    if (!scanning) scanning = Promise.all((vscode.workspace.workspaceFolders || [])
      .filter(folder => folder.uri.scheme === 'file').map(folder => discover(folder.uri.fsPath, read)))
      .then(groups => { projects = groups.flat(); return projects; }).finally(() => { scanning = undefined; });
    return scanning;
  }
  async function languageFor(project, force = false) {
    const saved = await savedLanguage(project);
    if (saved && !force) return saved;
    const choices = [...new Set([...project.languages, saved].filter(Boolean))].map(lang => ({ label: lang, description: lang === saved ? 'Current language' : undefined }));
    choices.push({ label: 'Enter another language code…', custom: true });
    const choice = await vscode.window.showQuickPick(choices, { title: `${project.title} · Preview language`, placeHolder: 'Saved for this documentation project; switch it at any time' });
    if (!choice) return undefined;
    const lang = choice.custom ? await vscode.window.showInputBox({ title: 'Markit language code', prompt: 'For example zh, en, or ja. Preview uses existing translations.', validateInput: value => /^[a-z][a-z\d-]*$/i.test(value) ? null : 'Enter a valid language code' }) : choice.label;
    if (!lang) return undefined;
    stateWrites = stateWrites.catch(() => {}).then(() => saveLanguage(project, lang));
    await stateWrites;
    return lang;
  }
  function visibleLine(document) {
    const editor = vscode.window.visibleTextEditors.find(item => item.document.uri.toString() === document.uri.toString());
    const start = editor?.visibleRanges[0]?.start;
    return start ? start.line + start.character / Math.max(1, document.lineAt(start.line).text.length) : 0;
  }
  function sendEditorScroll(editor) {
    if (!panel || !session || editor.document.uri.fsPath !== session.file || Date.now() < echoUntil) return;
    void panel.webview.postMessage({ type: 'editor-scroll', file: session.file, line: visibleLine(editor.document) });
  }
  function sendEditorSelection(editor, clearNative = false) {
    if (!panel || !session || editor.document.uri.fsPath !== session.file) return;
    void panel.webview.postMessage({ type: 'editor-selection', file: session.file, version: editor.document.version, clearNative,
      ranges: editor.selections.map(selection => ({ anchor: editor.document.offsetAt(selection.anchor), active: editor.document.offsetAt(selection.active) })) });
  }
  async function openLink(message) {
    if (!session || message.file !== session.file || typeof message.href !== 'string') return;
    if (/^https?:/i.test(message.href)) { await vscode.env.openExternal(vscode.Uri.parse(message.href)); return; }
    if (/^[a-z][a-z\d+.-]*:/i.test(message.href)) return;
    const href = decodeURIComponent(message.href.split('#')[0]);
    const candidates = new Set();
    for (const variant of activeProject.variants) {
      const input = path.resolve(path.dirname(variant.file), variant.config.i18n?.routePrefix || '.');
      for (const entry of variant.config.summary) {
        if (!entry.file) continue;
        const summary = path.resolve(input, entry.file); candidates.add(summary);
        try { for (const item of markdownLinks(await read(summary))) candidates.add(path.resolve(input, item)); } catch { /* Missing Summary is reported by project detection. */ }
      }
    }
    const current = pagePath(activeProject, session.file, session.language);
    const target = path.posix.normalize(path.posix.join(path.posix.dirname(current), href));
    let file = [...candidates].find(item => pagePath(activeProject, item, session.language) === target);
    if (!file && href.includes('*')) {
      const pattern = new RegExp('^' + href.replace(/[.+?^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*') + '(?:\\.md|\\.markdown)?$', 'i');
      file = [...candidates].find(item => pattern.test(path.basename(item)));
    }
    if (!file) file = path.resolve(path.dirname(session.file), href.replace(/\.html?$/i, '.md'));
    if (!inside(activeProject.root, file) || !/\.(md|markdown)$/i.test(file)) return;
    try { await fs.access(file); await vscode.window.showTextDocument(vscode.Uri.file(file), { viewColumn: vscode.ViewColumn.One, preserveFocus: false }); }
    catch { await vscode.window.showInformationMessage('The target Markdown file could not be found in this documentation project.'); }
  }
  function createPanel() {
    if (panel) return;
    panel = vscode.window.createWebviewPanel('markit.preview', 'Markit Preview', { viewColumn: vscode.ViewColumn.Beside, preserveFocus: true }, { enableScripts: true, retainContextWhenHidden: true, localResourceRoots: [] });
    panel.webview.html = loadingShell();
    panel.webview.onDidReceiveMessage(message => {
      if (message.type === 'preview-ack') { previewAcks.get(ackKey(message))?.(true); return; }
      if (message.type === 'language') void vscode.commands.executeCommand('markit.selectLanguage');
      else if (message.type === 'refresh') void vscode.commands.executeCommand('markit.refresh');
      else if (message.type === 'logs') output.show(true);
      else if (message.type === 'executable') void vscode.commands.executeCommand('markit.selectExecutable');
      else if (message.type === 'ready' || message.type === 'rendered') {
        const acknowledged = copyPublications.get(copySourceKey(message));
        if (acknowledged && (!presentedCopySource || acknowledged.generation > presentedCopySource.generation ||
            (acknowledged.generation === presentedCopySource.generation && acknowledged.renderId >= presentedCopySource.renderId))) presentedCopySource = acknowledged;
        const editor = vscode.window.visibleTextEditors.find(item => item.document.uri.fsPath === message.file);
        if (editor && !message.loading) { if (message.type === 'ready') sendEditorScroll(editor); sendEditorSelection(editor); }
      } else if (message.type === 'copy-selection' && session?.file === message.file) {
        if (!panel?.visible || !panel.active || !presentedCopySource || copySourceKey(message) !== copySourceKey(presentedCopySource) ||
            typeof message.text !== 'string' || !message.text || message.text.length > 16 * 1024 * 1024) return;
        // Copy the explicitly selected rendered snapshot, including while a newer
        // source version is compiling. Never substitute the source Markdown.
        void vscode.env.clipboard.writeText(message.text).catch(failure => {
          output.appendLine(`[copy] ${failure.message || failure}`);
          void vscode.window.showErrorMessage(`Could not copy preview selection: ${failure.message || failure}`);
        });
      } else if (message.type === 'preview-selection' && session?.file === message.file) {
        const editor = vscode.window.visibleTextEditors.find(item => item.document.uri.fsPath === message.file);
        if (!editor || editor.document.version !== message.version || !Number.isInteger(message.anchor) || !Number.isInteger(message.active)) return;
        const length = editor.document.getText().length;
        if (message.anchor < 0 || message.active < 0 || message.anchor > length || message.active > length) return;
        const selection = new vscode.Selection(editor.document.positionAt(message.anchor), editor.document.positionAt(message.active));
        const key = selectionKey(editor, [selection]);
        if (key !== selectionKey(editor)) {
          // VS Code may report programmatic assignments as Command events. Match
          // their exact source/version/ranges instead of clearing native browser
          // selection in response to our own preview -> editor round trip.
          const echoes = selectionEchoes.get(editor) || [];
          echoes.push(key); selectionEchoes.set(editor, echoes.slice(-32));
          editor.selection = selection;
        }
        echoUntil = Date.now() + 200;
        editor.revealRange(selection, vscode.TextEditorRevealType.Default);
      } else if (message.type === 'preview-scroll' && session?.file === message.file && Number.isFinite(message.line)) {
        const editor = vscode.window.visibleTextEditors.find(item => item.document.uri.fsPath === message.file);
        if (!editor) return;
        const line = Math.min(editor.document.lineCount - 1, Math.max(0, Math.floor(message.line)));
        const character = Math.floor((message.line - Math.floor(message.line)) * editor.document.lineAt(line).text.length);
        echoUntil = Date.now() + 200;
        const position = new vscode.Position(line, character);
        editor.revealRange(new vscode.Range(position, position), vscode.TextEditorRevealType.AtTop);
      } else if (message.type === 'open-link') void openLink(message).catch(error);
    }, undefined, context.subscriptions);
    panel.onDidChangeViewState(() => {
      if (!panel) return;
      if (!panel.visible) {
        editEpoch++; editScheduler?.pause();
        // Chromium may suspend requestAnimationFrame in retained hidden webviews.
        // Stop the producer instead of accumulating frames or timing out an ACK.
        if (loadingPending || session?.child) {
          resumeHidden = true;
          session?.cancelRender();
          cancelLoading();
        }
      } else if (resumeHidden && lastDocument) {
        resumeHidden = false;
        void follow(lastDocument).finally(() => { if (panel?.visible) editScheduler?.resume(); });
      } else if (panel.visible) editScheduler?.resume();
    }, undefined, context.subscriptions);
    panel.onDidDispose(() => {
      cancelPresentation();
      panel = undefined; presentedCopySource = undefined; copyPublications.clear(); generation++; viewRevision++; shellKey = undefined; resourceKey = undefined; loadingPending = false; resumeHidden = false;
      cancelEdits();
      const old = session; session = undefined; activeProject = undefined; status.hide();
      void old?.dispose().catch(failure => output.appendLine(`[cleanup] ${failure.message}`));
    }, undefined, context.subscriptions);
  }
  async function showPage(document, suppliedPage, frame) {
    if (panel && !panel.visible) { resumeHidden = true; return false; }
    const page = suppliedPage || session?.current;
    if (!panel || !page || (page.renderId !== undefined && page.renderId !== session?.renderId) || page.file !== document?.uri.fsPath || (requestedFile && requestedFile !== page.file)) return false;
    const revision = ++viewRevision, current = session, ticket = generation, targetPanel = panel;
    const localResourceRoots = [vscode.Uri.file(current.temp), vscode.Uri.file(activeProject.root), context.extensionUri];
    const nextResourceKey = JSON.stringify(localResourceRoots.map(uri => uri.toString()));
    // Content option changes can reload VS Code's iframe. Never touch this setter
    // for ordinary edits/refocus when the security/resource scope is unchanged.
    if (resourceKey !== nextResourceKey) {
      panel.webview.options = { enableScripts: true, localResourceRoots };
      resourceKey = nextResourceKey;
    }
    const resource = file => targetPanel.webview.asWebviewUri(vscode.Uri.file(file)).toString();
    const html = await rewriteResources(page.body, page, resource);
    if (page.markdown !== await current.source(page.file)) return false;
    if (!panel || session !== current || revision !== viewRevision || ticket !== generation || (page.renderId !== undefined && page.renderId !== current.renderId)) return false;
    panel.title = `Markit · ${current.language} · ${path.basename(document.uri.fsPath)}`;
    status.text = `$(${current.child && !page.background ? 'sync~spin' : 'globe'}) Markit: ${current.language}`; status.command = 'markit.selectLanguage';
    status.tooltip = `${activeProject.title} · ${activeProject.id}\nSwitch this documentation project's preview language`; status.show();
    const payload = { type: 'content', html, editEffects: vscode.workspace.getConfiguration('markit', document.uri).get('editEffects', true), generation: ticket, loading: Boolean(frame), streamStart: Boolean(frame), renderId: frame?.renderId ?? page.renderId, batchId: frame?.batchId, file: page.file, version: document.version, language: page.language, background: Boolean(page.background), offsets: page.offsets, bodyClass: page.bodyClass, line: visibleLine(document) };
    if (!frame) loadingPending = false;
    const key = current.token + JSON.stringify([current.config.theme, current.config.website?.assets]);
    if (shellKey === key) {
      const presented = frame ? waitForPresentation(payload) : undefined;
      registerCopySource(payload);
      await panel.webview.postMessage(payload);
      return presented;
    }
    const headLinks = page.head.match(/<link\b[^>]*rel=["']stylesheet["'][^>]*>/gi)?.join('\n') || '';
    const styles = await rewriteResources(headLinks, page, resource);
    if (page.markdown !== await current.source(page.file)) return false;
    if (!panel || session !== current || revision !== viewRevision || ticket !== generation || (page.renderId !== undefined && page.renderId !== current.renderId)) return false;
    const nonce = randomBytes(18).toString('hex');
    const bootstrap = JSON.stringify({ ...payload, html: undefined }).replace(/</g, '\\u003c');
    const bundle = resource(path.join(page.assets, 'js/markit.bundle.js'));
    const preview = panel.webview.asWebviewUri(vscode.Uri.joinPath(context.extensionUri, 'media', 'preview.js'));
    const editEffects = panel.webview.asWebviewUri(vscode.Uri.joinPath(context.extensionUri, 'media', 'edit-effects.js'));
    const selection = panel.webview.asWebviewUri(vscode.Uri.joinPath(context.extensionUri, 'media', 'selection.js'));
    const csp = panel.webview.cspSource;
    const presented = frame ? waitForPresentation(payload) : undefined;
    registerCopySource(payload);
    panel.webview.html = `<!doctype html><html lang="${escape(page.language)}"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src ${csp} https: data:; font-src ${csp} data: https:; style-src ${csp} https: 'unsafe-inline'; script-src ${csp} 'nonce-${nonce}';">
${styles}<style>${loadingStyle}${updatingStyle}html{scroll-behavior:auto!important;overflow-anchor:none}html,body{margin:0!important;padding:0!important;min-width:0!important}body{height:auto!important}.content{box-sizing:border-box;width:100%!important;max-width:1000px!important;margin:0 auto!important;padding:24px 32px!important}.article-extra,.chapter-navigation,.markit-reference-control,.markit-reference-menu{display:none!important}#markit-preview-error{position:fixed;bottom:12px;right:12px;max-width:80%;padding:8px;background:var(--vscode-editor-background);color:var(--vscode-errorForeground);z-index:99}@media(max-width:600px){.content{padding:16px!important}}</style>
<script src="${escape(bundle)}" defer></script><script src="${escape(selection.toString())}" defer></script><script src="${escape(editEffects.toString())}" defer></script><script src="${escape(preview.toString())}" defer></script></head><body class="${escape(page.bodyClass)}"><main class="content" id="markit-preview-article" aria-busy="${Boolean(frame)}">${html}</main>${frame ? loadingMarkup : loadingMarkup.replace('role="status"', 'role="status" hidden')}${updatingMarkup}<div id="markit-preview-error" role="alert" hidden></div><script id="markit-preview-data" type="application/json">${bootstrap}</script></body></html>`;
    shellKey = key;
    return presented;
  }
  async function presentPreview(current, frame, page) {
    if (panel && !panel.visible) { resumeHidden = true; return false; }
    const document = lastDocument;
    if (!panel || session !== current || document?.uri.fsPath !== page.file || requestedFile !== page.file) return false;
    if (frame.shell !== undefined) return showPage(document, page, frame);
    const ticket = generation, targetPanel = panel;
    const resource = file => targetPanel.webview.asWebviewUri(vscode.Uri.file(file)).toString();
    const operations = [];
    for (const operation of frame.operations || []) operations.push({ ...operation, html: operation.html ? await rewriteResources(operation.html, page, resource) : '' });
    if (!panel || session !== current || ticket !== generation || requestedFile !== page.file || page.renderId !== current.renderId) return false;
    const message = { ...frame, shell: undefined, type: 'preview-batch', operations, file: page.file, generation: ticket };
    const presented = waitForPresentation(message);
    await panel.webview.postMessage(message);
    return presented;
  }
  async function open(document, explicit, ticket) {
    if (!document || document.uri.scheme !== 'file' || document.languageId !== 'markdown') return;
    if (panel && !panel.visible) { lastDocument = document; resumeHidden = true; return; }
    if (!vscode.workspace.isTrusted) throw new Error('Trust this workspace before running Markit.');
    const matches = await owners(await index(), document.uri.fsPath, read);
    if (ticket !== generation) return;
    if (!matches.length) {
      if (explicit) await vscode.window.showWarningMessage('No Markit website project references this Markdown file. Check the summary entries in markit.json and their navigation files.');
      if (panel) { shellKey = undefined; panel.webview.html = '<!doctype html><html><body><p>This Markdown file does not belong to a configured Markit documentation project.</p></body></html>'; }
      return;
    }
    let project = matches.length === 1 ? matches[0] : matches.find(item => `${item.root}:${item.id}` === ambiguous.get(document.uri.fsPath));
    if (!project) {
      const selected = await vscode.window.showQuickPick(matches.map(item => ({ label: item.title, description: item.id, project: item })), { title: 'This Markdown file is shared by multiple projects. Choose its preview project.' });
      if (!selected || ticket !== generation) { if (ticket === generation) cancelLoading(); return; }
      project = selected.project; ambiguous.set(document.uri.fsPath, `${project.root}:${project.id}`);
    }
    lastDocument = document;
    if (!panel && !explicit) return;
    const same = activeProject?.root === project.root && activeProject?.id === project.id;
    if (!same || !session) {
      const language = await languageFor(project);
      if (!language || ticket !== generation) { if (ticket === generation) cancelLoading(); return; }
      createPanel();
      status.text = '$(sync~spin) Markit'; status.show();
      cancelEdits();
      const old = session; session = undefined; await old?.dispose();
      if (ticket !== generation || !panel) return;
      if (!panel.visible) { resumeHidden = true; return; }
      const settings = vscode.workspace.getConfiguration('markit', vscode.Uri.file(project.file));
      let executable = settings.get('executablePath', 'markit');
      if (executable.startsWith('${workspaceFolder}')) executable = executable.replace('${workspaceFolder}', project.root);
      if (!path.isAbsolute(executable) && /[\\/]/.test(executable)) executable = path.resolve(project.root, executable);
      const next = new PreviewSession(project, { onPreview: (page, frame) => presentPreview(next, frame, page), executable, environment: settings.get('environment', {}), startupTimeoutMs: settings.get('startupTimeoutMs', 120000) });
      next.on('log', text => output.append(text));
      next.on('failure', error);
      next.on('rendering', ({ language, renderId, background }) => {
        if (session !== next || !panel || next.file !== requestedFile) return;
        if (background && shellKey) {
          cancelPresentation();
          void panel.webview.postMessage({ type: 'background-start', file: next.file, generation, renderId });
        } else loading(next.file);
        status.text = `$(${background ? 'globe' : 'sync~spin'}) Markit: ${language}`;
        status.tooltip = `Rendering preview · ${path.basename(next.file)}\n${activeProject.title} · ${activeProject.id}`;
        status.command = 'markit.selectLanguage'; status.show();
      });
      next.on('updated', () => { if (session === next && panel && requestedFile === next.file && lastDocument?.uri.fsPath === next.file) void showPage(lastDocument).catch(error); });
      session = next; activeProject = project;
      editScheduler = new EditScheduler({
        debounceMs: settings.get('debounceMs', 120),
        run: async (file, text) => {
          const epoch = editEpoch;
          await next.pending.catch(() => {});
          if (session === next && panel?.visible && epoch === editEpoch) return next.update(file, text);
        },
        onError: failure => { if (session === next) error(failure); }
      });
      try { await next.start(language, buffers(project.root), document.uri.fsPath); }
      catch (failure) { if (session === next) { cancelEdits(); session = undefined; } await next.dispose(); throw failure; }
      if (ticket !== generation || !panel || !panel.visible) return;
    }
    await session.selectDocument(document.uri.fsPath);
    await showPage(document);
  }
  function follow(document, explicit = false) {
    if (!document || document.uri.scheme !== 'file' || document.languageId !== 'markdown') return Promise.resolve();
    // Cancel immediately, not after the serialized open queue finishes the old parse.
    if (explicit && panel && !panel.visible) panel.reveal(vscode.ViewColumn.Beside, true);
    const changed = requestedFile !== document.uri.fsPath;
    if (changed) { editEpoch++; editScheduler?.cancel(); }
    requestedFile = document.uri.fsPath;
    const ticket = ++generation;
    viewRevision++; cancelPresentation();
    if (changed || session?.child) session?.cancelRender();
    if (changed || !session?.current || session.current.file !== requestedFile) loading(requestedFile);
    return queue(() => open(document, explicit, ticket));
  }
  function sync(file, text) {
    if (!session || !inside(session.project.root, file)) return;
    if (path.relative(session.project.root, file).split(path.sep).some(part => EXCLUDED.has(part))) return;
    if (file.endsWith(STATE_FILE)) return;
    const current = session;
    current.setBuffer(file, text);
    editScheduler?.schedule(file, text);
  }

  context.subscriptions.push(output, status,
    vscode.commands.registerCommand('markit.showLogs', () => output.show(true)),
    vscode.commands.registerCommand('markit.preview', async uri => {
      const document = uri ? await vscode.workspace.openTextDocument(uri) : vscode.window.activeTextEditor?.document || lastDocument;
      return follow(document, true);
    }),
    vscode.commands.registerCommand('markit.selectLanguage', () => queue(async () => {
      if (!session || !activeProject) return;
      const current = session;
      const language = await languageFor(activeProject, true);
      if (session !== current || !language || language === current.language) return;
      editEpoch++; editScheduler?.cancel();
      status.text = '$(sync~spin) Markit';
      await session.pending;
      await session.switchLanguage(language);
      await showPage(lastDocument);
    })),
    vscode.commands.registerCommand('markit.refresh', () => queue(async () => {
      if (session) { await session.pending; await session.switchLanguage(session.language); await showPage(lastDocument); }
    })),
    vscode.commands.registerCommand('markit.selectExecutable', async () => {
      const selected = await vscode.window.showOpenDialog({ canSelectMany: false, canSelectFiles: true, canSelectFolders: false, title: 'Select the Markit executable' });
      if (selected?.length) {
        const resource = lastDocument?.uri || vscode.window.activeTextEditor?.document.uri;
        const target = resource && vscode.workspace.getWorkspaceFolder(resource) ? vscode.ConfigurationTarget.WorkspaceFolder : vscode.ConfigurationTarget.Global;
        await vscode.workspace.getConfiguration('markit', resource).update('executablePath', selected[0].fsPath, target);
        if (lastDocument) { activeProject = undefined; await follow(lastDocument, true); }
      }
    }),
    vscode.window.onDidChangeActiveTextEditor(editor => {
      if (editor?.document.languageId === 'markdown') void follow(editor.document);
    }),
    vscode.workspace.onDidChangeTextDocument(event => {
      if (event.document.uri.scheme !== 'file' || !event.contentChanges.length) return;
      if (panel && session?.file === event.document.uri.fsPath) {
        void panel.webview.postMessage({ type: 'source-edits', file: session.file,
          changes: event.contentChanges.map(change => ({ startLine: change.range.start.line, endLine: change.range.end.line, startCharacter: change.range.start.character, text: change.text })) });
      }
      sync(event.document.uri.fsPath, event.document.getText());
    }),
    vscode.window.onDidChangeTextEditorVisibleRanges(event => sendEditorScroll(event.textEditor)),
    vscode.window.onDidChangeTextEditorSelection(event => {
      const editor = event.textEditor, echoes = selectionEchoes.get(editor) || [];
      const index = echoes.indexOf(selectionKey(editor, event.selections || editor.selections));
      const userGesture = event.kind === vscode.TextEditorSelectionChangeKind.Mouse || event.kind === vscode.TextEditorSelectionChangeKind.Keyboard;
      const echo = index >= 0 && !userGesture;
      if (echo) echoes.splice(index, 1); else selectionEchoes.delete(editor);
      sendEditorSelection(editor, event.kind !== undefined && !echo);
    }),
    vscode.workspace.onDidChangeWorkspaceFolders(() => { projects = undefined; }),
    vscode.workspace.onDidChangeConfiguration(event => {
      if (event.affectsConfiguration('markit') && lastDocument) { activeProject = undefined; void follow(lastDocument, Boolean(panel)); }
    })
  );
  const watcher = vscode.workspace.createFileSystemWatcher('**/*');
  const diskChange = async uri => {
    if (/^markit(?:\.[\w-]+)?\.json$/i.test(path.basename(uri.fsPath))) projects = undefined;
    if (!session || !inside(session.project.root, uri.fsPath)) return;
    try { if (!(await fs.stat(uri.fsPath)).isFile()) return; } catch (failure) { if (failure.code !== 'ENOENT') return; }
    const dirty = vscode.workspace.textDocuments.find(doc => doc.uri.fsPath === uri.fsPath && doc.isDirty);
    sync(uri.fsPath, dirty?.getText());
  };
  context.subscriptions.push(watcher, watcher.onDidCreate(diskChange), watcher.onDidChange(diskChange), watcher.onDidDelete(diskChange));
  shutdown = async () => {
    stopped = true; generation++; cancelPresentation();
    cancelEdits();
    await session?.dispose();
  };
  context.subscriptions.push({ dispose() { void shutdown().catch(() => {}); } });
  if (vscode.window.activeTextEditor?.document.languageId === 'markdown') void follow(vscode.window.activeTextEditor.document);
}

module.exports = { activate, deactivate: () => shutdown?.() };
