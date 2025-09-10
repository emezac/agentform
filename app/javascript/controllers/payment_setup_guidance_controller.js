import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="payment-setup-guidance"
export default class extends Controller {
  static values = { 
    context: String,
    errorType: String
  }

  connect() {
    this.trackGuidanceDisplay()
  }

  trackSetupStart(event) {
    const actionType = event.params.actionType
    
    if (window.analytics) {
      window.analytics.track('Payment Setup Started', {
        context: this.contextValue,
        error_type: this.errorTypeValue,
        action_type: actionType,
        timestamp: new Date().toISOString()
      })
    }
    
    console.log(`Payment setup started: ${actionType} from context: ${this.contextValue}`)
  }

  showEducationalContent() {
    this.createEducationalModal()
    this.trackEducationalContentRequest()
  }

  contactSupport() {
    this.createSupportModal()
    this.trackSupportRequest()
  }

  createEducationalModal() {
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 z-50 overflow-y-auto'
    modal.innerHTML = this.getEducationalModalContent()
    
    document.body.appendChild(modal)
    
    // Add event listeners
    modal.addEventListener('click', (e) => {
      if (e.target === modal || e.target.closest('[data-action="close-modal"]')) {
        this.closeModal(modal)
      }
    })
    
    // Focus management
    const firstFocusable = modal.querySelector('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])')
    if (firstFocusable) {
      firstFocusable.focus()
    }
  }

  createSupportModal() {
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 z-50 overflow-y-auto'
    modal.innerHTML = this.getSupportModalContent()
    
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

  getEducationalModalContent() {
    return `
      <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>
        
        <div class="inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-2xl sm:w-full sm:p-6">
          <div class="sm:flex sm:items-start">
            <div class="mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full bg-indigo-100 sm:mx-0 sm:h-10 sm:w-10">
              <svg class="h-6 w-6 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
              </svg>
            </div>
            <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left w-full">
              <h3 class="text-lg leading-6 font-medium text-gray-900">
                About Payment Features
              </h3>
              <div class="mt-2">
                <div class="prose prose-sm text-gray-500">
                  <h4 class="text-base font-medium text-gray-900 mt-4 mb-2">What are Payment Questions?</h4>
                  <p>Payment questions allow you to collect payments directly through your forms. This includes:</p>
                  <ul class="list-disc list-inside space-y-1 mt-2">
                    <li>One-time payments for products or services</li>
                    <li>Subscription signups with recurring billing</li>
                    <li>Donation collection with custom amounts</li>
                    <li>Event registration with ticket sales</li>
                  </ul>
                  
                  <h4 class="text-base font-medium text-gray-900 mt-4 mb-2">Why Stripe Integration?</h4>
                  <p>Stripe is a secure, industry-leading payment processor that:</p>
                  <ul class="list-disc list-inside space-y-1 mt-2">
                    <li>Handles PCI compliance and security automatically</li>
                    <li>Supports 135+ currencies and multiple payment methods</li>
                    <li>Provides detailed analytics and reporting</li>
                    <li>Offers fraud protection and dispute management</li>
                  </ul>
                  
                  <h4 class="text-base font-medium text-gray-900 mt-4 mb-2">Premium Features</h4>
                  <p>Payment functionality is included in our Premium plans, which also provide:</p>
                  <ul class="list-disc list-inside space-y-1 mt-2">
                    <li>Unlimited forms and responses</li>
                    <li>Advanced analytics and reporting</li>
                    <li>Custom branding and white-label options</li>
                    <li>Priority support and onboarding assistance</li>
                  </ul>
                  
                  <div class="mt-4 p-4 bg-indigo-50 rounded-lg">
                    <p class="text-sm text-indigo-800">
                      <strong>Setup Time:</strong> Most users complete payment setup in 5-10 minutes. 
                      Our guided process walks you through each step.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div class="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse">
            <button type="button" 
                    class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-indigo-600 text-base font-medium text-white hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:ml-3 sm:w-auto sm:text-sm"
                    onclick="window.open('/payment_setup', '_blank')"
                    data-action="close-modal">
              Start Setup
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

  getSupportModalContent() {
    return `
      <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>
        
        <div class="inline-block align-bottom bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full sm:p-6">
          <div class="sm:flex sm:items-start">
            <div class="mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full bg-green-100 sm:mx-0 sm:h-10 sm:w-10">
              <svg class="h-6 w-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 5.636l-3.536 3.536m0 5.656l3.536 3.536M9.172 9.172L5.636 5.636m3.536 9.192L5.636 18.364M12 2.25a9.75 9.75 0 109.75 9.75A9.75 9.75 0 0012 2.25z" />
              </svg>
            </div>
            <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left w-full">
              <h3 class="text-lg leading-6 font-medium text-gray-900">
                Contact Support
              </h3>
              <div class="mt-2">
                <p class="text-sm text-gray-500 mb-4">
                  Our support team is here to help you with payment setup and any questions you might have.
                </p>
                
                <div class="space-y-3">
                  <div class="flex items-center p-3 bg-gray-50 rounded-lg">
                    <svg class="h-5 w-5 text-gray-400 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                    </svg>
                    <div>
                      <p class="text-sm font-medium text-gray-900">Email Support</p>
                      <p class="text-xs text-gray-500">support@agentform.com</p>
                    </div>
                  </div>
                  
                  <div class="flex items-center p-3 bg-gray-50 rounded-lg">
                    <svg class="h-5 w-5 text-gray-400 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                    </svg>
                    <div>
                      <p class="text-sm font-medium text-gray-900">Live Chat</p>
                      <p class="text-xs text-gray-500">Available 9 AM - 6 PM EST</p>
                    </div>
                  </div>
                  
                  <div class="flex items-center p-3 bg-gray-50 rounded-lg">
                    <svg class="h-5 w-5 text-gray-400 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                    </svg>
                    <div>
                      <p class="text-sm font-medium text-gray-900">Help Center</p>
                      <p class="text-xs text-gray-500">Guides and tutorials</p>
                    </div>
                  </div>
                </div>
                
                <div class="mt-4 p-3 bg-blue-50 rounded-lg">
                  <p class="text-sm text-blue-800">
                    <strong>Pro Tip:</strong> Include your error type "${this.errorTypeValue}" when contacting support for faster assistance.
                  </p>
                </div>
              </div>
            </div>
          </div>
          <div class="mt-5 sm:mt-4 sm:flex sm:flex-row-reverse">
            <button type="button" 
                    class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-green-600 text-base font-medium text-white hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 sm:ml-3 sm:w-auto sm:text-sm"
                    onclick="window.open('mailto:support@agentform.com?subject=Payment Setup Help - ${this.errorTypeValue}', '_blank')"
                    data-action="close-modal">
              Send Email
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

  trackGuidanceDisplay() {
    if (window.analytics) {
      window.analytics.track('Payment Setup Guidance Displayed', {
        context: this.contextValue,
        error_type: this.errorTypeValue,
        timestamp: new Date().toISOString()
      })
    }
  }

  trackEducationalContentRequest() {
    if (window.analytics) {
      window.analytics.track('Payment Educational Content Requested', {
        context: this.contextValue,
        error_type: this.errorTypeValue,
        timestamp: new Date().toISOString()
      })
    }
  }

  trackSupportRequest() {
    if (window.analytics) {
      window.analytics.track('Payment Support Requested', {
        context: this.contextValue,
        error_type: this.errorTypeValue,
        timestamp: new Date().toISOString()
      })
    }
  }
}