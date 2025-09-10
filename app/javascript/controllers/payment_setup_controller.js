import { Controller } from "@hotwired/stimulus"

// Stimulus controller for handling payment setup guidance and status updates
export default class extends Controller {
  static targets = ["setupChecklist", "requirementItem", "actionButton", "statusIndicator"]
  static values = { 
    hasPaymentQuestions: Boolean,
    stripeConfigured: Boolean,
    isPremium: Boolean,
    requiredFeatures: Array
  }

  connect() {
    console.log('Payment setup controller connected')
    this.updateSetupStatus()
    this.showRequiredActions()
    this.setupPolling()
  }

  disconnect() {
    this.stopPolling()
  }

  // Updates UI based on current setup status
  updateSetupStatus() {
    if (!this.hasPaymentQuestionsValue) {
      this.hideSetupRequirements()
      return
    }

    const setupComplete = this.stripeConfiguredValue && this.isPremiumValue
    const setupProgress = this.calculateSetupProgress()

    // Update status indicators
    this.statusIndicatorTargets.forEach(indicator => {
      this.updateStatusIndicator(indicator, setupComplete, setupProgress)
    })

    // Update checklist items
    this.updateChecklistItems()

    // Show/hide action buttons based on status
    this.updateActionButtons(setupComplete)

    // Dispatch custom event for other controllers to listen to
    this.dispatch('statusUpdated', { 
      detail: { 
        setupComplete, 
        setupProgress,
        stripeConfigured: this.stripeConfiguredValue,
        isPremium: this.isPremiumValue
      } 
    })
  }

  // Displays required setup actions
  showRequiredActions() {
    if (!this.hasPaymentQuestionsValue) return

    const missingRequirements = this.getMissingRequirements()
    
    this.requirementItemTargets.forEach(item => {
      const requirement = item.dataset.requirement
      const isComplete = !missingRequirements.includes(requirement)
      
      this.updateRequirementItem(item, requirement, isComplete)
    })

    // Show setup checklist if there are missing requirements
    if (missingRequirements.length > 0 && this.hasSetupChecklistTarget) {
      this.setupChecklistTarget.classList.remove('hidden')
      this.animateChecklistAppearance()
    }
  }

  // Handles setup action initiation
  initiateSetup(event) {
    event.preventDefault()
    
    const actionType = event.currentTarget.dataset.setupAction
    const actionUrl = event.currentTarget.dataset.actionUrl
    
    // Track setup initiation
    this.trackSetupEvent('setup_initiated', { action: actionType })
    
    switch (actionType) {
      case 'stripe_configuration':
        this.initiateStripeSetup(actionUrl)
        break
      case 'premium_subscription':
        this.initiatePremiumUpgrade(actionUrl)
        break
      case 'complete_setup':
        this.initiateCompleteSetup()
        break
      default:
        console.warn('Unknown setup action:', actionType)
    }
  }

