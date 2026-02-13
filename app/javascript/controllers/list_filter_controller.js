import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  static values = {
    url: String,
    param: { type: String, default: "q" },
    frame: String
  }

  connect() {
    this._timeout = null
  }

  disconnect() {
    if (this._timeout) clearTimeout(this._timeout)
  }

  filter() {
    if (this._timeout) clearTimeout(this._timeout)

    this._timeout = setTimeout(() => {
      const url = new URL(this.urlValue, window.location.origin)
      const query = this.inputTarget.value.trim()

      if (query.length > 0) {
        url.searchParams.set(this.paramValue, query)
      } else {
        url.searchParams.delete(this.paramValue)
      }

      // Reset to page 1 on filter change
      url.searchParams.delete("page")

      Turbo.visit(url.toString(), { frame: this.frameValue })
    }, 300)
  }
}
