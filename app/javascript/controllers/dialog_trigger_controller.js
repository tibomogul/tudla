import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { dialogId: String };

  show(event) {
    this.#act(event, "showModal");
  }

  close(event) {
    this.#act(event, "close");
  }

  #act(event, method) {
    const dialog = document.getElementById(this.dialogIdValue);
    if (!dialog) return;
    event.preventDefault();
    dialog[method]();
  }
}
