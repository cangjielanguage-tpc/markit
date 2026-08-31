/**
 * Language Switcher Module
 * Handles language dropdown interaction and preference storage
 */

/**
 * Save language preference to localStorage
 */
function saveLanguagePreference(lang: string): void {
  localStorage.setItem('preferred-language', lang)
}

/**
 * Initialize language switcher dropdown behavior
 */
export function initializeLanguageSwitcher(): void {
  const toggle = document.querySelector('.language-switcher-toggle') as HTMLButtonElement | null
  const dropdown = document.querySelector('.language-switcher-dropdown') as HTMLElement | null
  
  if (!toggle || !dropdown) {
    return
  }
  
  // Toggle dropdown on button click
  toggle.addEventListener('click', (e) => {
    e.stopPropagation()
    dropdown.classList.toggle('show')
  })
  
  // Close dropdown when clicking outside
  document.addEventListener('click', () => {
    dropdown.classList.remove('show')
  })
  
  // Keyboard navigation support (Enter and Space keys)
  toggle.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault()
      dropdown.classList.toggle('show')
    }
  })
  
  // Add click handlers to language options to save preference
  const languageOptions = dropdown.querySelectorAll('.language-option')
  languageOptions.forEach((option) => {
    option.addEventListener('click', (e) => {
      const target = e.currentTarget as HTMLElement
      const lang = target.getAttribute('data-language')
      if (lang) {
        saveLanguagePreference(lang)
      }
    })
  })
}

// Export for global access (for inline onclick handlers if needed)
if (typeof window !== 'undefined') {
  (window as any).saveLanguagePreference = saveLanguagePreference
}
