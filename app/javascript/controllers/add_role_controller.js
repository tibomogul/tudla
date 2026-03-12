import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["typeSelect", "entitySelect", "roleSelect", "submitButton"]
  static values = { existingRoles: { type: Array, default: [] } }

  connect() {
    this.selectionChanged()
  }

  typeChanged() {
    const selectedType = this.typeSelectTarget.value
    const options = this.entitySelectTarget.querySelectorAll("option[data-entity-type]")
    options.forEach(opt => {
      opt.hidden = opt.dataset.entityType !== selectedType || opt.dataset.alreadyAssigned === "true"
      if (opt.hidden && opt.selected) opt.selected = false
    })
    const first = this.entitySelectTarget.querySelector(`option[data-entity-type="${selectedType}"]:not([hidden])`)
    if (first) first.selected = true
    this.selectionChanged()
  }

  selectionChanged() {
    if (!this.hasSubmitButtonTarget || !this.hasRoleSelectTarget) return

    const selectedOption = this.entitySelectTarget.selectedOptions[0]
    if (!selectedOption || selectedOption.hidden) {
      this.submitButtonTarget.disabled = true
      return
    }

    const partyKey = selectedOption.dataset.partyKey
    const role = this.roleSelectTarget.value
    const roleKey = `${partyKey}-${role}`

    this.submitButtonTarget.disabled = this.existingRolesValue.includes(roleKey)
  }
}
