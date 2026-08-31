/**
 * Markit Renderer - Modern TypeScript version
 * Handles site UI hydration and theme management.
 *
 * Code blocks keep light/dark HTML in data attributes. The browser only mounts
 * the already generated HTML for the currently active site theme.
 */

import { setupThemeToggle, getCurrentTheme } from './theme';
import { initializeCodeBlocks } from '../code-blocks/index';
import {
  initializeNavigation,
  toggleFolder,
  toggleFloatingToc,
  toggleSidebar,
} from './navigation';
import { initializeBackToTop } from './back-to-top';
import { initializeCodeTabs } from './code-tabs';
import { initializeMathCopy } from './math-copy';
import { initializeMermaidViewer } from './mermaid-viewer';

export * from './languages';
export * from './theme';
export * from './code-actions';
export * from './navigation';
export * from './back-to-top';
export * from './code-tabs';
export * from './math-copy';
export * from './mermaid-viewer';

let isInitialized = false;

/**
 * Initialize the renderer
 */
export async function initialize(): Promise<void> {
  if (isInitialized) return;

  try {
    document.documentElement.setAttribute('data-theme', getCurrentTheme());

    initializeCodeBlocks();

    // Setup UI components
    setupThemeToggle();
    initializeNavigation();
    initializeBackToTop();
    initializeCodeTabs();
    initializeMathCopy();
    initializeMermaidViewer();

    isInitialized = true;
    console.log('Markit renderer initialized successfully');
  } catch (error) {
    console.error('Failed to initialize Markit renderer:', error);
    setupThemeToggle();
  }
}

// Export for manual use
export { toggleFolder, toggleFloatingToc, toggleSidebar };
