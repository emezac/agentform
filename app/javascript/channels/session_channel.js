// app/javascript/channels/session_channel.js

import consumer from "channels/consumer"

const sessionChannel = consumer.subscriptions.create("SessionChannel", {
  connected() {
    console.log("Connected to SessionChannel")
  },

  disconnected() {
    console.log("Disconnected from SessionChannel")
  },

  received(data) {
    console.log("Received data:", data)
    
    if (data.type === 'turbo_stream') {
      // Handle Turbo Stream data
      const target = document.getElementById(data.target)
      
      if (target) {
        if (data.action === 'append') {
          target.insertAdjacentHTML('beforeend', data.html)
        } else if (data.action === 'prepend') {
          target.insertAdjacentHTML('afterbegin', data.html)
        } else if (data.action === 'replace') {
          target.outerHTML = data.html
        }
        
        console.log(`Dynamic question added to ${data.target}`)
        
        // Trigger any JavaScript that needs to run after the content is added
        this.initializeDynamicContent(target)
      } else {
        console.warn(`Target element ${data.target} not found`)
      }
    }
  },

  initializeDynamicContent(target) {
    // Initialize any JavaScript needed for the new dynamic content
    // For example, form validation, event listeners, etc.
    
    // Re-run Stimulus controllers if you're using them
    if (window.Stimulus) {
      window.Stimulus.load()
    }
    
    // Add form submission handlers for dynamic questions
    const forms = target.querySelectorAll('form[data-dynamic-question]')
    forms.forEach(form => {
      form.addEventListener('submit', this.handleDynamicQuestionSubmit.bind(this))
    })
  },

  handleDynamicQuestionSubmit(event) {
    event.preventDefault()
    const form = event.target
    const formData = new FormData(form)
    
    // Submit the dynamic question response
    fetch(form.action, {
      method: 'POST',
      body: formData,
      headers: {
        'X-Requested-With': 'XMLHttpRequest',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        // Hide the dynamic question or show a thank you message
        form.style.display = 'none'
        
        // Optionally show a success message
        const successMessage = document.createElement('div')
        successMessage.className = 'dynamic-question-success'
        successMessage.textContent = 'Thank you for the additional information!'
        form.parentNode.insertBefore(successMessage, form.nextSibling)
      } else {
        console.error('Failed to submit dynamic question:', data.errors)
      }
    })
    .catch(error => {
      console.error('Error submitting dynamic question:', error)
    })
  }
})