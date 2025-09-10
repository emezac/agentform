import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["retryButton", "retryCountdown", "errorMessage"]
  static values = { 
    retryDelay: Number,
    autoRetry: Boolean,
    retryUrl: String,
    maxRetries: Number,
    currentRetries: Number
  }

  connect() {
    this.retryCount = this.currentRetriesValue || 0
    
    if (this.autoRetryValue && this.retryDelayValue > 0) {
      this.startRetryCountdown()
    }
  }

  retry(event) {
    event.preventDefault()
    
    const action = event.target.dataset.action
    
    switch (action) {
      case 'retry':
        this.performRetry()
        break
      case 'switch_input':
        this.switchInputMethod()
        break
      case 'edit_content':
        this.focusContentInput()
        break
      case 'upgrade':
        window.location.href = '/subscriptions/upgrade'
        break
      case 'support':
        window.location.href = '/support'
        break
      case 'show_examples':
        this.showExamples()
        break
      case 'use_template':
        window.location.href = '/templates'
        break
      case 'manual_form':
        window.location.href = '/forms/new'
        break
      case 'view_usage':
        window.location.href = '/profile/usage'
        break
      case 'status_page':
        window.open('https://status.agentform.com', '_blank')
        break
      default:
        this.performRetry()
    }
  }

  performRetry() {
    // Track retry attempt
    this.trackRetryAttempt()
    
    // Disable retry button and show loading state
    if (this.hasRetryButtonTarget) {
      this.retryButtonTarget.disabled = true
      this.retryButtonTarget.innerHTML = `
        <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Retrying...
      `
    }

    // Submit the form again
    const form = this.element.closest('form')
    if (form) {
      form.submit()
    } else {
      // Fallback: reload the page
      window.location.reload()
    }
  }

  switchInputMethod() {
    // Switch between prompt and document tabs
    const tabsController = this.application.getControllerForElementAndIdentifier(
      document.querySelector('[data-controller*="tabs"]'), 
      'tabs'
    )
    
    if (tabsController) {
      // Determine current tab and switch to the other
      const currentTab = document.querySelector('[data-tabs-target="tab"].active')?.dataset.tabName
      const newTab = currentTab === 'prompt' ? 'document' : 'prompt'
      
      // Trigger tab switch
      const newTabButton = document.querySelector(`[data-tab-name="${newTab}"]`)
      if (newTabButton) {
        newTabButton.click()
      }
    }
  }

  focusContentInput() {
    // Focus on the main content input
    const promptInput = document.querySelector('[data-form-preview-target="promptInput"]')
    const documentInput = document.querySelector('[data-file-upload-target="fileInput"]')
    
    if (promptInput && !promptInput.closest('.hidden')) {
      promptInput.focus()
      promptInput.scrollIntoView({ behavior: 'smooth', block: 'center' })
    } else if (documentInput && !documentInput.closest('.hidden')) {
      documentInput.click()
    }
  }

  showExamples() {
    // Show examples modal or navigate to examples page
    const examplesModal = document.querySelector('#examples-modal')
    if (examplesModal) {
      // If modal exists, show it
      examplesModal.classList.remove('hidden')
    } else {
      // Otherwise navigate to examples page
      window.location.href = '/help/examples'
    }
  }

  startRetryCountdown() {
    let remainingTime = this.retryDelayValue
    
    if (this.hasRetryCountdownTarget) {
      this.retryCountdownTarget.textContent = remainingTime
      this.retryCountdownTarget.classList.remove('hidden')
    }

    const countdown = setInterval(() => {
      remainingTime--
      
      if (this.hasRetryCountdownTarget) {
        this.retryCountdownTarget.textContent = remainingTime
      }
      
      if (remainingTime <= 0) {
        clearInterval(countdown)
        this.showAutoRetryPrompt()
      }
    }, 1000)
  }

  showAutoRetryPrompt() {
    if (this.hasRetryCountdownTarget) {
      this.retryCountdownTarget.classList.add('hidden')
    }

    const shouldRetry = confirm(
      'Would you like to automatically retry with optimized settings? ' +
      'This may improve the chances of success.'
    )
    
    if (shouldRetry) {
      this.performRetry()
    }
  }

  trackRetryAttempt() {
    // Track retry attempt for analytics
    if (window.gtag) {
      window.gtag('event', 'retry_attempt', {
        event_category: 'ai_form_generation',
        event_label: 'user_initiated_retry',
        value: this.retryCount + 1
      })
    }

    // Send to backend for tracking
    fetch('/api/v1/analytics/events', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]')?.content
      },
      body: JSON.stringify({
        event_type: 'retry_attempted',
        event_data: {
          retry_count: this.retryCount + 1,
          error_recovery: true,
          timestamp: new Date().toISOString()
        }
      })
    }).catch(error => {
      console.log('Analytics tracking failed:', error)
    })
  }

  // Handle escape key to close error details
  handleKeydown(event) {
    if (event.key === 'Escape') {
      const expandedDetails = this.element.querySelector('.error-details.expanded')
      if (expandedDetails) {
        expandedDetails.classList.remove('expanded')
      }
    }
  }

  // Toggle error details expansion
  toggleDetails(event) {
    event.preventDefault()
    const details = event.target.closest('.error-details')
    if (details) {
      details.classList.toggle('expanded')
    }
  }

  // Copy error details to clipboard for support
  copyErrorDetails(event) {
    event.preventDefault()
    
    const errorDetails = {
      timestamp: new Date().toISOString(),
      error_type: this.element.dataset.errorType,
      retry_count: this.retryCount,
      user_agent: navigator.userAgent,
      url: window.location.href
    }
    
    const errorText = JSON.stringify(errorDetails, null, 2)
    
    if (navigator.clipboard) {
      navigator.clipboard.writeText(errorText).then(() => {
        this.showCopySuccess()
      }).catch(() => {
        this.fallbackCopyToClipboard(errorText)
      })
    } else {
      this.fallbackCopyToClipboard(errorText)
    }
  }

  fallbackCopyToClipboard(text) {
    const textArea = document.createElement('textarea')
    textArea.value = text
    textArea.style.position = 'fixed'
    textArea.style.left = '-999999px'
    textArea.style.top = '-999999px'
    document.body.appendChild(textArea)
    textArea.focus()
    textArea.select()
    
    try {
      document.execCommand('copy')
      this.showCopySuccess()
    } catch (err) {
      console.error('Failed to copy error details:', err)
    }
    
    document.body.removeChild(textArea)
  }

  showCopySuccess() {
    // Show temporary success message
    const successMessage = document.createElement('div')
    successMessage.className = 'fixed top-4 right-4 bg-green-500 text-white px-4 py-2 rounded-md shadow-lg z-50'
    successMessage.textContent = 'Error details copied to clipboard'
    
    document.body.appendChild(successMessage)
    
    setTimeout(() => {
      document.body.removeChild(successMessage)
    }, 3000)
  }
}