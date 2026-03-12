import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["email", "username", "preferredName", "notice", "submitButton"]
  static values = { url: String }

  connect() {
    this.existingUser = false
    this.existingPartyKeys = []
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
    }
  }

  lookup() {
    const email = this.emailTarget.value.trim()
    if (!email) {
      this.reset()
      return
    }

    fetch(`${this.urlValue}?email=${encodeURIComponent(email)}`, {
      headers: { "Accept": "application/json" }
    })
      .then(response => response.json())
      .then(data => {
        if (data.found) {
          this.applyExistingUser(data)
        } else {
          this.reset()
        }
      })
  }

  applyExistingUser(data) {
    this.existingUser = true
    this.existingPartyKeys = data.existing_party_keys || []

    this.usernameTarget.value = data.username || ""
    this.usernameTarget.disabled = true

    this.preferredNameTarget.value = data.preferred_name || ""
    this.preferredNameTarget.disabled = true

    // Mark already-assigned party options
    const options = this.element.querySelectorAll("option[data-party-key]")
    let hasAvailable = false
    options.forEach(opt => {
      if (this.existingPartyKeys.includes(opt.dataset.partyKey)) {
        opt.dataset.alreadyAssigned = "true"
        opt.disabled = true
      } else {
        delete opt.dataset.alreadyAssigned
        opt.disabled = false
        hasAvailable = true
      }
    })

    // Trigger type filter refresh so hidden state is recalculated
    const typeSelect = this.element.querySelector("select[name='party_type']")
    if (typeSelect) typeSelect.dispatchEvent(new Event("change"))

    this.noticeTarget.textContent = hasAvailable
      ? "This user already exists. They will be added to the selected entity."
      : "This user already has roles for all entities in this organization."
    this.noticeTarget.hidden = false
  }

  reset() {
    this.existingUser = false
    this.existingPartyKeys = []

    this.usernameTarget.disabled = false
    this.usernameTarget.value = ""

    this.preferredNameTarget.disabled = false
    this.preferredNameTarget.value = ""

    const options = this.element.querySelectorAll("option[data-party-key]")
    options.forEach(opt => {
      delete opt.dataset.alreadyAssigned
      opt.disabled = false
    })

    // Trigger type filter refresh
    const typeSelect = this.element.querySelector("select[name='party_type']")
    if (typeSelect) typeSelect.dispatchEvent(new Event("change"))

    this.noticeTarget.hidden = true
  }

  // Called when the type select changes — reset entity and role to placeholders
  typeChanged() {
    this.#resetSelectToPlaceholder("party_id")
    this.#resetSelectToPlaceholder("role")
    this.selectionChanged()
  }

  // Called when the entity select changes — reset role to placeholder
  entityChanged() {
    this.#resetSelectToPlaceholder("role")
    this.selectionChanged()
  }

  selectionChanged() {
    if (!this.hasSubmitButtonTarget) return

    const typeSelect = this.element.querySelector("select[name='party_type']")
    const entitySelect = this.element.querySelector("select[name='party_id']")
    const roleSelect = this.element.querySelector("select[name='role']")

    // All three must have a non-placeholder value selected
    if (!typeSelect?.value || !entitySelect?.value || !roleSelect?.value) {
      this.submitButtonTarget.disabled = true
      return
    }

    const selectedOption = entitySelect.selectedOptions[0]
    if (!selectedOption || selectedOption.hidden) {
      this.submitButtonTarget.disabled = true
      return
    }

    // For existing users, check if this party is already assigned
    if (this.existingUser) {
      const partyKey = selectedOption.dataset.partyKey
      this.submitButtonTarget.disabled = this.existingPartyKeys.includes(partyKey)
      return
    }

    this.submitButtonTarget.disabled = false
  }

  // --- private ---

  #resetSelectToPlaceholder(name) {
    const select = this.element.querySelector(`select[name='${name}']`)
    if (!select) return
    const placeholder = select.querySelector("option[value='']")
    if (placeholder) {
      select.value = ""
      placeholder.selected = true
    }
  }
}
