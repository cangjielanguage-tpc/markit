/**
 * Search functionality for Markit documentation using FlexSearch
 * Provides section-level search with modal UI
 */

import { Document } from 'flexsearch';

export interface SearchIndexSection {
  id: string;
  title: string;
  content: string;
  url: string;
  pageTitle: string;
  breadcrumb: string[];
}

interface SearchDocument {
  id: string;
  title: string;
  content: string;
  url: string;
  pageTitle: string;
  breadcrumb: string;
  [key: string]: string; // Index signature for FlexSearch
}

const RESULTS_PER_PAGE = 20;
const MAX_RESULTS = 200;

const SEARCH_LOCALES = {
  en: {
    triggerTooltip: 'Search',
    placeholder: 'Search documentation...',
    closeTooltip: 'Close',
    typeToSearch: 'Type to search...',
    loading: 'Loading search index...',
    noResults: 'No results found',
    unavailable: 'Search index not available',
    previous: 'Previous',
    next: 'Next',
    pageInfo: (page: number, totalPages: number, results: number) =>
      `Page ${page} of ${totalPages} (${results} results)`
  },
  zh: {
    triggerTooltip: '搜索',
    placeholder: '搜索文档...',
    closeTooltip: '关闭',
    typeToSearch: '输入关键词搜索...',
    loading: '正在加载搜索索引...',
    noResults: '没有找到结果',
    unavailable: '搜索索引不可用',
    previous: '上一页',
    next: '下一页',
    pageInfo: (page: number, totalPages: number, results: number) =>
      `第 ${page} / ${totalPages} 页，共 ${results} 条结果`
  }
} as const;

type SearchLocale = typeof SEARCH_LOCALES.en;

let searchIndex: Document<SearchDocument>;
let allSections: SearchIndexSection[] = [];
let currentResults: SearchIndexSection[] = [];
let currentPage = 1;
let currentQuery = '';
let isIndexLoaded = false;
let isIndexLoading = false;

function currentLocale(): SearchLocale {
  const lang = (document.documentElement.lang || '').toLowerCase();
  if (lang.startsWith('zh')) {
    return SEARCH_LOCALES.zh;
  }
  return SEARCH_LOCALES.en;
}

function shortcutLabel(): string {
  const isMac = navigator.platform.toUpperCase().indexOf('MAC') >= 0;
  return isMac ? '⌘K' : 'Ctrl+K';
}

function hintHtml(className: string, text: string): string {
  return `<div class="${className}">${escapeHtml(text)}</div>`;
}

/**
 * Initialize FlexSearch index
 */
function initializeIndex() {
  searchIndex = new Document<SearchDocument>({
    document: {
      id: 'id',
      index: ['title', 'content', 'breadcrumb'],
      store: ['title', 'content', 'url', 'pageTitle', 'breadcrumb']
    },
    tokenize: 'forward',
    context: {
      resolution: 9,
      depth: 3,
      bidirectional: true
    }
  });
}

/**
 * Load search index from embedded data
 * This will be called by the dynamically loaded search-index.js
 */
export function loadSearchIndex(data: SearchIndexSection[]): void {
  allSections = data;
  initializeIndex();
  
  // Add all sections to FlexSearch index
  for (const section of data) {
    searchIndex.add({
      id: section.id,
      title: section.title,
      content: section.content,
      url: section.url,
      pageTitle: section.pageTitle,
      breadcrumb: section.breadcrumb.join(' > ')
    });
  }
  
  isIndexLoaded = true;
  isIndexLoading = false;
  console.log(`Search index loaded: ${data.length} sections`);
}

/**
 * Dynamically load search index script
 */
