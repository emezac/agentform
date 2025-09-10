import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="template-gallery"
export default class extends Controller {
  static targets = ["filterForm", "templateGrid", "resultsCount"]

  connect() {
    this.setupAutoSubmit()
    this.trackPageView()
  }

  // Auto-submit form when filters change
  setupAutoSubmit() {
    const form = this.element.querySelector('form')
    if (!form) return

    const selects = form.querySelectorAll('select')
    selects.forEach(select => {
      select.addEventListener('change', () => {
        this.trackFilterChange(select.name, select.value)
        form.submit()
      })
    })

    // Handle search input with debounce
    const searchInput = form.querySelector('input[name="search"]')
    if (searchInput) {
      let debounceTimer
      searchInput.addEventListener('input', (event) => {
        clearTimeout(debounceTimer)
        debounceTimer = setTimeout(() => {
          if (event.target.value.length >= 3 || event.target.value.length === 0) {
            this.trackSearch(event.target.value)
            form.submit()
          }
        }, 500)
      })
    }
  }

  // Track analytics events
  trackPageView() {
    this.trackEvent('template_gallery_viewed', {
      total_templates: this.getTemplateCount(),
      has_filters: this.hasActiveFilters()
    })
  }

  trackFilterChange(filterName, filterValue) {
    this.trackEvent('template_filter_applied', {
      filter_name: filterName,
      filter_value: filterValue,
      total_templates: this.getTemplateCount()
    })
  }

  trackSearch(searchTerm) {
    this.trackEvent('template_search_performed', {
      search_term: searchTerm,
      search_length: searchTerm.length
    })
  }

  trackTemplateInteraction(templateId, action) {
    this.trackEvent('template_interaction', {
      template_id: templateId,
      action: action,
      page: 'gallery'
    })
  }

  // Helper methods
  getTemplateCount() {
    const templateCards = this.element.querySelectorAll('[data-template-id]')
    return templateCards.length
  }

  hasActiveFilters() {
    const form = this.element.querySelector('form')
    if (!form) return false

    const formData = new FormData(form)
    for (let [key, value] of formData.entries()) {
      if (value && value !== '' && value !== 'all') {
        return true
      }
    }
    return false
  }

  trackEvent(eventName, properties = {}) {
    // Integration with analytics system
    if (window.analytics && typeof window.analytics.track === 'function') {
      window.analytics.track(eventName, {
        ...properties,
        timestamp: new Date().toISOString(),
        page: window.location.pathname,
        user_agent: navigator.userAgent
      })
    }

    // Fallback to console for development
    if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
      console.log(`Analytics Event: ${eventName}`, properties)
    }
  }
}