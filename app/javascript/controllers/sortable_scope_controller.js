import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Connects to data-controller="sortable-scope"
export default class extends Controller {
  static values = {
    reorderUrl: String // URL to PATCH with ids[]=...
  }

  connect() {
    this.sortable = Sortable.create(this.element, {
      animation: 150,
      handle: "[data-handle]",
      onEnd: (evt) => this.onEnd(evt)
    })
  }

  disconnect() {
    if (this.sortable) this.sortable.destroy()
  }

  onEnd(evt) {
    // Reorder within the list
    const ids = Array.from(this.element.querySelectorAll("[data-task-id], [data-scope-id]"))
      .map(el => parseInt(el.dataset.taskId || el.dataset.scopeId, 10))
    this.patch(this.reorderUrlValue, this.formDataFromIds(ids))
  }

  formDataFromIds(ids) {
    const fd = new FormData()
    ids.forEach(id => fd.append("ids[]", id))
    return fd
  }

  patch(url, body) {
    const token = document.querySelector('meta[name="csrf-token"]').content
    fetch(url, {
      method: "PATCH",
      headers: { "X-CSRF-Token": token },
      body
    })
  }
}
