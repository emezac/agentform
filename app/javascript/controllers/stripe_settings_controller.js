import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["publishableKey", "secretKey", "webhookSecret", "submitButton", "status"]

  connect() {
    console.log('Stripe settings controller connected')
    this.showHideFields()
  }

  toggleEnabled(event) {
    this.showHideFields()
  }

  showHideFields() {
    const stripeFields = document.getElementById('stripe-fields')
    const enabledCheckbox = document.getElementById('user_stripe_enabled')
    
    if (enabledCheckbox && stripeFields) {
      if (enabledCheckbox.checked) {
        stripeFields.classList.remove('hidden')
        // Make fields required when enabled
        if (this.hasPublishableKeyTarget) this.publishableKeyTarget.required = true
        if (this.hasSecretKeyTarget) this.secretKeyTarget.required = true
      } else {
        stripeFields.classList.add('hidden')
        // Remove required when disabled
        if (this.hasPublishableKeyTarget) this.publishableKeyTarget.required = false
        if (this.hasSecretKeyTarget) this.secretKeyTarget.required = false
        
        // Clear the status
        this.hideStatus()
      }
    }
  }

  async testConnection() {
    const button = event.target
    const originalText = button.textContent
    
    // Show loading state
    button.disabled = true
    button.innerHTML = `
      <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-current" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      Testing...
    `

    try {
      const response = await fetch('/stripe_settings/test_connection', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })

      const data = await response.json()

      if (data.success) {
        this.showSuccessStatus(data)
      } else {
        this.showErrorStatus(data.error)
      }
    } catch (error) {
      console.error('Test connection error:', error)
      this.showErrorStatus('Connection test failed. Please try again.')
    } finally {
      // Reset button
      button.disabled = false
      button.textContent = originalText
    }
  }

  showSuccessStatus(data) {
    if (!this.hasStatusTarget) return
    
    this.statusTarget.className = 'mt-4 p-4 rounded-md bg-green-50 border border-green-200'
    this.statusTarget.innerHTML = `
      <div class="flex items-start">
        <svg class="w-5 h-5 text-green-600 mt-0.5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
        </svg>
        <div class="flex-1">
          <h4 class="text-sm font-medium text-green-900">Connection Successful!</h4>
          <div class="mt-2 text-sm text-green-700">
            <p><strong>Account ID:</strong> ${data.account_id}</p>
            ${data.business_name ? `<p><strong>Business:</strong> ${data.business_name}</p>` : ''}
            <p><strong>Country:</strong> ${data.country}</p>
            <p><strong>Currency:</strong> ${data.currency}</p>
            <p><strong>Charges Enabled:</strong> ${data.charges_enabled ? 'Yes' : 'No'}</p>
            <p><strong>Payouts Enabled:</strong> ${data.payouts_enabled ? 'Yes' : 'No'}</p>
          </div>
        </div>
      </div>
    `
    this.statusTarget.classList.remove('hidden')
  }

  showErrorStatus(error) {
    if (!this.hasStatusTarget) return
    
    this.statusTarget.className = 'mt-4 p-4 rounded-md bg-red-50 border border-red-200'
    this.statusTarget.innerHTML = `
      <div class="flex items-start">
        <svg class="w-5 h-5 text-red-600 mt-0.5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
        </svg>
        <div>
          <h4 class="text-sm font-medium text-red-900">Connection Failed</h4>
          <p class="mt-1 text-sm text-red-700">${error}</p>
        </div>
      </div>
    `
    this.statusTarget.classList.remove('hidden')
  }

  hideStatus() {
    if (this.hasStatusTarget) {
      this.statusTarget.classList.add('hidden')
    }
  }

  validateKeys() {
    if (!this.hasPublishableKeyTarget || !this.hasSecretKeyTarget) return true
    
    const publishableKey = this.publishableKeyTarget.value
    const secretKey = this.secretKeyTarget.value
    
    let isValid = true
    
    // Validate publishable key
    if (publishableKey && !publishableKey.startsWith('pk_')) {
      this.showFieldError(this.publishableKeyTarget, 'Publishable key must start with pk_')
      isValid = false
    } else {
      this.clearFieldError(this.publishableKeyTarget)
    }
    
    // Validate secret key
    if (secretKey && !secretKey.startsWith('sk_')) {
      this.showFieldError(this.secretKeyTarget, 'Secret key must start with sk_')
      isValid = false
    } else {
      this.clearFieldError(this.secretKeyTarget)
    }
    
    return isValid
  }

  showFieldError(field, message) {
    field.classList.add('border-red-300', 'focus:border-red-500', 'focus:ring-red-500')
    field.classList.remove('border-gray-300', 'focus:border-indigo-500', 'focus:ring-indigo-500')
    
    // Remove existing error message
    const existingError = field.parentNode.querySelector('.field-error')
    if (existingError) {
      existingError.remove()
    }
    
    // Add new error message
    const errorElement = document.createElement('p')
    errorElement.className = 'field-error mt-1 text-xs text-red-600'
    errorElement.textContent = message
    field.parentNode.appendChild(errorElement)
  }

  clearFieldError(field) {
    field.classList.remove('border-red-300', 'focus:border-red-500', 'focus:ring-red-500')
    field.classList.add('border-gray-300', 'focus:border-indigo-500', 'focus:ring-indigo-500')
    
    const errorElement = field.parentNode.querySelector('.field-error')
    if (errorElement) {
      errorElement.remove()
    }
  }
}