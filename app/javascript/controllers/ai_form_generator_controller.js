import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="ai-form-generator"
export default class extends Controller {
  static targets = ["submitButton", "progressIndicator", "statusMessage", "errorContainer"]
  static values = { 
    submitUrl: String,
    redirectUrl: String,
    timeout: { type: Number, default: 120000 } // 2 minutes default timeout
  }

  connect() {
    this.isSubmitting = false
    this.setupFormValidation()
  }

  setupFormValidation() {
    // Listen for validation events from other controllers
    this.element.addEventListener('form-preview:updated', this.handleValidationUpdate.bind(this))
    this.element.addEventListener('file-upload:fileSelected', this.handleFileSelection.bind(this))
    this.element.addEventListener('file-upload:fileCleared', this.handleFileCleared.bind(this))
  }

  handleSubmit(event) {
    event.preventDefault()
    
    if (this.isSubmitting) {
      return
    }

    // Get the form that triggered the submission
    this.currentForm = event.target.closest('form')
    if (!this.currentForm) {
      console.error('No form found for submission')
      return
    }

    if (!this.validateForm()) {
      return
    }

    this.startSubmission()
  }

  validateForm() {
    if (!this.currentForm) {
      this.showError('Form not found')
      return false
    }

    // Get current form data
    const formData = new FormData(this.currentForm)
    const prompt = formData.get('prompt')
    const document = formData.get('document')

    // Check if we have either prompt or document
    if (!prompt?.trim() && (!document || document.size === 0)) {
      this.showError('Please provide either a text prompt or upload a document.')
      return false
    }

    // Validate prompt length if provided
    if (prompt?.trim()) {
      const wordCount = this.countWords(prompt.trim())
      if (wordCount < 10) {
        this.showError('Prompt must be at least 10 words long.')
        return false
      }
      if (wordCount > 5000) {
        this.showError('Prompt must be less than 5000 words.')
        return false
      }
    }

    return true
  }

  startSubmission() {
    this.isSubmitting = true
    this.updateSubmitButton(true)
    this.showProgressIndicator()
    this.clearErrors()
    
    // Set up timeout
    this.timeoutId = setTimeout(() => {
      this.handleTimeout()
    }, this.timeoutValue)

    // Submit the form
    this.submitForm()
  }

