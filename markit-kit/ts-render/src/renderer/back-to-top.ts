/**
 * Back to top button functionality
 */

/**
 * Initialize back to top button functionality
 */
export function initializeBackToTop(): void {
  const backToTopBtn = document.getElementById('back-to-top');
  if (!backToTopBtn) return;
  const button = backToTopBtn;

  // Show/hide button based on scroll position
  function toggleButtonVisibility() {
    if (window.pageYOffset > 300) {
      button.classList.add('visible');
    } else {
      button.classList.remove('visible');
    }
  }

  // Scroll to top smoothly when clicked
  function scrollToTop() {
    window.scrollTo({
      top: 0,
      behavior: 'smooth',
    });
  }

  // Add event listeners
  window.addEventListener('scroll', toggleButtonVisibility, { passive: true });
  button.addEventListener('click', scrollToTop);

  // Initial check
  toggleButtonVisibility();
}
