'use strict';

const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { loadNodeCliSession } = require('./helpers/node-cli-session');
const PreviewSession = loadNodeCliSession('fake-markit.js');

const source = '# 中文 heading\n\nFirst viewport.\n\n[forward][ref]\n\n[ref]: https://example.com\n';
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const deferred = () => { let resolve; const promise = new Promise(done => { resolve = done; }); return { promise, resolve }; };

// This intentionally small executable exercises the real pipe/process lifecycle without
// requiring a native build, VS Code, or a browser. Native parser equality has separate tests.
const fakeCli = `
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const readline = require('node:readline');
const args = process.argv.slice(2);
const value = key => args[args.indexOf(key) + 1];
const source = fs.readFileSync(value('--page'), 'utf8');
const output = value('-o');
fs.mkdirSync(output, { recursive: true });
const mode = process.env.MARKIT_FAKE_MODE || 'normal';
const html = '<html><head><title>Preview</title></head><body class="document-mode"><div class="content"><script id="markit-page-markdown-source">' + Buffer.from(mode === 'stale' ? 'different source' : source).toString('hex') + '</script></div></body></html>';
const frame = data => {
  const bytes = Buffer.from('MARKIT_PREVIEW\\t' + JSON.stringify(data) + '\\n');
  if (mode === 'fragmented') {
    for (let index = 0; index < bytes.length; index++) process.stdout.write(bytes.subarray(index, index + 1));
  } else process.stdout.write(bytes);
};
const input = readline.createInterface({ input: process.stdin });
let stage = 0;
input.on('line', line => {
  if (line !== 'ack') process.exit(4);
  fs.appendFileSync(path.join(output, 'acks'), line + '\\n');
  if (stage++ === 0) {
    frame({ type:'preview', operations:[{id:1,kind:'append',html:mode === 'fragmented' ? '<h1>甲😀</h1>' : '<h1>First viewport</h1>'}], consumedBytes:32,totalBytes:Buffer.byteLength(source) });
  } else {
    fs.writeFileSync(path.join(output, 'finished'), 'complete');
    input.close();
    process.exit(0);
  }
});
process.stderr.write('diagnostic on stderr\\n');
process.stdout.write('ordinary build log\\n');
if (mode === 'malformed') process.stdout.write('MARKIT_PREVIEW\\t{not-json}\\n');
else if (mode === 'missing-shell') frame({type:'preview',operations:[]});
else if (mode === 'invalid') frame({type:'preview',operations:'wrong'});
else if (mode === 'exit-error') process.exit(7);
else if (mode === 'timeout') {} // Keep stdin alive until killed by the host.
else frame({type:'preview',operations:[],consumedBytes:0,totalBytes:Buffer.byteLength(source),shell:html});
`;

async function fixture(t, options = {}) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'markit-stream-test-'));
  const executable = path.join(root, 'fake-markit.js');
  await fs.writeFile(executable, fakeCli, { mode: 0o755 });
  const session = new PreviewSession({ root, variants: [] }, {
    executable, startupTimeoutMs: 3000, ...options
  });
  session.file = path.join(root, 'source.md');
  session.snapshot = root;
  session.output = path.join(root, 'output');
  session.assets = path.join(root, 'assets');
  session.runtimeConfig = path.join(root, 'markit.json');
  session.language = 'zh';
  session.buffers = new Map([[session.file, source]]);
  session.fullBuild = true;
  await fs.writeFile(session.file, source);
  session.pageMetadata = () => ({file:session.file,language:session.language,root,input:root,
    output:session.output,outputFile:path.join(session.output,'source.html'),assets:session.assets,temp:root});
  let published = 0;
  session.readPage = async () => {
    assert.equal(await fs.readFile(path.join(session.output, 'finished'), 'utf8'), 'complete', 'final page is read only after native completion');
    return { ...session.pageMetadata(), markdown: source, body: '<h1>Final resolved output</h1>', offsets: [0] };
  };
  session.publish = async page => { published++; session.current = page; session.emit('updated', page); };
  t.after(async () => { await session.dispose(); await fs.rm(root, {recursive:true,force:true}); });
  return { session, root, published: () => published };
}

