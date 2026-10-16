import { Controller } from "@hotwired/stimulus"

// The form is ready for a backend action; no data is saved at this stage.
export default class extends Controller {
  static targets = ["status", "submit"]
  static values = { message: String }

  connect() {
    this.submitTargets.forEach(button => { button.disabled = false })
  }

  submit(event) {
    event.preventDefault()
    if (!this.element.reportValidity()) return
    this.statusTarget.textContent = this.messageValue
    this.statusTarget.hidden = false
  }

  clear() {
    this.statusTarget.hidden = true
    this.statusTarget.textContent = ""
  }
}
