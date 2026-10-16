import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  open(event) {
    this.opener = event.currentTarget
    this.panelTarget.showModal()
  }

  close() {
    this.panelTarget.close()
  }

  restoreFocus() {
    this.opener?.focus()
  }

  dismissBackdrop(event) {
    if (event.target !== this.panelTarget) return
    const bounds = this.panelTarget.getBoundingClientRect()
    if (event.clientX < bounds.left || event.clientX > bounds.right ||
        event.clientY < bounds.top || event.clientY > bounds.bottom) this.close()
  }

  disconnect() {
    if (this.hasPanelTarget && this.panelTarget.open) this.panelTarget.close()
  }
}
