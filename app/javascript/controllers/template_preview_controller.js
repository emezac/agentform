import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="template-preview"
export default class extends Controller {
  static targets = ["paymentBadge", "requirementsList", "setupModal"]
  static values = { 
    templateId: String,
    hasPaymentQuestions: Boolean,
    requiredFeatures: Array
  }

  connect() {
    this.updatePaymentBadgeVisibility()
  }

  // Show payment requirements modal when user clicks on payment badge or requirements
  showPaymentRequirements(event) {
    event.preventDefault()
    
    if (!this.hasPaymentQuestionsValue) {
      return
    }

    this.populateRequirementsList()
    this.showModal()
  }

  // User chooses to proceed with guided setup
  proceedWithSetup(event) {
    event.preventDefault()
    
    // Track analytics event
    this.trackEvent('payment_setup_initiated', {
      template_id: this.templateIdValue,
      required_features: this.requiredFeaturesValue
    })

    // Redirect to payment setup with template context
    const setupUrl = `/payment_setup?template_id=${this.templateIdValue}&return_to=${encodeURIComponent(window.location.pathname)}`
    window.location.href = setupUrl
  }

  // User chooses to proceed without setup (with reminders)
  proceedWithoutSetup(event) {
    event.preventDefault()
    
    // Track analytics event
    this.trackEvent('payment_setup_skipped', {
      template_id: this.templateIdValue,
      required_features: this.requiredFeaturesValue
    })

    // Close modal and proceed with template instantiation
    this.hideModal()
    
    // Redirect to template instantiation
    const instantiateUrl = `/templates/${this.templateIdValue}/instantiate`
    
    // Create a form and submit it (for POST request)
    const form = document.createElement('form')
    form.method = 'POST'
    form.action = instantiateUrl
    
    // Add CSRF token
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
    if (csrfToken) {
      const csrfInput = document.createElement('input')
      csrfInput.type = 'hidden'
      csrfInput.name = 'authenticity_token'
      csrfInput.value = csrfToken
      form.appendChild(csrfInput)
    }
    
    // Add skip setup parameter
    const skipSetupInput = document.createElement('input')
    skipSetupInput.type = 'hidden'
    skipSetupInput.name = 'skip_setup'
    skipSetupInput.value = 'true'
    form.appendChild(skipSetupInput)
    
    document.body.appendChild(form)
    form.submit()
  }

  // Close modal
  closeModal(event) {
    if (event) {
      event.preventDefault()
    }
    this.hideModal()
  }

  // Handle escape key to close modal
  handleKeydown(event) {
    if (event.key === 'Escape') {
      this.closeModal()
    }
  }

  // Private methods

  updatePaymentBadgeVisibility() {
    if (this.hasPaymentBadgeTarget) {
      if (this.hasPaymentQuestionsValue) {
        this.paymentBadgeTarget.classList.remove('hidden')
      } else {
        this.paymentBadgeTarget.classList.add('hidden')
      }
    }
  }

  populateRequirementsList() {
    if (!this.hasRequirementsListTarget) return

    const requirements = this.requiredFeaturesValue || []
    const requirementItems = requirements.map(feature => {
      const config = this.getFeatureConfig(feature)
      return `
        <div class="flex items-start space-x-3 p-3 bg-gray-50 rounded-lg">
          <div class="flex-shrink-0 w-5 h-5 mt-0.5">
            ${config.icon}
          </div>
          <div class="flex-1">
            <h4 class="text-sm font-medium text-gray-900">${config.title}</h4>
            <p class="text-xs text-gray-600 mt-1">${config.description}</p>
          </div>
        </div>
      `
    }).join('')

    this.requirementsListTarget.innerHTML = requirementItems
  }

  getFeatureConfig(feature) {
    const configs = {
      'stripe_payments': {
        title: 'Stripe Payment Configuration',
        description: 'Connect your Stripe account to accept payments through forms',
        icon: '<svg class="w-5 h-5 text-blue-600" fill="currentColor" viewBox="0 0 20 20"><path d="M4 4a2 2 0 00-2 2v1h16V6a2 2 0 00-2-2H4zM18 9H2v5a2 2 0 002 2h12a2 2 0 002-2V9zM4 13a1 1 0 011-1h1a1 1 0 110 2H5a1 1 0 01-1-1zm5-1a1 1 0 100 2h1a1 1 0 100-2H9z"></path></svg>'
      },
      'premium_subscription': {
        title: 'Premium Subscription',
        description: 'Upgrade to Premium to unlock payment features and advanced functionality',
        icon: '<svg class="w-5 h-5 text-purple-600" fill="currentColor" viewBox="0 0 20 20"><path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"></path></svg>'
      }
    }

    return configs[feature] || {
      title: feature.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase()),
      description: 'Required for payment functionality',
      icon: '<svg class="w-5 h-5 text-gray-600" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"></path></svg>'
    }
  }

  showModal() {
    if (this.hasSetupModalTarget) {
      this.setupModalTarget.classList.remove('hidden')
      document.body.classList.add('overflow-hidden')
      
      // Focus trap
      const focusableElements = this.setupModalTarget.querySelectorAll(
        'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
      )
      if (focusableElements.length > 0) {
        focusableElements[0].focus()
      }

      // Add escape key listener
      document.addEventListener('keydown', this.handleKeydown.bind(this))
    }
  }

  hideModal() {
    if (this.hasSetupModalTarget) {
      this.setupModalTarget.classList.add('hidden')
      document.body.classList.remove('overflow-hidden')
      
      // Remove escape key listener
      document.removeEventListener('keydown', this.handleKeydown.bind(this))
    }
  }

  trackEvent(eventName, properties = {}) {
    // Integration with analytics system
    if (window.analytics && typeof window.analytics.track === 'function') {
      window.analytics.track(eventName, {
        ...properties,
        timestamp: new Date().toISOString(),
        page: window.location.pathname
      })
    }

    // Fallback to console for development
    // Check if we're in development by looking for Rails development indicators
    const isDevelopment = document.querySelector('meta[name="environment"]')?.getAttribute('content') === 'development' ||
                         window.location.hostname === 'localhost' ||
                         window.location.hostname === '127.0.0.1'
    
    if (isDevelopment) {
      console.log(`Analytics Event: ${eventName}`, properties)
    }
  }
}