import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="form-builder"
export default class extends Controller {
  static targets = ["saveIndicator", "saveStatus", "questionsList"]
  static values = { 
    formId: String,
    csrfToken: String
  }

  connect() {
    console.log('Form builder controller connected successfully')
    console.log('Form ID:', this.formIdValue)
    console.log('Has questionsList target:', this.hasQuestionsListTarget)
  }

  // Test method to verify connection
  testConnection(event) {
    event.preventDefault()
    alert('Controller is working!')
    console.log('Test successful')
    console.log('Form ID:', this.formIdValue)
    console.log('Has questionsList target:', this.hasQuestionsListTarget)
  }

  // Main add question method
  addQuestion(event) {
    event.preventDefault()
    console.log('Add question clicked')
    
    const questionType = event.currentTarget.dataset.questionType || 'text_short'
    console.log('Question type:', questionType)
    
    this.createQuestion(questionType)
  }

  // Create question via AJAX
  async createQuestion(questionType) {
    console.log('Creating question with type:', questionType)
    
    // Show loading state
    const addButtons = this.element.querySelectorAll('[data-action*="addQuestion"]')
    addButtons.forEach(button => {
      button.disabled = true
      button.style.opacity = '0.5'
    })
    
    try {
      const url = `/forms/${this.formIdValue}/questions`
      console.log('Making request to:', url)
      
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfTokenValue,
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          form_question: {
            question_type: questionType,
            title: `New ${questionType.replace('_', ' ')} question`,
            required: false
          }
        })
      })

      console.log('Response status:', response.status)

      if (response.ok) {
        const data = await response.json()
        console.log('Question created successfully:', data)
        
        // Reload page to show the new question
        window.location.reload()
        
      } else {
        const errorData = await response.json()
        console.error('Server error:', errorData)
        throw new Error(errorData.errors ? errorData.errors.join(', ') : 'Failed to create question')
      }
    } catch (error) {
      console.error('Error creating question:', error)
      alert('Failed to create question: ' + error.message)
    } finally {
      // Restore button states
      addButtons.forEach(button => {
        button.disabled = false
        button.style.opacity = '1'
      })
    }
  }

  // Additional methods for functionality
  editQuestion(event) {
    event.preventDefault()
    const questionCard = event.currentTarget.closest('[data-question-id]')
    const questionId = questionCard.dataset.questionId
    console.log('Edit question:', questionId, 'Form ID:', this.formIdValue)
    
    // Build the correct URL
    const editUrl = `/forms/${this.formIdValue}/questions/${questionId}/edit`
    console.log('Navigating to:', editUrl)
    window.location.href = editUrl
  }

  async deleteQuestion(event) {
    event.preventDefault()
    
    if (!confirm('Are you sure you want to delete this question?')) {
      return
    }

    const questionCard = event.currentTarget.closest('[data-question-id]')
    const questionId = questionCard.dataset.questionId
    console.log('Deleting question:', questionId)

    // Show loading state
    const deleteButton = event.currentTarget
    const originalText = deleteButton.innerHTML
    deleteButton.innerHTML = '...'
    deleteButton.disabled = true

    try {
      const response = await fetch(`/forms/${this.formIdValue}/questions/${questionId}`, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': this.csrfTokenValue,
          'Accept': 'application/json'
        }
      })

      if (response.ok) {
        console.log('Question deleted successfully')
        
        // Immediately disable all buttons to prevent further clicks
        const allButtons = questionCard.querySelectorAll('button')
        allButtons.forEach(btn => {
          btn.disabled = true
          btn.style.pointerEvents = 'none'
        })
        
        // Add a "deleted" class for visual feedback
        questionCard.classList.add('deleted')
        questionCard.style.pointerEvents = 'none'
        
        // Animate removal
        questionCard.style.transition = 'all 0.3s ease'
        questionCard.style.opacity = '0.3'
        questionCard.style.transform = 'translateX(-20px)'
        questionCard.style.filter = 'grayscale(100%)'
        
        // Remove from DOM after animation
        setTimeout(() => {
          questionCard.remove()
          this.updateStepNumbers()
        }, 300)
        
      } else {
        const errorData = await response.json()
        throw new Error(errorData.error || 'Failed to delete question')
      }
    } catch (error) {
      console.error('Error deleting question:', error)
      alert('Failed to delete question: ' + error.message)
      
      // Restore button state
      deleteButton.innerHTML = originalText
      deleteButton.disabled = false
    }
  }

  async duplicateQuestion(event) {
    event.preventDefault()
    const questionCard = event.currentTarget.closest('[data-question-id]')
    const questionId = questionCard.dataset.questionId
    console.log('Duplicating question:', questionId)

    // Show loading state
    const duplicateButton = event.currentTarget
    const originalText = duplicateButton.innerHTML
    duplicateButton.innerHTML = '...'
    duplicateButton.disabled = true

    try {
      const response = await fetch(`/forms/${this.formIdValue}/questions/${questionId}/duplicate`, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': this.csrfTokenValue,
          'Accept': 'application/json'
        }
      })

      if (response.ok) {
        console.log('Question duplicated successfully')
        // Reload page to show duplicated question
        window.location.reload()
        
      } else {
        const errorData = await response.json()
        throw new Error(errorData.error || 'Failed to duplicate question')
      }
    } catch (error) {
      console.error('Error duplicating question:', error)
      alert('Failed to duplicate question: ' + error.message)
    } finally {
      // Restore button state
      duplicateButton.innerHTML = originalText
      duplicateButton.disabled = false
    }
  }

  // Toggle question required status
  async toggleRequired(event) {
    const questionCard = event.currentTarget.closest('[data-question-id]')
    const questionId = questionCard.dataset.questionId
    const isRequired = event.currentTarget.checked
    
    console.log('Toggling required for question:', questionId, 'to:', isRequired)

    try {
      const response = await fetch(`/forms/${this.formIdValue}/questions/${questionId}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfTokenValue,
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          form_question: {
            required: isRequired
          }
        })
      })

      if (response.ok) {
        console.log('Required status updated successfully')
        
        // Update the badge in the UI
        const requiredBadge = questionCard.querySelector('.bg-red-100.text-red-800')
        if (isRequired && !requiredBadge) {
          // Add required badge
          const badgeContainer = questionCard.querySelector('.flex.items-center.space-x-2.mb-1')
          const newBadge = document.createElement('span')
          newBadge.className = 'inline-flex items-center px-2 py-1 text-xs font-medium bg-red-100 text-red-800 rounded-full'
          newBadge.textContent = 'Required'
          badgeContainer.appendChild(newBadge)
        } else if (!isRequired && requiredBadge) {
          // Remove required badge
          requiredBadge.remove()
        }
        
        this.setSaveStatus("saved")
      } else {
        // Revert the checkbox if the request failed
        event.currentTarget.checked = !isRequired
        const errorData = await response.json()
        throw new Error(errorData.error || 'Failed to update question')
      }
    } catch (error) {
      console.error('Error updating question:', error)
      // Revert checkbox on error
      event.currentTarget.checked = !isRequired
      alert('Failed to update required status: ' + error.message)
      this.setSaveStatus("error")
    }
  }

  // Set save status (for auto-save feedback)
  setSaveStatus(status) {
    if (!this.hasSaveIndicatorTarget || !this.hasSaveStatusTarget) return
    
    switch (status) {
      case "saving":
        this.saveIndicatorTarget.classList.remove("bg-green-400", "bg-red-400")
        this.saveIndicatorTarget.classList.add("bg-yellow-400")
        this.saveStatusTarget.textContent = "Saving..."
        break
      case "saved":
        this.saveIndicatorTarget.classList.remove("bg-yellow-400", "bg-red-400")
        this.saveIndicatorTarget.classList.add("bg-green-400")
        this.saveStatusTarget.textContent = "Saved"
        break
      case "error":
        this.saveIndicatorTarget.classList.remove("bg-green-400", "bg-yellow-400")
        this.saveIndicatorTarget.classList.add("bg-red-400")
        this.saveStatusTarget.textContent = "Error"
        break
    }
  }

  // Helper method to update step numbers after deletion
  updateStepNumbers() {
    const questionCards = this.questionsListTarget.querySelectorAll('[data-question-id]')
    questionCards.forEach((card, index) => {
      const stepLabel = card.querySelector('.inline-flex.items-center.px-2.py-1')
      if (stepLabel) {
        stepLabel.textContent = `Step ${index + 1}`
      }
    })
  }

  // Check if question type is payment-related
  isPaymentQuestion(questionType) {
    return questionType === 'payment' || questionType === 'subscription' || questionType === 'donation'
  }

  // Override createQuestion to handle payment questions
  async createQuestion(questionType) {
    console.log('Creating question with type:', questionType)
    
    // Check if this is a payment question and notify payment setup controller
    const isPayment = this.isPaymentQuestion(questionType)
    
    // Show loading state
    const addButtons = this.element.querySelectorAll('[data-action*="addQuestion"]')
    addButtons.forEach(button => {
      button.disabled = true
      button.style.opacity = '0.5'
    })
    
    try {
      const url = `/forms/${this.formIdValue}/questions`
      console.log('Making request to:', url)
      
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfTokenValue,
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          form_question: {
            question_type: questionType,
            title: `New ${questionType.replace('_', ' ')} question`,
            required: false
          }
        })
      })

      console.log('Response status:', response.status)

      if (response.ok) {
        const data = await response.json()
        console.log('Question created successfully:', data)
        
        // If this was a payment question, notify the payment setup controller
        if (isPayment) {
          this.notifyPaymentQuestionAdded()
        }
        
        // Reload page to show the new question
        window.location.reload()
        
      } else {
        const errorData = await response.json()
        console.error('Server error:', errorData)
        throw new Error(errorData.errors ? errorData.errors.join(', ') : 'Failed to create question')
      }
    } catch (error) {
      console.error('Error creating question:', error)
      alert('Failed to create question: ' + error.message)
    } finally {
      // Restore button states
      addButtons.forEach(button => {
        button.disabled = false
        button.style.opacity = '1'
      })
    }
  }

  // Override deleteQuestion to handle payment questions
  async deleteQuestion(event) {
    event.preventDefault()
    
    if (!confirm('Are you sure you want to delete this question?')) {
      return
    }

    const questionCard = event.currentTarget.closest('[data-question-id]')
    const questionId = questionCard.dataset.questionId
    
    // Check if this is a payment question
    const questionTypeElement = questionCard.querySelector('.font-medium')
    const questionType = questionTypeElement ? questionTypeElement.textContent.toLowerCase() : ''
    const isPayment = this.isPaymentQuestion(questionType)
    
    console.log('Deleting question:', questionId)

    // Show loading state
    const deleteButton = event.currentTarget
    const originalText = deleteButton.innerHTML
    deleteButton.innerHTML = '...'
    deleteButton.disabled = true

    try {
      const response = await fetch(`/forms/${this.formIdValue}/questions/${questionId}`, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': this.csrfTokenValue,
          'Accept': 'application/json'
        }
      })

      if (response.ok) {
        console.log('Question deleted successfully')
        
        // If this was a payment question, notify the payment setup controller
        if (isPayment) {
          this.notifyPaymentQuestionRemoved()
        }
        
        // Immediately disable all buttons to prevent further clicks
        const allButtons = questionCard.querySelectorAll('button')
        allButtons.forEach(btn => {
          btn.disabled = true
          btn.style.pointerEvents = 'none'
        })
        
        // Add a "deleted" class for visual feedback
        questionCard.classList.add('deleted')
        questionCard.style.pointerEvents = 'none'
        
        // Animate removal
        questionCard.style.transition = 'all 0.3s ease'
        questionCard.style.opacity = '0.3'
        questionCard.style.transform = 'translateX(-20px)'
        questionCard.style.filter = 'grayscale(100%)'
        
        // Remove from DOM after animation
        setTimeout(() => {
          questionCard.remove()
          this.updateStepNumbers()
        }, 300)
        
      } else {
        const errorData = await response.json()
        throw new Error(errorData.error || 'Failed to delete question')
      }
    } catch (error) {
      console.error('Error deleting question:', error)
      alert('Failed to delete question: ' + error.message)
      
      // Restore button state
      deleteButton.innerHTML = originalText
      deleteButton.disabled = false
    }
  }

  // Notify payment setup controller about payment question changes
  notifyPaymentQuestionAdded() {
    const paymentSetupController = this.application.getControllerForElementAndIdentifier(
      this.element, 'payment-setup-status'
    )
    
    if (paymentSetupController) {
      paymentSetupController.onPaymentQuestionAdded()
    }
  }

  notifyPaymentQuestionRemoved() {
    const paymentSetupController = this.application.getControllerForElementAndIdentifier(
      this.element, 'payment-setup-status'
    )
    
    if (paymentSetupController) {
      paymentSetupController.onPaymentQuestionRemoved()
    }
  }
}