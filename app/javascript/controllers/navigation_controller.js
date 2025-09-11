import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "overlay"]

  connect() {
    this.isOpen = false
  }

  toggleSidebar() {
    this.isOpen = !this.isOpen
    this.updateSidebarVisibility()
  }

  closeSidebar() {
    this.isOpen = false
    this.updateSidebarVisibility()
  }

  updateSidebarVisibility() {
    if (this.hasOverlayTarget) {
      if (this.isOpen) {
        this.overlayTarget.classList.remove("hidden")
      } else {
        this.overlayTarget.classList.add("hidden")
      }
    }
  }
}