async function loadSearchIndexScript(): Promise<void> {
  if (isIndexLoaded || isIndexLoading) {
    return;
  }
  
  isIndexLoading = true;
  
  return new Promise((resolve, reject) => {
    const script = document.createElement('script');
    
    // Calculate path to root directory
    const currentPath = window.location.pathname;
    const depth = (currentPath.match(/\//g) || []).length - 1;
    const rootPath = depth > 0 ? '../'.repeat(depth) : './';
    
    script.src = rootPath + 'js/search-index.js';
    script.async = true;
    
    script.onload = () => {
      console.log('Search index script loaded');
      resolve();
    };
    
    script.onerror = () => {
      isIndexLoading = false;
      console.warn('Search index file not found - search functionality disabled');
      // 不抛出错误，优雅地处理
      resolve();
    };
    
    document.head.appendChild(script);
  });
}

/**
 * Perform search and return results
 */
export function performSearch(query: string): SearchIndexSection[] {
  if (!query || query.trim().length === 0) {
    console.log('Empty query');
    return [];
  }
  
  const results = searchIndex.search(query, {
    limit: MAX_RESULTS,
    enrich: true
  });
  
  // FlexSearch returns results grouped by field, we need to merge them
  const resultMap = new Map<string, SearchIndexSection>();
  
  for (const fieldResult of results) {
    if (fieldResult.result) {
      for (const item of fieldResult.result) {
        // item.id contains the document id directly
        const docId = item.id as string;
        
        const section = allSections.find(s => s.id === docId);
        if (section && !resultMap.has(section.id)) {
          resultMap.set(section.id, section);
        }
      }
    }
  }
  
  const finalResults = Array.from(resultMap.values()).slice(0, MAX_RESULTS);
  
  return finalResults;
}

/**
 * Highlight search query in text
 */
function highlightText(text: string, query: string): string {
  if (!query || query.trim().length === 0) {
    return escapeHtml(text);
  }
  
  // Escape the text first
  const escapedText = escapeHtml(text);
  
  // Split query into words for multi-word highlighting
  const queryWords = query.trim().split(/\s+/).filter(w => w.length > 0);
  
  let result = escapedText;
  for (const word of queryWords) {
    // Escape special regex characters
    const escapedWord = word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    // Create case-insensitive regex
    const regex = new RegExp(`(${escapedWord})`, 'gi');
    // Replace with highlighted version
    result = result.replace(regex, '<mark class="search-highlight">$1</mark>');
  }
  
  return result;
}

/**
 * Render search results
 */
function renderResults(results: SearchIndexSection[], page: number = 1, query: string = '') {
  const resultsContainer = document.getElementById('search-modal-results');
  const footer = document.getElementById('search-modal-footer');
  const pageInfo = document.getElementById('search-page-info');
  const prevBtn = document.getElementById('search-prev-page') as HTMLButtonElement;
  const nextBtn = document.getElementById('search-next-page') as HTMLButtonElement;
  
  if (!resultsContainer) return;
  
  currentResults = results;
  currentPage = page;
  
  if (results.length === 0) {
    resultsContainer.innerHTML = hintHtml('search-no-results', currentLocale().noResults);
    if (footer) footer.style.display = 'none';
    return;
  }
  
  // Calculate pagination
  const totalPages = Math.ceil(results.length / RESULTS_PER_PAGE);
  const startIdx = (page - 1) * RESULTS_PER_PAGE;
  const endIdx = Math.min(startIdx + RESULTS_PER_PAGE, results.length);
  const pageResults = results.slice(startIdx, endIdx);
  
  // Render results
  const resultsHtml = pageResults.map(section => {
    // Strip HTML tags from breadcrumb items
    const plainBreadcrumb = section.breadcrumb.map(item => stripHtmlTags(item));
    const breadcrumbHtml = plainBreadcrumb.length > 0 
      ? `<div class="search-result-breadcrumb">${escapeHtml(plainBreadcrumb.join(' > '))}</div>`
      : '';
    
    // Strip HTML tags from content for display
    const plainContent = stripHtmlTags(section.content);
    const excerpt = plainContent.length > 150 
      ? plainContent.substring(0, 150) + '...'
      : plainContent;
    
    // Strip HTML tags from title as well
    const plainTitle = stripHtmlTags(section.title);
    
    // Highlight query in title and excerpt
    const highlightedTitle = highlightText(plainTitle, query);
    const highlightedExcerpt = highlightText(excerpt, query);
    
    // Calculate absolute URL from root directory
    let relativeUrl = section.url;
    
    // Skip if it's already an absolute URL
    if (!relativeUrl.startsWith('http://') && !relativeUrl.startsWith('https://')) {
      // Read root path from meta tag
      const rootMeta = document.querySelector('meta[name="markit-root"]');
      const rootPath = rootMeta?.getAttribute('content') || './';
      relativeUrl = rootPath + relativeUrl;
    }
    
    return `
      <a href="${escapeHtml(relativeUrl)}" class="search-result-item">
        <div class="search-result-title">${highlightedTitle}</div>
        ${breadcrumbHtml}
        <div class="search-result-excerpt">${highlightedExcerpt}</div>
      </a>
    `;
  }).join('');
  
  resultsContainer.innerHTML = resultsHtml;
  
  // Update pagination
  if (footer && pageInfo && prevBtn && nextBtn) {
    footer.style.display = totalPages > 1 ? 'flex' : 'none';
    pageInfo.textContent = currentLocale().pageInfo(page, totalPages, results.length);
    prevBtn.disabled = page === 1;
    nextBtn.disabled = page === totalPages;
  }
}

function applySearchLocale(): void {
  const locale = currentLocale();
  const shortcut = shortcutLabel();

  const trigger = document.getElementById('search-trigger');
  if (trigger) {
    trigger.setAttribute('data-tooltip', `${locale.triggerTooltip} (${shortcut})`);
    trigger.setAttribute('title', `${locale.triggerTooltip} (${shortcut})`);
    trigger.setAttribute('aria-label', `${locale.triggerTooltip} (${shortcut})`);
  }

  const input = document.getElementById('search-modal-input') as HTMLInputElement | null;
  if (input) {
    input.placeholder = locale.placeholder;
    input.setAttribute('aria-label', locale.placeholder);
  }

  const closeBtn = document.getElementById('search-modal-close');
  if (closeBtn) {
    closeBtn.setAttribute('data-tooltip', `${locale.closeTooltip} (Esc)`);
    closeBtn.setAttribute('title', `${locale.closeTooltip} (Esc)`);
    closeBtn.setAttribute('aria-label', `${locale.closeTooltip} (Esc)`);
  }

  const prevBtn = document.getElementById('search-prev-page') as HTMLButtonElement | null;
  if (prevBtn) {
    prevBtn.textContent = locale.previous;
  }

  const nextBtn = document.getElementById('search-next-page') as HTMLButtonElement | null;
  if (nextBtn) {
    nextBtn.textContent = locale.next;
  }

  const resultsContainer = document.getElementById('search-modal-results');
  if (resultsContainer && resultsContainer.querySelector('.search-modal-hint')) {
    resultsContainer.innerHTML = hintHtml('search-modal-hint', locale.typeToSearch);
  }
}

/**
 * Initialize search modal event handlers
 */
export function initSearchModal() {
  const modal = document.getElementById('search-modal');
  const input = document.getElementById('search-modal-input') as HTMLInputElement;
  const closeBtn = document.getElementById('search-modal-close');
  const backdrop = document.querySelector('.search-modal-backdrop');
  const prevBtn = document.getElementById('search-prev-page');
  const nextBtn = document.getElementById('search-next-page');
  
  if (!modal) {
    console.warn('Search modal not found in DOM');
    return;
  }

  applySearchLocale();
  
  let debounceTimer: number | null = null;
  
  // Search input handler
  if (input) {
    input.addEventListener('input', (e) => {
      const query = (e.target as HTMLInputElement).value;
      currentQuery = query;
      
      if (debounceTimer) {
        clearTimeout(debounceTimer);
      }
      
      debounceTimer = window.setTimeout(() => {
        if (!isIndexLoaded) return;
        const results = performSearch(query);
        renderResults(results, 1, query);
      }, 300);
    });
  }
  
  // Close modal handlers
  const closeModal = () => {
    if (modal) {
      modal.classList.remove('active');
      document.body.style.overflow = '';
    }
  };
  
  if (closeBtn) {
    closeBtn.addEventListener('click', closeModal);
  }
  
  if (backdrop) {
    backdrop.addEventListener('click', closeModal);
  }
  
  // Escape key to close
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && modal?.classList.contains('active')) {
      closeModal();
    }
  });
  
  // Pagination handlers
  if (prevBtn) {
    prevBtn.addEventListener('click', () => {
      if (currentPage > 1) {
        renderResults(currentResults, currentPage - 1, currentQuery);
      }
    });
  }
  
  if (nextBtn) {
    nextBtn.addEventListener('click', () => {
      const totalPages = Math.ceil(currentResults.length / RESULTS_PER_PAGE);
      if (currentPage < totalPages) {
        renderResults(currentResults, currentPage + 1, currentQuery);
      }
    });
  }
}

