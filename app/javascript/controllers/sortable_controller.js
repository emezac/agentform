import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static values = { handle: String }
  
  connect() {
    this.initializeSortable()
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
    }
  }

  initializeSortable() {
    const handleSelector = this.hasHandleValue ? this.handleValue : '.cursor-grab'
    
    this.sortable = Sortable.create(this.element, {
      handle: handleSelector,
      animation: 150,
      ghostClass: 'sortable-ghost',
      chosenClass: 'sortable-chosen',
      dragClass: 'sortable-drag',
      onEnd: (evt) => {
        this.dispatch('sorted', { detail: { item: evt.item, newIndex: evt.newIndex, oldIndex: evt.oldIndex } })
      }
    })
  }
}