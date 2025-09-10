// app/javascript/channels/form_response_channel.js

import consumer from "channels/consumer"

let formResponseChannel = null

export function subscribeToFormResponse(formResponseId) {
  console.log("Subscribing to FormResponse channel:", formResponseId)
  
  // Unsubscribe from previous channel if exists
  if (formResponseChannel) {
    formResponseChannel.unsubscribe()
  }
  
  formResponseChannel = consumer.subscriptions.create(
    {
      channel: "FormResponseChannel",
      form_response_id: formResponseId
    },
    {
      connected() {
        console.log("Connected to FormResponseChannel for:", formResponseId)
      },

      disconnected() {
        console.log("Disconnected from FormResponseChannel")
      },

      received(data) {
        console.log("Received broadcast data:", data)
        
        // Handle Turbo Stream HTML directly
        if (typeof data === 'string' && data.includes('<turbo-stream')) {
          console.log("Processing Turbo Stream HTML")
          
          // Create a temporary element to parse the turbo-stream
          const tempDiv = document.createElement('div')
          tempDiv.innerHTML = data
          
          const turboStream = tempDiv.querySelector('turbo-stream')
          if (turboStream) {
            const action = turboStream.getAttribute('action')
            const target = turboStream.getAttribute('target')
            const template = turboStream.querySelector('template')
            
            console.log(`Turbo Stream - Action: ${action}, Target: ${target}`)
            
            if (template && target) {
              const targetElement = document.getElementById(target)
              if (targetElement) {
                if (action === 'append') {
                  targetElement.insertAdjacentHTML('beforeend', template.innerHTML)
                } else if (action === 'prepend') {
                  targetElement.insertAdjacentHTML('afterbegin', template.innerHTML)
                } else if (action === 'replace') {
                  targetElement.outerHTML = template.innerHTML
                }
                
                console.log("Successfully updated DOM element:", target)
                this.initializeDynamicContent(targetElement)
              } else {
                console.error("Target element not found:", target)
              }
            }
          }
        } else {
          console.log("Received non-turbo-stream data:", typeof data, data)
        }
      },

      initializeDynamicContent(target) {
        console.log("Initializing dynamic content in:", target)
        
        // Add form submission handlers for dynamic questions
        const forms = target.querySelectorAll('form[data-dynamic-question]')
        forms.forEach(form => {
          console.log("Adding event listener to dynamic form:", form)
          form.addEventListener('submit', this.handleDynamicQuestionSubmit.bind(this))
        })
        
        // Add animation classes if needed
        const dynamicQuestions = target.querySelectorAll('.dynamic-question-container')
        dynamicQuestions.forEach(question => {
          question.style.opacity = '0'
          question.style.transform = 'translateY(20px)'
          
          setTimeout(() => {
            question.style.transition = 'opacity 0.3s ease, transform 0.3s ease'
            question.style.opacity = '1'
            question.style.transform = 'translateY(0)'
          }, 100)
        })
      },

      handleDynamicQuestionSubmit(event) {
        event.preventDefault()
        const form = event.target
        const formData = new FormData(form)
        
        console.log("Submitting dynamic question form:", form.action)
        
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
          console.log("Dynamic question response:", data)
          
          if (data.success) {
            // Hide the dynamic question
            form.style.display = 'none'
            
            // Show success message
            const successMessage = document.createElement('div')
            successMessage.className = 'dynamic-question-success mt-3 p-3 bg-green-100 border border-green-400 text-green-700 rounded'
            successMessage.textContent = 'Thank you for the additional information!'
            form.parentNode.insertBefore(successMessage, form.nextSibling)
          } else {
            console.error('Failed to submit dynamic question:', data.errors)
            alert('Failed to submit response. Please try again.')
          }
        })
        .catch(error => {
          console.error('Error submitting dynamic question:', error)
          alert('An error occurred. Please try again.')
        })
      }
    }
  )
  
  return formResponseChannel
}

// Auto-subscribe when page loads if form response ID is available
document.addEventListener('DOMContentLoaded', function() {
  const formResponseElement = document.querySelector('[data-form-response-id]')
  if (formResponseElement) {
    const formResponseId = formResponseElement.getAttribute('data-form-response-id')
    console.log("Auto-subscribing to FormResponse:", formResponseId)
    subscribeToFormResponse(formResponseId)
  }
})