import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="pitch-tabs"
// Handles tab switching for pitch ingredient editor and show views.
// All panels remain in the DOM so form fields are always submitted.
export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    this.tabTargets.forEach(tab => {
      tab.addEventListener("click", (e) => {
        e.preventDefault()
        this.switch(tab.dataset.tab)
      })
    })
  }

  switch(tabName) {
    this.tabTargets.forEach(tab => {
      tab.classList.toggle("tab-active", tab.dataset.tab === tabName)
    })

    this.panelTargets.forEach(panel => {
      panel.classList.toggle("hidden", panel.dataset.tab !== tabName)
    })
  }
}
