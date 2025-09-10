import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="auto-dismiss"
export default class extends Controller {
  static values = { delay: Number }
  
  connect() {
    this.timeout = setTimeout(() => {
      this.dismiss()
    }, this.delayValue || 5000)
  }
  
  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }
  
  dismiss() {
    this.element.style.transition = "opacity 0.3s ease-out, transform 0.3s ease-out"
    this.element.style.opacity = "0"
    this.element.style.transform = "translateY(-10px)"
    
    setTimeout(() => {
      if (this.element.parentNode) {
        this.element.remove()
      }
    }, 300)
  }
}