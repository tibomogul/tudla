import { Controller } from "@hotwired/stimulus";

// Replaces the native window.confirm() that Turbo uses for `data-turbo-confirm`
// with a DaisyUI <dialog>. Reads optional per-call attributes from the form or
// its submitter:
//   data-turbo-confirm-button-label="Delete"   -> button text
//   data-turbo-confirm-destructive="true"      -> red styling (default)
//   data-turbo-confirm-destructive="false"     -> primary styling
//
// Markup (rendered in the layout): a singleton dialog with id="turbo-confirm".
export default class extends Controller {
  static targets = ["message", "confirmButton"];

  connect() {
    if (window.Turbo) {
      window.Turbo.config.forms.confirm = (message, formElement, submitter) =>
        this._prompt(message, submitter || formElement);
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

  _prompt(message, source) {
    this.messageTarget.textContent = message;
    this._applyButtonOptions(source);
    this._dialog().showModal();
    return new Promise((resolve) => { this._resolve = resolve; });
  }

  _applyButtonOptions(source) {
    const btn = this.confirmButtonTarget;
    const label = source?.dataset?.turboConfirmButtonLabel || "Confirm";
    const destructiveAttr = source?.dataset?.turboConfirmDestructive;
    const destructive = destructiveAttr === undefined ? true : destructiveAttr !== "false";
    btn.textContent = label;
    btn.classList.toggle("btn-error", destructive);
    btn.classList.toggle("btn-primary", !destructive);
  }

  _dialog() {
    return this.element.querySelector("dialog");
  }
}
