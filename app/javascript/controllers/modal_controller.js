import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "backdrop", "panel"]

  show() {
    this.containerTarget.classList.remove("hidden")
    
    requestAnimationFrame(() => {
      // Fade in backdrop
      this.backdropTarget.classList.remove("opacity-0")
      this.backdropTarget.classList.add("opacity-100")
      
      // Scale in panel
      this.panelTarget.classList.remove("opacity-0", "scale-95")
      this.panelTarget.classList.add("opacity-100", "scale-100")
    })
  }

  hide() {
    // Fade out backdrop
    this.backdropTarget.classList.remove("opacity-100")
    this.backdropTarget.classList.add("opacity-0")
    
    // Scale out panel
    this.panelTarget.classList.remove("opacity-100", "scale-100")
    this.panelTarget.classList.add("opacity-0", "scale-95")
    
    setTimeout(() => {
      this.containerTarget.classList.add("hidden")
    }, 200)
  }

  confirm(event) {
    // Trigger the confirm action
    const confirmEvent = new CustomEvent("modal:confirmed", {
      detail: { modal: this }
    })
    this.element.dispatchEvent(confirmEvent)
    this.hide()
  }

  cancel() {
    const cancelEvent = new CustomEvent("modal:cancelled", {
      detail: { modal: this }
    })
    this.element.dispatchEvent(cancelEvent)
    this.hide()
  }
}