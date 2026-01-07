import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="theme-dark"
// Applies "dark" class to element when theme is dark
export default class extends Controller {
  connect() {
    this.applyThemeClass()
    // Listen for theme changes
    this.observer = new MutationObserver(() => this.applyThemeClass())
    this.observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['data-theme']
    })
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  applyThemeClass() {
    const theme = localStorage.getItem('theme') || 
                  document.documentElement.dataset.theme ||
                  (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light')
    
    if (theme === 'dark') {
      this.element.classList.add('dark')
    } else {
      this.element.classList.remove('dark')
    }
  }
}
