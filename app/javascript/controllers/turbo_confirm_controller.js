import { Controller } from "@hotwired/stimulus";

// Replaces the native window.confirm() that Turbo uses for `data-turbo-confirm`
// with a DaisyUI <dialog>. Mounted on <body> so it owns the document-wide hook.
//
// Markup (rendered in the layout): a singleton dialog with id="turbo-confirm".
// Inside: a <p data-turbo-confirm-target="message"> for the prompt and two
// buttons with data-action #confirm / #cancel.
export default class extends Controller {
  static targets = ["message"];

  connect() {
    if (window.Turbo) {
      window.Turbo.config.forms.confirm = (message) => this._prompt(message);
    }
    this._resolve = null;
  }

  confirm() {
    if (this._resolve) this._resolve(true);
    this._dialog().close();
  }

  cancel() {
    if (this._resolve) this._resolve(false);
    this._dialog().close();
  }

  _prompt(message) {
    this.messageTarget.textContent = message;
    this._dialog().showModal();
    return new Promise((resolve) => { this._resolve = resolve; });
  }

  _dialog() {
    return this.element.querySelector("dialog");
  }
}
