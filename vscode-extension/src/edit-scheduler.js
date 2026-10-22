'use strict';

// One in-flight update, with at most one trailing value per changed file. A
// quiet period debounces bursts; maxWait prevents continuous typing starving
// the preview; minInterval limits process starts even for fast renders.
class EditScheduler {
  constructor({ run, onError = () => {}, debounceMs = 120, clock = globalThis }) {
    this.run = run;
    this.onError = onError;
    this.delay = Math.max(100, Number(debounceMs) || 120);
    this.interval = Math.max(this.delay, 250);
    this.maxWait = Math.max(this.delay, 500);
    this.clock = clock;
    this.pending = new Map();
    this.lastStart = -Infinity;
    this.running = false;
    this.disposed = false;
  }
  now() { return this.clock.now ? this.clock.now() : Date.now(); }
  schedule(key, value) {
    if (this.disposed) return;
    const now = this.now(), old = this.pending.get(key);
    this.pending.set(key, { value, first: old?.first ?? now, last: now });
    this.arm();
  }
  due(entry) {
    return Math.max(this.lastStart + this.interval,
      Math.min(entry.last + this.delay, entry.first + this.maxWait));
  }
  arm() {
    this.clearTimer();
    if (this.disposed || this.paused || this.running || !this.pending.size) return;
    const due = Math.min(...Array.from(this.pending.values(), entry => this.due(entry)));
    this.timer = this.clock.setTimeout(() => this.start(), Math.max(0, due - this.now()));
  }
  start() {
    this.timer = undefined;
    if (this.disposed || this.paused || this.running) return;
    const ready = [...this.pending].filter(([, entry]) => this.due(entry) <= this.now());
    if (!ready.length) { this.arm(); return; }
    const [key, entry] = ready.sort((a, b) => a[1].first - b[1].first)[0];
    this.pending.delete(key);
    this.active = [key, entry];
    this.running = true;
    this.lastStart = this.now();
    Promise.resolve().then(() => this.disposed ? undefined : this.run(key, entry.value))
      .catch(failure => { if (!this.disposed) this.onError(failure); })
      .finally(() => { this.active = undefined; this.running = false; this.arm(); });
  }
  clearTimer() {
    if (this.timer !== undefined) this.clock.clearTimeout(this.timer);
    this.timer = undefined;
  }
  pause() {
    this.paused = true;
    this.clearTimer();
    // A hidden view cancels its native child; retain the canceled edit unless a
    // newer value for that file is already pending.
    if (this.active && !this.pending.has(this.active[0])) this.pending.set(...this.active);
  }
  resume() { this.paused = false; this.arm(); }
  cancel() { this.clearTimer(); this.pending.clear(); this.active = undefined; }
  dispose() { this.disposed = true; this.cancel(); }
}

module.exports = { EditScheduler };
