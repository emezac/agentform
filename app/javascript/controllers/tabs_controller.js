import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tabs"
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { 
    defaultTab: String,
    activeTab: String 
  }

  connect() {
    // Set default tab based on URL parameters or defaultTab value
    const urlParams = new URLSearchParams(window.location.search)
    const sourceParam = urlParams.get('source')
    
    let initialTab = this.defaultTabValue || 'prompt'
    if (sourceParam && ['prompt', 'document'].includes(sourceParam)) {
      initialTab = sourceParam
    }
    
    this.switchTo(initialTab)
  }

  switch(event) {
    event.preventDefault()
    const tabName = event.currentTarget.dataset.tab
    this.switchTo(tabName)
  }

  switchTo(tabName) {
    // Store previous tab for event dispatch
    const previousTab = this.activeTabValue
    
    // Update active tab value
    this.activeTabValue = tabName
    
    // Update tab states with smooth transitions
    this.tabTargets.forEach(tab => {
      const isActive = tab.dataset.tab === tabName
      
      if (isActive) {
        tab.classList.add('active', 'bg-indigo-50', 'text-indigo-700', 'border-indigo-200')
        tab.classList.remove('text-gray-500', 'hover:text-gray-700', 'border-transparent')
        tab.setAttribute('aria-selected', 'true')
      } else {
        tab.classList.remove('active', 'bg-indigo-50', 'text-indigo-700', 'border-indigo-200')
        tab.classList.add('text-gray-500', 'hover:text-gray-700', 'border-transparent')
        tab.setAttribute('aria-selected', 'false')
      }
    })
    
    // Update panel visibility with fade transitions
    this.panelTargets.forEach(panel => {
      const isActive = panel.dataset.panel === tabName
      
      if (isActive) {
        panel.classList.remove('hidden')
        panel.classList.add('animate-fade-in')
        // Remove animation class after animation completes
        setTimeout(() => {
          panel.classList.remove('animate-fade-in')
        }, 400)
      } else {
        panel.classList.add('hidden')
        panel.classList.remove('animate-fade-in')
      }
    })
    
    // Update URL parameter without page reload
    this.updateUrlParameter(tabName)
    
    // Dispatch custom event for other controllers to listen to
    this.dispatch('switched', { 
      detail: { 
        activeTab: tabName,
        previousTab: previousTab 
      } 
    })
    
    // Also dispatch to specific panels for controllers that might be nested inside
    this.panelTargets.forEach(panel => {
      if (panel.dataset.panel === tabName) {
        const customEvent = new CustomEvent('tabs:switched', {
          detail: { 
            activeTab: tabName,
            previousTab: previousTab 
          },
          bubbles: true
        })
        panel.dispatchEvent(customEvent)
      }
    })
  }

  updateUrlParameter(tabName) {
    const url = new URL(window.location)
    url.searchParams.set('source', tabName)
    window.history.replaceState({}, '', url)
  }

  // Getter for current active tab
  get currentTab() {
    return this.activeTabValue
  }

  // Method to programmatically switch tabs (for external controllers)
  activateTab(tabName) {
    if (['prompt', 'document'].includes(tabName)) {
      this.switchTo(tabName)
    }
  }
}