  // Polls for setup completion status
  checkSetupProgress() {
    if (!this.hasPaymentQuestionsValue) return

    fetch('/payment_setup/status', {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.updateSetupValues(data.setup_status)
        this.updateSetupStatus()
      }
    })
    .catch(error => {
      console.warn('Failed to check setup progress:', error)
    })
  }

  // Private methods

  calculateSetupProgress() {
    const totalRequirements = 2 // Stripe + Premium
    let completedRequirements = 0
    
    if (this.stripeConfiguredValue) completedRequirements++
    if (this.isPremiumValue) completedRequirements++
    
    return Math.round((completedRequirements / totalRequirements) * 100)
  }

  getMissingRequirements() {
    const missing = []
    
    if (!this.stripeConfiguredValue) missing.push('stripe_configuration')
    if (!this.isPremiumValue) missing.push('premium_subscription')
    
    return missing
  }

  updateStatusIndicator(indicator, setupComplete, setupProgress) {
    const progressBar = indicator.querySelector('.progress-bar')
    const statusText = indicator.querySelector('.status-text')
    const statusIcon = indicator.querySelector('.status-icon')
    
    if (progressBar) {
      progressBar.style.width = `${setupProgress}%`
      progressBar.className = setupComplete 
        ? 'progress-bar bg-green-500 h-2 rounded-full transition-all duration-500'
        : 'progress-bar bg-indigo-500 h-2 rounded-full transition-all duration-500'
    }
    
    if (statusText) {
      statusText.textContent = setupComplete 
        ? 'Payment setup complete' 
        : `Setup ${setupProgress}% complete`
    }
    
    if (statusIcon) {
      statusIcon.innerHTML = setupComplete
        ? '<svg class="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>'
        : '<svg class="w-5 h-5 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>'
    }
  }

  updateChecklistItems() {
    this.requirementItemTargets.forEach(item => {
      const requirement = item.dataset.requirement
      let isComplete = false
      
      switch (requirement) {
        case 'stripe_configuration':
          isComplete = this.stripeConfiguredValue
          break
        case 'premium_subscription':
          isComplete = this.isPremiumValue
          break
      }
      
      this.updateRequirementItem(item, requirement, isComplete)
    })
  }

  updateRequirementItem(item, requirement, isComplete) {
    const checkbox = item.querySelector('.requirement-checkbox')
    const text = item.querySelector('.requirement-text')
    const actionButton = item.querySelector('.requirement-action')
    
    if (checkbox) {
      checkbox.checked = isComplete
      checkbox.className = isComplete
        ? 'requirement-checkbox w-4 h-4 text-green-600 bg-green-100 border-green-300 rounded focus:ring-green-500'
        : 'requirement-checkbox w-4 h-4 text-gray-400 bg-gray-100 border-gray-300 rounded focus:ring-indigo-500'
    }
    
    if (text) {
      text.className = isComplete
        ? 'requirement-text text-sm text-green-700 line-through'
        : 'requirement-text text-sm text-gray-700'
    }
    
    if (actionButton) {
      actionButton.style.display = isComplete ? 'none' : 'inline-flex'
    }
    
    // Add completion animation
    if (isComplete && !item.dataset.wasComplete) {
      item.classList.add('animate-pulse')
      setTimeout(() => item.classList.remove('animate-pulse'), 1000)
      item.dataset.wasComplete = 'true'
    }
  }

  updateActionButtons(setupComplete) {
    this.actionButtonTargets.forEach(button => {
      const buttonType = button.dataset.buttonType
      
      if (buttonType === 'complete-setup') {
        button.style.display = setupComplete ? 'none' : 'inline-flex'
      } else if (buttonType === 'publish-form') {
        button.disabled = !setupComplete
        button.className = setupComplete
          ? 'inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500'
          : 'inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-gray-400 bg-gray-200 cursor-not-allowed'
      }
    })
  }

  hideSetupRequirements() {
    if (this.hasSetupChecklistTarget) {
      this.setupChecklistTarget.classList.add('hidden')
    }
  }

  animateChecklistAppearance() {
    if (this.hasSetupChecklistTarget) {
      this.setupChecklistTarget.style.opacity = '0'
      this.setupChecklistTarget.style.transform = 'translateY(-10px)'
      
      setTimeout(() => {
        this.setupChecklistTarget.style.transition = 'opacity 0.3s ease-out, transform 0.3s ease-out'
        this.setupChecklistTarget.style.opacity = '1'
        this.setupChecklistTarget.style.transform = 'translateY(0)'
      }, 100)
    }
  }

  initiateStripeSetup(actionUrl) {
    // Open Stripe configuration in new tab to preserve form state
    const stripeUrl = actionUrl || '/stripe_settings'
    window.open(stripeUrl, '_blank', 'noopener,noreferrer')
    
    // Start polling for completion
    this.startSetupPolling('stripe_configuration')
  }

  initiatePremiumUpgrade(actionUrl) {
    // Open subscription management in new tab
    const subscriptionUrl = actionUrl || '/subscription_management'
    window.open(subscriptionUrl, '_blank', 'noopener,noreferrer')
    
    // Start polling for completion
    this.startSetupPolling('premium_subscription')
  }

  initiateCompleteSetup() {
    // Show modal with both setup options
    this.showCompleteSetupModal()
  }

  showCompleteSetupModal() {
    // Create and show modal with setup options
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 z-50 overflow-y-auto'
    modal.innerHTML = `
      <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>
        <div class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full">
          <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
            <h3 class="text-lg leading-6 font-medium text-gray-900 mb-4">Complete Payment Setup</h3>
            <div class="space-y-4">
              ${!this.stripeConfiguredValue ? `
                <div class="flex items-center justify-between p-3 border rounded-lg">
                  <div>
                    <h4 class="font-medium">Configure Stripe</h4>
                    <p class="text-sm text-gray-600">Set up payment processing</p>
                  </div>
                  <button class="setup-action-btn bg-indigo-600 text-white px-3 py-1 rounded text-sm" data-action="stripe">
                    Configure
                  </button>
                </div>
              ` : ''}
              ${!this.isPremiumValue ? `
                <div class="flex items-center justify-between p-3 border rounded-lg">
                  <div>
                    <h4 class="font-medium">Upgrade to Premium</h4>
                    <p class="text-sm text-gray-600">Unlock payment features</p>
                  </div>
                  <button class="setup-action-btn bg-indigo-600 text-white px-3 py-1 rounded text-sm" data-action="premium">
                    Upgrade
                  </button>
                </div>
              ` : ''}
            </div>
          </div>
          <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
            <button class="close-modal-btn mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm">
              Close
            </button>
          </div>
        </div>
      </div>
    `
    
    document.body.appendChild(modal)
    
    // Add event listeners
    modal.querySelector('.close-modal-btn').addEventListener('click', () => {
      document.body.removeChild(modal)
    })
    
    modal.querySelectorAll('.setup-action-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const action = e.target.dataset.action
        if (action === 'stripe') {
          this.initiateStripeSetup()
        } else if (action === 'premium') {
          this.initiatePremiumUpgrade()
        }
        document.body.removeChild(modal)
      })
    })
  }

  setupPolling() {
    // Poll every 5 seconds when setup is incomplete
    if (!this.stripeConfiguredValue || !this.isPremiumValue) {
      this.pollingInterval = setInterval(() => {
        this.checkSetupProgress()
      }, 5000)
    }
  }

  stopPolling() {
    if (this.pollingInterval) {
      clearInterval(this.pollingInterval)
      this.pollingInterval = null
    }
  }

  startSetupPolling(setupType) {
    // More frequent polling when user is actively setting up
    this.activeSetupPolling = setInterval(() => {
      this.checkSetupProgress()
    }, 2000)
    
    // Stop active polling after 2 minutes
    setTimeout(() => {
      if (this.activeSetupPolling) {
        clearInterval(this.activeSetupPolling)
        this.activeSetupPolling = null
      }
    }, 120000)
  }

  updateSetupValues(setupStatus) {
    this.stripeConfiguredValue = setupStatus.stripe_configured
    this.isPremiumValue = setupStatus.premium_subscription
  }

  trackSetupEvent(eventType, additionalData = {}) {
    const eventData = {
      has_payment_questions: this.hasPaymentQuestionsValue,
      stripe_configured: this.stripeConfiguredValue,
      is_premium: this.isPremiumValue,
      required_features: this.requiredFeaturesValue,
      event_type: eventType,
      timestamp: new Date().toISOString(),
      ...additionalData
    }

    // Send to analytics if available
    if (window.analytics && typeof window.analytics.track === 'function') {
      window.analytics.track('payment_setup_interaction', eventData)
    }

    // Log to console in development
    if (process.env.NODE_ENV === 'development') {
      console.log('Payment Setup Event:', eventData)
    }

    // Send to server for logging
    this.sendSetupEvent(eventData)
  }

  async sendSetupEvent(eventData) {
    try {
      await fetch('/analytics/payment_setup', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
        },
        body: JSON.stringify({ event: eventData })
      })
    } catch (error) {
      console.warn('Failed to send payment setup event:', error)
    }
  }
}