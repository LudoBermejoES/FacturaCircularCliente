import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  open() {
    this.element.classList.remove('hidden')
  }

  close() {
    this.element.classList.add('hidden')
  }

  // Close modal when clicking outside the modal content
  clickOutside(event) {
    if (event.target === this.element) {
      this.close()
    }
  }

  // Close modal on ESC key
  keydown(event) {
    if (event.key === 'Escape') {
      this.close()
    }
  }

  connect() {
    // Add event listeners for closing modal
    this.element.addEventListener('click', this.clickOutside.bind(this))
    document.addEventListener('keydown', this.keydown.bind(this))
  }

  disconnect() {
    // Clean up event listeners
    this.element.removeEventListener('click', this.clickOutside.bind(this))
    document.removeEventListener('keydown', this.keydown.bind(this))
  }
}