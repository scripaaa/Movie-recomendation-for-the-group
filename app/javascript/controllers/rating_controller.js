import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["value"]

  select(event) {
    this.valueTarget.textContent = `${event.target.value} / 10`
  }
}
