import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "slide", "counter", "filename", "filesize", "uploader", "downloadLink"]
  static values = { index: Number }

  connect() {
    this.boundKeyHandler = this.handleKeydown.bind(this)
  }

  open(event) {
    const attachmentId = event.currentTarget.dataset.attachmentId
    const slideIndex = this.slideTargets.findIndex(
      (slide) => slide.dataset.attachmentId === attachmentId
    )

    if (slideIndex >= 0) {
      this.indexValue = slideIndex
    } else {
      this.indexValue = 0
    }

    this.showSlide()
    this.dialogTarget.showModal()
    document.addEventListener("keydown", this.boundKeyHandler)
  }

  close() {
    this.pauseAllMedia()
    this.dialogTarget.close()
    document.removeEventListener("keydown", this.boundKeyHandler)
  }

  next() {
    this.pauseCurrentMedia()
    this.indexValue = (this.indexValue + 1) % this.slideTargets.length
    this.showSlide()
  }

  prev() {
    this.pauseCurrentMedia()
    this.indexValue = (this.indexValue - 1 + this.slideTargets.length) % this.slideTargets.length
    this.showSlide()
  }

  showSlide() {
    this.slideTargets.forEach((slide, i) => {
      slide.classList.toggle("hidden", i !== this.indexValue)
    })

    const current = this.slideTargets[this.indexValue]
    if (!current) return

    this.loadContent(current)
    this.updateHeader(current)
  }

  loadContent(slide) {
    const previewUrl = slide.dataset.previewUrl
    const previewType = slide.dataset.previewType

    if (previewType === "img") {
      const img = slide.querySelector("img")
      if (img && !img.src) img.src = previewUrl
    } else if (previewType === "iframe") {
      const iframe = slide.querySelector("iframe")
      if (iframe && !iframe.src) iframe.src = previewUrl
    } else if (previewType === "video") {
      const video = slide.querySelector("video")
      if (video && !video.src) {
        video.src = previewUrl
        video.load()
      }
    } else if (previewType === "audio") {
      const audio = slide.querySelector("audio")
      if (audio && !audio.src) {
        audio.src = previewUrl
        audio.load()
      }
    }
  }

  updateHeader(slide) {
    const total = this.slideTargets.length

    if (this.hasCounterTarget) {
      this.counterTarget.textContent = `${this.indexValue + 1} of ${total}`
    }
    if (this.hasFilenameTarget) {
      this.filenameTarget.textContent = slide.dataset.filename
    }
    if (this.hasFilesizeTarget) {
      this.filesizeTarget.textContent = slide.dataset.filesize
    }
    if (this.hasUploaderTarget) {
      this.uploaderTarget.textContent = `Uploaded by ${slide.dataset.uploader}`
    }
    if (this.hasDownloadLinkTarget) {
      this.downloadLinkTarget.href = slide.dataset.downloadUrl
    }
  }

  pauseCurrentMedia() {
    const current = this.slideTargets[this.indexValue]
    if (!current) return
    this.pauseMediaIn(current)
  }

  pauseAllMedia() {
    this.slideTargets.forEach((slide) => this.pauseMediaIn(slide))
  }

  pauseMediaIn(slide) {
    const video = slide.querySelector("video")
    if (video) video.pause()
    const audio = slide.querySelector("audio")
    if (audio) audio.pause()
  }

  handleKeydown(event) {
    if (event.key === "ArrowRight") {
      event.preventDefault()
      this.next()
    } else if (event.key === "ArrowLeft") {
      event.preventDefault()
      this.prev()
    } else if (event.key === "Escape") {
      this.close()
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeyHandler)
  }
}
