import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status"]

  connect() {
    this.checkConnectionStatus()
  }

  async checkConnectionStatus() {
    try {
      const response = await fetch('/google_oauth/status', {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      const data = await response.json()
      this.updateStatusDisplay(data)
    } catch (error) {
      console.error('Failed to check Google connection status:', error)
    }
  }

  async testConnection() {
    const button = event.target
    const originalText = button.innerHTML
    
    button.disabled = true
    button.innerHTML = `
      <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-gray-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      Testing...
    `

    try {
      // Test by making a simple API call to Google Sheets
      const response = await fetch('/google_oauth/status', {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      const data = await response.json()
      
      if (data.connected) {
        this.showNotification('Google Sheets connection is working perfectly!', 'success')
      } else {
        this.showNotification('Connection test failed. Please reconnect to Google.', 'error')
      }
    } catch (error) {
      this.showNotification('Connection test failed. Please check your internet connection.', 'error')
    } finally {
      button.disabled = false
      button.innerHTML = originalText
    }
  }

  showHelp() {
    const helpModal = document.createElement('div')
    helpModal.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50'
    helpModal.innerHTML = `
      <div class="bg-white rounded-lg max-w-md w-full mx-4 p-6">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-semibold text-gray-900">Google Sheets Integration Help</h3>
          <button class="text-gray-400 hover:text-gray-600" onclick="this.closest('.fixed').remove()">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>
        
        <div class="space-y-4 text-sm text-gray-600">
          <div>
            <h4 class="font-medium text-gray-900 mb-2">What happens when you connect?</h4>
            <ul class="space-y-1 ml-4">
              <li>• AgentForm will request permission to access your Google Sheets</li>
              <li>• You can create new spreadsheets or use existing ones</li>
              <li>• Form responses will be automatically exported to your chosen sheets</li>
              <li>• You maintain full control over your Google account</li>
            </ul>
          </div>
          
          <div>
            <h4 class="font-medium text-gray-900 mb-2">Is it secure?</h4>
            <p>Yes! We use Google's official OAuth2 protocol. AgentForm never sees your Google password and you can revoke access at any time from your Google Account settings.</p>
          </div>
          
          <div>
            <h4 class="font-medium text-gray-900 mb-2">What permissions do we need?</h4>
            <ul class="space-y-1 ml-4">
              <li>• <strong>Google Sheets:</strong> To create and update spreadsheets</li>
              <li>• <strong>Profile info:</strong> To show which account is connected</li>
            </ul>
          </div>
        </div>
        
        <div class="mt-6 flex justify-end">
          <button onclick="this.closest('.fixed').remove()" 
                  class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700">
            Got it
          </button>
        </div>
      </div>
    `
    
    document.body.appendChild(helpModal)
  }

  updateStatusDisplay(data) {
    if (!this.hasStatusTarget) return

    const statusElement = this.statusTarget
    
    if (data.connected) {
      statusElement.innerHTML = `
        <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-green-100 text-green-800">
          <div class="w-2 h-2 bg-green-400 rounded-full mr-2"></div>
          Connected
        </span>
      `
    } else {
      statusElement.innerHTML = `
        <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-gray-100 text-gray-800">
          <div class="w-2 h-2 bg-gray-400 rounded-full mr-2"></div>
          Not Connected
        </span>
      `
    }
  }

  showNotification(message, type = 'info') {
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 max-w-sm w-full bg-white shadow-lg rounded-lg pointer-events-auto ring-1 ring-black ring-opacity-5 z-50`
    
    const bgColor = {
      'success': 'bg-green-50 border-green-200',
      'error': 'bg-red-50 border-red-200',
      'info': 'bg-blue-50 border-blue-200'
    }[type] || 'bg-gray-50 border-gray-200'

    const iconColor = {
      'success': 'text-green-400',
      'error': 'text-red-400',
      'info': 'text-blue-400'
    }[type] || 'text-gray-400'

    const icon = {
      'success': '✓',
      'error': '✕',
      'info': 'ℹ'
    }[type] || 'ℹ'

    notification.innerHTML = `
      <div class="p-4 ${bgColor} border rounded-lg">
        <div class="flex">
          <div class="flex-shrink-0">
            <span class="inline-flex items-center justify-center w-5 h-5 rounded-full ${iconColor} text-sm font-medium">
              ${icon}
            </span>
          </div>
          <div class="ml-3 w-0 flex-1">
            <p class="text-sm text-gray-900">${message}</p>
          </div>
          <div class="ml-4 flex-shrink-0 flex">
            <button class="inline-flex text-gray-400 hover:text-gray-500" onclick="this.parentElement.parentElement.parentElement.parentElement.remove()">
              <span class="sr-only">Close</span>
              <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"></path>
              </svg>
            </button>
          </div>
        </div>
      </div>
    `

    document.body.appendChild(notification)

    setTimeout(() => {
      if (notification.parentNode) {
        notification.remove()
      }
    }, 5000)
  }
}