import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.classList.add("opacity-0", "transition-opacity", "duration-500")
    requestAnimationFrame(() => this.element.classList.remove("opacity-0"))
  }
}