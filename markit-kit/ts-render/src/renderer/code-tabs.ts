/**
 * Code Block Tabs
 * Handles tab switching for grouped code blocks
 */

/**
 * Initialize code block tabs
 */
export function initializeCodeTabs(): void {
  const codeGroups = document.querySelectorAll('.code-block-group');
  
  codeGroups.forEach((group) => {
    setupCodeGroup(group as HTMLElement);
  });
}

/**
 * Setup a single code group
 */
function setupCodeGroup(group: HTMLElement): void {
  const tabs = group.querySelectorAll('.code-tab');
  const panels = group.querySelectorAll('.code-panel');
  
  tabs.forEach((tab) => {
    tab.addEventListener('click', () => {
      const tabIndex = tab.getAttribute('data-tab');
      if (!tabIndex) return;
      
      // Remove active class from all tabs and panels
      tabs.forEach((t) => t.classList.remove('active'));
      panels.forEach((p) => p.classList.remove('active'));
      
      // Add active class to clicked tab and corresponding panel
      tab.classList.add('active');
      const targetPanel = group.querySelector(`.code-panel[data-panel="${tabIndex}"]`);
      if (targetPanel) {
        targetPanel.classList.add('active');
      }
    });
  });
  
  // Add file extension class to icons for CSS styling
  tabs.forEach((tab) => {
    const fileNameElement = tab.querySelector('.file-name');
    const iconElement = tab.querySelector('.file-icon');
    
    if (fileNameElement && iconElement) {
      const fileName = fileNameElement.textContent || '';
      const ext = fileName.split('.').pop()?.toLowerCase();
      if (ext) {
        iconElement.classList.add(`icon-${ext}`);
      }
    }
  });
}
