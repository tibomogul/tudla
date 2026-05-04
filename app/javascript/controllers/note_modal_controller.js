import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { url: String };

  open(event) {
    event.preventDefault();
    const frame = document.getElementById("note_modal_frame");
    const dialog = document.getElementById("note_show_modal");
    if (!frame || !dialog) return;
    frame.src = ""; // this guarantees a fetch in the next statement
    frame.src = this.urlValue;
    dialog.showModal();
  }
}
