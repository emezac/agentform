import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="payment-error-flash"
export default class extends Controller {
  static values = { 
    errorType: String,
    dismissible: Boolean
  }
  
  static targets = ["helpModal", "checklistModal"]

  connect() {
    this.trackErrorDisplay()
    
    // Auto-dismiss after 10 seconds if dismissible
    if (this.dismissibleValue) {
      this.autoDismissTimeout = setTimeout(() => {
        this.dismiss()
      }, 10000)
    }
  }

  disconnect() {
    if (this.autoDismissTimeout) {
      clearTimeout(this.autoDismissTimeout)
    }
  }

  dismiss() {
    if (this.autoDismissTimeout) {
      clearTimeout(this.autoDismissTimeout)
    }
    
    this.element.style.transition = 'opacity 0.3s ease-out, transform 0.3s ease-out'
    this.element.style.opacity = '0'
    this.element.style.transform = 'translateY(-10px)'
    
    setTimeout(() => {
      this.element.remove()
    }, 300)
    
    this.trackErrorDismiss()
  }

  trackAction(event) {
    const actionType = event.params.actionType
    
    // Track the action click
    if (window.analytics) {
      window.analytics.track('Payment Error Action Clicked', {
        error_type: this.errorTypeValue,
        action_type: actionType,
        timestamp: new Date().toISOString()
      })
    }
    
    console.log(`Payment error action clicked: ${actionType} for error: ${this.errorTypeValue}`)
  }

  showHelp() {
    this.createHelpModal()
    this.trackHelpRequest()
  }

  showChecklist() {
    this.createChecklistModal()
    this.trackChecklistRequest()
  }

  createHelpModal() {
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 z-50 overflow-y-auto'
    modal.innerHTML = this.getHelpModalContent()
    
    document.body.appendChild(modal)
    
    // Add event listeners for modal close
    modal.addEventListener('click', (e) => {
      if (e.target === modal || e.target.closest('[data-action="close-modal"]')) {
        this.closeModal(modal)
      }
    })
    
    // Focus trap and accessibility
    const firstFocusable = modal.querySelector('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])')
    if (firstFocusable) {
      firstFocusable.focus()
    }
  }

  createChecklistModal() {
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 z-50 overflow-y-auto'
    modal.innerHTML = this.getChecklistModalContent()
    
    document.body.appendChild(modal)
    
    // Add event listeners
    modal.addEventListener('click', (e) => {
      if (e.target === modal || e.target.closest('[data-action="close-modal"]')) {
        this.closeModal(modal)
      }
    })
  }

  closeModal(modal) {
    modal.style.transition = 'opacity 0.3s ease-out'
    modal.style.opacity = '0'
    
    setTimeout(() => {
      modal.remove()
    }, 300)
  }

  getHelpModalContent() {
    const errorTypeHelp = this.getErrorTypeHelp()
    
    return `
      <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>
        
        <div class="inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full sm:p-6">
          <div class="sm:flex sm:items-start">
            <div class="mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full bg-blue-100 sm:mx-0 sm:h-10 sm:w-10">
              <svg class="h-6 w-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left">
              <h3 class="text-lg leading-6 font-medium text-gray-900">
                Payment Setup Help
              </h3>
              <div class="mt-2">
                <div class="text-sm text-gray-500">
                  ${errorTypeHelp.description}
                </div>
                <div class="mt-4">
                  <h4 class="font-medium text-gray-900 mb-2">Next Steps:</h4>
                  <ol class="list-decimal list-inside space-y-1 text-sm text-gray-700">
                    ${errorTypeHelp.steps.map(step => `<li>${step}</li>`).join('')}
                  </ol>
                </div>
                ${errorTypeHelp.additionalInfo ? `
                  <div class="mt-4 p-3 bg-blue-50 rounded-md">
                    <p class="text-sm text-blue-800">${errorTypeHelp.additionalInfo}</p>
                  </div>
                ` : ''}
              </div>
            </div>
          </div>
          <div class="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse">
            <button type="button" 
                    class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-blue-600 text-base font-medium text-white hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 sm:ml-3 sm:w-auto sm:text-sm"
                    data-action="close-modal">
              Got it
            </button>
            <button type="button" 
                    class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:w-auto sm:text-sm"
                    data-action="close-modal">
              Close
            </button>
          </div>
        </div>
      </div>
    `
  }

