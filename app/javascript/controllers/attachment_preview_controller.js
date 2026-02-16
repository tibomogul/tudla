import { Controller } from "@hotwired/stimulus"

const MIN_SCALE = 0.25
const MAX_SCALE = 5
const SCALE_STEP = 0.25
const WHEEL_SCALE_STEP = 0.1
const ZOOMABLE_TYPES = ["img", "video"]

export default class extends Controller {
  static targets = ["dialog", "slide", "counter", "filename", "filesize", "uploader", "downloadLink", "zoomLevel", "zoomToolbar", "carouselArea"]
  static values = { index: Number }

  connect() {
    this.boundKeyHandler = this.handleKeydown.bind(this)
    this.scale = 1
    this.panX = 0
    this.panY = 0
    this.isPanning = false
    this.panStartX = 0
    this.panStartY = 0
    this.panStartPanX = 0
    this.panStartPanY = 0
  }

  // ── Modal lifecycle ──

  open(event) {
    const attachmentId = event.currentTarget.dataset.attachmentId
    const slideIndex = this.slideTargets.findIndex(
      (slide) => slide.dataset.attachmentId === attachmentId
    )

    this.indexValue = slideIndex >= 0 ? slideIndex : 0
    this.showSlide()
    this.dialogTarget.showModal()
    document.addEventListener("keydown", this.boundKeyHandler)
  }

  close() {
    this.pauseAllMedia()
    this.zoomReset()
    this.dialogTarget.close()
    document.removeEventListener("keydown", this.boundKeyHandler)
  }

  // ── Navigation ──

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
    this.zoomReset()

    this.slideTargets.forEach((slide, i) => {
      slide.classList.toggle("hidden", i !== this.indexValue)
    })

    const current = this.slideTargets[this.indexValue]
    if (!current) return

    this.loadContent(current)
    this.updateHeader(current)
    this.updateZoomToolbarVisibility(current)
    this.updateCursor()
  }

  // ── Content loading ──

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

  // ── Header updates ──

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

  // ── Zoom ──

  get currentSlideType() {
    const current = this.slideTargets[this.indexValue]
    return current ? current.dataset.previewType : null
  }

  get isZoomable() {
    return ZOOMABLE_TYPES.includes(this.currentSlideType)
  }

  zoomIn() {
    if (!this.isZoomable) return
    this.setScale(Math.min(this.scale + SCALE_STEP, MAX_SCALE))
  }

  zoomOut() {
    if (!this.isZoomable) return
    this.setScale(Math.max(this.scale - SCALE_STEP, MIN_SCALE))
  }

  zoomReset() {
    this.scale = 1
    this.panX = 0
    this.panY = 0
    this.applyTransform()
    this.updateZoomLevel()
    this.updateCursor()
  }

  setScale(newScale) {
    this.scale = Math.round(newScale * 100) / 100
    if (this.scale <= 1) {
      this.panX = 0
      this.panY = 0
    }
    this.applyTransform()
    this.updateZoomLevel()
    this.updateCursor()
  }

  applyTransform() {
    const current = this.slideTargets[this.indexValue]
    if (!current) return

    const el = this.getZoomableElement(current)
    if (!el) return

    if (this.scale === 1 && this.panX === 0 && this.panY === 0) {
      el.style.transform = ""
    } else {
      el.style.transform = `translate(${this.panX}px, ${this.panY}px) scale(${this.scale})`
    }
    el.style.transformOrigin = "center center"
  }

  updateZoomLevel() {
    if (this.hasZoomLevelTarget) {
      this.zoomLevelTarget.textContent = `${Math.round(this.scale * 100)}%`
    }
  }

  updateZoomToolbarVisibility(slide) {
    if (!this.hasZoomToolbarTarget) return
    const zoomButtons = this.zoomToolbarTarget.querySelectorAll("[data-action*='zoom']")
    const zoomLabel = this.hasZoomLevelTarget ? this.zoomLevelTarget : null
    const isZoomable = ZOOMABLE_TYPES.includes(slide.dataset.previewType)

    zoomButtons.forEach((btn) => {
      btn.classList.toggle("btn-disabled", !isZoomable)
      btn.disabled = !isZoomable
    })
    if (zoomLabel) {
      zoomLabel.classList.toggle("opacity-30", !isZoomable)
    }
  }

  getZoomableElement(slide) {
    const type = slide.dataset.previewType
    if (type === "img") return slide.querySelector("img")
    if (type === "video") return slide.querySelector("video")
    return null
  }

  // ── Mouse wheel zoom ──

  handleWheel(event) {
    if (!this.isZoomable) return
    event.preventDefault()

    const delta = event.deltaY > 0 ? -WHEEL_SCALE_STEP : WHEEL_SCALE_STEP
    const newScale = Math.max(MIN_SCALE, Math.min(this.scale + delta, MAX_SCALE))
    this.setScale(newScale)
  }

  // ── Double-click toggle zoom ──

  handleDblClick(event) {
    if (!this.isZoomable) return

    if (this.scale > 1) {
      this.zoomReset()
    } else {
      this.setScale(2)
    }
  }

  // ── Pan (drag) ──

  panStart(event) {
    if (!this.isZoomable || this.scale <= 1) return
    if (event.target.closest("button")) return

    event.preventDefault()
    this.isPanning = true
    this.panStartX = event.clientX
    this.panStartY = event.clientY
    this.panStartPanX = this.panX
    this.panStartPanY = this.panY

    if (this.hasCarouselAreaTarget) {
      this.carouselAreaTarget.style.cursor = "grabbing"
      this.carouselAreaTarget.setPointerCapture(event.pointerId)
    }
  }

  panMove(event) {
    if (!this.isPanning) return
    event.preventDefault()

    const dx = event.clientX - this.panStartX
    const dy = event.clientY - this.panStartY
    this.panX = this.panStartPanX + dx
    this.panY = this.panStartPanY + dy
    this.applyTransform()
  }

  panEnd(event) {
    if (!this.isPanning) return
    this.isPanning = false

    if (this.hasCarouselAreaTarget && event.pointerId != null) {
      try { this.carouselAreaTarget.releasePointerCapture(event.pointerId) } catch (_) {}
    }

    this.updateCursor()
  }

  panCancel(event) {
    this.panEnd(event)
  }

  updateCursor() {
    if (!this.hasCarouselAreaTarget) return
    if (this.isZoomable && this.scale > 1) {
      this.carouselAreaTarget.style.cursor = "grab"
    } else {
      this.carouselAreaTarget.style.cursor = ""
    }
  }

  // ── Media controls ──

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

  // ── Keyboard ──

  handleKeydown(event) {
    if (event.key === "ArrowRight") {
      event.preventDefault()
      this.next()
    } else if (event.key === "ArrowLeft") {
      event.preventDefault()
      this.prev()
    } else if (event.key === "Escape") {
      this.close()
    } else if (event.key === "+" || event.key === "=") {
      event.preventDefault()
      this.zoomIn()
    } else if (event.key === "-") {
      event.preventDefault()
      this.zoomOut()
    } else if (event.key === "0") {
      event.preventDefault()
      this.zoomReset()
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeyHandler)
  }
}
