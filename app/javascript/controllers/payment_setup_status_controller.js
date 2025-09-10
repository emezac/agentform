import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="payment-setup-status"
export default class extends Controller {
  static targets = [
    "statusIndicator", 
    "notificationBar", 
    "progressBar", 
    "progressText", 
    "actionButton",
    "setupModal",
    "requirementsList"
  ]
  
  static values = { 
    formId: String,
    hasPaymentQuestions: Boolean,
    stripeConfigured: Boolean,
    isPremium: Boolean,
    setupComplete: Boolean,
    completionPercentage: Number
  }

  connect() {
    console.log('Payment setup status controller connected')
    this.updateStatusDisplay()
    this.startPeriodicCheck()
  }

  disconnect() {
    if (this.checkInterval) {
      clearInterval(this.checkInterval)
    }
  }

  // Update the visual status display
  updateStatusDisplay() {
    if (!this.hasPaymentQuestionsValue) {
      this.hidePaymentStatus()
      return
    }

    this.showPaymentStatus()
    this.updateProgressBar()
    this.updateNotificationBar()
    this.updateStatusIndicator()
  }

  // Show payment status elements
  showPaymentStatus() {
    if (this.hasStatusIndicatorTarget) {
      this.statusIndicatorTarget.classList.remove('hidden')
    }
    if (this.hasNotificationBarTarget) {
      this.notificationBarTarget.classList.remove('hidden')
    }
  }

  // Hide payment status elements
  hidePaymentStatus() {
    if (this.hasStatusIndicatorTarget) {
      this.statusIndicatorTarget.classList.add('hidden')
    }
    if (this.hasNotificationBarTarget) {
      this.notificationBarTarget.classList.add('hidden')
    }
  }

  // Update progress bar
  updateProgressBar() {
    if (!this.hasProgressBarTarget) return

    const percentage = this.completionPercentageValue
    this.progressBarTarget.style.width = `${percentage}%`
    
    // Update progress text
    if (this.hasProgressTextTarget) {
      this.progressTextTarget.textContent = `${percentage}% Complete`
    }

    // Update progress bar color based on completion
    this.progressBarTarget.classList.remove('bg-red-500', 'bg-yellow-500', 'bg-green-500')
    if (percentage < 50) {
      this.progressBarTarget.classList.add('bg-red-500')
    } else if (percentage < 100) {
      this.progressBarTarget.classList.add('bg-yellow-500')
    } else {
      this.progressBarTarget.classList.add('bg-green-500')
    }
  }

  // Update notification bar content
  updateNotificationBar() {
    if (!this.hasNotificationBarTarget) return

    if (this.setupCompleteValue) {
      this.showSuccessNotification()
    } else {
      this.showSetupRequiredNotification()
    }
  }

  // Show success notification
  showSuccessNotification() {
    this.notificationBarTarget.className = 'bg-green-50 border-l-4 border-green-400 p-4 mb-6'
    this.notificationBarTarget.innerHTML = `
      <div class="flex items-center justify-between">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
            </svg>
          </div>
          <div class="ml-3">
            <p class="text-sm text-green-700">
              <strong>Payment setup complete!</strong> Your form is ready to accept payments.
            </p>
          </div>
        </div>
      </div>
    `
  }

  // Show setup required notification
  showSetupRequiredNotification() {
    const missingRequirements = this.getMissingRequirements()
    const requirementsList = missingRequirements.map(req => `<li>${req}</li>`).join('')

    this.notificationBarTarget.className = 'bg-amber-50 border-l-4 border-amber-400 p-4 mb-6'
    this.notificationBarTarget.innerHTML = `
      <div class="flex items-center justify-between">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-amber-400" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
            </svg>
          </div>
          <div class="ml-3 flex-1">
            <p class="text-sm text-amber-700">
              <strong>Payment setup required</strong> to publish this form with payment questions.
            </p>
            <ul class="mt-2 text-sm text-amber-600 list-disc list-inside">
              ${requirementsList}
            </ul>
          </div>
        </div>
        <div class="ml-4 flex-shrink-0">
          <button data-action="click->payment-setup-status#openSetupModal" 
                  class="bg-amber-100 hover:bg-amber-200 text-amber-800 px-3 py-2 rounded-md text-sm font-medium transition-colors">
            Complete Setup
          </button>
        </div>
      </div>
    `
  }

  // Update status indicator in header
  updateStatusIndicator() {
    if (!this.hasStatusIndicatorTarget) return

    if (this.setupCompleteValue) {
      this.statusIndicatorTarget.innerHTML = `
        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
          <div class="w-2 h-2 bg-green-400 rounded-full mr-1.5"></div>
          Payment Ready
        </span>
      `
    } else {
      this.statusIndicatorTarget.innerHTML = `
        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-800">
          <div class="w-2 h-2 bg-amber-400 rounded-full mr-1.5"></div>
          Setup Required
        </span>
      `
    }
  }

  // Get missing requirements
  getMissingRequirements() {
    const requirements = []
    
    if (!this.stripeConfiguredValue) {
      requirements.push('Configure Stripe payment processing')
    }
    
    if (!this.isPremiumValue) {
      requirements.push('Upgrade to Premium subscription')
    }
    
    return requirements
  }

