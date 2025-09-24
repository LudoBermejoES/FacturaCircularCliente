import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["defaultBadge", "setDefaultButton"]
  static values = {
    companyId: String,
    contactId: String
  }

  connect() {
    // Initialize controller when DOM loads
  }

  async setDefault(event) {
    event.preventDefault()

    const button = event.currentTarget
    const addressId = button.dataset.addressId

    if (!addressId) {
      console.error("Address ID not found")
      return
    }

    try {
      // Disable button to prevent double-clicks
      button.disabled = true
      button.textContent = "Setting..."

      const response = await fetch(`/companies/${this.companyIdValue}/contacts/${this.contactIdValue}/addresses/${addressId}/set_default`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json'
        }
      })

      if (response.ok) {
        // Update UI to reflect the change
        this.updateDefaultBadges(addressId)

        // Show success message
        this.showNotification("Address set as default successfully", "success")
      } else {
        const errorData = await response.json()
        this.showNotification(errorData.message || "Failed to set default address", "error")
      }
    } catch (error) {
      console.error("Error setting default address:", error)
      this.showNotification("An error occurred. Please try again.", "error")
    } finally {
      // Re-enable button
      button.disabled = false
      button.textContent = "Set as Default"
    }
  }

  updateDefaultBadges(newDefaultAddressId) {
    // Hide all default badges first
    this.defaultBadgeTargets.forEach(badge => {
      badge.classList.add('hidden')
    })

    // Show the badge for the new default address
    const newDefaultBadge = this.defaultBadgeTargets.find(
      badge => badge.dataset.addressId === newDefaultAddressId
    )

    if (newDefaultBadge) {
      newDefaultBadge.classList.remove('hidden')
    }

    // Update button visibility - hide button for new default, show for others
    this.setDefaultButtonTargets.forEach(button => {
      if (button.dataset.addressId === newDefaultAddressId) {
        button.style.display = 'none'
      } else {
        button.style.display = 'inline'
      }
    })
  }

  showNotification(message, type) {
    // Create a simple notification element
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 z-50 px-4 py-2 rounded-md shadow-lg ${
      type === 'success'
        ? 'bg-green-100 text-green-800 border border-green-200'
        : 'bg-red-100 text-red-800 border border-red-200'
    }`
    notification.textContent = message

    document.body.appendChild(notification)

    // Remove notification after 3 seconds
    setTimeout(() => {
      if (notification.parentNode) {
        notification.parentNode.removeChild(notification)
      }
    }, 3000)
  }
}