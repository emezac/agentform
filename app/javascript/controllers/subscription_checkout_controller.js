import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="subscription-checkout"
export default class extends Controller {
  static targets = [
    "monthlyForm", 
    "yearlyForm", 
    "monthlyButton", 
    "yearlyButton",
    "monthlyDiscountField",
    "yearlyDiscountField"
  ]

  connect() {
    this.currentDiscount = null
    this.originalPrices = {
      monthly: 29.00,
      yearly: 290.00
    }
  }

  // Handle discount applied event
  updateDiscount(event) {
    const { discountCode, pricing } = event.detail
    this.currentDiscount = {
      code: discountCode.code,
      percentage: discountCode.discount_percentage,
      pricing: pricing
    }
    
    // Update hidden discount code fields
    if (this.hasMonthlyDiscountFieldTarget) {
      this.monthlyDiscountFieldTarget.value = discountCode.code
    }
    if (this.hasYearlyDiscountFieldTarget) {
      this.yearlyDiscountFieldTarget.value = discountCode.code
    }
    
    // Update button text to show discounted prices
    this.updateButtonPricing()
  }

  // Handle discount cleared event
  clearDiscount(event) {
    this.currentDiscount = null
    
    // Clear hidden discount code fields
    if (this.hasMonthlyDiscountFieldTarget) {
      this.monthlyDiscountFieldTarget.value = ''
    }
    if (this.hasYearlyDiscountFieldTarget) {
      this.yearlyDiscountFieldTarget.value = ''
    }
    
    // Reset button text to original prices
    this.updateButtonPricing()
  }

  // Update button pricing display
  updateButtonPricing() {
    if (this.currentDiscount) {
      // Calculate discounted prices
      const monthlyDiscount = Math.round(this.originalPrices.monthly * this.currentDiscount.percentage / 100 * 100) / 100
      const yearlyDiscount = Math.round(this.originalPrices.yearly * this.currentDiscount.percentage / 100 * 100) / 100
      
      const monthlyFinal = this.originalPrices.monthly - monthlyDiscount
      const yearlyFinal = this.originalPrices.yearly - yearlyDiscount
      
      // Update monthly button
      if (this.hasMonthlyButtonTarget) {
        this.monthlyButtonTarget.innerHTML = `
          <span class="flex flex-col items-center">
            <span class="text-sm line-through opacity-75">$${this.originalPrices.monthly}/month</span>
            <span>Subscribe Monthly ($${monthlyFinal.toFixed(2)}/month)</span>
            <span class="text-xs">${this.currentDiscount.percentage}% off first payment</span>
          </span>
        `
      }
      
      // Update yearly button
      if (this.hasYearlyButtonTarget) {
        this.yearlyButtonTarget.innerHTML = `
          <span class="flex flex-col items-center">
            <span class="text-sm line-through opacity-75">$${this.originalPrices.yearly}/year</span>
            <span>Subscribe Yearly ($${yearlyFinal.toFixed(2)}/year)</span>
            <span class="text-xs">${this.currentDiscount.percentage}% off first payment</span>
          </span>
        `
      }
    } else {
      // Reset to original pricing
      if (this.hasMonthlyButtonTarget) {
        this.monthlyButtonTarget.textContent = `Subscribe Monthly ($${this.originalPrices.monthly}/month)`
      }
      
      if (this.hasYearlyButtonTarget) {
        this.yearlyButtonTarget.textContent = `Subscribe Yearly ($${this.originalPrices.yearly}/year)`
      }
    }
  }

  // Handle form submission (can add additional logic here if needed)
  submitForm(event) {
    // Allow form to submit normally
    // The discount code will be included in the hidden field
    return true
  }
}