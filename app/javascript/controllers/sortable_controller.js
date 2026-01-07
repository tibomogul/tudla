import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Connects to data-controller="sortable"
export default class extends Controller {
  static values = {
    list: String, // "today" or "backlog"
    reorderUrl: String // URL to PATCH with ids[]=...
  }

  connect() {
    this.sortable = Sortable.create(this.element, {
      group: "tasks-shared",
      animation: 150,
      handle: "[data-handle]",
      onEnd: (evt) => this.onEnd(evt),
      onAdd: (evt) => this.onAdd(evt)
    })
  }

  disconnect() {
    if (this.sortable) this.sortable.destroy()
  }

  onEnd(evt) {
    // Reorder within the same list
    if (evt.from === evt.to) {
      const ids = Array.from(this.element.querySelectorAll("[data-task-id]"))
        .map(el => parseInt(el.dataset.taskId, 10))
      this.patch(this.reorderUrlValue, this.formDataFromIds(ids))
    }
  }

  onAdd(evt) {
    // Cross-list move: send to move_to_* with position
    const taskEl = evt.item
    const taskId = parseInt(taskEl.dataset.taskId, 10)
    const position = evt.newIndex

    const toList = this.listValue // controller on target list
    let url
    if (toList === "today") {
      url = `/tasks/${taskId}/move_to_today`
    } else {
      url = `/tasks/${taskId}/move_to_backlog`
    }
    this.patch(url, this.formData({ position }))
  }

  formData(obj) {
    const fd = new FormData()
    Object.entries(obj).forEach(([k, v]) => fd.append(k, v))
    return fd
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
      headers: { "X-CSRF-Token": token, "Accept": "text/vnd.turbo-stream.html" },
      body
    })
  }
}
