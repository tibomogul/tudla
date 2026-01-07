import { Controller } from "@hotwired/stimulus"

// Manages team reports list with configurable word limit and modal display
export default class extends Controller {
  static targets = ["content", "wordLimit", "modal", "modalContent", "modalTitle"]
  static values = {
    defaultWordLimit: { type: Number, default: 50 }
  }

  connect() {
    console.log('[TeamReports] Controller connected')
    this.loadWordLimit()
    console.log('[TeamReports] Word limit:', this.defaultWordLimitValue)
    this.truncateAllContent()
  }

  // Load word limit from localStorage
  loadWordLimit() {
    const savedLimit = localStorage.getItem('teamReportsWordLimit')
    if (savedLimit) {
      const limitValue = parseInt(savedLimit, 10)
      this.defaultWordLimitValue = limitValue
      if (this.hasWordLimitTarget) {
        // Set the select value, defaulting to 50 if not found
        const selectElement = this.wordLimitTarget
        const optionExists = Array.from(selectElement.options).some(option => 
          parseInt(option.value, 10) === limitValue
        )
        if (optionExists) {
          selectElement.value = limitValue
        }
      }
    }
  }

  // Update word limit and save to localStorage
  updateWordLimit(event) {
    const newLimit = parseInt(event.target.value, 10)
    if (!isNaN(newLimit) && newLimit > 0) {
      this.defaultWordLimitValue = newLimit
      localStorage.setItem('teamReportsWordLimit', newLimit)
      this.truncateAllContent()
    }
  }

  // Truncate all content elements
  truncateAllContent() {
    this.contentTargets.forEach(element => {
      this.truncateContent(element)
    })
  }

  // Truncate a single content element using pre-rendered markdown
  truncateContent(element) {
    console.log('[TeamReports] Truncating content element')
    const fullText = element.dataset.fullContent
    const fullHtml = element.dataset.fullHtml
    
    console.log('[TeamReports] fullText length:', fullText?.length, 'fullHtml length:', fullHtml?.length)
    
    // Check if data is available
    if (!fullText || !fullHtml) {
      console.error('[TeamReports] Missing data attributes for truncation', element)
      element.innerHTML = '<p class="text-error">Error: Missing content data</p>'
      return
    }
    
    const words = fullText.trim().split(/\s+/)
    const wordLimit = this.defaultWordLimitValue
    
    console.log('[TeamReports] Word count:', words.length, 'Word limit:', wordLimit)
    
    if (words.length > wordLimit) {
      // Select the closest pre-rendered truncated version
      let truncatedHtml
      
      if (wordLimit <= 25) {
        truncatedHtml = element.dataset.truncated25
        console.log('[TeamReports] Using truncated-25, value:', truncatedHtml)
      } else if (wordLimit <= 50) {
        truncatedHtml = element.dataset.truncated50
        console.log('[TeamReports] Using truncated-50, value:', truncatedHtml?.substring(0, 100))
      } else if (wordLimit <= 100) {
        truncatedHtml = element.dataset.truncated100
        console.log('[TeamReports] Using truncated-100, value:', truncatedHtml?.substring(0, 100))
      } else if (wordLimit <= 200) {
        truncatedHtml = element.dataset.truncated200
        console.log('[TeamReports] Using truncated-200')
      } else if (wordLimit <= 500) {
        truncatedHtml = element.dataset.truncated500
        console.log('[TeamReports] Using truncated-500')
      } else {
        // For limits > 500, show full content
        truncatedHtml = fullHtml
        console.log('[TeamReports] Using full HTML')
      }
      
      // Fallback if truncated version doesn't exist or is empty
      if (!truncatedHtml || truncatedHtml.trim() === '') {
        console.warn(`[TeamReports] Missing or empty truncated-${wordLimit} data attribute, using full HTML`)
        console.log('[TeamReports] Actual value was:', JSON.stringify(truncatedHtml))
        truncatedHtml = fullHtml
      }
      
      console.log('[TeamReports] Setting innerHTML, length:', truncatedHtml?.length)
      element.innerHTML = truncatedHtml
    } else {
      // Show full content as rendered markdown
      console.log('[TeamReports] Content under limit, using full HTML')
      element.innerHTML = fullHtml
    }
  }

  // Open modal with full report
  openModal(event) {
    event.preventDefault()
    const button = event.currentTarget
    const reportId = button.dataset.reportId
    const userName = button.dataset.userName
    const asOfDate = button.dataset.asOfDate
    const contentHtml = button.dataset.reportContentHtml

    this.modalTitleTarget.textContent = `Report by ${userName} - ${asOfDate}`
    this.modalContentTarget.innerHTML = contentHtml
    this.modalTarget.classList.remove('hidden')
    this.modalTarget.classList.add('flex')
    
    // Prevent body scroll when modal is open
    document.body.style.overflow = 'hidden'
  }

  // Close modal
  closeModal(event) {
    if (event) {
      event.preventDefault()
    }
    
    this.modalTarget.classList.add('hidden')
    this.modalTarget.classList.remove('flex')
    
    // Restore body scroll
    document.body.style.overflow = ''
  }

  // Close modal when clicking backdrop
  closeOnBackdrop(event) {
    if (event.target === event.currentTarget) {
      this.closeModal(event)
    }
  }

  // Close modal on Escape key
  handleKeydown(event) {
    if (event.key === 'Escape') {
      this.closeModal(event)
    }
  }
}