/**
 * Open search modal
 */
export async function openSearchModal() {
  const modal = document.getElementById('search-modal');
  const input = document.getElementById('search-modal-input') as HTMLInputElement;
  const resultsContainer = document.getElementById('search-modal-results');
  
  if (!modal) {
    console.warn('Search modal not found');
    return;
  }
  
  modal.classList.add('active');
  document.body.style.overflow = 'hidden';
  
  // Show loading state if index not loaded
  if (!isIndexLoaded && resultsContainer) {
    resultsContainer.innerHTML = hintHtml('search-modal-hint', currentLocale().loading);
  }
  
  // Load search index if not already loaded
  if (!isIndexLoaded) {
    try {
      await loadSearchIndexScript();
      
      // Wait a bit for the script to execute and call loadSearchIndex
      await new Promise(resolve => setTimeout(resolve, 100));
      
      if (resultsContainer) {
        if (isIndexLoaded) {
          resultsContainer.innerHTML = hintHtml('search-modal-hint', currentLocale().typeToSearch);
        } else {
          resultsContainer.innerHTML = hintHtml('search-no-results', currentLocale().unavailable);
        }
      }
    } catch (error) {
      console.error('Failed to load search index:', error);
      if (resultsContainer) {
        resultsContainer.innerHTML = hintHtml('search-no-results', currentLocale().unavailable);
      }
      return;
    }
  }
  
  if (input) {
    input.value = '';
    input.focus();
    
    // Reset results
    if (resultsContainer && isIndexLoaded) {
      resultsContainer.innerHTML = hintHtml('search-modal-hint', currentLocale().typeToSearch);
    }
    
    const footer = document.getElementById('search-modal-footer');
    if (footer) {
      footer.style.display = 'none';
    }
  }
}

/**
 * Escape HTML to prevent XSS
 */
function escapeHtml(text: string): string {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

/**
 * Strip HTML tags from text
 */
function stripHtmlTags(html: string): string {
  const div = document.createElement('div');
  div.innerHTML = html;
  return div.textContent || '';
}

/**
 * Initialize search functionality
 */
export function initSearch() {
  initSearchModal();
  applySearchLocale();
  
  // Bind search trigger buttons
  const searchTriggers = document.querySelectorAll('[data-search-trigger]');
  searchTriggers.forEach(trigger => {
    trigger.addEventListener('click', (e) => {
      e.preventDefault();
      openSearchModal();
    });
  });
  
  // Keyboard shortcut: Ctrl/Cmd + K
  document.addEventListener('keydown', (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
      e.preventDefault();
      openSearchModal();
    }
  });
}

// Export for global access
if (typeof window !== 'undefined') {
  (window as any).MarkitSearch = {
    init: initSearch,
    open: openSearchModal,
    loadIndex: loadSearchIndex  // Called by search-index.js
  };
  
  // Auto-initialize on DOMContentLoaded
  window.addEventListener('DOMContentLoaded', () => {
    initSearch();
  });
}
