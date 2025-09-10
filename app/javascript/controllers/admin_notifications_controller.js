import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["counter", "list"]

  connect() {
    console.log("Admin notifications controller connected")
    this.setupAutoRefresh()
  }

  disconnect() {
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval)
    }
  }

  setupAutoRefresh() {
    // Refresh notifications every 30 seconds
    this.refreshInterval = setInterval(() => {
      this.refreshNotifications()
    }, 30000)
  }

  refreshNotifications() {
    fetch('/admin/notifications', {
      headers: {
        'Accept': 'text/vnd.turbo-stream.html',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => response.text())
    .then(html => {
      if (html.includes('turbo-stream')) {
        Turbo.renderStreamMessage(html)
      }
    })
    .catch(error => {
      console.error('Error refreshing notifications:', error)
    })
  }

  markAsRead(event) {
    const notificationId = event.target.dataset.notificationId
    
    fetch(`/admin/notifications/${notificationId}/mark_as_read`, {
      method: 'PATCH',
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        'Accept': 'text/vnd.turbo-stream.html'
      }
    })
    .then(response => response.text())
    .then(html => {
      Turbo.renderStreamMessage(html)
    })
    .catch(error => {
      console.error('Error marking notification as read:', error)
    })
  }

  markAllAsRead(event) {
    event.preventDefault()
    
    fetch('/admin/notifications/mark_all_as_read', {
      method: 'PATCH',
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        'Accept': 'text/vnd.turbo-stream.html'
      }
    })
    .then(response => response.text())
    .then(html => {
      Turbo.renderStreamMessage(html)
    })
    .catch(error => {
      console.error('Error marking all notifications as read:', error)
    })
  }

  deleteNotification(event) {
    const notificationId = event.target.dataset.notificationId
    
    if (!confirm('Are you sure you want to delete this notification?')) {
      return
    }
    
    fetch(`/admin/notifications/${notificationId}`, {
      method: 'DELETE',
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        'Accept': 'text/vnd.turbo-stream.html'
      }
    })
    .then(response => response.text())
    .then(html => {
      Turbo.renderStreamMessage(html)
    })
    .catch(error => {
      console.error('Error deleting notification:', error)
    })
  }

  // Filter handling
  applyFilters(event) {
    const form = event.target.closest('form')
    const formData = new FormData(form)
    const params = new URLSearchParams(formData)
    
    fetch(`/admin/notifications?${params.toString()}`, {
      headers: {
        'Accept': 'text/vnd.turbo-stream.html',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => response.text())
    .then(html => {
      if (html.includes('turbo-stream')) {
        Turbo.renderStreamMessage(html)
      } else {
        // Fallback: replace the entire list
        const parser = new DOMParser()
        const doc = parser.parseFromString(html, 'text/html')
        const newList = doc.querySelector('#notifications-list')
        if (newList && this.hasListTarget) {
          this.listTarget.innerHTML = newList.innerHTML
        }
      }
    })
    .catch(error => {
      console.error('Error applying filters:', error)
    })
  }
}