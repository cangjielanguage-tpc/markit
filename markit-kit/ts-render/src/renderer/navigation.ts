/**
 * Navigation functionality
 */

/**
 * Toggle folder in navigation
 */
export function toggleFolder(folderId: string): void {
  const element = document.getElementById(folderId);
  if (!element) return;

  const folderElement = element.previousElementSibling;

  if (element.classList.contains('collapsed')) {
    element.classList.remove('collapsed');
    element.classList.add('expanded');
    if (folderElement) {
      folderElement.classList.remove('collapsed');
    }
  } else {
    element.classList.remove('expanded');
    element.classList.add('collapsed');
    if (folderElement) {
      folderElement.classList.add('collapsed');
    }
  }
}

/**
 * Toggle floating table of contents
 */
export function toggleFloatingToc(): void {
  const content = document.getElementById('floating-toc-content');
  const toggle = document.querySelector('.floating-toc-toggle');

  if (!content || !toggle) return;

  if (content.classList.contains('collapsed')) {
    content.classList.remove('collapsed');
    toggle.textContent = '−';
  } else {
    content.classList.add('collapsed');
    toggle.textContent = '+';
  }
}

function syncFloatingTocForViewport(): void {
  const content = document.getElementById('floating-toc-content');
  const toggle = document.querySelector('.floating-toc-toggle');

  if (!content || !toggle) return;

  if (window.innerWidth > 1500 && content.classList.contains('collapsed')) {
    content.classList.remove('collapsed');
    toggle.textContent = '−';
  }
}

/**
 * Toggle sidebar visibility
 */
export function toggleSidebar(): void {
  const sidebar = document.getElementById('sidebar');
  const container = document.querySelector('.website-container');
  const toggleBtn = document.getElementById('sidebar-toggle');

  if (!sidebar) return;

  if (sidebar.classList.contains('collapsed')) {
    sidebar.classList.remove('collapsed');
    container?.classList.remove('sidebar-collapsed');
    if (toggleBtn) {
      toggleBtn.dataset.tooltip = 'Hide sidebar';
    }
  } else {
    sidebar.classList.add('collapsed');
    container?.classList.add('sidebar-collapsed');
    if (toggleBtn) {
      toggleBtn.dataset.tooltip = 'Show sidebar';
    }
  }
}

/**
 * Initialize navigation functionality
 */
export function initializeNavigation(): void {
  // Check if sidebar is empty (homepage)
  const sidebar = document.getElementById('sidebar');
  const sidebarNav = sidebar?.querySelector('.sidebar-nav');

  if (sidebarNav && sidebarNav.innerHTML.trim() === '') {
    document.body.classList.add('homepage');
    return;
  }

  // Setup sidebar toggle
  const sidebarToggle = document.getElementById('sidebar-toggle');
  if (sidebarToggle) {
    sidebarToggle.addEventListener('click', toggleSidebar);
  }

  // Setup floating TOC toggle
  const tocToggle = document.querySelector('.floating-toc-toggle');
  if (tocToggle) {
    tocToggle.addEventListener('click', toggleFloatingToc);
  }
  window.addEventListener('resize', syncFloatingTocForViewport);
  syncFloatingTocForViewport();

  // 为每个导航分组标题添加点击事件
  const sectionTitles = document.querySelectorAll('.nav-section-title');
  sectionTitles.forEach((title) => {
    title.addEventListener('click', (e) => {
      // 如果点击的是链接，不处理折叠
      const target = e.target as HTMLElement;
      if (target.tagName === 'A' || target.closest('a')) {
        return;
      }
      
      e.preventDefault();
      e.stopPropagation();
      const section = title.closest('.nav-section');
      section?.classList.toggle('collapsed');
    });
  });

  // Initialize TOC highlighting
  initializeTocHighlighting();
}

/**
 * Initialize table of contents highlighting
 */
function initializeTocHighlighting(): void {
  const tocLinks = document.querySelectorAll('.floating-toc-link');
  const headings = document.querySelectorAll('h1, h2, h3, h4, h5, h6');

  if (tocLinks.length === 0 || headings.length === 0) return;

  function updateActiveTocLink() {
    let activeHeadingId = '';
    const scrollTop = window.pageYOffset;

    headings.forEach((heading) => {
      if ((heading as HTMLElement).offsetTop <= scrollTop + 100) {
        activeHeadingId = (heading as HTMLElement).id;
      }
    });

    tocLinks.forEach((link) => link.classList.remove('active'));

    if (activeHeadingId !== '') {
      const activeLink = document.querySelector(
        `.floating-toc-link[href="#${activeHeadingId}"]`
      );
      if (activeLink) {
        activeLink.classList.add('active');

        // Auto-scroll TOC container
        const tocContent = document.getElementById('floating-toc-content');
        if (tocContent) {
          const linkTop = (activeLink as HTMLElement).offsetTop;
          const linkHeight = (activeLink as HTMLElement).offsetHeight;
          const containerHeight = tocContent.clientHeight;
          const containerScrollTop = tocContent.scrollTop;

          if (linkTop < containerScrollTop) {
            tocContent.scrollTo({
              top: linkTop - 20,
              behavior: 'smooth',
            });
          } else if (linkTop + linkHeight > containerScrollTop + containerHeight) {
            tocContent.scrollTo({
              top: linkTop - containerHeight + linkHeight + 20,
              behavior: 'smooth',
            });
          }
        }
      }
    }
  }

  window.addEventListener('scroll', updateActiveTocLink);
  updateActiveTocLink();
}
