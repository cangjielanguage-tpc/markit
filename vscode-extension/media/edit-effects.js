'use strict';

// Grapheme offsets are UTF-16 offsets for DOM Range, never UTF-8 source offsets.
function changedGraphemes(text, previous = '') {
  // Without grapheme segmentation, show final text immediately rather than split
  // combining marks or emoji ZWJ sequences into incorrect visual units.
  if (typeof Intl.Segmenter !== 'function') return [];
  const split = value => [...new Intl.Segmenter(undefined, { granularity: 'grapheme' }).segment(value)];
  const next = split(text), old = split(previous);
  let start = 0, end = next.length, oldEnd = old.length;
  while (start < end && start < oldEnd && next[start].segment === old[start].segment) start++;
  while (end > start && oldEnd > start && next[end - 1].segment === old[oldEnd - 1].segment) { end--; oldEnd--; }
  return next.slice(start, end).map(item => ({ ...item, end: item.index + item.segment.length }));
}
function plainParagraph(node) {
  return node?.nodeName === 'P' && node.childNodes.length === 1 && node.firstChild.nodeType === 3 && node.textContent.length <= 4096;
}
function createEditEffects({ article, environment = window }) {
  const document = environment.document;
  let overlay, frame, animation = 0;
  const cancel = () => {
    animation++;
    if (frame !== undefined) environment.cancelAnimationFrame(frame);
    frame = undefined; overlay?.remove(); overlay = undefined;
  };
  const events = ['pointerdown', 'keydown', 'scroll', 'resize', 'selectionchange', 'visibilitychange', 'pagehide'];
  for (const event of events) environment.addEventListener(event, cancel, true);
  const motion = environment.matchMedia?.('(prefers-reduced-motion: reduce)');
  motion?.addEventListener?.('change', cancel);
  const solidBackground = node => {
    let background;
    for (let current = node; current; current = current.parentElement) {
      const style = environment.getComputedStyle(current);
      // A viewport overlay cannot reproduce transformed or composited text.
      if ((style.opacity && Number(style.opacity) !== 1) || ['filter', 'backdropFilter', 'transform'].some(key => style[key] && style[key] !== 'none') || (style.mixBlendMode && style.mixBlendMode !== 'normal')) return;
      if (background) continue;
      if (style.backgroundImage && style.backgroundImage !== 'none') return;
      const color = style.backgroundColor;
      if (!color || color === 'transparent' || /rgba\([^)]*,\s*0\s*\)/.test(color)) continue;
      if (!/^rgb\([^/]+\)$/.test(color) && !/^rgba\([^/]+,\s*1\s*\)$/.test(color)) return;
      background = color;
    }
    return background;
  };
  function run(changes, enabled = true) {
    cancel();
    if (!enabled || document.hidden || motion?.matches || environment.getSelection?.()?.isCollapsed === false || environment.CSS?.highlights?.get('markit-selection')?.size || changes.length > 4) return false;
    const planned = [];
    let count = 0;
    for (const { node, previousText } of changes) {
      if (!plainParagraph(node) || !article.contains(node)) continue;
      const style = environment.getComputedStyle(node);
      if (style.direction === 'rtl' || (style.writingMode && style.writingMode !== 'horizontal-tb') || (previousText?.length || 0) > 4096) continue;
      const glyphs = changedGraphemes(node.textContent, previousText);
      count += glyphs.length;
      if (count > 256) return false;
      const background = solidBackground(node);
      if (background && glyphs.length) planned.push({ node, glyphs, background });
    }
    if (!planned.length) return false;
    const masks = [], steps = [];
    overlay = document.createElement('div'); overlay.setAttribute('aria-hidden', 'true');
    overlay.style.cssText = 'position:fixed;inset:0;pointer-events:none;z-index:90;overflow:hidden;contain:strict';
    const make = css => { const element = document.createElement('i'); element.style.cssText = css; overlay.append(element); return element; };
    try {
      for (const { node, glyphs, background } of planned) {
        const range = document.createRange();
        for (const glyph of glyphs) {
          range.setStart(node.firstChild, glyph.index); range.setEnd(node.firstChild, glyph.end);
          const group = [];
          for (const rect of range.getClientRects()) {
            if (rect.width <= 0 || rect.height <= 0 || rect.bottom < 0 || rect.top > environment.innerHeight || rect.right < 0 || rect.left > environment.innerWidth) continue;
            if (masks.length >= 320) { cancel(); return false; }
            const mask = make(`position:absolute;left:${rect.left}px;top:${rect.top}px;width:${rect.width}px;height:${rect.height}px;background:${background}`);
            const item = { mask, x: rect.right, y: rect.top, height: rect.height }; masks.push(item); group.push(item);
          }
          if (group.length) steps.push(group);
        }
      }
    } catch { cancel(); return false; }
    if (!steps.length) { cancel(); return false; }
    const caret = make('position:absolute;width:2px;background:var(--vscode-editorCursor-foreground,var(--vscode-editor-foreground,#222));opacity:0');
    document.body.append(overlay);
    const ticket = animation, interval = Math.min(120, 2400 / steps.length), particles = [];
    const colors = ['#38bdf8', '#34d399', '#f472b6', '#fbbf24', '#a78bfa', '#22d3ee'];
    let start, revealed = 0, emitted = 0;
    const tick = now => {
      if (ticket !== animation) return;
      start ??= now;
      const elapsed = now - start, target = Math.min(steps.length, Math.floor(elapsed / interval));
      while (revealed < target) {
        const group = steps[revealed++]; group.forEach(item => item.mask.remove());
        const last = group.at(-1);
        caret.style.left = `${last.x}px`; caret.style.top = `${last.y}px`; caret.style.height = `${last.height}px`; caret.style.opacity = '1';
        const burst = Math.min(4, 72 - emitted);
        for (let index = 0; index < burst; index++, emitted++) {
          const size = 1.5 + (emitted % 4) * 0.6;
          const element = make(`position:absolute;left:${last.x}px;top:${last.y + last.height * .6}px;width:${size}px;height:${size}px;border-radius:50%;background:${colors[emitted % colors.length]}`);
          particles.push({ element, born: elapsed, vx: (emitted % 7 - 3) * 12, vy: -25 - emitted % 5 * 7 });
        }
      }
      for (const particle of particles) {
        const age = elapsed - particle.born, seconds = age / 1000;
        particle.element.style.transform = `translate(${particle.vx * seconds}px,${particle.vy * seconds + 60 * seconds * seconds}px)`;
        particle.element.style.opacity = String(Math.max(0, 1 - age / 450));
      }
      if (revealed === steps.length) caret.style.opacity = '0';
      if (elapsed >= steps.length * interval + 450) { cancel(); return; }
      frame = environment.requestAnimationFrame(tick);
    };
    frame = environment.requestAnimationFrame(tick);
    return true;
  }
  return { run, cancel, dispose() { cancel(); for (const event of events) environment.removeEventListener(event, cancel, true); motion?.removeEventListener?.('change', cancel); } };
}
if (typeof module !== 'undefined') module.exports = { changedGraphemes, plainParagraph, createEditEffects };
if (typeof window !== 'undefined') window.MarkitEditEffects = { create: createEditEffects };
