import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = { url: String, version: String, live: Boolean }

  connect() {
    if (this.liveValue) this.timer = setInterval(() => this.refresh(), 3000)
  }

  disconnect() {
    clearInterval(this.timer)
    this.abortController?.abort()
  }

  pause() { this.submitting = true }
  resume() { this.submitting = false }

  async refresh() {
    if (document.hidden || this.submitting || this.refreshing) return
    this.refreshing = true
    this.abortController = new AbortController()
    try {
      const response = await fetch(this.urlValue, {
        headers: { Accept: "application/json" }, cache: "no-store", signal: this.abortController.signal
      })
      if (!response.ok) return
      const state = await response.json()
      if (state.version !== this.versionValue && !this.submitting) {
        Turbo.visit(window.location.href, { action: "replace" })
      }
    } catch {
      // Keep the current card on transient network errors; the next poll retries.
    } finally {
      this.refreshing = false
    }
  }
}
