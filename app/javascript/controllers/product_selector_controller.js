import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "results", "createLineButton"]
  static values = {
    searchUrl: String,
    lineIndex: Number
  }

  connect() {
    this.debounceTimer = null
    this.isResultsVisible = false
    this.selectedProduct = null
  }

  disconnect() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
  }

  search(event) {
    clearTimeout(this.debounceTimer)
    const query = event.target.value

    if (query.length < 2) {
      this.hideResults()
      return
    }

    this.debounceTimer = setTimeout(() => {
      this.performSearch(query)
    }, 300)
  }

  async performSearch(query) {
    try {
      const url = new URL(this.searchUrlValue, window.location.origin)
      url.searchParams.set('q', query)

      const response = await fetch(url, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const products = await response.json()
      this.displayResults(products)
    } catch (error) {
      console.error('Error searching products:', error)
      this.hideResults()
    }
  }

  displayResults(products) {
    if (!products || products.length === 0) {
      this.showNoResults()
      return
    }

    const resultsHtml = products.map(product => `
      <div class="px-4 py-2 hover:bg-gray-100 cursor-pointer border-b border-gray-100 last:border-b-0"
           data-action="click->product-selector#selectProduct"
           data-product-id="${product.id}"
           data-product-sku="${product.sku}"
           data-product-name="${product.name}"
           data-product-description="${product.description || ''}"
           data-product-base-price="${product.base_price}"
           data-product-tax-rate="${product.tax_rate}">
        <div class="flex items-center justify-between">
          <div class="flex-1 min-w-0">
            <div class="text-sm font-medium text-gray-900 truncate">
              ${product.display_name || `${product.sku} - ${product.name}`}
            </div>
            <div class="text-sm text-gray-500 truncate">
              ${product.description || 'No description'}
            </div>
          </div>
          <div class="text-right">
            <div class="text-sm font-medium text-gray-900">
              ${product.formatted_price || `€${product.base_price}`}
            </div>
            <div class="text-xs text-gray-500">
              ${product.tax_rate}% tax
            </div>
          </div>
        </div>
      </div>
    `).join('')

    this.resultsTarget.innerHTML = resultsHtml
    this.showResults()
  }

  showNoResults() {
    this.resultsTarget.innerHTML = `
      <div class="px-4 py-3 text-sm text-gray-500 text-center">
        <div class="flex items-center justify-center">
          <svg class="h-5 w-5 text-gray-400 mr-2" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0110.607 10.607z" />
          </svg>
          No products found
        </div>
      </div>
    `
    this.showResults()
  }

  selectProduct(event) {
    const productData = event.currentTarget.dataset

    // Store the selected product data
    this.selectedProduct = {
      id: productData.productId,
      sku: productData.productSku,
      name: productData.productName,
      description: productData.productDescription || productData.productName,
      base_price: productData.productBasePrice,
      tax_rate: productData.productTaxRate
    }

    // Update the search field to show the selected product
    this.searchTarget.value = `${productData.productSku} - ${productData.productName}`
    this.hideResults()

    // Enable the create line button
    if (this.hasCreateLineButtonTarget) {
      this.createLineButtonTarget.disabled = false
      this.createLineButtonTarget.classList.remove('opacity-50', 'cursor-not-allowed')
      this.createLineButtonTarget.classList.add('hover:bg-green-700')
    }

    // Dispatch custom event for other controllers
    this.dispatch('productSelected', {
      detail: this.selectedProduct
    })
  }

  createLine() {
    if (!this.selectedProduct) {
      console.log('createLine called but no product selected')
      return
    }

    console.log('createLine dispatching event for product:', this.selectedProduct)
    // Dispatch custom event to invoice form controller to add a new line with product data
    const event = new CustomEvent('createProductLine', {
      detail: {
        product: this.selectedProduct,
        quantity: 1
      },
      bubbles: true
    })

    this.element.dispatchEvent(event)
    console.log('createProductLine event dispatched')

    // Clear the selection after creating line
    this.clearSelection()
  }

  clearSelection() {
    this.searchTarget.value = ''
    this.hideResults()
    this.selectedProduct = null

    // Disable the create line button
    if (this.hasCreateLineButtonTarget) {
      this.createLineButtonTarget.disabled = true
      this.createLineButtonTarget.classList.add('opacity-50', 'cursor-not-allowed')
      this.createLineButtonTarget.classList.remove('hover:bg-green-700')
    }
  }

  showResults() {
    this.resultsTarget.classList.remove('hidden')
    this.isResultsVisible = true
  }

  hideResults() {
    this.resultsTarget.classList.add('hidden')
    this.isResultsVisible = false
  }

  // Hide results when clicking outside
  clickOutside(event) {
    if (this.isResultsVisible && !this.element.contains(event.target)) {
      this.hideResults()
    }
  }

  // Connect global click listener when controller connects
  initialize() {
    this.clickOutsideHandler = this.clickOutside.bind(this)
  }

  connect() {
    super.connect?.()
    document.addEventListener('click', this.clickOutsideHandler)
    document.addEventListener('product-modal:productCreated', this.handleProductCreated.bind(this))
  }

  disconnect() {
    super.disconnect?.()
    document.removeEventListener('click', this.clickOutsideHandler)
    document.removeEventListener('product-modal:productCreated', this.handleProductCreated.bind(this))
  }

  // Handle newly created products
  handleProductCreated(event) {
    const product = event.detail.product

    // Auto-select the newly created product
    this.selectNewProduct(product)
  }

  // Select a newly created product
  selectNewProduct(product) {
    // Store the selected product data
    this.selectedProduct = {
      id: product.id,
      sku: product.sku,
      name: product.name,
      description: product.description || product.name,
      base_price: product.base_price,
      tax_rate: product.tax_rate
    }

    // Update the search field to show the selected product
    this.searchTarget.value = `${product.sku} - ${product.name}`
    this.hideResults()

    // Enable the create line button
    if (this.hasCreateLineButtonTarget) {
      this.createLineButtonTarget.disabled = false
      this.createLineButtonTarget.classList.remove('opacity-50', 'cursor-not-allowed')
      this.createLineButtonTarget.classList.add('hover:bg-green-700')
    }

    // Dispatch custom event for other controllers
    this.dispatch('productSelected', {
      detail: this.selectedProduct
    })
  }
}