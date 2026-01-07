// app/javascript/controllers/user_select_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "option", "dropdown", "selectedDisplay", "form"]
  static values = {
    taskId: Number
  }

  connect() {
    // Close dropdown when clicking outside
    this.boundCloseDropdown = this.closeDropdown.bind(this)
    document.addEventListener("click", this.boundCloseDropdown)
  }

  disconnect() {
    document.removeEventListener("click", this.boundCloseDropdown)
  }

  toggleDropdown(event) {
    event.stopPropagation()
    this.dropdownTarget.classList.toggle("hidden")
    if (!this.dropdownTarget.classList.contains("hidden")) {
      this.searchTarget.focus()
      this.searchTarget.select()
    }
  }

  closeDropdown(event) {
    if (!this.element.contains(event.target)) {
      this.dropdownTarget.classList.add("hidden")
    }
  }

  filter(event) {
    const searchTerm = event.target.value.toLowerCase()
    
    this.optionTargets.forEach(option => {
      const username = option.dataset.username?.toLowerCase() || ""
      const preferredName = option.dataset.preferredName?.toLowerCase() || ""
      
      const matches = username.includes(searchTerm) || preferredName.includes(searchTerm)
      option.classList.toggle("hidden", !matches)
    })
  }

  selectUser(event) {
    event.preventDefault()
    const userId = event.currentTarget.dataset.userId
    const userName = event.currentTarget.dataset.displayName
    
    // Update the display
    this.selectedDisplayTarget.textContent = userName || "None"
    
    // Submit the form to update the task
    this.formTarget.querySelector('input[name="task[responsible_user_id]"]').value = userId
    this.formTarget.requestSubmit()
    
    // Close the dropdown
    this.dropdownTarget.classList.add("hidden")
    this.searchTarget.value = ""
    this.optionTargets.forEach(option => option.classList.remove("hidden"))
  }

  clearSelection(event) {
    event.preventDefault()
    
    // Update display
    this.selectedDisplayTarget.textContent = "None"
    
    // Submit the form with empty user_id
    this.formTarget.querySelector('input[name="task[responsible_user_id]"]').value = ""
    this.formTarget.requestSubmit()
    
    // Close the dropdown
    this.dropdownTarget.classList.add("hidden")
    this.searchTarget.value = ""
    this.optionTargets.forEach(option => option.classList.remove("hidden"))
  }
}
