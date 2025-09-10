import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "answerInput", 
    "submitButton", 
    "submitText", 
    "loadingSpinner", 
    "startedAt",
    "charCount",
    "otherCheckbox",
    "otherInput",
    "otherInputContainer"
  ]
  
  static values = {
    questionId: String,
    formToken: String,
    required: Boolean
  }
  
  connect() {
    this.setStartTime()
    this.setupCharacterCount()
    this.setupAutoSave()
  }
  
  setStartTime() {
    if (this.hasStartedAtTarget) {
      this.startedAtTarget.value = new Date().toISOString()
    }
  }
  
  setupCharacterCount() {
    this.answerInputTargets.forEach(input => {
      if (input.type === 'text' || input.type === 'textarea') {
        this.updateCharCount(input)
      }
    })
  }
  
  setupAutoSave() {
    // Set up auto-save interval if enabled
    this.autoSaveInterval = setInterval(() => {
      this.autoSaveDraft()
    }, 30000) // Auto-save every 30 seconds
  }
  
  disconnect() {
    if (this.autoSaveInterval) {
      clearInterval(this.autoSaveInterval)
    }
  }
  
  validateInput(event) {
    const input = event.target
    this.updateCharCount(input)
    this.updateSliderValue(event)
    this.validateAnswer()
  }
  
  updateCharCount(input) {
    if (this.hasCharCountTarget && (input.type === 'text' || input.tagName === 'TEXTAREA')) {
      this.charCountTarget.textContent = input.value.length
    }
  }
  
  validateAnswer() {
    const isValid = this.isAnswerValid()
    
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = !isValid
    }
    
    this.hideValidationErrors()
    return isValid
  }
  
  isAnswerValid() {
    if (!this.requiredValue) return true
    
    // Check different input types
    const textInputs = this.answerInputTargets.filter(input => 
      input.type === 'text' || input.type === 'email' || input.tagName === 'TEXTAREA'
    )
    
    const radioInputs = this.answerInputTargets.filter(input => input.type === 'radio')
    const checkboxInputs = this.answerInputTargets.filter(input => input.type === 'checkbox')
    
    // Text inputs
    if (textInputs.length > 0) {
      return textInputs.some(input => input.value.trim() !== '')
    }
    
    // Radio buttons
    if (radioInputs.length > 0) {
      return radioInputs.some(input => input.checked)
    }
    
    // Checkboxes
    if (checkboxInputs.length > 0) {
      return checkboxInputs.some(input => input.checked)
    }
    
    return true
  }
  
  submitAnswer(event) {
    event.preventDefault()
    
    if (!this.validateAnswer()) {
      this.showValidationErrors(['Please provide an answer to continue'])
      return
    }
    
    // Trigger simple exit animation
    this.triggerAnimation('question-will-change')
    
    // Small delay for animation, then submit
    setTimeout(() => {
      this.performSubmission(event.target)
    }, 200)
  }

  performSubmission(form) {
    this.showLoading()
    
    const formData = new FormData(form)
    
    fetch(form.action, {
      method: 'POST',
      body: formData,
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      }
    })
    .then(response => response.json())
    .then(data => {
      this.hideLoading()
      
      if (data.success) {
        if (data.completed) {
          // Simple success animation before redirect
          this.showSuccessMessage(() => {
            if (data.redirect_url && data.redirect_url !== 'undefined' && data.redirect_url !== '/f/undefined') {
              console.log('Redirecting to:', data.redirect_url)
              window.location.href = data.redirect_url
            } else {
              console.error('Invalid redirect URL:', data.redirect_url)
              this.showValidationErrors(['Invalid redirect URL. Please refresh the page.'])
              if (this.formTokenValue) {
                window.location.href = `/f/${this.formTokenValue}`
              } else {
                window.location.reload()
              }
            }
          })
        } else if (data.next_question) {
          this.loadNextQuestion(data.next_question)
        } else {
          window.location.reload()
        }
      } else {
        this.showValidationErrors(data.errors || ['An error occurred. Please try again.'])
      }
    })
    .catch(error => {
      this.hideLoading()
      console.error('Error:', error)
      this.showValidationErrors(['An error occurred. Please try again.'])
    })
  }
  
  showLoading() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
    }
    
    if (this.hasSubmitTextTarget) {
      this.submitTextTarget.textContent = 'Processing...'
    }
    
    if (this.hasLoadingSpinnerTarget) {
      this.loadingSpinnerTarget.classList.remove('hidden')
    }
  }
  
  hideLoading() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
    }
    
    if (this.hasSubmitTextTarget) {
      this.submitTextTarget.textContent = 'Continue'
    }
    
    if (this.hasLoadingSpinnerTarget) {
      this.loadingSpinnerTarget.classList.add('hidden')
    }
  }
  
  showValidationErrors(errors) {
    const errorContainer = document.getElementById('validation-errors')
    const errorList = document.getElementById('error-list')
    
    if (errorContainer && errorList) {
      errorList.innerHTML = ''
      errors.forEach(error => {
        const li = document.createElement('li')
        li.textContent = error
        errorList.appendChild(li)
      })
      
      errorContainer.classList.remove('hidden')
      errorContainer.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
    }
  }
  
  hideValidationErrors() {
    const errorContainer = document.getElementById('validation-errors')
    if (errorContainer) {
      errorContainer.classList.add('hidden')
    }
  }
  
  toggleOtherInput(event) {
    const checkbox = event.target
    
    if (this.hasOtherInputContainerTarget) {
      if (checkbox.checked) {
        this.otherInputContainerTarget.classList.remove('hidden')
        if (this.hasOtherInputTarget) {
          this.otherInputTarget.focus()
        }
      } else {
        this.otherInputContainerTarget.classList.add('hidden')
        if (this.hasOtherInputTarget) {
          this.otherInputTarget.value = ''
        }
      }
    }
  }
  
  saveDraft() {
    const formData = this.collectFormData()
    
    fetch(`/f/${this.formTokenValue}/save_draft`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ draft_data: formData })
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.showNotification('Draft saved successfully', 'success')
      } else {
        this.showNotification('Failed to save draft', 'error')
      }
    })
    .catch(error => {
      console.error('Error saving draft:', error)
      this.showNotification('Failed to save draft', 'error')
    })
  }
  
  autoSaveDraft() {
    // Only auto-save if there's content and the form is not being submitted
    if (this.hasAnswerContent() && !this.isSubmitting) {
      this.saveDraft()
    }
  }
  
  hasAnswerContent() {
    return this.answerInputTargets.some(input => {
      if (input.type === 'radio' || input.type === 'checkbox') {
        return input.checked
      } else {
        return input.value.trim() !== ''
      }
    })
  }
  
  collectFormData() {
    const data = {}
    
    this.answerInputTargets.forEach(input => {
      if (input.type === 'radio' || input.type === 'checkbox') {
        if (input.checked) {
          if (data[input.name]) {
            if (Array.isArray(data[input.name])) {
              data[input.name].push(input.value)
            } else {
              data[input.name] = [data[input.name], input.value]
            }
          } else {
            data[input.name] = input.value
          }
        }
      } else {
        data[input.name] = input.value
      }
    })
    
    return data
  }
  
  goToPrevious() {
    // This would need to be implemented based on your navigation logic
    // For now, we'll just go back in browser history
    window.history.back()
  }
  
  showNotification(message, type = 'info') {
    // Create a simple notification
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 z-50 p-4 rounded-lg shadow-lg ${
      type === 'success' ? 'bg-green-100 text-green-800 border border-green-200' :
      type === 'error' ? 'bg-red-100 text-red-800 border border-red-200' :
      'bg-blue-100 text-blue-800 border border-blue-200'
    }`
    notification.textContent = message
    
    document.body.appendChild(notification)
    
    // Remove after 3 seconds
    setTimeout(() => {
      notification.remove()
    }, 3000)
  }
  
  updateSliderValue(event) {
    const input = event.target
    if (input.type === 'range') {
      const prefix = input.dataset.prefix || ''
      const suffix = input.dataset.suffix || ''
      const value = input.value
      
      // Find the slider value display element
      const sliderValueElement = this.element.querySelector('[data-question-response-target="sliderValue"]')
      if (sliderValueElement) {
        sliderValueElement.textContent = prefix + value + suffix
      }
    }
  }

  loadNextQuestion(questionData) {
    // This would implement dynamic question loading
    // For now, we'll just reload the page
    window.location.reload()
  }

  // Simple animation methods
  showSuccessMessage(callback) {
    // Simple success notification
    const notification = document.createElement('div')
    notification.className = 'fixed top-4 right-4 z-50 bg-green-500 text-white px-6 py-3 rounded-lg shadow-lg'
    notification.innerHTML = `
      <div class="flex items-center">
        <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
        </svg>
        Form submitted successfully!
      </div>
    `
    document.body.appendChild(notification)
    
    setTimeout(() => {
      notification.remove()
      if (callback) callback()
    }, 1500)
  }

  loadNextQuestion(questionData) {
    // Simple page reload for next question
    window.location.reload()
  }

  // Helper method to trigger animations
  triggerAnimation(eventType) {
    // Try to call the form animation controller if it exists
    const formAnimationController = this.application.getControllerForElementAndIdentifier(this.element, 'form-animation')
    if (formAnimationController) {
      switch(eventType) {
        case 'question-will-change':
          formAnimationController.animateNextQuestion()
          break
        case 'form-submitting':
          formAnimationController.showLoadingState()
          break
        case 'form-submitted':
          formAnimationController.hideLoadingState()
          break
      }
    }
  }
}