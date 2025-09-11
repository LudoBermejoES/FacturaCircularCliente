import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    message: String,
    type: String,
    duration: { type: Number, default: 5000 }
  }

  connect() {
    this.show()
    this.autoHide()
  }

  show() {
    // Animate in
    requestAnimationFrame(() => {
      this.element.classList.add("transform", "ease-out", "duration-300", "transition")
      this.element.classList.remove("translate-y-2", "opacity-0")
      this.element.classList.add("translate-y-0", "opacity-100")
    })
  }

  hide() {
    // Animate out
    this.element.classList.add("ease-in", "duration-200")
    this.element.classList.remove("translate-y-0", "opacity-100")
    this.element.classList.add("translate-y-2", "opacity-0")
    
    setTimeout(() => {
      this.element.remove()
    }, 200)
  }

  autoHide() {
    if (this.durationValue > 0) {
      setTimeout(() => {
        this.hide()
      }, this.durationValue)
    }
  }

  close() {
    this.hide()
  }
}