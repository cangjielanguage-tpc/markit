type MermaidViewState = {
  scale: number;
  x: number;
  y: number;
  dragging: boolean;
  dragStartX: number;
  dragStartY: number;
  startX: number;
  startY: number;
};

const MIN_SCALE = 0.5;
const MAX_SCALE = 3;
const ZOOM_STEP = 0.2;
const PAN_STEP = 56;

const stateMap = new WeakMap<HTMLElement, MermaidViewState>();

export function initializeMermaidViewer(): void {
  const containers = document.querySelectorAll<HTMLElement>('.mk-mermaid-container[data-mermaid4cj="native"]');
  containers.forEach(setupMermaidViewer);
}

function setupMermaidViewer(container: HTMLElement): void {
  if (container.dataset.mermaidViewer === 'ready') {
    return;
  }

  const diagrams = getDiagrams(container);
  if (diagrams.length === 0) {
    return;
  }

  container.dataset.mermaidViewer = 'ready';
  container.classList.add('mk-mermaid-interactive');
  container.tabIndex = container.tabIndex >= 0 ? container.tabIndex : 0;

  const state: MermaidViewState = {
    scale: 1,
    x: 0,
    y: 0,
    dragging: false,
    dragStartX: 0,
    dragStartY: 0,
    startX: 0,
    startY: 0,
  };
  stateMap.set(container, state);

  container.appendChild(createControls(container));
  applyTransform(container);
  setupPointerPan(container);
  setupWheelZoom(container);
  setupKeyboardPan(container);
}

function getDiagrams(container: HTMLElement): HTMLElement[] {
  return Array.from(container.querySelectorAll<HTMLElement>('.mk-mermaid-diagram'));
}

function createControls(container: HTMLElement): HTMLElement {
  const controls = document.createElement('div');
  controls.className = 'mk-mermaid-controls';
  controls.setAttribute('aria-label', 'Mermaid diagram controls');

  const zoomIn = createButton('Zoom in', iconZoomIn(), () => zoom(container, ZOOM_STEP));
  const zoomOut = createButton('Zoom out', iconZoomOut(), () => zoom(container, -ZOOM_STEP));
  const reset = createButton('Reset view', iconReset(), () => resetView(container));
  const left = createButton('Pan left', iconChevronLeft(), () => pan(container, PAN_STEP, 0));
  const right = createButton('Pan right', iconChevronRight(), () => pan(container, -PAN_STEP, 0));
  const up = createButton('Pan up', iconChevronUp(), () => pan(container, 0, PAN_STEP));
  const down = createButton('Pan down', iconChevronDown(), () => pan(container, 0, -PAN_STEP));

  controls.appendChild(up);
  controls.appendChild(zoomIn);
  controls.appendChild(left);
  controls.appendChild(reset);
  controls.appendChild(right);
  controls.appendChild(down);
  controls.appendChild(zoomOut);

  return controls;
}

function createButton(label: string, html: string, onClick: () => void): HTMLButtonElement {
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'mk-mermaid-control-btn';
  button.setAttribute('aria-label', label);
  button.title = label;
  button.innerHTML = html;
  button.addEventListener('click', (event) => {
    event.preventDefault();
    event.stopPropagation();
    onClick();
  });
  return button;
}

function zoom(container: HTMLElement, delta: number, origin?: { x: number; y: number }): void {
  const state = stateMap.get(container);
  if (!state) {
    return;
  }

  const nextScale = clamp(roundScale(state.scale + delta), MIN_SCALE, MAX_SCALE);
  if (nextScale === state.scale) {
    return;
  }

  if (origin) {
    const ratio = nextScale / state.scale;
    state.x = origin.x - (origin.x - state.x) * ratio;
    state.y = origin.y - (origin.y - state.y) * ratio;
  }
  state.scale = nextScale;
  applyTransform(container);
}

function pan(container: HTMLElement, dx: number, dy: number): void {
  const state = stateMap.get(container);
  if (!state) {
    return;
  }
  state.x += dx;
  state.y += dy;
  applyTransform(container);
}

function resetView(container: HTMLElement): void {
  const state = stateMap.get(container);
  if (!state) {
    return;
  }
  state.scale = 1;
  state.x = 0;
  state.y = 0;
  applyTransform(container);
}

