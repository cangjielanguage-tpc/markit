import { addCodeActionButtons } from '../renderer/code-actions';
import { normalizeLanguage } from '../renderer/languages';
export function initializeCodeBlocks(): void {
  enhanceAllCodeBlocks();
}

export function mountCodehlBlocks(): void {
  enhanceAllCodeBlocks();
}

export function enhanceAllCodeBlocks(): void {
  const codeBlocks = document.querySelectorAll('pre code');

  for (const codeBlock of codeBlocks) {
    enhanceCodeBlock(codeBlock as HTMLElement);
  }
}

export function enhanceCodeBlock(codeBlock: HTMLElement): void {
  const originalPre = codeBlock.parentElement;
  const lang = languageFromCodeElement(codeBlock, originalPre);

  const normalizedLang = normalizeLanguage(lang);
  if (normalizedLang === 'math' || normalizedLang === 'latex' || normalizedLang === 'mermaid') {
    return;
  }

  if (originalPre) {
    addCodeActionButtons(originalPre, lang);
  }
}

function languageFromCodeElement(codeBlock: HTMLElement, preElement: Element | null): string {
  let lang = 'text';
  let langMatch = codeBlock.className.match(/language-([\w-]+)/);
  if (!langMatch && preElement) {
    langMatch = preElement.className.match(/(?:language-|codehl-lang-)([\w-]+)/);
  }
  if (langMatch) {
    lang = langMatch[1];
  }
  return lang;
}