async function exists(file) { try { await fs.access(file); return true; } catch (error) { if (error.code === 'ENOENT') return false; throw error; } }

test('progressive callback precedes completion and ACK provides real producer backpressure', { timeout: 10000 }, async t => {
  const entered = deferred(), release = deferred(), frames = [], logs = [];
  const { session, published } = await fixture(t, { onPreview: async (page, frame) => {
    frames.push(frame);
    assert.equal(page.markdown, source);
    assert.equal(page.file, session.file);
    assert.equal(frame.renderId, session.renderId);
    if (frame.batchId === 1) { entered.resolve(); await release.promise; }
  }});
  session.on('log', text => logs.push(text));
  const rendering = session.render();
  await entered.promise;
  await delay(40);
  assert.equal(frames.length, 1, 'producer cannot deliver its next batch before presentation resolves');
  assert.equal(published(), 0);
  assert.equal(await exists(path.join(session.output, 'finished')), false);
  assert.equal(await exists(path.join(session.output, 'acks')), false);
  assert(session.child?.pid, 'real subprocess still runs while the shell is presented');
  release.resolve();
  await rendering;
  assert.equal(frames.length, 2);
  assert.deepEqual(frames.map(frame => frame.batchId), [1, 2]);
  assert.equal(frames[1].operations[0].html, '<h1>First viewport</h1>');
  assert.equal(await fs.readFile(path.join(session.output, 'acks'), 'utf8'), 'ack\nack\n');
  assert.equal(published(), 1);
  assert.equal(session.fullBuild, false);
  assert.equal(session.child, undefined);
  assert.match(logs.join(''), /diagnostic on stderr/);
  assert.match(logs.join(''), /ordinary build log/);
  assert.doesNotMatch(logs.join(''), /MARKIT_PREVIEW/);
});

test('canceling an outstanding presentation suppresses ACK and stale publication; next render works', { timeout: 10000 }, async t => {
  const entered = deferred(), release = deferred();
  const { session, published } = await fixture(t, { onPreview: async () => { entered.resolve(); await release.promise; } });
  const rendering = session.render();
  await entered.promise;
  const oldId = session.renderId;
  session.cancelRender();
  release.resolve();
  await rendering;
  assert(session.renderId > oldId);
  assert.equal(published(), 0);
  assert.equal(await exists(path.join(session.output, 'acks')), false);
  assert.equal(await exists(path.join(session.output, 'finished')), false);
  session.options.onPreview = async () => {};
  await session.render();
  assert.equal(published(), 1);
  assert(session.current.renderId > oldId);
});

test('real pipe preserves fragmented UTF-8 frames through the Node fixture launcher', { timeout: 10000 }, async t => {
  const frames = [];
  const { session, published } = await fixture(t, {
    environment: { MARKIT_FAKE_MODE: 'fragmented' },
    onPreview: async (_page, frame) => frames.push(frame)
  });
  await session.render();
  assert.equal(frames.length, 2);
  assert.deepEqual(frames.map(frame => frame.batchId), [1, 2]);
  assert.equal(frames[1].operations[0].html, '<h1>甲😀</h1>');
  assert.equal(await fs.readFile(path.join(session.output, 'acks'), 'utf8'), 'ack\nack\n');
  assert.equal(published(), 1);
  assert.equal(session.child, undefined);
});

test('each repeated render starts fresh batch IDs and advances render identity', { timeout: 10000 }, async t => {
  const identities = [];
  const { session, published } = await fixture(t, { onPreview: async (_page, frame) => identities.push([frame.renderId, frame.batchId]) });
  await session.render();
  await session.render();
  assert.deepEqual(identities, [[1,1],[1,2],[2,1],[2,2]]);
  assert.equal(published(), 2);
});

for (const [mode, expected] of [
  ['malformed', /JSON|Unexpected|property name/i],
  ['missing-shell', /omitted its shell/],
  ['invalid', /Invalid Markit preview stream frame/],
  ['stale', /stale preview source map/],
  ['exit-error', /Markit exited \(7\)/],
  ['timeout', /Timed out rendering/]
]) {
  test(`stream failure ${mode} rejects, clears child and never publishes`, { timeout: 10000 }, async t => {
    const { session, published } = await fixture(t, { environment: {MARKIT_FAKE_MODE:mode}, startupTimeoutMs: mode === 'timeout' ? 100 : 3000 });
    await assert.rejects(session.render(), expected);
    assert.equal(published(), 0);
    assert.equal(session.child, undefined);
  });
}