function applyTransform(container: HTMLElement): void {
  const state = stateMap.get(container);
  if (!state) {
    return;
  }
  const transform = `translate(${state.x}px, ${state.y}px) scale(${state.scale})`;
  getDiagrams(container).forEach((diagram) => {
    diagram.style.transform = transform;
  });
  container.dataset.mermaidScale = state.scale.toFixed(2);
}

function setupPointerPan(container: HTMLElement): void {
  container.addEventListener('pointerdown', (event) => {
    const target = event.target as HTMLElement | null;
    if (!target || target.closest('.mk-mermaid-controls')) {
      return;
    }
    const state = stateMap.get(container);
    if (!state) {
      return;
    }

    event.preventDefault();
    state.dragging = true;
    state.dragStartX = event.clientX;
    state.dragStartY = event.clientY;
    state.startX = state.x;
    state.startY = state.y;
    container.classList.add('mk-mermaid-dragging');
    container.setPointerCapture(event.pointerId);
  });

  container.addEventListener('pointermove', (event) => {
    const state = stateMap.get(container);
    if (!state?.dragging) {
      return;
    }
    event.preventDefault();
    state.x = state.startX + event.clientX - state.dragStartX;
    state.y = state.startY + event.clientY - state.dragStartY;
    applyTransform(container);
  });

  const finishDrag = (event: PointerEvent): void => {
    const state = stateMap.get(container);
    if (!state?.dragging) {
      return;
    }
    state.dragging = false;
    container.classList.remove('mk-mermaid-dragging');
    if (container.hasPointerCapture(event.pointerId)) {
      container.releasePointerCapture(event.pointerId);
    }
  };

  container.addEventListener('pointerup', finishDrag);
  container.addEventListener('pointercancel', finishDrag);
  container.addEventListener('selectstart', (event) => {
    const state = stateMap.get(container);
    if (state?.dragging) {
      event.preventDefault();
    }
  });
}

function setupWheelZoom(container: HTMLElement): void {
  container.addEventListener(
    'wheel',
    (event) => {
      if (!event.ctrlKey && !event.metaKey) {
        return;
      }
      event.preventDefault();
      const rect = container.getBoundingClientRect();
      zoom(container, event.deltaY < 0 ? ZOOM_STEP : -ZOOM_STEP, {
        x: event.clientX - rect.left - rect.width / 2,
        y: event.clientY - rect.top - rect.height / 2,
      });
    },
    { passive: false },
  );
}

function setupKeyboardPan(container: HTMLElement): void {
  container.addEventListener('keydown', (event) => {
    if (event.target !== container) {
      return;
    }
    if (event.key === '+') {
      zoom(container, ZOOM_STEP);
    } else if (event.key === '-' || event.key === '_') {
      zoom(container, -ZOOM_STEP);
    } else if (event.key === '0') {
      resetView(container);
    } else if (event.key === 'ArrowLeft') {
      pan(container, PAN_STEP, 0);
    } else if (event.key === 'ArrowRight') {
      pan(container, -PAN_STEP, 0);
    } else if (event.key === 'ArrowUp') {
      pan(container, 0, PAN_STEP);
    } else if (event.key === 'ArrowDown') {
      pan(container, 0, -PAN_STEP);
    } else {
      return;
    }
    event.preventDefault();
  });
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function roundScale(value: number): number {
  return Math.round(value * 100) / 100;
}

function iconChevronUp(): string {
  return icon('<path d="m18 15-6-6-6 6"/>');
}

function iconChevronDown(): string {
  return icon('<path d="m6 9 6 6 6-6"/>');
}

function iconChevronLeft(): string {
  return icon('<path d="m15 18-6-6 6-6"/>');
}

function iconChevronRight(): string {
  return icon('<path d="m9 18 6-6-6-6"/>');
}

function iconZoomIn(): string {
  return icon('<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/><path d="M11 8v6"/><path d="M8 11h6"/>');
}

function iconZoomOut(): string {
  return icon('<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/><path d="M8 11h6"/>');
}

function iconReset(): string {
  return icon('<path d="M8 3H5a2 2 0 0 0-2 2v3"/><path d="M21 8V5a2 2 0 0 0-2-2h-3"/><path d="M3 16v3a2 2 0 0 0 2 2h3"/><path d="M16 21h3a2 2 0 0 0 2-2v-3"/>');
}

function icon(paths: string): string {
  return `<svg aria-hidden="true" focusable="false" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2.25" stroke-linecap="round" stroke-linejoin="round">${paths}</svg>`;
}
