import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["spinner", "content"]

  connect() {
    this.hideSpinner()
  }

  show() {
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove("hidden")
    }
    if (this.hasContentTarget) {
      this.contentTarget.classList.add("opacity-50", "pointer-events-none")
    }
  }

  hide() {
    this.hideSpinner()
  }

  hideSpinner() {
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.add("hidden")
    }
    if (this.hasContentTarget) {
      this.contentTarget.classList.remove("opacity-50", "pointer-events-none")
    }
  }

  // Handle form submissions with loading state
  submitForm(event) {
    this.show()
    // The form will submit normally
  }
}