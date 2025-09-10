import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("Debug controller connected")
  }

  turboStreamReceived(event) {
    console.log("Turbo Stream received:", event.detail)
  }
}