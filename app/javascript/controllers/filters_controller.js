// app/javascript/controllers/filters_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["user", "period"]
  static values = {
    domid: String
  }

  update() {
    const userId = this.userTarget.value
    const period = this.periodTarget.value
    const url = new URL(window.location.href)
    url.searchParams.set("user_id", userId)
    url.searchParams.set("period", period)
    // url.pathname = `${url.pathname}/history`

    Turbo.visit(url.toString(), { frame: this.domid })
  }
}