  async submitForm() {
    try {
      const formData = new FormData(this.currentForm)
      
      // Use the form's action if submitUrlValue is not set
      const submitUrl = this.submitUrlValue || this.currentForm.action
      
      const response = await fetch(submitUrl, {
        method: 'POST',
        body: formData,
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': this.getCSRFToken(),
          'Accept': 'application/json'
        }
      })

      // Log response details for debugging
      console.log('Response status:', response.status)
      console.log('Response headers:', Object.fromEntries(response.headers.entries()))

      if (response.ok) {
        // Check if response is JSON
        const contentType = response.headers.get('content-type')
        if (contentType && contentType.includes('application/json')) {
          const result = await response.json()
          this.handleSuccess(result)
        } else {
          // If not JSON, it might be a redirect or HTML error page
          const text = await response.text()
          console.log('Non-JSON response:', text.substring(0, 500))
          this.handleError({ error: 'Server returned unexpected response format' })
        }
      } else {
        // Handle different error status codes
        await this.handleHttpError(response)
      }
    } catch (error) {
      console.error('Fetch error:', error)
      this.handleNetworkError(error)
    } finally {
      this.cleanup()
    }
  }

  async handleHttpError(response) {
    try {
      const contentType = response.headers.get('content-type')
      
      if (contentType && contentType.includes('application/json')) {
        const errorData = await response.json()
        this.handleError(errorData)
      } else {
        // Server returned HTML error page (common with 422/500 errors)
        const errorText = await response.text()
        console.log('HTML error response:', errorText.substring(0, 1000))
        
        // Try to extract meaningful error from HTML
        const errorMessage = this.extractErrorFromHtml(errorText) || 
                             `Server error (${response.status}): ${response.statusText}`
        
        this.handleError({ error: errorMessage })
      }
    } catch (parseError) {
      console.error('Error parsing error response:', parseError)
      this.handleError({ 
        error: `Server error (${response.status}): Unable to parse error details` 
      })
    }
  }

  extractErrorFromHtml(htmlText) {
    // Try to extract error message from Rails error pages
    const errorPatterns = [
      /<div[^>]*class="[^"]*exception[^"]*"[^>]*>([^<]+)/i,
      /<h1[^>]*>([^<]+)<\/h1>/i,
      /<title>([^<]+)<\/title>/i,
      /ActiveRecord::RecordInvalid:\s*(.+?)(?:\n|<)/i,
      /Validation failed:\s*(.+?)(?:\n|<)/i
    ]
    
    for (const pattern of errorPatterns) {
      const match = htmlText.match(pattern)
      if (match && match[1]) {
        return match[1].trim()
      }
    }
    
    return null
  }

  handleSuccess(result) {
    this.updateStatusMessage('Form generated successfully!', 'success')
    
    // Show the loading overlay while redirecting
    this.showGlobalLoadingOverlay()
    
    // Redirect after a short delay to show success message
    setTimeout(() => {
      if (result.redirect_url) {
        window.location.href = result.redirect_url
      } else if (this.redirectUrlValue) {
        window.location.href = this.redirectUrlValue
      } else {
        // Fallback: reload the page
        window.location.reload()
      }
    }, 1500)
  }

  handleError(errorData) {
    let errorMessage = 'An error occurred while generating your form.'
    
    if (typeof errorData === 'string') {
      errorMessage = errorData
    } else if (errorData && typeof errorData === 'object') {
      if (errorData.error) {
        errorMessage = errorData.error
      } else if (errorData.errors && Array.isArray(errorData.errors)) {
        errorMessage = errorData.errors.join(', ')
      } else if (errorData.message) {
        errorMessage = errorData.message
      }
    }
    
    // Clean up error message - ensure it's a string before calling replace
    errorMessage = this.cleanErrorMessage(String(errorMessage))
    
    this.showError(errorMessage)
    this.updateStatusMessage('Generation failed', 'error')
  }

  cleanErrorMessage(message) {
    // Ensure message is a string
    if (typeof message !== 'string') {
      return 'An unknown error occurred'
    }
    
    // Remove technical details that users don't need to see
    return message
      .replace(/ActiveRecord::[A-Za-z]+:\s*/g, '')
      .replace(/Validation failed:\s*/g, '')
      .replace(/undefined method\s+.+?\s+for\s+.+/g, 'Service temporarily unavailable')
      .replace(/\s+/g, ' ')
      .trim()
  }

  handleNetworkError(error) {
    console.error('Network error:', error)
    let errorMessage = 'Network error. Please check your connection and try again.'
    
    if (error.name === 'TypeError' && error.message.includes('Failed to fetch')) {
      errorMessage = 'Unable to connect to server. Please check your internet connection.'
    } else if (error.name === 'AbortError') {
      errorMessage = 'Request was cancelled. Please try again.'
    }
    
    this.showError(errorMessage)
    this.updateStatusMessage('Connection failed', 'error')
  }

  handleTimeout() {
    this.showError('Request timed out. Please try again with shorter content.')
    this.updateStatusMessage('Request timed out', 'error')
    this.cleanup()
  }

  updateSubmitButton(isLoading) {
    // Find submit button in the current form
    const submitButton = this.currentForm?.querySelector('input[type="submit"], button[type="submit"]')
    if (!submitButton) return

    if (isLoading) {
      submitButton.disabled = true
      submitButton.classList.add('opacity-75', 'cursor-not-allowed')
      
      // Update button text with loading indicator
      const originalText = submitButton.textContent || submitButton.value
      submitButton.dataset.originalText = originalText
      
      if (submitButton.tagName === 'INPUT') {
        submitButton.value = 'Generating...'
      } else {
        submitButton.innerHTML = `
          <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white inline" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          Generating...
        `
      }
    } else {
      submitButton.disabled = false
      submitButton.classList.remove('opacity-75', 'cursor-not-allowed')
      
      // Restore original text
      const originalText = submitButton.dataset.originalText
      if (originalText) {
        if (submitButton.tagName === 'INPUT') {
          submitButton.value = originalText
        } else {
          submitButton.textContent = originalText
        }
      }
    }
  }

  showProgressIndicator() {
    if (this.hasProgressIndicatorTarget) {
      this.progressIndicatorTarget.classList.remove('hidden')
      this.progressIndicatorTarget.classList.add('animate-fade-in')
    }
  }

  hideProgressIndicator() {
    if (this.hasProgressIndicatorTarget) {
      this.progressIndicatorTarget.classList.add('hidden')
      this.progressIndicatorTarget.classList.remove('animate-fade-in')
    }
  }

  showGlobalLoadingOverlay() {
    // Show the AI processing overlay that's already in your HTML
    const overlay = document.getElementById('ai-processing-overlay')
    if (overlay) {
      overlay.classList.remove('hidden')
    }
  }

  hideGlobalLoadingOverlay() {
    const overlay = document.getElementById('ai-processing-overlay')
    if (overlay) {
      overlay.classList.add('hidden')
    }
  }

  updateStatusMessage(message, type = 'info') {
    if (!this.hasStatusMessageTarget) return

    this.statusMessageTarget.textContent = message
    this.statusMessageTarget.classList.remove('hidden', 'text-gray-600', 'text-green-600', 'text-red-600', 'text-blue-600')
    
    const colorClass = {
      'success': 'text-green-600',
      'error': 'text-red-600',
      'info': 'text-blue-600',
      'warning': 'text-amber-600'
    }[type] || 'text-gray-600'
    
    this.statusMessageTarget.classList.add(colorClass, 'animate-fade-in')
  }

  showError(message) {
    // Remove existing error messages first
    this.clearErrors()
    
    // Create error element if no target exists
    if (!this.hasErrorContainerTarget) {
      this.createErrorContainer(message)
    } else {
      this.errorContainerTarget.textContent = message
      this.errorContainerTarget.classList.remove('hidden')
      this.errorContainerTarget.classList.add('animate-fade-in')
    }
  }

  createErrorContainer(message) {
    const errorDiv = document.createElement('div')
    errorDiv.className = 'bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-lg mb-4 animate-fade-in'
    errorDiv.innerHTML = `
      <div class="flex items-center">
        <svg class="w-5 h-5 mr-2 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
        </svg>
        <span>${message}</span>
      </div>
    `
    
    // Insert at the top of the form
    if (this.currentForm) {
      this.currentForm.insertBefore(errorDiv, this.currentForm.firstChild)
      
      // Auto-remove after 8 seconds
      setTimeout(() => {
        errorDiv.remove()
      }, 8000)
    }
  }

  clearErrors() {
    if (this.hasErrorContainerTarget) {
      this.errorContainerTarget.classList.add('hidden')
      this.errorContainerTarget.textContent = ''
    }
    
    // Also remove any dynamically created error messages
    const errors = document.querySelectorAll('.bg-red-50')
    errors.forEach(error => {
      if (error.textContent.includes('Prompt must') || 
          error.textContent.includes('Please provide') ||
          error.textContent.includes('Server error') ||
          error.textContent.includes('Network error')) {
        error.remove()
      }
    })
  }

  cleanup() {
    this.isSubmitting = false
    this.updateSubmitButton(false)
    this.hideProgressIndicator()
    this.hideGlobalLoadingOverlay()
    this.currentForm = null
    
    if (this.timeoutId) {
      clearTimeout(this.timeoutId)
      this.timeoutId = null
    }
  }

  // Validation event handlers
  handleValidationUpdate(event) {
    const { isValid } = event.detail
    this.updateSubmitButtonState(isValid)
  }

  handleFileSelection(event) {
    // File was selected, enable submission if other validations pass
    this.updateSubmitButtonState(true)
  }

  handleFileCleared(event) {
    // File was cleared, check if prompt is valid
    if (!this.currentForm) return
    
    const formData = new FormData(this.currentForm)
    const prompt = formData.get('prompt')
    const isValid = prompt?.trim() && this.countWords(prompt.trim()) >= 10
    this.updateSubmitButtonState(isValid)
  }

  updateSubmitButtonState(isValid) {
    const submitButton = this.currentForm?.querySelector('input[type="submit"], button[type="submit"]')
    if (submitButton && !this.isSubmitting) {
      submitButton.disabled = !isValid
      if (isValid) {
        submitButton.classList.remove('opacity-50', 'cursor-not-allowed')
      } else {
        submitButton.classList.add('opacity-50', 'cursor-not-allowed')
      }
    }
  }

  // Utility methods
  countWords(text) {
    if (!text) return 0
    return text.split(/\s+/).filter(word => word.length > 0).length
  }

  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ''
  }

  // Public method to trigger submission (for external use)
  submit() {
    if (!this.isSubmitting && this.currentForm) {
      this.handleSubmit(new Event('submit'))
    }
  }

  // Public method to reset form state
  reset() {
    this.cleanup()
    this.clearErrors()
    if (this.hasStatusMessageTarget) {
      this.statusMessageTarget.classList.add('hidden')
    }
  }

  disconnect() {
    this.cleanup()
  }
}