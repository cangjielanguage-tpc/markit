let mathCopyInitialized = false;

export function initializeMathCopy(): void {
  if (mathCopyInitialized || typeof document === 'undefined') {
    return;
  }

  document.addEventListener('copy', (event) => {
    const selection = window.getSelection();
    if (!selection || selection.rangeCount === 0 || selection.isCollapsed) {
      return;
    }

    const formulas = selectedMathElements(selection);
    if (formulas.length === 0) {
      return;
    }

    const tex = formulas
      .map((element) => texForMathElement(element))
      .filter((value): value is string => Boolean(value))
      .join('\n');
    if (!tex) {
      return;
    }

    event.clipboardData?.setData('text/plain', tex);
    event.preventDefault();
  });

  mathCopyInitialized = true;
}

function selectedMathElements(selection: Selection): HTMLElement[] {
  const all = Array.from(document.querySelectorAll<HTMLElement>('.katex'));
  const result: HTMLElement[] = [];

  for (const element of all) {
    if (selectionIntersectsElement(selection, element)) {
      result.push(element);
    }
  }

  return result;
}

function selectionIntersectsElement(selection: Selection, element: HTMLElement): boolean {
  for (let i = 0; i < selection.rangeCount; i++) {
    const range = selection.getRangeAt(i);
    if (range.intersectsNode(element)) {
      return true;
    }
  }
  return false;
}

function texForMathElement(element: HTMLElement): string | null {
  const dataTex = element.dataset.tex;
  if (dataTex) {
    return dataTex;
  }

  const annotation = element.querySelector('annotation[encoding="application/x-tex"]');
  return annotation?.textContent || null;
}
