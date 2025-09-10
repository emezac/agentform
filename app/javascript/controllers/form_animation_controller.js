import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["questionContainer", "progressBar", "navigationButtons", "progressFill", "questionInput"]
  static values = {
    currentStep: Number,
    totalSteps: Number,
    animationType: { type: String, default: "slide-up-elegant" },
    animationDuration: { type: Number, default: 400 }
  }

  connect() {
    console.log('Form animation controller connected')
    this.isAnimating = false
    
    // Apply initial animation styles without hiding content
    this.setupInitialAnimations()
  }

  disconnect() {
    // Clean up any running animations
    if (this.animationTimeout) {
      clearTimeout(this.animationTimeout)
    }
  }

  setupInitialAnimations() {
    // Only apply animations if elements are visible
    const elementsToAnimate = [
      { element: this.element, delay: 0, name: 'main container' },
      { element: this.hasProgressBarTarget ? this.progressBarTarget : null, delay: 150, name: 'progress bar' },
      { element: this.hasQuestionInputTarget ? this.questionInputTarget : null, delay: 300, name: 'question input' },
      { element: this.hasNavigationButtonsTarget ? this.navigationButtonsTarget : null, delay: 450, name: 'navigation buttons' }
    ].filter(item => item.element)

    console.log(`Setting up animations for ${elementsToAnimate.length} elements`)

    elementsToAnimate.forEach(({ element, delay, name }) => {
      if (element) {
        console.log(`Preparing animation for: ${name}`)
        
        // Set initial state for animation (subtle, won't break functionality)
        element.style.transform = 'translateY(15px)'
        element.style.opacity = '0.7'
        
        // Animate in after delay
        setTimeout(() => {
          this.animateElementIn(element, name)
        }, delay)
      }
    })
  }

  animateElementIn(element, name = 'element') {
    if (!element) return
    
    console.log(`✨ Animating ${name} in`)
    
    // Apply smooth transition
    element.style.transition = 'all 0.6s cubic-bezier(0.16, 1, 0.3, 1)'
    element.style.transform = 'translateY(0)'
    element.style.opacity = '1'
    
    // Add subtle bounce effect
    setTimeout(() => {
      element.style.transform = 'translateY(-2px)'
      setTimeout(() => {
        element.style.transform = 'translateY(0)'
        
        // Clean up after animation
        setTimeout(() => {
          element.style.transition = ''
          element.style.transform = ''
          element.style.opacity = ''
          console.log(`✅ Animation complete for ${name}`)
        }, 200)
      }, 100)
    }, 500)
  }

  animateElementOut(element, callback) {
    if (!element) {
      if (callback) callback()
      return
    }
    
    console.log('Animating element out:', element.className)
    
    this.isAnimating = true
    element.style.transition = 'all 0.3s cubic-bezier(0.4, 0, 0.6, 1)'
    element.style.transform = 'translateY(-20px)'
    element.style.opacity = '0.5'
    
    setTimeout(() => {
      this.isAnimating = false
      if (callback) callback()
    }, 300)
  }

  // Public methods for external controllers
  animateNextQuestion() {
    console.log('Animating to next question')
    
    // Simple fade out animation
    if (this.element) {
      this.animateElementOut(this.element)
    }
  }

  showLoadingState() {
    const submitButton = this.element.querySelector('[data-question-response-target="submitButton"]')
    if (submitButton) {
      submitButton.style.opacity = '0.7'
      submitButton.style.pointerEvents = 'none'
    }
  }

  hideLoadingState() {
    const submitButton = this.element.querySelector('[data-question-response-target="submitButton"]')
    if (submitButton) {
      submitButton.style.opacity = '1'
      submitButton.style.pointerEvents = 'auto'
    }
  }
}