test('presentation rejection terminates the waiting producer and never publishes', {timeout:10000}, async t => {
  const {session,published} = await fixture(t,{onPreview:async()=>{throw new Error('webview disposed');}});
  await assert.rejects(session.render(), /webview disposed/);
  assert.equal(published(),0);
  assert.equal(session.child,undefined);
});

test('source changes while rendering cancel the obsolete stream without publishing', {timeout:10000}, async t => {
  const { session, published } = await fixture(t, { onPreview: async (_page, frame) => {
    if (frame.batchId === 1) session.setBuffer(session.file, source + '\nnew edit\n');
  }});
  await session.render();
  assert.equal(published(), 0);
  assert.equal(session.child, undefined);
});

for (const action of ['cancel', 'dispose', 'timeout']) {
  test(`${action} unblocks a presentation whose webview ACK never arrives`, {timeout:10000}, async t => {
    const entered = deferred();
    const {session,published} = await fixture(t, {
      startupTimeoutMs: action === 'timeout' ? 300 : 3000,
      onPreview: async () => { entered.resolve(); await new Promise(() => {}); }
    });
    const rendering = session.render();
    // Install a rejection handler before the timeout can fire.
    const result = action === 'timeout' ? assert.rejects(rendering, /Timed out rendering/) : rendering;
    await entered.promise;
    if (action === 'cancel') session.cancelRender();
    if (action === 'dispose') await session.dispose();
    await result;
    assert.equal(published(),0);
    assert.equal(session.child,undefined);
  });
}

test('spawn failure rejects cleanly without a lingering child', {timeout:10000}, async t => {
  const {session,published,root} = await fixture(t);
  session.options.executable = path.join(root,'nonexistent-command');
  await assert.rejects(session.render(), {code:'ENOENT'});
  assert.equal(published(),0);
  assert.equal(session.child,undefined);
});

test('explicit negative presentation acknowledgement cancels without reporting a render error', {timeout:10000}, async t => {
  const {session,published} = await fixture(t,{onPreview:async()=>false});
  await session.render();
  assert.equal(published(),0);
  assert.equal(session.child,undefined);
});

test('initial configuration finishes before a concurrent edit is rendered', {timeout:10000}, async t => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(),'markit-stream-start-test-'));
  const file = path.join(root,'source.md');
  await fs.writeFile(file,source);
  const entered = deferred(), release = deferred(), renders = [];
  const session = new PreviewSession({root,file:path.join(root,'markit.json'),variants:[]},{});
  let configured = false;
  session.configure = async () => { entered.resolve(); await release.promise; configured = true; };
  session.render = async () => { renders.push({configured,text:await session.source(file)}); };
  t.after(async()=>{release.resolve();await session.dispose();await fs.rm(root,{recursive:true,force:true});});
  const started = session.start('en',[],file);
  await entered.promise;
  session.cancelRender();
  const edit = session.update(file,source+'\nLATEST EDIT\n');
  await delay(30);
  const premature = renders.length;
  release.resolve();
  await Promise.all([started,edit]);
  assert.equal(premature,0,'no child may spawn while initial runtime configuration is incomplete');
  assert(renders.length > 0);
  assert(renders.every(render=>render.configured));
  assert.match(renders.at(-1).text,/LATEST EDIT/);
});

test('an interrupted switch cannot reuse another file with identical Markdown', {timeout:10000}, async t => {
  const {session,root} = await fixture(t);
  const oldFile = path.join(root,'old.md');
  session.current = {file:oldFile,language:session.language,markdown:source,renderId:0};
  let configured = 0, rendered = 0;
  session.configure = async () => {configured++;};
  session.render = async () => {rendered++;};
  await session.selectDocument(session.file);
  assert.equal(configured,1);
  assert.equal(rendered,1);
});

