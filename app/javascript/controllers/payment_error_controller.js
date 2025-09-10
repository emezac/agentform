import { Controller } from "@hotwired/stimulus"

// Stimulus controller for handling payment error interactions
export default class extends Controller {
  static values = { 
    type: String,
    actions: Array
  }

  connect() {
    this.setupErrorTracking()
  }

  // Dismisses the payment error message
  dismiss(event) {
    event.preventDefault()
    
    // Track dismissal
    this.trackErrorEvent('dismissed')
    
    // Fade out and remove the error element
    this.element.style.transition = 'opacity 0.3s ease-out'
    this.element.style.opacity = '0'
    
    setTimeout(() => {
      if (this.element.parentNode) {
        this.element.remove()
      }
    }, 300)
  }

  // Handles action button clicks
  handleAction(event) {
    const actionType = event.currentTarget.dataset.action
    
    // Track action taken
    this.trackErrorEvent('action_taken', { action: actionType })
    
    // Allow default behavior (navigation) to proceed
  }

  // Sets up error tracking and analytics
  setupErrorTracking() {
    // Track error display
    this.trackErrorEvent('displayed')
    
    // Set up automatic dismissal after 30 seconds for non-critical errors
    if (this.typeValue !== 'stripe_not_configured' && this.typeValue !== 'premium_required') {
      setTimeout(() => {
        if (this.element && this.element.parentNode) {
          this.dismiss({ preventDefault: () => {} })
        }
      }, 30000)
    }
  }

  // Tracks payment error events for analytics
  trackErrorEvent(eventType, additionalData = {}) {
    const eventData = {
      error_type: this.typeValue,
      required_actions: this.actionsValue,
      event_type: eventType,
      timestamp: new Date().toISOString(),
      ...additionalData
    }

    // Send to analytics if available
    if (window.analytics && typeof window.analytics.track === 'function') {
      window.analytics.track('payment_validation_error', eventData)
    }

    // Log to console in development
    if (process.env.NODE_ENV === 'development') {
      console.log('Payment Error Event:', eventData)
    }

    // Send to server for logging
    this.sendErrorEvent(eventData)
  }

  // Sends error event to server for logging
  async sendErrorEvent(eventData) {
    try {
      await fetch('/api/v1/analytics/payment_errors', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
        },
        body: JSON.stringify({ event: eventData })
      })
    } catch (error) {
      console.warn('Failed to send payment error event:', error)
    }
  }

  // Handles retry actions
  retry(event) {
    event.preventDefault()
    
    this.trackErrorEvent('retry_attempted')
    
    // Reload the page or trigger a re-validation
    window.location.reload()
  }

  // Shows additional help information
  showHelp(event) {
    event.preventDefault()
    
    this.trackErrorEvent('help_requested')
    
    // Could open a modal or navigate to help page
    const helpUrl = event.currentTarget.dataset.helpUrl || '/help/payment-setup'
    window.open(helpUrl, '_blank')
  }
}