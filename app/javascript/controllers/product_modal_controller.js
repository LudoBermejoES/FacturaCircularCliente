import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "form", "nameField", "skuField", "priceField", "taxRateField", "descriptionField"]

  connect() {
    this.isModalOpen = false
    // Prevent scrolling when modal is open
    document.addEventListener('keydown', this.handleKeyDown.bind(this))
  }

  disconnect() {
    document.removeEventListener('keydown', this.handleKeyDown.bind(this))
  }

  // Open the modal
  open() {
    this.modalTarget.classList.remove('hidden')
    this.isModalOpen = true
    document.body.classList.add('overflow-hidden')

    // Focus the first input
    if (this.hasSkuFieldTarget) {
      this.skuFieldTarget.focus()
    }
  }

  // Close the modal
  close() {
    this.modalTarget.classList.add('hidden')
    this.isModalOpen = false
    document.body.classList.remove('overflow-hidden')
    this.clearForm()
  }

  // Handle backdrop click to close modal
  closeOnBackdrop(event) {
    if (event.target === event.currentTarget) {
      this.close()
    }
  }

  // Handle ESC key to close modal
  handleKeyDown(event) {
    if (this.isModalOpen && event.key === 'Escape') {
      this.close()
    }
  }

  // Clear the form
  clearForm() {
    if (this.hasFormTarget) {
      this.formTarget.reset()
    }
  }

  // Create product via AJAX
  async create(event) {
    event.preventDefault()

    const formData = new FormData(this.formTarget)
    const productData = {
      sku: formData.get('product[sku]'),
      name: formData.get('product[name]'),
      description: formData.get('product[description]'),
      base_price: formData.get('product[base_price]'),
      tax_rate: formData.get('product[tax_rate]') || 21,
      is_active: true
    }

    try {
      const response = await fetch('/products', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': this.getCSRFToken()
        },
        body: JSON.stringify({
          product: productData
        })
      })

      if (response.ok) {
        const result = await response.json()

        // Dispatch custom event with the created product data
        this.dispatch('productCreated', {
          detail: {
            product: {
              id: result.id,
              sku: result.sku,
              name: result.name,
              description: result.description,
              base_price: result.base_price,
              tax_rate: result.tax_rate,
              display_name: result.display_name,
              formatted_price: result.formatted_price
            }
          }
        })

        this.close()
        this.showSuccess('Product created successfully!')
      } else {
        const errorData = await response.json()
        this.showErrors(errorData.errors || ['Failed to create product'])
      }
    } catch (error) {
      console.error('Error creating product:', error)
      this.showErrors(['Network error occurred'])
    }
  }

  // Get CSRF token
  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ''
  }

  // Show success message
  showSuccess(message) {
    // Create a temporary success message
    const alert = document.createElement('div')
    alert.className = 'fixed top-4 right-4 z-50 max-w-sm bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded shadow-lg'
    alert.innerHTML = `
      <div class="flex">
        <div class="py-1">
          <svg class="h-6 w-6 text-green-500 mr-4" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        </div>
        <div>
          <div class="font-bold">Success!</div>
          <div class="text-sm">${message}</div>
        </div>
      </div>
    `
    document.body.appendChild(alert)

    // Remove after 3 seconds
    setTimeout(() => {
      alert.remove()
    }, 3000)
  }

  // Show error messages
  showErrors(errors) {
    // Clear previous errors
    this.clearErrors()

    // Add new error messages
    errors.forEach(error => {
      const errorElement = document.createElement('div')
      errorElement.className = 'text-red-600 text-sm mt-1'
      errorElement.textContent = error

      // Append to form (or create a general error area)
      const errorContainer = this.element.querySelector('.error-messages')
      if (errorContainer) {
        errorContainer.appendChild(errorElement)
      }
    })
  }

  // Clear error messages
  clearErrors() {
    const errorContainer = this.element.querySelector('.error-messages')
    if (errorContainer) {
      errorContainer.innerHTML = ''
    }
  }
}