import { Controller } from "@hotwired/stimulus"

// Handles AI-assisted report draft generation
// On connect, posts the form data to reports#prepare_draft and
// populates the Marksmith textarea with the returned draft while
// showing a blocking modal with loading status and protecting against
// accidental navigation away. Users can cancel to get a blank
// template.
export default class extends Controller {
  static targets = ["content", "status", "modal", "notice"]

  connect() {
    // Only attempt draft generation on the New Report form
    const url = this.element.dataset.reportDraftUrl
    if (!url) return

    this.prepareDraft(url)
  }

  prepareDraft(url) {
    // Marksmith may not have initialized the editor textarea yet,
    // so only require the status/modal targets to start the request.
    if (!this.hasStatusTarget || !this.hasModalTarget) return

    this.abortController = new AbortController()
    this.enableBeforeUnload()
    this.showModal("Preparing AI draft based on your recent activity…")

    const formData = new FormData(this.element)

    fetch(url, {
      method: "POST",
      headers: {
        "Accept": "application/json",
        "X-CSRF-Token": this.csrfToken
      },
      body: formData,
      signal: this.abortController.signal
    })
      .then(response => response.json().then(data => ({ ok: response.ok, data })))
      .then(({ ok, data }) => {
        if (!ok || data.error) {
          console.error("Report draft error:", data.error)
          this.showStatus("Could not prepare AI draft. You can still write the report manually.")
        } else {
          this.setContent(data.content)
          this.hideStatus()
        }

        if (data.notice) {
          this.showNotice(data.notice)
        }

        this.finishDraft()
      })
      .catch(error => {
        if (error.name === "AbortError") {
          return
        }

        console.error("Report draft request failed:", error)
        this.showStatus("Could not prepare AI draft due to a network error.")
        this.finishDraft()
      })
  }

  setContent(markdown) {
    if (!markdown) return

    // Target is ideally the underlying textarea rendered by Marksmith.
    // If the content target is not available yet, try to find a textarea
    // inside this form as a fallback.
    let textarea = this.hasContentTarget ? this.contentTarget : null

    if (!textarea) {
      textarea = this.element.querySelector("textarea[name$='[content]']")
    }

    if (!textarea) return

    textarea.value = markdown

    // Trigger input event so Marksmith updates its preview
    const event = new Event("input", { bubbles: true })
    textarea.dispatchEvent(event)
  }

  showStatus(message) {
    this.statusTarget.textContent = message
    this.statusTarget.classList.remove("hidden")
  }

  hideStatus() {
    this.statusTarget.classList.add("hidden")
  }

  showModal(message) {
    this.showStatus(message)
    this.modalTarget.classList.remove("hidden")
  }

  hideModal() {
    this.modalTarget.classList.add("hidden")
  }

  showNotice(message) {
    if (!this.hasNoticeTarget) return
    this.noticeTarget.textContent = message
    this.noticeTarget.classList.remove("hidden")
  }

  cancel(event) {
    if (event) event.preventDefault()

    if (this.abortController) {
      this.abortController.abort()
    }

    this.setContent(this.blankTemplate)
    this.hideStatus()
    this.finishDraft()
  }

  finishDraft() {
    this.disableBeforeUnload()
    this.hideModal()
  }

  get csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta && meta.getAttribute("content")
  }

  enableBeforeUnload() {
    this.beforeUnloadHandler = (event) => {
      event.preventDefault()
      event.returnValue = ""
    }
    window.addEventListener("beforeunload", this.beforeUnloadHandler)
  }

  disableBeforeUnload() {
    if (this.beforeUnloadHandler) {
      window.removeEventListener("beforeunload", this.beforeUnloadHandler)
      this.beforeUnloadHandler = null
    }
  }

  get blankTemplate() {
    return `*My Vibe:* 

*_Yesterday's Wins (Completed Tasks):_*
* :white_check_mark: 

*_Today's Focus & Status:_*
:large_green_circle: *_Main Focus_* ()
* :hammer: 
* :soon: 

*_Blockers / @Mentions:_*
* :construction: `
  }
}
