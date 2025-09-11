import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message"]

  connect() {
    // Auto-hide flash messages after 5 seconds
    this.messageTargets.forEach((message) => {
      setTimeout(() => {
        this.fadeOut(message)
      }, 5000)
    })
  }

  close(event) {
    const message = event.currentTarget.closest('[data-flash-target="message"]')
    this.fadeOut(message)
  }

  fadeOut(element) {
    element.style.transition = "opacity 0.3s ease-out"
    element.style.opacity = "0"
    
    setTimeout(() => {
      element.remove()
    }, 300)
  }
}