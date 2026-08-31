/**
 * Theme management
 */

export type ThemeMode = 'auto' | 'light' | 'dark';
export type SiteTheme = 'light' | 'dark';

let currentThemeMode: ThemeMode =
  (localStorage.getItem('theme-mode') as ThemeMode) || 'auto';

/**
 * Get current site theme based on mode.
 */
export function getCurrentTheme(): SiteTheme {
  if (currentThemeMode === 'light') {
    return 'light';
  } else if (currentThemeMode === 'dark') {
    return 'dark';
  } else {
    const prefersDark =
      window.matchMedia &&
      window.matchMedia('(prefers-color-scheme: dark)').matches;
    return prefersDark ? 'dark' : 'light';
  }
}

/**
 * Apply theme to document
 */
export async function applyTheme(mode: ThemeMode): Promise<void> {
  currentThemeMode = mode;
  localStorage.setItem('theme-mode', mode);

  const theme = getCurrentTheme();
  document.documentElement.setAttribute('data-theme', theme);

  // Mount pre-rendered light/dark code block HTML stored in data attributes.
  // Import dynamically to avoid circular dependency.
  const { mountCodehlBlocks } = await import('../code-blocks/index.js');
  mountCodehlBlocks();

  // Update theme toggle button
  updateThemeToggleButton();

  // Trigger re-render event
  window.dispatchEvent(new CustomEvent('theme-changed', { detail: { theme } }));
}

/**
 * Update theme toggle button state
 */
function updateThemeToggleButton(): void {
  const button = document.getElementById('theme-toggle');
  if (!button) return;

  button.classList.remove('auto-mode');

  if (currentThemeMode === 'auto') {
    button.classList.add('auto-mode');
  }

  let tooltipText = '';
  switch (currentThemeMode) {
    case 'light':
      tooltipText = 'Switch to dark theme';
      break;
    case 'dark':
      tooltipText = 'Switch to auto theme';
      break;
    case 'auto':
      tooltipText = 'Switch to light theme';
      break;
  }
  button.dataset.tooltip = tooltipText;
}

/**
 * Setup theme toggle functionality
 */
export function setupThemeToggle(): void {
  const button = document.getElementById('theme-toggle');
  if (button) {
    button.addEventListener('click', async () => {
      // Cycle through themes: auto -> light -> dark -> auto
      const modes: ThemeMode[] = ['auto', 'light', 'dark'];
      const currentIndex = modes.indexOf(currentThemeMode);
      const nextMode = modes[(currentIndex + 1) % modes.length];
      await applyTheme(nextMode);
    });

    updateThemeToggleButton();
  }

  // Listen for system theme changes when in auto mode
  if (window.matchMedia) {
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', async () => {
      if (currentThemeMode === 'auto') {
        await applyTheme('auto');
      }
    });
  }

  // Update search shortcut hint based on OS
  updateSearchShortcut();
}

/**
 * Update search shortcut hint based on OS
 */
function updateSearchShortcut(): void {
  const isMac = navigator.platform.toUpperCase().indexOf('MAC') >= 0;

  const shortcutHint = document.querySelector('.search-shortcut-hint');
  if (shortcutHint) {
    const keys = shortcutHint.querySelectorAll('.shortcut-key');
    if (keys.length >= 2) {
      (keys[0] as HTMLElement).textContent = isMac ? '⌘' : 'Ctrl';
      (keys[1] as HTMLElement).textContent = 'K';
    }
  }

  const searchTrigger = document.getElementById('search-trigger');
  if (searchTrigger) {
    const lang = document.documentElement.lang.toLowerCase();
    const label = lang.startsWith('zh') ? '搜索' : 'Search';
    searchTrigger.setAttribute('title', isMac ? `${label} (⌘K)` : `${label} (Ctrl+K)`);
    searchTrigger.setAttribute('data-tooltip', isMac ? `${label} (⌘K)` : `${label} (Ctrl+K)`);
  }
}
