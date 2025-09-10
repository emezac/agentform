import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="payment-setup-required-button"
export default class extends Controller {
  static values = { 
    errorType: String
  }

  connect() {
    this.trackButtonDisplay()
  }

  trackSetupClick(event) {
    const actionType = event.params.actionType
    
    if (window.analytics) {
      window.analytics.track('Payment Setup Button Clicked', {
        error_type: this.errorTypeValue,
        action_type: actionType,
        timestamp: new Date().toISOString()
      })
    }
    
    console.log(`Payment setup button clicked: ${actionType} for error: ${this.errorTypeValue}`)
  }

  trackPublishClick() {
    if (window.analytics) {
      window.analytics.track('Form Publish Button Clicked', {
        has_payment_setup_error: false,
        timestamp: new Date().toISOString()
      })
    }
    
    console.log('Form publish button clicked (no payment errors)')
  }

  trackButtonDisplay() {
    if (window.analytics) {
      window.analytics.track('Payment Setup Required Button Displayed', {
        error_type: this.errorTypeValue,
        timestamp: new Date().toISOString()
      })
    }
  }
}