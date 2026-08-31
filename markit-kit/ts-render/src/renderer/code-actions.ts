/**
 * Code action buttons (copy, etc.)
 */

import { languageDisplayNames } from './languages';

/**
 * Add action buttons and language label to a code block
 */
export function addCodeActionButtons(preElement: HTMLElement, language: string): void {
  // Check if buttons already exist
  if (preElement.querySelector('.code-actions')) {
    return;
  }

  // Create language label
  if (language !== 'text') {
    const languageLabel = document.createElement('div');
    languageLabel.className = 'code-language';
    languageLabel.textContent = languageDisplayNames[language] || language;
    preElement.appendChild(languageLabel);
  }

  // Create actions container
  const actionsContainer = document.createElement('div');
  actionsContainer.className = 'code-actions';

  // Create copy button
  const copyBtn = document.createElement('button');
  copyBtn.className = 'code-action-btn copy-btn';
  copyBtn.setAttribute('aria-label', 'Copy code to clipboard');
  copyBtn.innerHTML = `<svg aria-hidden="true" focusable="false" class="octicon octicon-copy" viewBox="0 0 16 16" width="16" height="16" fill="currentColor" display="inline-block" overflow="visible" style="vertical-align:text-bottom"><path d="M0 6.75C0 5.784.784 5 1.75 5h1.5a.75.75 0 0 1 0 1.5h-1.5a.25.25 0 0 0-.25.25v7.5c0 .138.112.25.25.25h7.5a.25.25 0 0 0 .25-.25v-1.5a.75.75 0 0 1 1.5 0v1.5A1.75 1.75 0 0 1 9.25 16h-7.5A1.75 1.75 0 0 1 0 14.25Z"></path><path d="M5 1.75C5 .784 5.784 0 6.75 0h7.5C15.216 0 16 .784 16 1.75v7.5A1.75 1.75 0 0 1 14.25 11h-7.5A1.75 1.75 0 0 1 5 9.25Zm1.75-.25a.25.25 0 0 0-.25.25v7.5c0 .138.112.25.25.25h7.5a.25.25 0 0 0 .25-.25v-7.5a.25.25 0 0 0-.25-.25Z"></path></svg>`;

  // Add copy functionality
  copyBtn.addEventListener('click', async () => {
    try {
      const codeElement = preElement.querySelector('code');
      const codeContent = codeElement?.textContent || '';
      await navigator.clipboard.writeText(codeContent);

      // Show feedback
      const originalHTML = copyBtn.innerHTML;

      copyBtn.innerHTML = `<svg aria-hidden="true" focusable="false" viewBox="0 0 16 16" width="16" height="16" fill="currentColor"><path d="M13.78 4.22a.75.75 0 0 1 0 1.06l-7.25 7.25a.75.75 0 0 1-1.06 0L2.22 9.28a.75.75 0 0 1 1.06-1.06L6 10.94l6.72-6.72a.75.75 0 0 1 1.06 0Z"></path></svg>`;
      copyBtn.classList.add('copied');

      setTimeout(() => {
        copyBtn.innerHTML = originalHTML;
        copyBtn.classList.remove('copied');
      }, 2000);
    } catch (error) {
      console.error('Failed to copy code:', error);
    }
  });

  actionsContainer.appendChild(copyBtn);
  preElement.appendChild(actionsContainer);
}

/**
 * Copy markdown source from inline script tag
 */
export function copyMarkdownSource(btn: HTMLElement): void {
  const src = btn.nextElementSibling;
  if (!src || !src.classList.contains('markdown-source')) return;

  const text = src instanceof HTMLTextAreaElement ? src.value : (src.textContent || '');
  navigator.clipboard.writeText(text).then(() => {
    const origHtml = btn.innerHTML;
    btn.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>';
    btn.classList.add('copied');
    btn.dataset.tooltip = 'Copied!';
    setTimeout(() => {
      btn.innerHTML = origHtml;
      btn.classList.remove('copied');
      btn.dataset.tooltip = 'Copy Markdown';
    }, 2000);
  }).catch((e) => {
    console.error('Failed to copy markdown:', e);
  });
}

// Expose to global scope for inline onclick handlers
if (typeof window !== 'undefined') {
  (window as any).copyMarkdownSource = copyMarkdownSource;
}
