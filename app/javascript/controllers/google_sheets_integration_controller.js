import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "setupType", 
    "setupForm", 
    "newSpreadsheetOptions", 
    "existingSpreadsheetOptions",
    "spreadsheetTitle",
    "spreadsheetId",
    "sheetName",
    "autoSync",
    "exportExisting"
  ]
  
  static values = { 
    formId: String 
  }

  connect() {
    // Use setTimeout to ensure DOM is fully loaded
    setTimeout(() => {
      this.updateSetupOptions()
    }, 100)
  }

  disconnect() {
    // Clean up any resources when controller is disconnected
    // Remove any pending timeouts or event listeners if needed
  }

  setupTypeChanged() {
    this.updateSetupOptions()
  }

  updateSetupOptions() {
    // Check if targets exist before using them
    if (!this.hasNewSpreadsheetOptionsTarget || !this.hasExistingSpreadsheetOptionsTarget) {
      return
    }
    
    const selectedType = this.setupTypeTargets.find(radio => radio.checked)?.value
    
    if (selectedType === "create_new") {
      this.newSpreadsheetOptionsTarget.classList.remove("hidden")
      this.existingSpreadsheetOptionsTarget.classList.add("hidden")
    } else {
      this.newSpreadsheetOptionsTarget.classList.add("hidden")
      this.existingSpreadsheetOptionsTarget.classList.remove("hidden")
    }
  }

  async testConnection(event) {
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
      const response = await fetch(`/forms/${this.formIdValue}/integrations/google_sheets/test_connection`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      const data = await response.json()
      
      if (data.success) {
        this.showNotification('Connection successful! Google Sheets API is working.', 'success')
        if (data.test_spreadsheet_url) {
          this.showNotification(`Test spreadsheet created: <a href="${data.test_spreadsheet_url}" target="_blank" class="underline">View here</a>`, 'info')
        }
      } else {
        this.showNotification(`Connection failed: ${data.error}`, 'error')
      }
    } catch (error) {
      this.showNotification('Connection test failed. Please check your configuration.', 'error')
    } finally {
      button.disabled = false
      button.innerHTML = originalText
    }
  }

  async setupIntegration(event) {
    const button = event.target
    const originalText = button.innerHTML
    
    button.disabled = true
    button.innerHTML = `
      <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      Connecting...
    `

    try {
      const setupType = this.setupTypeTargets.find(radio => radio.checked)?.value
      const payload = {
        google_sheets_integration: {
          sheet_name: this.sheetNameTarget.value,
          auto_sync: this.autoSyncTarget.checked
        },
        export_existing: this.exportExistingTarget.checked
      }

      if (setupType === 'create_new') {
        payload.create_new_spreadsheet = true
        payload.spreadsheet_title = this.spreadsheetTitleTarget.value
      } else {
        payload.google_sheets_integration.spreadsheet_id = this.spreadsheetIdTarget.value
      }

      const response = await fetch(`/forms/${this.formIdValue}/integrations/google_sheets`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify(payload)
      })

      const data = await response.json()
      
      if (response.ok) {
        this.showNotification(data.message, 'success')
        if (data.spreadsheet_url) {
          this.showNotification(`Spreadsheet ready: <a href="${data.spreadsheet_url}" target="_blank" class="underline">Open Google Sheets</a>`, 'info')
        }
        // Reload the page to show the connected state
        setTimeout(() => window.location.reload(), 2000)
      } else {
        this.showNotification(data.error || 'Setup failed', 'error')
      }
    } catch (error) {
      this.showNotification('Setup failed. Please try again.', 'error')
    } finally {
      button.disabled = false
      button.innerHTML = originalText
    }
  }

  async exportNow(event) {
    const button = event.target
    const originalText = button.innerHTML
    
    button.disabled = true
    button.innerHTML = `
      <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-gray-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      Exporting...
    `

    try {
      const response = await fetch(`/forms/${this.formIdValue}/integrations/google_sheets/export`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      const data = await response.json()
      
      if (response.ok) {
        this.showNotification(data.message, 'success')
        if (data.spreadsheet_url) {
          this.showNotification(`<a href="${data.spreadsheet_url}" target="_blank" class="underline">View updated spreadsheet</a>`, 'info')
        }
      } else {
        this.showNotification(data.error || 'Export failed', 'error')
      }
    } catch (error) {
      this.showNotification('Export failed. Please try again.', 'error')
    } finally {
      button.disabled = false
      button.innerHTML = originalText
    }
  }

  async toggleAutoSync(event) {
    const checkbox = event.target
    const isEnabled = checkbox.checked

    try {
      const response = await fetch(`/forms/${this.formIdValue}/integrations/google_sheets/toggle_auto_sync`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      const data = await response.json()
      
      if (response.ok) {
        this.showNotification(data.message, 'success')
      } else {
        // Revert checkbox state on error
        checkbox.checked = !isEnabled
        this.showNotification('Failed to update auto-sync setting', 'error')
      }
    } catch (error) {
      checkbox.checked = !isEnabled
      this.showNotification('Failed to update auto-sync setting', 'error')
    }
  }

  async disconnectIntegration(event) {
    if (!confirm('Are you sure you want to disconnect Google Sheets? This will stop automatic syncing.')) {
      return
    }

    const button = event.target
    const originalText = button.innerHTML
    
    button.disabled = true
    button.innerHTML = `
      <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-red-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      Disconnecting...
    `

    try {
      const response = await fetch(`/forms/${this.formIdValue}/integrations/google_sheets`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      const data = await response.json()
      
      if (response.ok) {
        this.showNotification(data.message, 'success')
        // Reload the page to show the disconnected state
        setTimeout(() => window.location.reload(), 1500)
      } else {
        this.showNotification('Failed to disconnect', 'error')
      }
    } catch (error) {
      this.showNotification('Failed to disconnect', 'error')
    } finally {
      button.disabled = false
      button.innerHTML = originalText
    }
  }

  showNotification(message, type = 'info') {
    // Create notification element
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

    // Auto-remove after 5 seconds
    setTimeout(() => {
      if (notification.parentNode) {
        notification.remove()
      }
    }, 5000)
  }
}