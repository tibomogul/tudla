import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="betting-modal"
export default class extends Controller {
  static targets = ["betDialog", "details", "chevron"]

  openBet() {
    this.betDialogTarget.showModal()
  }

  togglePreview() {
    this.detailsTarget.classList.toggle("hidden")
    this.chevronTarget.classList.toggle("rotate-180")
  }
}
