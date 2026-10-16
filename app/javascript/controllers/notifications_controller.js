import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "panel"]

  toggle() {
    if (!this.panelTarget.hidden) return this.dismiss()

    this.panelTarget.hidden = false
    this.triggerTarget.setAttribute("aria-expanded", "true")
    this.position()
    this.panelTarget.focus({ preventScroll: true })
  }

  position() {
    if (this.panelTarget.hidden) return

    const anchor = this.element.getBoundingClientRect()
    const viewportWidth = document.documentElement.clientWidth
    this.panelTarget.style.maxWidth = `${viewportWidth - 32}px`
    const width = this.panelTarget.getBoundingClientRect().width
    const left = Math.max(16, Math.min(anchor.right - width, viewportWidth - width - 16))
    this.panelTarget.style.left = `${left - anchor.left}px`
  }

  close() {
    this.panelTarget.hidden = true
    this.triggerTarget.setAttribute("aria-expanded", "false")
  }

  dismiss() {
    this.close()
    this.triggerTarget.focus({ preventScroll: true })
  }

  dismissOutside(event) {
    if (!this.panelTarget.hidden && !this.element.contains(event.target)) this.close()
  }

  dismissWithEscape(event) {
    if (this.panelTarget.hidden) return

    event.preventDefault()
    event.stopPropagation()
    this.dismiss()
  }
}
