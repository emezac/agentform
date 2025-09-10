import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="discount-code"
export default class extends Controller {
  static targets = [
    "input", 
    "applyButton", 
    "clearButton",
    "feedback", 
    "originalPrice", 
    "discountAmount", 
    "finalPrice",
    "discountPercentage",
    "pricingDetails"
  ]
  
  static values = { 
    billingCycle: String,
    validateUrl: String
  }

  connect() {
    this.isValidating = false
    this.currentDiscount = null
    this.debounceTimer = null
    
    // Initialize state
    this.clearDiscount()
  }

  disconnect() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
  }

  // Handle input changes with debouncing
  inputChanged() {
    const code = this.inputTarget.value.trim()
    
    // Clear previous timer
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
    
    // Clear feedback and enable/disable buttons
    this.clearFeedback()
    this.updateButtonStates(code)
    
    // If code is empty, clear discount
    if (!code) {
      this.clearDiscount()
      return
    }
    
    // Debounce validation (wait 500ms after user stops typing)
    this.debounceTimer = setTimeout(() => {
      this.validateCode(code)
    }, 500)
  }

  // Manual apply button click
  applyDiscount(event) {
    event.preventDefault()
    const code = this.inputTarget.value.trim()
    
    if (!code) {
      this.showError("Please enter a discount code")
      return
    }
    
    this.validateCode(code)
  }

  // Clear discount code
  clearDiscount(event) {
    if (event) {
      event.preventDefault()
    }
    
    this.inputTarget.value = ""
    this.currentDiscount = null
    this.clearFeedback()
    this.resetPricing()
    this.updateButtonStates("")
    
    // Clear any pending validation
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
  }

  // Validate discount code via API
  async validateCode(code) {
    if (this.isValidating) return
    
    this.isValidating = true
    this.showLoading()
    
    try {
      const response = await fetch(this.validateUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        },
        body: JSON.stringify({
          code: code,
          billing_cycle: this.billingCycleValue
        })
      })
      
      const data = await response.json()
      
      if (response.ok && data.valid) {
        this.handleValidDiscount(data)
      } else {
        this.handleInvalidDiscount(data.error || "Invalid discount code")
      }
    } catch (error) {
      console.error('Discount validation error:', error)
      this.showError("Unable to validate discount code. Please try again.")
    } finally {
      this.isValidating = false
    }
  }

  // Handle valid discount response
  handleValidDiscount(data) {
    this.currentDiscount = data
    
    // Show success feedback
    this.showSuccess(`${data.discount_code.discount_percentage}% discount applied!`)
    
    // Update pricing display
    this.updatePricing(data.pricing)
    
    // Update button states
    this.updateButtonStates(this.inputTarget.value.trim(), true)
    
    // Dispatch custom event for other components
    this.dispatch("applied", { 
      detail: { 
        discountCode: data.discount_code,
        pricing: data.pricing
      } 
    })
  }

  // Handle invalid discount response
  handleInvalidDiscount(errorMessage) {
    this.currentDiscount = null
    this.showError(errorMessage)
    this.resetPricing()
    this.updateButtonStates(this.inputTarget.value.trim(), false)
    
    // Dispatch custom event
    this.dispatch("cleared")
  }

  // Update pricing display
  updatePricing(pricing) {
    if (this.hasOriginalPriceTarget) {
      this.originalPriceTarget.textContent = this.formatPrice(pricing.original_amount)
    }
    
    if (this.hasDiscountAmountTarget) {
      this.discountAmountTarget.textContent = `-${this.formatPrice(pricing.discount_amount)}`
    }
    
    if (this.hasFinalPriceTarget) {
      this.finalPriceTarget.textContent = this.formatPrice(pricing.final_amount)
    }
    
    if (this.hasDiscountPercentageTarget && this.currentDiscount) {
      this.discountPercentageTarget.textContent = `${this.currentDiscount.discount_code.discount_percentage}%`
    }
    
    // Show pricing details section
    if (this.hasPricingDetailsTarget) {
      this.pricingDetailsTarget.classList.remove('hidden')
    }
  }

  // Reset pricing to original values
  resetPricing() {
    if (this.hasDiscountAmountTarget) {
      this.discountAmountTarget.textContent = "$0.00"
    }
    
    if (this.hasDiscountPercentageTarget) {
      this.discountPercentageTarget.textContent = "0%"
    }
    
    // Hide pricing details section
    if (this.hasPricingDetailsTarget) {
      this.pricingDetailsTarget.classList.add('hidden')
    }
    
    // Dispatch custom event
    this.dispatch("cleared")
  }

  // Update button states based on input and validation status
  updateButtonStates(code, isValid = null) {
    const hasCode = code.length > 0
    
    // Apply button
    if (this.hasApplyButtonTarget) {
      this.applyButtonTarget.disabled = !hasCode || this.isValidating
      
      if (this.isValidating) {
        this.applyButtonTarget.textContent = "Validating..."
      } else if (isValid === true) {
        this.applyButtonTarget.textContent = "Applied ✓"
      } else {
        this.applyButtonTarget.textContent = "Apply"
      }
    }
    
    // Clear button
    if (this.hasClearButtonTarget) {
      if (hasCode || isValid === true) {
        this.clearButtonTarget.classList.remove('hidden')
      } else {
        this.clearButtonTarget.classList.add('hidden')
      }
    }
  }

  // Show loading state
  showLoading() {
    this.clearFeedback()
    if (this.hasFeedbackTarget) {
      this.feedbackTarget.innerHTML = `
        <div class="flex items-center text-sm text-gray-600">
          <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-gray-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          Validating discount code...
        </div>
      `
      this.feedbackTarget.classList.remove('hidden')
    }
  }

  // Show success message
  showSuccess(message) {
    this.clearFeedback()
    if (this.hasFeedbackTarget) {
      this.feedbackTarget.innerHTML = `
        <div class="flex items-center text-sm text-green-600">
          <svg class="mr-2 h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
          </svg>
          ${message}
        </div>
      `
      this.feedbackTarget.classList.remove('hidden')
    }
  }

  // Show error message
  showError(message) {
    this.clearFeedback()
    if (this.hasFeedbackTarget) {
      this.feedbackTarget.innerHTML = `
        <div class="flex items-center text-sm text-red-600">
          <svg class="mr-2 h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd"></path>
          </svg>
          ${message}
        </div>
      `
      this.feedbackTarget.classList.remove('hidden')
    }
  }

  // Clear feedback messages
  clearFeedback() {
    if (this.hasFeedbackTarget) {
      this.feedbackTarget.innerHTML = ""
      this.feedbackTarget.classList.add('hidden')
    }
  }

  // Format price for display
  formatPrice(cents) {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD'
    }).format(cents / 100)
  }

  // Get CSRF token for API requests
  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ''
  }

  // Getter for current discount data (for external access)
  get discountData() {
    return this.currentDiscount
  }

  // Check if discount is currently applied
  get hasDiscount() {
    return this.currentDiscount !== null
  }
}