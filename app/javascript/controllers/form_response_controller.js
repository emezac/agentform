import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["progressBar", "currentStep", "totalSteps", "nextButton", "prevButton", "submitButton"]
  static values = {
    formId: String,
    sessionId: String,
    responseId: String,
    currentStepIndex: Number,
    totalSteps: Number,
    autoSave: Boolean
  }
  
  connect() {
    this.setupBeforeUnload()
    this.trackPageView()
    this.initializeAutoSave()
    this.updateProgress()
    this.updateNavigationButtons()
  }
  
  disconnect() {
    this.removeBeforeUnload()
    this.clearAutoSaveTimeout()
  }

  // Auto-save functionality
  initializeAutoSave() {
    if (!this.autoSaveValue) return

    this.autoSaveTimeout = null
    this.lastSaveData = null
    
    // Set up auto-save on input changes
    this.element.addEventListener('input', this.handleInputChange.bind(this))
    this.element.addEventListener('change', this.handleInputChange.bind(this))
  }

  handleInputChange(event) {
    if (!this.autoSaveValue) return
    
    // Debounce auto-save
    this.clearAutoSaveTimeout()
    this.autoSaveTimeout = setTimeout(() => {
      this.performAutoSave()
    }, 2000) // Auto-save after 2 seconds of inactivity
  }

  clearAutoSaveTimeout() {
    if (this.autoSaveTimeout) {
      clearTimeout(this.autoSaveTimeout)
      this.autoSaveTimeout = null
    }
  }

  async performAutoSave() {
    const formData = this.collectFormData()
    
    // Don't save if data hasn't changed
    if (JSON.stringify(formData) === this.lastSaveData) {
      return
    }

    try {
      const response = await fetch(`/forms/${this.formIdValue}/responses/${this.responseIdValue}/auto_save`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCsrfToken()
        },
        body: JSON.stringify({
          form_response: {
            question_responses_attributes: formData
          }
        })
      })

      if (response.ok) {
        this.lastSaveData = JSON.stringify(formData)
        this.showSaveIndicator('saved')
      } else {
        throw new Error('Auto-save failed')
      }
    } catch (error) {
      console.error('Auto-save error:', error)
      this.showSaveIndicator('error')
    }
  }

  collectFormData() {
    const formData = []
    const inputs = this.element.querySelectorAll('[data-question-id]')
    
    inputs.forEach(input => {
      const questionId = input.dataset.questionId
      let value = null

      if (input.type === 'radio' || input.type === 'checkbox') {
        if (input.checked) {
          value = input.value
        }
      } else if (input.tagName === 'SELECT') {
        value = input.value
      } else {
        value = input.value.trim()
      }

      if (value !== null && value !== '') {
        formData.push({
          form_question_id: questionId,
          answer_data: value
        })
      }
    })

    return formData
  }

  showSaveIndicator(status) {
    // Create or update save indicator
    let indicator = this.element.querySelector('.auto-save-indicator')
    
    if (!indicator) {
      indicator = document.createElement('div')
      indicator.className = 'auto-save-indicator fixed top-4 right-4 px-3 py-2 rounded-md text-sm font-medium transition-all duration-300'
      this.element.appendChild(indicator)
    }

    // Remove existing status classes
    indicator.classList.remove('bg-green-100', 'text-green-800', 'bg-red-100', 'text-red-800', 'bg-yellow-100', 'text-yellow-800')

    switch (status) {
      case 'saving':
        indicator.classList.add('bg-yellow-100', 'text-yellow-800')
        indicator.textContent = 'Saving...'
        break
      case 'saved':
        indicator.classList.add('bg-green-100', 'text-green-800')
        indicator.textContent = 'Saved'
        // Hide after 2 seconds
        setTimeout(() => {
          indicator.style.opacity = '0'
        }, 2000)
        break
      case 'error':
        indicator.classList.add('bg-red-100', 'text-red-800')
        indicator.textContent = 'Save failed'
        break
    }

    indicator.style.opacity = '1'
  }
  
  setupBeforeUnload() {
    this.beforeUnloadHandler = (event) => {
      // Only show warning if form has content
      if (this.hasUnsavedContent()) {
        event.preventDefault()
        event.returnValue = 'You have unsaved changes. Are you sure you want to leave?'
        return event.returnValue
      }
    }
    
    window.addEventListener('beforeunload', this.beforeUnloadHandler)
  }
  
  removeBeforeUnload() {
    if (this.beforeUnloadHandler) {
      window.removeEventListener('beforeunload', this.beforeUnloadHandler)
    }
  }
  
  hasUnsavedContent() {
    // Check if any form inputs have content
    const inputs = document.querySelectorAll('input, textarea, select')
    return Array.from(inputs).some(input => {
      if (input.type === 'radio' || input.type === 'checkbox') {
        return input.checked
      } else {
        return input.value.trim() !== ''
      }
    })
  }
  
  trackPageView() {
    // Track form view for analytics
    if (typeof gtag !== 'undefined') {
      gtag('event', 'form_view', {
        'form_id': this.formIdValue,
        'session_id': this.sessionIdValue
      })
    }
    
    // Custom analytics tracking
    if (window.agentFormAnalytics) {
      window.agentFormAnalytics.trackView({
        formId: this.formIdValue,
        sessionId: this.sessionIdValue,
        timestamp: new Date().toISOString()
      })
    }
  }

  // Navigation methods
  async nextStep(event) {
    event.preventDefault()
    
    // Validate current step before proceeding
    if (!this.validateCurrentStep()) {
      return
    }

    // Save current step data
    await this.saveCurrentStep()

    // Navigate to next step
    if (this.currentStepIndexValue < this.totalStepsValue - 1) {
      this.currentStepIndexValue += 1
      this.navigateToStep(this.currentStepIndexValue)
    } else {
      // This is the last step, submit the form
      this.submitForm()
    }
  }

  async prevStep(event) {
    event.preventDefault()
    
    if (this.currentStepIndexValue > 0) {
      this.currentStepIndexValue -= 1
      this.navigateToStep(this.currentStepIndexValue)
    }
  }

  async navigateToStep(stepIndex) {
    try {
      const response = await fetch(`/forms/${this.formIdValue}/responses/${this.responseIdValue}/step/${stepIndex}`, {
        method: 'GET',
        headers: {
          'Accept': 'text/html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (response.ok) {
        const html = await response.text()
        
        // Update the step content
        const stepContainer = this.element.querySelector('.step-container')
        if (stepContainer) {
          stepContainer.innerHTML = html
        }

        this.updateProgress()
        this.updateNavigationButtons()
        this.scrollToTop()
      } else {
        throw new Error('Failed to load step')
      }
    } catch (error) {
      console.error('Navigation error:', error)
      this.showError('Failed to navigate to step')
    }
  }

  validateCurrentStep() {
    const requiredInputs = this.element.querySelectorAll('[required]')
    let isValid = true

    requiredInputs.forEach(input => {
      if (!this.isInputValid(input)) {
        this.showFieldError(input, 'This field is required')
        isValid = false
      } else {
        this.clearFieldError(input)
      }
    })

    return isValid
  }

  isInputValid(input) {
    if (input.type === 'radio') {
      const radioGroup = this.element.querySelectorAll(`input[name="${input.name}"]`)
      return Array.from(radioGroup).some(radio => radio.checked)
    } else if (input.type === 'checkbox') {
      return input.checked
    } else {
      return input.value.trim() !== ''
    }
  }

  showFieldError(input, message) {
    // Remove existing error
    this.clearFieldError(input)

    // Add error styling
    input.classList.add('border-red-500', 'focus:border-red-500', 'focus:ring-red-500')

    // Create error message
    const errorElement = document.createElement('div')
    errorElement.className = 'field-error text-red-600 text-sm mt-1'
    errorElement.textContent = message

    // Insert error message after the input
    input.parentNode.insertBefore(errorElement, input.nextSibling)
  }

  clearFieldError(input) {
    // Remove error styling
    input.classList.remove('border-red-500', 'focus:border-red-500', 'focus:ring-red-500')

    // Remove error message
    const errorElement = input.parentNode.querySelector('.field-error')
    if (errorElement) {
      errorElement.remove()
    }
  }

  async saveCurrentStep() {
    if (this.autoSaveValue) {
      // If auto-save is enabled, just perform a final save
      await this.performAutoSave()
    } else {
      // Manual save for current step
      const formData = this.collectFormData()
      
      try {
        const response = await fetch(`/forms/${this.formIdValue}/responses/${this.responseIdValue}/save_step`, {
          method: 'PATCH',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': this.getCsrfToken()
          },
          body: JSON.stringify({
            form_response: {
              question_responses_attributes: formData
            }
          })
        })

        if (!response.ok) {
          throw new Error('Failed to save step')
        }
      } catch (error) {
        console.error('Save step error:', error)
        throw error
      }
    }
  }

  async submitForm(event) {
    if (event) event.preventDefault()

    // Validate all required fields
    if (!this.validateCurrentStep()) {
      return
    }

    // Show loading state
    this.setSubmitButtonLoading(true)

    try {
      // Save current step data
      await this.saveCurrentStep()

      // Submit the form
      const response = await fetch(`/forms/${this.formIdValue}/responses/${this.responseIdValue}/submit`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCsrfToken()
        }
      })

      if (response.ok) {
        const result = await response.json()
        
        // Redirect to thank you page
        if (result.redirect_url) {
          window.location.href = result.redirect_url
        } else {
          window.location.href = `/forms/${this.formIdValue}/responses/${this.responseIdValue}/thank_you`
        }
      } else {
        throw new Error('Failed to submit form')
      }
    } catch (error) {
      console.error('Submit error:', error)
      this.showError('Failed to submit form. Please try again.')
    } finally {
      this.setSubmitButtonLoading(false)
    }
  }

  updateProgress() {
    const progressPercentage = ((this.currentStepIndexValue + 1) / this.totalStepsValue) * 100

    // Update progress bar
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = `${progressPercentage}%`
    }

    // Update step counter
    if (this.hasCurrentStepTarget) {
      this.currentStepTarget.textContent = this.currentStepIndexValue + 1
    }
    
    if (this.hasTotalStepsTarget) {
      this.totalStepsTarget.textContent = this.totalStepsValue
    }
  }

  updateNavigationButtons() {
    // Update previous button
    if (this.hasPrevButtonTarget) {
      if (this.currentStepIndexValue === 0) {
        this.prevButtonTarget.style.display = 'none'
      } else {
        this.prevButtonTarget.style.display = 'inline-flex'
      }
    }

    // Update next/submit button
    if (this.hasNextButtonTarget && this.hasSubmitButtonTarget) {
      if (this.currentStepIndexValue === this.totalStepsValue - 1) {
        this.nextButtonTarget.style.display = 'none'
        this.submitButtonTarget.style.display = 'inline-flex'
      } else {
        this.nextButtonTarget.style.display = 'inline-flex'
        this.submitButtonTarget.style.display = 'none'
      }
    }
  }

  setSubmitButtonLoading(loading) {
    if (this.hasSubmitButtonTarget) {
      if (loading) {
        this.submitButtonTarget.disabled = true
        this.submitButtonTarget.innerHTML = `
          <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          Submitting...
        `
      } else {
        this.submitButtonTarget.disabled = false
        this.submitButtonTarget.innerHTML = 'Submit'
      }
    }
  }

  scrollToTop() {
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  showError(message) {
    // Create or update error notification
    let errorElement = this.element.querySelector('.form-error-notification')
    
    if (!errorElement) {
      errorElement = document.createElement('div')
      errorElement.className = 'form-error-notification fixed top-4 right-4 bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded max-w-md'
      this.element.appendChild(errorElement)
    }

    errorElement.innerHTML = `
      <div class="flex">
        <div class="flex-shrink-0">
          <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
          </svg>
        </div>
        <div class="ml-3">
          <p class="text-sm">${message}</p>
        </div>
        <div class="ml-auto pl-3">
          <button class="inline-flex text-red-400 hover:text-red-600" onclick="this.parentElement.parentElement.parentElement.remove()">
            <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
            </svg>
          </button>
        </div>
      </div>
    `

    // Auto-hide after 5 seconds
    setTimeout(() => {
      if (errorElement.parentNode) {
        errorElement.remove()
      }
    }, 5000)
  }

  getCsrfToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ''
  }

  // Keyboard navigation
  handleKeydown(event) {
    if (event.key === 'Enter' && event.ctrlKey) {
      // Ctrl+Enter to go to next step
      if (this.hasNextButtonTarget && this.nextButtonTarget.style.display !== 'none') {
        this.nextStep(event)
      } else if (this.hasSubmitButtonTarget && this.submitButtonTarget.style.display !== 'none') {
        this.submitForm(event)
      }
    }
  }
}