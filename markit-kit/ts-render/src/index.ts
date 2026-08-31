/**
 * Markit Renderer - Main entry point
 * Re-exports all modules for ES module usage
 */

// Re-export all modules
export * from './search/index.js'
export * from './renderer/index.js'
export * from './code-blocks/index.js'
export * from './language-switcher/index.js'

// Import for side effects (auto-initialization)
import { initialize } from './renderer/index.js'
import { initializeLanguageSwitcher } from './language-switcher/index.js'

// Auto-initialize when DOM is ready
if (typeof window !== 'undefined') {
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
      initialize()
      initializeLanguageSwitcher()
    })
  } else {
    initialize()
    initializeLanguageSwitcher()
  }
}
