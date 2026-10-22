'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { EditScheduler } = require('../src/edit-scheduler');

function clock() {
  let time = 0, id = 0;
  const timers = new Map();
  return { timers, now: () => time,
    setTimeout(fn, delay) { const key = ++id; timers.set(key, { fn, at: time + delay }); return key; },
    clearTimeout(key) { timers.delete(key); },
    async tick(ms) {
      for (let i = 0; i < 8; i++) await Promise.resolve();
      const target = time + ms;
      for (;;) {
        const next = [...timers].filter(([, timer]) => timer.at <= target).sort((a, b) => a[1].at - b[1].at)[0];
        if (!next) break;
        time = next[1].at; timers.delete(next[0]); next[1].fn();
        for (let i = 0; i < 8; i++) await Promise.resolve();
      }
      time = target;
      for (let i = 0; i < 8; i++) await Promise.resolve();
    }
  };
}

test('quiet bursts debounce latest text and throttle consecutive starts', async () => {
  const c = clock(), calls = [], s = new EditScheduler({ clock: c, run: (key, value) => calls.push([c.now(), key, value]) });
  s.schedule('a', 'first'); await c.tick(80); s.schedule('a', 'latest');
  await c.tick(119); assert.deepEqual(calls, []);
  await c.tick(1); assert.deepEqual(calls, [[200, 'a', 'latest']]);
  s.schedule('a', 'next'); await c.tick(249); assert.equal(calls.length, 1);
  await c.tick(1); assert.deepEqual(calls[1], [450, 'a', 'next']);
  assert.equal(c.timers.size, 0);
});

test('continuous typing has bounded max wait and a trailing latest update', async () => {
  const c = clock(), calls = [], s = new EditScheduler({ clock: c, run: (key, value) => calls.push([c.now(), value]) });
  for (let n = 0; n < 24; n++) { s.schedule('a', n); await c.tick(50); }
  await c.tick(500);
  assert.deepEqual(calls, [[500, 9], [1000, 19], [1270, 23]]);
  assert.equal(c.timers.size, 0);
});

test('slow updates retain only latest pending values and never overlap', async () => {
  const c = clock(), calls = []; let finish, active = 0;
  const s = new EditScheduler({ clock: c, run: (key, value) => {
    assert.equal(active++, 0); calls.push([key, value]);
    return new Promise(resolve => { finish = () => { active--; resolve(); }; });
  } });
  s.schedule('a', 'first'); await c.tick(120);
  for (let n = 0; n < 50; n++) { s.schedule('a', n); await c.tick(20); }
  s.schedule('b', 'other'); await c.tick(500);
  assert.equal(calls.length, 1); assert.equal(s.pending.size, 2); assert.equal(c.timers.size, 0);
  finish(); await c.tick(0); await c.tick(0);
  assert.deepEqual(calls[1], ['a', 49]);
  finish(); await c.tick(250);
  assert.deepEqual(calls[2], ['b', 'other']);
  finish(); await c.tick(500); assert.equal(c.timers.size, 0);
});

test('cancel/dispose remove timers and ignore late completion and errors', async () => {
  const c = clock(), calls = [], errors = []; let reject;
  const s = new EditScheduler({ clock: c, run: key => { calls.push(key); return new Promise((_, fail) => { reject = fail; }); }, onError: e => errors.push(e) });
  s.schedule('a', 1); s.cancel(); await c.tick(1000); assert.equal(calls.length, 0);
  s.schedule('b', 1); await c.tick(120); s.schedule('c', 1); s.dispose();
  reject(new Error('late')); await c.tick(1000); s.schedule('d', 1); await c.tick(1000);
  assert.deepEqual(calls, ['b']); assert.deepEqual(errors, []); assert.equal(c.timers.size, 0); assert.equal(s.pending.size, 0);
});

test('large configured debounce is respected and errors do not strand trailing edits', async () => {
  const c = clock(), calls = [], errors = [];
  const s = new EditScheduler({ clock: c, debounceMs: 1000, run: (key, value) => { calls.push([c.now(), value]); if (value === 1) throw new Error('failed'); }, onError: e => errors.push(e.message) });
  s.schedule('a', 1); await c.tick(999); assert.equal(calls.length, 0); await c.tick(1);
  s.schedule('a', 2); await c.tick(999); assert.equal(calls.length, 1); await c.tick(1);
  assert.deepEqual(calls, [[1000, 1], [2000, 2]]); assert.deepEqual(errors, ['failed']); assert.equal(c.timers.size, 0);
});

test('hide pauses timers and canceled in-flight edits resume with latest pending text', async () => {
  const c = clock(), calls = []; let finish;
  const s = new EditScheduler({ clock: c, run: (key, value) => {
    calls.push([key, value]); return new Promise(resolve => { finish = resolve; });
  } });
  s.schedule('a', 'old'); await c.tick(120);
  s.schedule('a', 'latest'); s.pause(); finish(); await c.tick(1000);
  assert.deepEqual(calls, [['a', 'old']]); assert.equal(c.timers.size, 0);
  s.schedule('b', 'hidden change'); await c.tick(1000); assert.equal(c.timers.size, 0);
  s.resume(); await c.tick(0); assert.deepEqual(calls[1], ['a', 'latest']);
  finish(); await c.tick(250); assert.deepEqual(calls[2], ['b', 'hidden change']);
  finish(); await c.tick(0); s.dispose(); assert.equal(c.timers.size, 0);
});

test('a transition-canceled active edit cannot be resurrected by later hide/reveal', async () => {
  const c = clock(), calls = []; let finish;
  const s = new EditScheduler({ clock: c, run: (key, value) => {
    calls.push(value); return new Promise(resolve => { finish = resolve; });
  } });
  s.schedule('a', 'old'); await c.tick(120); s.schedule('a', 'newer');
  s.cancel(); s.pause(); finish(); await c.tick(500); s.resume(); await c.tick(500);
  assert.deepEqual(calls, ['old']); assert.equal(s.pending.size, 0); assert.equal(c.timers.size, 0);
});
