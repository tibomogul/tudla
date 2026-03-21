import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="report-ai-assist"
export default class extends Controller {
  static targets = ["dialog", "preview", "chatMessages", "chatInput", "sendButton", "loadingIndicator", "acceptButton"]
  static values = {
    aiAssistUrl: String,
    renderMarkdownUrl: String
  }

  connect() {
    this.conversationHistory = []
    this.currentContent = ""
    this.originalContent = ""
    this.messageAbortController = null
    this.previewAbortController = null
  }

  disconnect() {
    this.abortInflightRequests()
  }

  updateAcceptButton() {
    const hasChanges = this.currentContent !== this.originalContent
    this.acceptButtonTarget.disabled = !hasChanges
  }

  get marksmithTextarea() {
    return this.element.querySelector('[data-marksmith-target="fieldElement"]')
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  open() {
    const textarea = this.marksmithTextarea
    this.originalContent = textarea ? textarea.value : ""
    this.currentContent = this.originalContent
    this.conversationHistory = []

    // Reset chat
    this.chatMessagesTarget.innerHTML = ""
    this.chatInputTarget.value = ""

    // Add greeting
    this.appendMessage("assistant", "Hi! I can help you write and improve your report. I have access to project and task data, so feel free to ask about those too. What would you like to do?")

    // Render preview and disable accept until changes are made
    this.renderPreview()
    this.updateAcceptButton()

    this.dialogTarget.showModal()
  }

  close() {
    this.abortInflightRequests()
    this.dialogTarget.close()
  }

  accept() {
    const textarea = this.marksmithTextarea
    if (textarea) {
      textarea.value = this.currentContent
      textarea.dispatchEvent(new Event("input", { bubbles: true }))
    }
    this.dialogTarget.close()
  }

  async sendMessage() {
    const message = this.chatInputTarget.value.trim()
    if (!message) return

    // Prevent double-sends while a request is in-flight
    if (this.messageAbortController) return

    this.messageAbortController = new AbortController()

    // Clear input and disable
    this.chatInputTarget.value = ""
    this.sendButtonTarget.disabled = true
    this.loadingIndicatorTarget.classList.remove("hidden")

    // Append user message
    this.appendMessage("user", message)
    this.conversationHistory.push({ role: "user", content: message })

    try {
      const response = await fetch(this.aiAssistUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({
          content: this.currentContent,
          message: message,
          conversation_history: this.conversationHistory
        }),
        signal: this.messageAbortController.signal
      })

      let data
      try {
        data = await response.json()
      } catch {
        throw new Error("Invalid JSON response")
      }

      // Append assistant reply
      this.appendMessage("assistant", data.reply)

      // Only add to history and process content updates on successful responses
      if (response.ok) {
        this.conversationHistory.push({ role: "assistant", content: data.reply })

        // Update content if provided
        if (data.updated_content != null) {
          this.currentContent = data.updated_content
          this.renderPreview()
          this.updateAcceptButton()
        }
      }
    } catch (error) {
      if (error.name === "AbortError") return
      this.appendMessage("assistant", "Sorry, something went wrong. Please try again.")
    } finally {
      this.messageAbortController = null
      this.sendButtonTarget.disabled = false
      this.loadingIndicatorTarget.classList.add("hidden")
      this.chatInputTarget.focus()
    }
  }

  async renderPreview() {
    // Abort any in-flight preview request
    if (this.previewAbortController) {
      this.previewAbortController.abort()
    }
    this.previewAbortController = new AbortController()

    try {
      const response = await fetch(this.renderMarkdownUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({ content: this.currentContent }),
        signal: this.previewAbortController.signal
      })

      let data
      try {
        data = await response.json()
      } catch {
        throw new Error("Invalid JSON response")
      }
      this.previewTarget.innerHTML = data.html
    } catch (error) {
      if (error.name === "AbortError") return
      this.previewTarget.innerHTML = "<p class='text-error'>Failed to render preview.</p>"
    } finally {
      this.previewAbortController = null
    }
  }

  handleKeydown(e) {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault()
      this.sendMessage()
    }
  }

  appendMessage(role, text) {
    const wrapper = document.createElement("div")
    wrapper.className = role === "user" ? "chat chat-end" : "chat chat-start"

    const bubble = document.createElement("div")
    bubble.className = role === "user"
      ? "chat-bubble chat-bubble-primary"
      : "chat-bubble chat-bubble-secondary"
    bubble.textContent = text

    wrapper.appendChild(bubble)
    this.chatMessagesTarget.appendChild(wrapper)
    this.chatMessagesTarget.scrollTop = this.chatMessagesTarget.scrollHeight
  }

  abortInflightRequests() {
    if (this.messageAbortController) {
      this.messageAbortController.abort()
      this.messageAbortController = null
    }
    if (this.previewAbortController) {
      this.previewAbortController.abort()
      this.previewAbortController = null
    }
  }
}
