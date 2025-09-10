import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="file-upload"
export default class extends Controller {
  static targets = ["fileInput", "dropZone", "fileName", "fileSize", "fileInfo", "uploadPrompt", "errorMessage"]
  static values = { 
    maxSize: { type: Number, default: 10485760 }, // 10MB in bytes
    acceptedTypes: { type: Array, default: ['application/pdf', 'text/markdown', 'text/plain'] }
  }

  connect() {
    try {
      // Check if the controller's element is visible before initializing
      if (!this.isElementVisible()) {
        console.log('file-upload controller connected but element is hidden, skipping initialization')
        return
      }
      
      // Only initialize if we have the required targets
      if (!this.hasDropZoneTarget) {
        console.log('file-upload controller connected but no dropZone target found, will initialize when visible')
        return
      }
      
      this.setupDragAndDrop()
      this.hideFileInfo()
    } catch (error) {
      console.error('Error in file-upload controller connect:', error)
      // Silently fail - controller will not be functional but won't break the page
    }
  }

  // Called when the element becomes visible (e.g., when tab is switched)
  initializeWhenVisible() {
    if (this.hasDropZoneTarget && this.isElementVisible()) {
      this.setupDragAndDrop()
      this.hideFileInfo()
    }
  }

  isElementVisible() {
    const element = this.element
    if (!element) return false
    
    // Check if element or any parent has 'hidden' class
    let current = element
    while (current) {
      if (current.classList && current.classList.contains('hidden')) {
        return false
      }
      current = current.parentElement
    }
    
    // Check computed style
    const style = window.getComputedStyle(element)
    return style.display !== 'none' && style.visibility !== 'hidden'
  }

  setupDragAndDrop() {
    try {
      // Verify dropZone target exists before setting up event listeners
      if (!this.dropZoneTarget) {
        console.warn('dropZoneTarget is not available in setupDragAndDrop')
        return
      }

      // Prevent setting up multiple times
      if (this.dragDropInitialized) {
        return
      }

      // Prevent default drag behaviors on the entire document
      ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
        document.addEventListener(eventName, this.preventDefaults.bind(this), false)
      })

      // Highlight drop zone when item is dragged over it
      ['dragenter', 'dragover'].forEach(eventName => {
        this.dropZoneTarget.addEventListener(eventName, this.highlight.bind(this), false)
      })

      ['dragleave', 'drop'].forEach(eventName => {
        this.dropZoneTarget.addEventListener(eventName, this.unhighlight.bind(this), false)
      })

      // Handle dropped files
      this.dropZoneTarget.addEventListener('drop', this.handleDrop.bind(this), false)
      
      this.dragDropInitialized = true
    } catch (error) {
      console.error('Error in setupDragAndDrop:', error)
    }
  }

  disconnect() {
    // Clean up event listeners when controller is disconnected
    if (this.dragDropInitialized) {
      ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
        document.removeEventListener(eventName, this.preventDefaults.bind(this), false)
      })
    }
    
    // Remove tab switch listener
    this.element.removeEventListener('tabs:switched', this.handleTabSwitch.bind(this))
  }

  // Handle tab switch events
  handleTabSwitch(event) {
    const { activeTab } = event.detail
    
    // If switching to document tab and we haven't initialized yet, do it now
    if (activeTab === 'document' && !this.dragDropInitialized) {
      setTimeout(() => {
        this.initializeWhenVisible()
      }, 100) // Small delay to ensure DOM updates are complete
    }
  }

  preventDefaults(e) {
    e.preventDefault()
    e.stopPropagation()
  }

  highlight(e) {
    if (this.hasDropZoneTarget && this.dropZoneTarget) {
      this.dropZoneTarget.classList.add('border-indigo-400', 'bg-indigo-50')
      this.dropZoneTarget.classList.remove('border-gray-300')
    }
  }

  unhighlight(e) {
    if (this.hasDropZoneTarget && this.dropZoneTarget) {
      this.dropZoneTarget.classList.remove('border-indigo-400', 'bg-indigo-50')
      this.dropZoneTarget.classList.add('border-gray-300')
    }
  }

  handleDrop(e) {
    const dt = e.dataTransfer
    const files = dt.files
    this.handleFiles(files)
  }

  // Handle file selection via input
  fileSelected(event) {
    const files = event.target.files
    this.handleFiles(files)
  }

  handleFiles(files) {
    if (files.length === 0) return

    const file = files[0] // Only handle the first file
    
    if (this.validateFile(file)) {
      this.displayFileInfo(file)
      this.clearError()
      
      // Dispatch event with file data for other controllers
      this.dispatch('fileSelected', { 
        detail: { 
          file: file,
          fileName: file.name,
          fileSize: file.size,
          fileType: file.type
        } 
      })
    }
  }

  validateFile(file) {
    // Check file size
    if (file.size > this.maxSizeValue) {
      this.showError(`File size must be less than ${this.formatFileSize(this.maxSizeValue)}`)
      return false
    }

    // Check file type
    if (!this.acceptedTypesValue.includes(file.type)) {
      const acceptedExtensions = this.getAcceptedExtensions()
      this.showError(`Please upload a valid file type: ${acceptedExtensions.join(', ')}`)
      return false
    }

    return true
  }

  displayFileInfo(file) {
    if (this.hasFileNameTarget) {
      this.fileNameTarget.textContent = file.name
    }
    
    if (this.hasFileSizeTarget) {
      this.fileSizeTarget.textContent = this.formatFileSize(file.size)
    }
    
    // Hide upload prompt and show file info
    this.hideUploadPrompt()
    
    if (this.hasFileInfoTarget) {
      this.fileInfoTarget.classList.remove('hidden')
      this.fileInfoTarget.classList.add('animate-fade-in')
    }
  }

  hideFileInfo() {
    if (this.hasFileInfoTarget) {
      this.fileInfoTarget.classList.add('hidden')
    }
  }

  showUploadPrompt() {
    if (this.hasUploadPromptTarget) {
      this.uploadPromptTarget.classList.remove('hidden')
    }
  }

  hideUploadPrompt() {
    if (this.hasUploadPromptTarget) {
      this.uploadPromptTarget.classList.add('hidden')
    }
  }

  clearFile() {
    // Clear the file input
    if (this.hasFileInputTarget) {
      this.fileInputTarget.value = ''
    }
    
    // Hide file info and show upload prompt
    this.hideFileInfo()
    this.showUploadPrompt()
    
    // Clear any errors
    this.clearError()
    
    // Dispatch cleared event
    this.dispatch('fileCleared')
  }

  showError(message) {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.textContent = message
      this.errorMessageTarget.classList.remove('hidden')
      this.errorMessageTarget.classList.add('animate-fade-in')
    }
  }

  clearError() {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.classList.add('hidden')
      this.errorMessageTarget.textContent = ''
    }
  }

  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes'
    
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }

  getAcceptedExtensions() {
    const typeMap = {
      'application/pdf': 'PDF',
      'text/markdown': 'Markdown (.md)',
      'text/plain': 'Text (.txt)'
    }
    
    return this.acceptedTypesValue.map(type => typeMap[type] || type)
  }

  // Public method to trigger file selection
  triggerFileSelect() {
    if (this.hasFileInputTarget) {
      this.fileInputTarget.click()
    }
  }

  // Drag event handlers for external use
  dragOver(event) {
    this.highlight(event)
  }

  dragEnter(event) {
    this.highlight(event)
  }

  dragLeave(event) {
    this.unhighlight(event)
  }

  drop(event) {
    this.unhighlight(event)
    this.handleDrop(event)
  }
}