for (const boundary of ['source','asset-copy']) {
  test(`cancellation during publication ${boundary} cannot publish stale content`, {timeout:10000}, async t => {
    const {session} = await fixture(t);
    const entered = deferred(), release = deferred();
    session.config = {};
    session.renderId = 8;
    const page = {file:session.file,language:session.language,markdown:source,renderId:8};
    let updates = 0;
    session.on('updated',()=>updates++);
    if (boundary === 'source') session.source = async () => {entered.resolve();await release.promise;return source;};
    else t.mock.method(fs,'cp',async()=>{entered.resolve();await release.promise;});
    const publishing = PreviewSession.prototype.publish.call(session,page);
    await entered.promise;
    session.cancelRender();
    release.resolve();
    await publishing;
    assert.equal(updates,0);
    assert.equal(session.current,undefined);
    assert.equal(session.assetKey,undefined);
  });
}

for (const action of ['document','language']) {
  test(`${action} reconfiguration finishes before a concurrent edit render`, {timeout:10000}, async t => {
    const {session} = await fixture(t);
    const entered = deferred(), release = deferred(), renders = [];
    let configured = false;
    session.configure = async()=>{entered.resolve();await release.promise;configured=true;};
    session.render = async()=>{renders.push(configured);};
    const changing = action === 'document' ? session.selectDocument(session.file) : session.switchLanguage('en');
    await entered.promise;
    const edit = session.update(session.file,source+'\nLatest edit\n');
    await delay(30);
    const premature = renders.length;
    release.resolve();
    await Promise.all([changing,edit]);
    assert.equal(premature,0);
    assert(renders.length>0);
    assert(renders.every(Boolean));
  });
}

test('completed same-page edits consume progressive frames in background and publish only final content', async t => {
  const frames = [], modes = [];
  const { session, published } = await fixture(t, { onPreview: (page, frame) => frames.push(frame) });
  session.on('rendering', event => modes.push(event.background));
  await session.render({ background: true });
  assert.equal(modes.at(-1), false, 'an edit during first load still needs progressive content');
  assert.equal(frames.length, 2);
  frames.length = 0;
  const old = session.current;
  session.readPage = async () => { assert.equal(session.current, old, 'old coherent page remains until completion'); return { ...old, markdown: source }; };
  await session.render({ background: true });
  assert.equal(modes.at(-1), true);
  assert.equal(frames.length, 0, 'no shell or partial batches replace the displayed article');
  assert.equal(published(), 2);
  assert.equal(session.current.background, true);
  assert.equal((await fs.readFile(path.join(session.output, 'acks'), 'utf8')).trim().split('\n').length, 4);
});

test('background errors retain the previous page and foreground replacement requires streaming until complete', async t => {
  const frames = [];
  const { session } = await fixture(t, { onPreview: (page, frame) => frames.push(frame) });
  await session.render(); const old = session.current;
  session.options.environment = { MARKIT_FAKE_MODE: 'exit-error' };
  await assert.rejects(session.render({ background: true }), /Markit exited/);
  assert.equal(session.current, old);
  session.options.environment = {};
  session.foregroundPending = true; frames.length = 0;
  await session.render({ background: true });
  assert.equal(session.current.background, false, 'canceled foreground has no complete currently visible article');
  assert.equal(frames.length, 2);
});


test('reverting a canceled background render republishes the retained page to settle its status', async t => {
  const { session } = await fixture(t);
  await session.render();
  const retained = session.current;
  const started = deferred();
  session.on('rendering', event => { if (event.background) started.resolve(event); });
  session.options.environment = { MARKIT_FAKE_MODE: 'timeout' };
  const changed = session.update(session.file, source + '\nChanged B\n');
  const background = await started.promise;
  session.setBuffer(session.file, source); // real host immediately cancels outdated work
  session.cancelRender();
  await changed;
  const updates = [];
  session.on('updated', page => updates.push(page));
  await session.update(session.file, source);
  assert.equal(updates.length, 1, 'no-op revert still supplies final settlement');
  assert.equal(session.current.body, retained.body);
  assert.equal(session.current.markdown, source);
  assert.equal(session.current.background, true);
  assert.equal(session.current.renderId, session.renderId);
  assert(session.current.renderId > background.renderId);
  await session.update(session.file, source);
  assert.equal(updates.length, 1, 'ordinary duplicate saves do not republish');
});
