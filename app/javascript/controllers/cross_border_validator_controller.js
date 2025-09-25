// Cross-border transaction validation controller
// Integrates with CrossBorderTaxValidator service for real-time validation

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "validationResults", "validationStatus", "warningsList", "recommendationsList",
    "documentsList", "validationButton", "sellerJurisdiction", "buyerJurisdiction",
    "transactionAmount", "buyerType", "productTypes"
  ]

  static values = {
    invoiceData: Object,
    validationCache: Object
  }

  connect() {
    console.log("Cross-border validator connected")
    this.validationCacheValue = this.validationCacheValue || {}

    // Auto-validate when key fields change
    this.setupAutoValidation()
  }

  setupAutoValidation() {
    // Listen for changes to key fields
    const keyFields = [
      'select[name="invoice[establishment_id]"]',
      'select[name="invoice[buyer_country_override]"]',
      'input[name="invoice[buyer_city_override]"]',
      'select[name="buyer_selection"]'
    ]

    keyFields.forEach(selector => {
      const field = document.querySelector(selector)
      if (field) {
        field.addEventListener('change', () => this.scheduleValidation())
        field.addEventListener('input', () => this.scheduleValidation())
      }
    })

    // Listen for line item changes
    document.addEventListener('input', (event) => {
      if (event.target.matches('[name*="[description]"]') ||
          event.target.matches('[name*="[quantity]"]') ||
          event.target.matches('[name*="[unit_price]"]')) {
        this.scheduleValidation()
      }
    })
  }

  scheduleValidation() {
    // Debounce validation calls
    clearTimeout(this.validationTimeout)
    this.validationTimeout = setTimeout(() => {
      this.validateTransaction()
    }, 1000) // 1 second debounce
  }

  async validateTransaction() {
    try {
      this.showValidationLoading()

      const transactionData = this.extractTransactionData()
      const cacheKey = this.createCacheKey(transactionData)

      // Check cache first
      if (this.validationCacheValue[cacheKey]) {
        this.displayValidationResults(this.validationCacheValue[cacheKey])
        return
      }

      const validationResult = await this.performValidation(transactionData)

      // Cache result for 5 minutes
      this.validationCacheValue[cacheKey] = validationResult
      setTimeout(() => {
        delete this.validationCacheValue[cacheKey]
      }, 5 * 60 * 1000)

      this.displayValidationResults(validationResult)

    } catch (error) {
      console.error('Cross-border validation error:', error)
      this.showValidationError(error.message)
    }
  }

  extractTransactionData() {
    // Extract establishment and jurisdiction info
    const establishmentSelect = document.querySelector('select[name="invoice[establishment_id]"]')
    const establishmentId = establishmentSelect?.value

    // Get establishment data from form or API
    const sellerJurisdiction = this.extractSellerJurisdiction(establishmentId)

    // Extract buyer information
    const buyerCountryOverride = document.querySelector('select[name="invoice[buyer_country_override]"]')?.value
    const buyerCityOverride = document.querySelector('input[name="invoice[buyer_city_override]"]')?.value
    const buyerSelection = document.querySelector('select[name="buyer_selection"]')?.value

    const buyerJurisdiction = this.extractBuyerJurisdiction(buyerCountryOverride, buyerSelection)

    // Extract transaction details
    const invoiceLines = this.extractInvoiceLines()
    const transactionAmount = this.calculateTransactionAmount(invoiceLines)
    const productTypes = this.extractProductTypes(invoiceLines)

    return {
      seller_jurisdiction_code: sellerJurisdiction,
      buyer_jurisdiction_code: buyerJurisdiction,
      seller_establishment: establishmentId,
      buyer_location: buyerCityOverride || this.extractBuyerLocation(buyerSelection),
      transaction_amount: transactionAmount,
      product_types: productTypes,
      buyer_type: this.determineBuyerType(buyerSelection),
      invoice_lines: invoiceLines,
      transaction_date: document.querySelector('input[name="invoice[issue_date]"]')?.value || new Date().toISOString().split('T')[0]
    }
  }

  extractSellerJurisdiction(establishmentId) {
    if (!establishmentId) return 'ESP' // Default

    // Try to get from establishment data
    const establishmentOption = document.querySelector(`option[value="${establishmentId}"]`)
    const jurisdictionCode = establishmentOption?.dataset.jurisdictionCode

    return jurisdictionCode || 'ESP'
  }

  extractBuyerJurisdiction(countryOverride, buyerSelection) {
    // If country override is set, use it
    if (countryOverride) return countryOverride

    // Try to extract from buyer selection
    if (buyerSelection) {
      const [type, id] = buyerSelection.split(':')

      if (type === 'company') {
        // For companies, try to get jurisdiction from company data
        const companyOption = document.querySelector(`option[value="company:${id}"]`)
        return companyOption?.dataset.countryCode || 'ESP'
      } else if (type === 'contact') {
        // For contacts, try to get from contact data
        const contactOption = document.querySelector(`option[value="contact:${id}"]`)
        return contactOption?.dataset.countryCode || 'ESP'
      }
    }

    return 'ESP' // Default
  }

  extractBuyerLocation(buyerSelection) {
    if (!buyerSelection) return null

    const [type, id] = buyerSelection.split(':')

    if (type === 'company') {
      const companyOption = document.querySelector(`option[value="company:${id}"]`)
      return companyOption?.dataset.location || null
    } else if (type === 'contact') {
      const contactOption = document.querySelector(`option[value="contact:${id}"]`)
      return contactOption?.dataset.location || null
    }

    return null
  }

  extractInvoiceLines() {
    const lines = []
    const lineItems = document.querySelectorAll('[data-line-index]')

    lineItems.forEach((lineItem, index) => {
      const description = lineItem.querySelector('[name*="[description]"]')?.value?.trim()
      const quantity = parseFloat(lineItem.querySelector('[name*="[quantity]"]')?.value || 0)
      const unitPrice = parseFloat(lineItem.querySelector('[name*="[unit_price]"]')?.value || 0)
      const taxRate = parseFloat(lineItem.querySelector('[name*="[tax_rate]"]')?.value || 0)
      const discountPercentage = parseFloat(lineItem.querySelector('[name*="[discount_percentage]"]')?.value || 0)

      if (description && quantity > 0 && unitPrice > 0) {
        lines.push({
          description,
          quantity,
          unit_price: unitPrice,
          tax_rate: taxRate,
          discount_percentage: discountPercentage,
          line_total: (quantity * unitPrice) * (1 - discountPercentage / 100)
        })
      }
    })

    return lines
  }

  calculateTransactionAmount(invoiceLines) {
    return invoiceLines.reduce((total, line) => total + (line.line_total || 0), 0)
  }

  extractProductTypes(invoiceLines) {
    const productTypes = new Set(['goods']) // Default

    invoiceLines.forEach(line => {
      const description = line.description.toLowerCase()

      // Digital services detection
      const digitalKeywords = ['software', 'license', 'subscription', 'saas', 'digital', 'download', 'streaming']
      if (digitalKeywords.some(keyword => description.includes(keyword))) {
        productTypes.add('digital_services')
      }

      // Services detection
      const serviceKeywords = ['consulting', 'training', 'support', 'maintenance', 'service']
      if (serviceKeywords.some(keyword => description.includes(keyword))) {
        productTypes.add('services')
      }

      // Education detection
      const educationKeywords = ['training', 'education', 'course', 'workshop', 'seminar']
      if (educationKeywords.some(keyword => description.includes(keyword))) {
        productTypes.add('education')
      }
    })

    return Array.from(productTypes)
  }

  determineBuyerType(buyerSelection) {
    if (!buyerSelection) return 'business'

    const [type, id] = buyerSelection.split(':')

    // Companies are always business
    if (type === 'company') return 'business'

    // For contacts, check if they have business indicators
    if (type === 'contact') {
      const contactOption = document.querySelector(`option[value="contact:${id}"]`)
      const contactName = contactOption?.textContent || ''

      // Simple heuristic - look for business indicators
      const businessIndicators = ['ltd', 'llc', 'inc', 'corp', 'gmbh', 'sarl', 's.l.', 'lda', 'sa']
      const isBusinessContact = businessIndicators.some(indicator =>
        contactName.toLowerCase().includes(indicator)
      )

      return isBusinessContact ? 'business' : 'consumer'
    }

    return 'business' // Default
  }

  async performValidation(transactionData) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')

    const response = await fetch('/api/v1/tax/validate_cross_border', {
      method: 'POST',
      headers: {
        'X-CSRF-Token': csrfToken,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: JSON.stringify({
        transaction: transactionData
      })
    })

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}))
      throw new Error(errorData.error || `Validation failed (${response.status})`)
    }

    return await response.json()
  }

  displayValidationResults(validationResult) {
    this.hideValidationLoading()

    if (!validationResult || !validationResult.validation_results) {
      this.showValidationError('Invalid validation response')
      return
    }

    const results = validationResult.validation_results
    const summary = results.summary

    // Update validation status
    this.updateValidationStatus(summary)

    // Display warnings
    this.displayWarnings(validationResult.warnings || [])

    // Display recommendations
    this.displayRecommendations(validationResult.recommendations || [])

    // Display required documents
    this.displayRequiredDocuments(validationResult.required_documents || [])

    // Show detailed results
    this.displayDetailedResults(results)

    // Show validation results container
    if (this.hasValidationResultsTarget) {
      this.validationResultsTarget.classList.remove('hidden')
    }
  }

  updateValidationStatus(summary) {
    if (!this.hasValidationStatusTarget) return

    const statusElement = this.validationStatusTarget

    let statusClass, statusIcon, statusText

    switch (summary.status) {
      case 'success':
        statusClass = 'bg-green-100 text-green-800 border-green-200'
        statusIcon = '✅'
        statusText = 'Validation Passed'
        break
      case 'warning':
        statusClass = 'bg-yellow-100 text-yellow-800 border-yellow-200'
        statusIcon = '⚠️'
        statusText = 'Validation Warnings'
        break
      case 'error':
        statusClass = 'bg-red-100 text-red-800 border-red-200'
        statusIcon = '❌'
        statusText = 'Validation Errors'
        break
      default:
        statusClass = 'bg-gray-100 text-gray-800 border-gray-200'
        statusIcon = 'ℹ️'
        statusText = 'Unknown Status'
    }

    statusElement.className = `inline-flex items-center px-3 py-2 rounded-md text-sm font-medium border ${statusClass}`
    statusElement.innerHTML = `
      <span class="mr-2">${statusIcon}</span>
      ${statusText}
      <span class="ml-2 text-xs">
        (${summary.errors || 0} errors, ${summary.warnings || 0} warnings)
      </span>
    `
  }

  displayWarnings(warnings) {
    if (!this.hasWarningsListTarget) return

    this.warningsListTarget.innerHTML = ''

    if (warnings.length === 0) {
      this.warningsListTarget.innerHTML = '<li class="text-gray-500 italic">No warnings</li>'
      return
    }

    warnings.forEach(warning => {
      const li = document.createElement('li')
      li.className = 'flex items-start space-x-2 text-yellow-800'
      li.innerHTML = `
        <span class="flex-shrink-0 w-5 h-5 mt-0.5">⚠️</span>
        <span class="flex-1">${warning}</span>
      `
      this.warningsListTarget.appendChild(li)
    })
  }

  displayRecommendations(recommendations) {
    if (!this.hasRecommendationsListTarget) return

    this.recommendationsListTarget.innerHTML = ''

    if (recommendations.length === 0) {
      this.recommendationsListTarget.innerHTML = '<li class="text-gray-500 italic">No recommendations</li>'
      return
    }

    recommendations.forEach(recommendation => {
      const li = document.createElement('li')
      li.className = 'flex items-start space-x-2 text-blue-800'
      li.innerHTML = `
        <span class="flex-shrink-0 w-5 h-5 mt-0.5">💡</span>
        <span class="flex-1">${recommendation}</span>
      `
      this.recommendationsListTarget.appendChild(li)
    })
  }

  displayRequiredDocuments(documents) {
    if (!this.hasDocumentsListTarget) return

    this.documentsListTarget.innerHTML = ''

    if (documents.length === 0) {
      this.documentsListTarget.innerHTML = '<li class="text-gray-500 italic">No additional documents required</li>'
      return
    }

    documents.forEach(document => {
      const li = document.createElement('li')
      li.className = 'flex items-start space-x-2 text-gray-800'
      li.innerHTML = `
        <span class="flex-shrink-0 w-5 h-5 mt-0.5">📄</span>
        <span class="flex-1">${document}</span>
      `
      this.documentsListTarget.appendChild(li)
    })
  }

  displayDetailedResults(results) {
    // This could be expanded to show detailed validation results
    // For now, we'll just log them for debugging
    console.log('Detailed validation results:', results)
  }

  showValidationLoading() {
    if (this.hasValidationButtonTarget) {
      this.validationButtonTarget.disabled = true
      this.validationButtonTarget.innerHTML = `
        <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Validating...
      `
    }
  }

  hideValidationLoading() {
    if (this.hasValidationButtonTarget) {
      this.validationButtonTarget.disabled = false
      this.validationButtonTarget.innerHTML = 'Validate Transaction'
    }
  }

  showValidationError(message) {
    this.hideValidationLoading()

    if (this.hasValidationStatusTarget) {
      this.validationStatusTarget.className = 'inline-flex items-center px-3 py-2 rounded-md text-sm font-medium border bg-red-100 text-red-800 border-red-200'
      this.validationStatusTarget.innerHTML = `
        <span class="mr-2">❌</span>
        Validation Error: ${message}
      `
    }
  }

  createCacheKey(transactionData) {
    return JSON.stringify({
      seller: transactionData.seller_jurisdiction_code,
      buyer: transactionData.buyer_jurisdiction_code,
      amount: Math.round(transactionData.transaction_amount || 0),
      products: transactionData.product_types.sort(),
      type: transactionData.buyer_type
    })
  }

  disconnect() {
    // Clean up timers
    if (this.validationTimeout) {
      clearTimeout(this.validationTimeout)
    }

    // Clear cache
    this.validationCacheValue = {}
  }
}