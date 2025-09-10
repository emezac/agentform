// app/javascript/controllers/dynamic_question_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitButton", "answerInput"]
  static values = {
    responseId: String,
    dynamicId: String
  }

  submitAnswer(event) {
    event.preventDefault()
    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.textContent = "Processing..."

    const answerValue = this.answerInputTarget ? this.answerInputTarget.value : "" // Maneja diferentes tipos de input
    // Necesitarás una ruta para enviar esta respuesta. La crearemos a continuación.
    const url = `/form_responses/${this.responseIdValue}/dynamic_questions/${this.dynamicIdValue}/answer`
    const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content')

    fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken,
        'Accept': 'application/json'
      },
      body: JSON.stringify({
        answer: {
          value: answerValue
        }
      })
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        window.location.reload()
      } else {
        alert("Hubo un error al enviar tu respuesta.")
        this.submitButtonTarget.disabled = false
        this.submitButtonTarget.textContent = "Continuar"
      }
    })
  }
}