  // Open setup modal
  openSetupModal(event) {
    event.preventDefault()
    
    if (this.hasSetupModalTarget) {
      this.setupModalTarget.classList.remove('hidden')
      this.populateSetupModal()
    } else {
      // Fallback: redirect to payment setup page
      window.open('/payment_setup', '_blank')
    }
  }

  // Close setup modal
  closeSetupModal(event) {
    event.preventDefault()
    
    if (this.hasSetupModalTarget) {
      this.setupModalTarget.classList.add('hidden')
    }
  }

  // Populate setup modal with requirements
  populateSetupModal() {
    if (!this.hasRequirementsListTarget) return

    const requirements = this.getMissingRequirements()
    const requirementsHtml = requirements.map(req => {
      let actionUrl = '#'
      let actionText = 'Setup'
      
      if (req.includes('Stripe')) {
        actionUrl = '/stripe_settings'
        actionText = 'Configure Stripe'
      } else if (req.includes('Premium')) {
        actionUrl = '/subscription_management'
        actionText = 'Upgrade Plan'
      }
      
      return `
        <li class="flex items-center justify-between py-3 border-b border-gray-200 last:border-b-0">
          <span class="text-sm text-gray-700">${req}</span>
          <a href="${actionUrl}" target="_blank" 
             class="inline-flex items-center px-3 py-1 border border-transparent text-xs font-medium rounded text-indigo-700 bg-indigo-100 hover:bg-indigo-200 transition-colors">
            ${actionText}
          </a>
        </li>
      `
    }).join('')

    this.requirementsListTarget.innerHTML = requirementsHtml
  }

  // Start periodic check for setup completion
  startPeriodicCheck() {
    // Check every 30 seconds for setup completion
    this.checkInterval = setInterval(() => {
      this.checkSetupStatus()
    }, 30000)
  }

  // Check setup status via API
  async checkSetupStatus() {
    try {
      const response = await fetch(`/forms/${this.formIdValue}/payment_setup_status`, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (response.ok) {
        const data = await response.json()
        this.updateStatusFromAPI(data)
      }
    } catch (error) {
      console.error('Error checking payment setup status:', error)
    }
  }

  // Update status from API response
  updateStatusFromAPI(data) {
    let statusChanged = false

    if (this.stripeConfiguredValue !== data.stripe_configured) {
      this.stripeConfiguredValue = data.stripe_configured
      statusChanged = true
    }

    if (this.isPremiumValue !== data.premium_subscription) {
      this.isPremiumValue = data.premium_subscription
      statusChanged = true
    }

    if (this.setupCompleteValue !== data.setup_complete) {
      this.setupCompleteValue = data.setup_complete
      statusChanged = true
    }

    if (this.completionPercentageValue !== data.completion_percentage) {
      this.completionPercentageValue = data.completion_percentage
      statusChanged = true
    }

    if (statusChanged) {
      this.updateStatusDisplay()
      this.showStatusChangeNotification(data)
    }
  }

  // Show notification when status changes
  showStatusChangeNotification(data) {
    if (data.setup_complete) {
      this.showToast('Payment setup completed! Your form is now ready to accept payments.', 'success')
    } else if (data.completion_percentage > this.completionPercentageValue) {
      this.showToast('Payment setup progress updated.', 'info')
    }
  }

  // Show toast notification
  showToast(message, type = 'info') {
    const toast = document.createElement('div')
    toast.className = `fixed top-4 right-4 z-50 max-w-sm w-full bg-white shadow-lg rounded-lg pointer-events-auto ring-1 ring-black ring-opacity-5 overflow-hidden`
    
    const bgColor = type === 'success' ? 'bg-green-50' : type === 'error' ? 'bg-red-50' : 'bg-blue-50'
    const textColor = type === 'success' ? 'text-green-800' : type === 'error' ? 'text-red-800' : 'text-blue-800'
    
    toast.innerHTML = `
      <div class="p-4">
        <div class="flex items-start">
          <div class="flex-shrink-0">
            <svg class="h-6 w-6 ${textColor}" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          <div class="ml-3 w-0 flex-1 pt-0.5">
            <p class="text-sm font-medium ${textColor}">${message}</p>
          </div>
          <div class="ml-4 flex-shrink-0 flex">
            <button class="bg-white rounded-md inline-flex text-gray-400 hover:text-gray-500 focus:outline-none" onclick="this.parentElement.parentElement.parentElement.parentElement.remove()">
              <span class="sr-only">Close</span>
              <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
              </svg>
            </button>
          </div>
        </div>
      </div>
    `
    
    document.body.appendChild(toast)
    
    // Auto-remove after 5 seconds
    setTimeout(() => {
      if (toast.parentNode) {
        toast.remove()
      }
    }, 5000)
  }

  // Handle payment question changes
  onPaymentQuestionAdded() {
    this.hasPaymentQuestionsValue = true
    this.updateStatusDisplay()
  }

  onPaymentQuestionRemoved() {
    // Check if there are still payment questions
    this.checkPaymentQuestions()
  }

  // Check if form still has payment questions
  async checkPaymentQuestions() {
    try {
      const response = await fetch(`/forms/${this.formIdValue}/has_payment_questions`, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (response.ok) {
        const data = await response.json()
        this.hasPaymentQuestionsValue = data.has_payment_questions
        this.updateStatusDisplay()
      }
    } catch (error) {
      console.error('Error checking payment questions:', error)
    }
  }
}