  getChecklistModalContent() {
    return `
      <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>
        
        <div class="inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-md sm:w-full sm:p-6">
          <div class="sm:flex sm:items-start">
            <div class="mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full bg-indigo-100 sm:mx-0 sm:h-10 sm:w-10">
              <svg class="h-6 w-6 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4" />
              </svg>
            </div>
            <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left w-full">
              <h3 class="text-lg leading-6 font-medium text-gray-900">
                Setup Checklist
              </h3>
              <div class="mt-2">
                <div class="space-y-3">
                  ${this.getChecklistItems().map(item => `
                    <div class="flex items-center">
                      <div class="flex-shrink-0">
                        ${item.completed ? 
                          '<svg class="h-5 w-5 text-green-500" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" /></svg>' :
                          '<svg class="h-5 w-5 text-gray-300" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm0-2a6 6 0 100-12 6 6 0 000 12z" clip-rule="evenodd" /></svg>'
                        }
                      </div>
                      <div class="ml-3 flex-1">
                        <p class="text-sm font-medium ${item.completed ? 'text-gray-900' : 'text-gray-500'}">
                          ${item.title}
                        </p>
                        ${item.description ? `<p class="text-xs text-gray-500">${item.description}</p>` : ''}
                      </div>
                    </div>
                  `).join('')}
                </div>
              </div>
            </div>
          </div>
          <div class="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse">
            <button type="button" 
                    class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-indigo-600 text-base font-medium text-white hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:ml-3 sm:w-auto sm:text-sm"
                    data-action="close-modal">
              Close
            </button>
          </div>
        </div>
      </div>
    `
  }

  getErrorTypeHelp() {
    const helpContent = {
      'stripe_not_configured': {
        description: 'Your form contains payment questions, but Stripe is not configured to process payments.',
        steps: [
          'Go to Stripe Settings in your account',
          'Connect your Stripe account or create a new one',
          'Configure your payment settings and webhooks',
          'Test your payment configuration',
          'Return to publish your form'
        ],
        additionalInfo: 'Stripe is required to securely process payments from your forms. The setup process typically takes 5-10 minutes.'
      },
      'premium_subscription_required': {
        description: 'Payment questions are a Premium feature that requires an upgraded subscription.',
        steps: [
          'Go to Subscription Management',
          'Choose a Premium plan that fits your needs',
          'Complete the upgrade process',
          'Return to publish your form with payment features'
        ],
        additionalInfo: 'Premium plans include unlimited payment forms, advanced analytics, and priority support.'
      },
      'multiple_requirements_missing': {
        description: 'Several setup steps are required before you can publish forms with payment functionality.',
        steps: [
          'Review the setup checklist below',
          'Complete each required step',
          'Verify your configuration',
          'Return to publish your form'
        ],
        additionalInfo: 'We recommend completing all setup steps at once for the best experience.'
      },
      'invalid_payment_configuration': {
        description: 'One or more payment questions in your form have configuration issues.',
        steps: [
          'Review your payment questions in the form editor',
          'Check that all required fields are properly configured',
          'Verify payment amounts and currency settings',
          'Test your payment flow',
          'Save and try publishing again'
        ],
        additionalInfo: 'Common issues include missing payment amounts, invalid currency codes, or incomplete question setup.'
      }
    }
    
    return helpContent[this.errorTypeValue] || {
      description: 'There was an issue with your payment setup.',
      steps: [
        'Review the error message above',
        'Follow the suggested actions',
        'Contact support if you need additional help'
      ],
      additionalInfo: null
    }
  }

  getChecklistItems() {
    // This would typically come from the server, but for now we'll generate based on error type
    const baseItems = [
      {
        title: 'Stripe Configuration',
        description: 'Connect and configure Stripe for payment processing',
        completed: false
      },
      {
        title: 'Premium Subscription',
        description: 'Upgrade to Premium for payment features',
        completed: false
      },
      {
        title: 'Payment Questions Setup',
        description: 'Configure payment questions in your form',
        completed: true
      }
    ]
    
    return baseItems
  }

  trackErrorDisplay() {
    if (window.analytics) {
      window.analytics.track('Payment Error Displayed', {
        error_type: this.errorTypeValue,
        timestamp: new Date().toISOString()
      })
    }
  }

  trackErrorDismiss() {
    if (window.analytics) {
      window.analytics.track('Payment Error Dismissed', {
        error_type: this.errorTypeValue,
        timestamp: new Date().toISOString()
      })
    }
  }

  trackHelpRequest() {
    if (window.analytics) {
      window.analytics.track('Payment Error Help Requested', {
        error_type: this.errorTypeValue,
        timestamp: new Date().toISOString()
      })
    }
  }

  trackChecklistRequest() {
    if (window.analytics) {
      window.analytics.track('Payment Error Checklist Requested', {
        error_type: this.errorTypeValue,
        timestamp: new Date().toISOString()
      })
    }
  }
}