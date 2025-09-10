import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["option", "container"]
  static values = { 
    questionId: String,
    required: Boolean 
  }

  connect() {
    console.log('Rating controller connected for question:', this.questionIdValue)
    this.initializeSelection()
  }

  disconnect() {
    console.log('Rating controller disconnected')
  }

  // Handle rating selection
  selectRating(event) {
    console.log('Rating selected:', event.target.value)
    const radio = event.target
    const value = radio.value
    
    if (radio.checked) {
      // Remove selected class from all options
      this.optionTargets.forEach(option => {
        option.classList.remove('selected')
      })
      
      // Add selected class to clicked option
      const selectedOption = this.optionTargets.find(option => 
        option.dataset.value === value
      )
      
      if (selectedOption) {
        selectedOption.classList.add('selected')
        
        // Add a subtle animation
        selectedOption.style.animation = 'none'
        selectedOption.offsetHeight // Trigger reflow
        selectedOption.style.animation = 'pulse 0.3s ease-in-out'
      }
      
      // Also trigger the change event for the question response controller
      radio.dispatchEvent(new Event('change', { bubbles: true }))
    }
  }

  // Initialize any pre-selected values
  initializeSelection() {
    console.log('Initializing selection, options found:', this.optionTargets.length)
    this.optionTargets.forEach(option => {
      const value = option.dataset.value
      const radio = this.element.querySelector(`input[type="radio"][value="${value}"]`)
      
      if (radio && radio.checked) {
        console.log('Found pre-selected value:', value)
        option.classList.add('selected')
      }
    })
  }

  // Handle hover effects
  optionTargetConnected(element) {
    element.addEventListener('mouseenter', this.handleMouseEnter)
    element.addEventListener('mouseleave', this.handleMouseLeave)
  }

  optionTargetDisconnected(element) {
    element.removeEventListener('mouseenter', this.handleMouseEnter)
    element.removeEventListener('mouseleave', this.handleMouseLeave)
  }

  handleMouseEnter = (event) => {
    const option = event.currentTarget
    if (!option.classList.contains('selected')) {
      option.classList.add('border-indigo-400', 'bg-indigo-50', 'scale-110')
    }
  }

  handleMouseLeave = (event) => {
    const option = event.currentTarget
    if (!option.classList.contains('selected')) {
      option.classList.remove('border-indigo-400', 'bg-indigo-50', 'scale-110')
    }
  }
}