/**
 * Language mappings and display names
 */

export const languageDisplayNames: Record<string, string> = {
  bash: 'Shell',
  sh: 'Shell',
  shell: 'Shell',
  markdown: 'Markdown',
  json: 'JSON',
  python: 'Python',
  java: 'Java',
  c: 'C',
  xml: 'XML',
  yaml: 'YAML',
  cangjie: 'Cangjie',
  antlr4: 'ANTLR4',
};

/**
 * Normalize language identifier
 * Handles common aliases and case variations
 */
export function normalizeLanguage(lang: string): string {
  const lower = lang.toLowerCase();
  
  // Cangjie aliases
  if (lower === 'cj' || lower === 'cangjie') {
    return 'cangjie';
  }
  
  // ANTLR4 aliases
  if (lower === 'antlr' || lower === 'g4' || lower === 'antlr4') {
    return 'antlr4';
  }
  
  if (lower === 'sh' || lower === 'shell') {
    return 'bash';
  }
  
  // Return normalized lowercase
  return lower;
}
