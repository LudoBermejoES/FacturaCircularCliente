import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "lineItems", "lineItemTemplate", "subtotal", "tax", "total", "addButton", "seriesSelect", "invoiceNumber",
    "contactField", "contactSelect", "invoiceTypeSelect", "buyerSelect", "buyerPartyId", "buyerContactId",
    "establishmentSelect", "taxJurisdiction", "buyerLocationToggle", "buyerLocationFields",
    "taxContextStatus", "taxContextIndicator", "taxContextDetails", "transactionType", "crossBorder",
    "euTransaction", "reverseCharge", "autoTaxCalculate", "calculateTaxButton", "refreshTaxButton",
    "taxContextEstablishmentId", "taxContextCrossBorder", "taxContextEuTransaction", "taxContextReverseCharge"
  ]
  static values = {
    lineIndex: Number,
    taxRate: { type: Number, default: 21 },
    allSeries: Array,
    taxContextData: Object,
    companyEstablishments: Array
  }

  // Performance optimization properties
  taxContextCache = new Map()
  establishmentCache = new Map()
  debounceTimers = new Map()
  requestCache = new Map()
  lastTaxCalculationSignature = null

  connect() {
    this.lineIndexValue = this.lineItemsTarget.querySelectorAll('.line-item').length
    if (this.lineIndexValue === 0) {
      this.addLineItem()
    }
    this.calculateTotals()

    // Store all series options for filtering
    if (this.hasSeriesSelectTarget) {
      this.storeAllSeriesOptions()
      // Filter series based on current invoice type on page load
      if (this.hasInvoiceTypeSelectTarget) {
        const currentInvoiceType = this.invoiceTypeSelectTarget.value
        if (currentInvoiceType) {
          this.filterSeriesByType(currentInvoiceType)
        }
      }
    }

    // Listen for product line creation events
    this.element.addEventListener('createProductLine', this.handleCreateProductLine.bind(this))
  }

  disconnect() {
    this.element.removeEventListener('createProductLine', this.handleCreateProductLine.bind(this))
  }

  handleCreateProductLine(event) {
    console.log('handleCreateProductLine called with:', event.detail)
    const { product, quantity } = event.detail

    // Create a new line item with product data
    this.addLineItemWithProduct(product, quantity)
  }

  addLineItemWithProduct(product, quantity = 1) {
    console.log('addLineItemWithProduct called with product:', product, 'quantity:', quantity)
    // Get the template HTML
    const template = this.lineItemTemplateTarget.innerHTML
    console.log('Template found:', template.length > 0 ? 'Yes' : 'No')
    console.log('Template content:', template.substring(0, 100) + '...')

    // Create a temporary table container to manipulate the HTML (needed for <tr> elements)
    const tempTable = document.createElement('table')
    const tempTbody = document.createElement('tbody')
    tempTbody.innerHTML = template.replace(/NEW_RECORD/g, this.lineIndexValue)
    tempTable.appendChild(tempTbody)
    console.log('TempTbody innerHTML:', tempTbody.innerHTML.substring(0, 100) + '...')

    // Find the line item row in the template (not the product selector row)
    let lineItemRow = tempTbody.querySelector('.line-item')
    console.log('LineItemRow found:', lineItemRow ? 'Yes' : 'No')

    if (lineItemRow) {


      // Add just the filled line item (no need for product selector on the new line)
      const fullLineHTML = `
        ${lineItemRow.outerHTML}
      `

      // Add the complete line item
      console.log('Inserting HTML:', fullLineHTML.substring(0, 200) + '...')
      this.lineItemsTarget.insertAdjacentHTML('beforeend', fullLineHTML)
      const lastRow = this.lineItemsTarget.rows[this.lineItemsTarget.rows.length - 1];

            // Fill in the product data
      const descriptionField = lastRow.querySelector('input[name*="[description]"]')
      const quantityField = lastRow.querySelector('input[name*="[quantity]"]')
      const unitPriceField = lastRow.querySelector('input[name*="[unit_price]"]')
      const taxRateField = lastRow.querySelector('input[name*="[tax_rate]"]')
      const discountField = lastRow.querySelector('input[name*="[discount_percentage]"]')

      if (descriptionField) descriptionField.value = product.description
      if (quantityField) quantityField.value = quantity
      if (unitPriceField) unitPriceField.value = product.base_price
      if (taxRateField) taxRateField.value = product.tax_rate
      if (discountField) discountField.value = 0
      console.log(lastRow)
      console.log('HTML inserted successfully')
    } else {
      console.log('Error: lineItemRow not found in template')
    }

    this.lineIndexValue++
    this.calculateTotals()
  }

  addLineItem(event) {
    if (event) event.preventDefault()

    const template = this.lineItemTemplateTarget.innerHTML
    const newLineItem = template.replace(/NEW_RECORD/g, this.lineIndexValue)

    this.lineItemsTarget.insertAdjacentHTML('beforeend', newLineItem)
    this.lineIndexValue++
    this.calculateTotals()

    // Focus on the description field of the new line item
    const newItems = this.lineItemsTarget.querySelectorAll('.line-item')
    const lastItem = newItems[newItems.length - 1]
    const descriptionField = lastItem.querySelector('input[name*="[description]"]')
    if (descriptionField) {
      descriptionField.focus()
    }
  }

  removeLineItem(event) {
    event.preventDefault()
    
    const lineItem = event.target.closest('.line-item')
    
    // Don't remove if it's the last line item
    const lineItems = this.lineItemsTarget.querySelectorAll('.line-item')
    if (lineItems.length > 1) {
      lineItem.remove()
      this.calculateTotals()
    } else {
      // Clear the last line item instead of removing it
      lineItem.querySelectorAll('input').forEach(input => {
        if (input.type !== 'hidden') {
          input.value = input.type === 'number' ? '0' : ''
        }
      })
      this.calculateTotals()
    }
  }

  calculateLineTotal(event) {
    const lineItem = event.target.closest('.line-item')
    this.updateLineTotal(lineItem)
    this.calculateTotals()
  }

  updateLineTotal(lineItem) {
    const quantity = parseFloat(lineItem.querySelector('input[name*="[quantity]"]')?.value) || 0
    const unitPrice = parseFloat(lineItem.querySelector('input[name*="[unit_price]"]')?.value) || 0
    const discount = parseFloat(lineItem.querySelector('input[name*="[discount_percentage]"]')?.value) || 0
    const taxRate = parseFloat(lineItem.querySelector('input[name*="[tax_rate]"]')?.value) || 0
    
    const subtotal = quantity * unitPrice
    const discountAmount = subtotal * (discount / 100)
    const lineNet = subtotal - discountAmount
    const lineTax = lineNet * (taxRate / 100)
    const lineTotal = lineNet + lineTax
    
    const totalElement = lineItem.querySelector('.line-total')
    if (totalElement) {
      totalElement.textContent = `€${lineTotal.toFixed(2)}`
    }
    
    return lineTotal
  }

  calculateTotals() {
    let subtotal = 0
    let totalTax = 0

    const lineItems = this.lineItemsTarget.querySelectorAll('.line-item')

    lineItems.forEach(lineItem => {
      const quantity = parseFloat(lineItem.querySelector('input[name*="[quantity]"]')?.value) || 0
      const unitPrice = parseFloat(lineItem.querySelector('input[name*="[unit_price]"]')?.value) || 0
      const discount = parseFloat(lineItem.querySelector('input[name*="[discount_percentage]"]')?.value) || 0
      const taxRate = parseFloat(lineItem.querySelector('input[name*="[tax_rate]"]')?.value) || 0

      const lineSubtotal = quantity * unitPrice
      const discountAmount = lineSubtotal * (discount / 100)
      const lineNet = lineSubtotal - discountAmount
      const lineTax = lineNet * (taxRate / 100)

      subtotal += lineNet
      totalTax += lineTax

      this.updateLineTotal(lineItem)
    })

    // Get global financial amounts
    const generalDiscounts = parseFloat(document.querySelector('input[name="invoice[total_general_discounts]"]')?.value) || 0
    const generalSurcharges = parseFloat(document.querySelector('input[name="invoice[total_general_surcharges]"]')?.value) || 0
    const financialExpenses = parseFloat(document.querySelector('input[name="invoice[total_financial_expenses]"]')?.value) || 0
    const reimbursableExpenses = parseFloat(document.querySelector('input[name="invoice[total_reimbursable_expenses]"]')?.value) || 0
    const withholdingAmount = parseFloat(document.querySelector('input[name="invoice[withholding_amount]"]')?.value) || 0

    // Calculate gross amount before taxes (following backend logic)
    // total_gross_amount_before_taxes = subtotal - general_discounts + general_surcharges + financial_expenses + reimbursable_expenses
    const grossBeforeTaxes = subtotal - generalDiscounts + generalSurcharges + financialExpenses + reimbursableExpenses

    // Calculate final total (gross before taxes + tax outputs - withholding)
    const total = grossBeforeTaxes + totalTax - withholdingAmount

    // Update display
    if (this.hasSubtotalTarget) {
      this.subtotalTarget.textContent = `€${subtotal.toFixed(2)}`
    }
    if (this.hasTaxTarget) {
      this.taxTarget.textContent = `€${totalTax.toFixed(2)}`
    }
    if (this.hasTotalTarget) {
      this.totalTarget.textContent = `€${total.toFixed(2)}`
    }

    // Update global amounts display
    const generalDiscountsTarget = document.querySelector('[data-invoice-form-target="generalDiscounts"]')
    if (generalDiscountsTarget) {
      generalDiscountsTarget.textContent = generalDiscounts > 0 ? `-€${generalDiscounts.toFixed(2)}` : '-€0.00'
    }

    const generalSurchargesTarget = document.querySelector('[data-invoice-form-target="generalSurcharges"]')
    if (generalSurchargesTarget) {
      generalSurchargesTarget.textContent = generalSurcharges > 0 ? `+€${generalSurcharges.toFixed(2)}` : '+€0.00'
    }

    const financialExpensesTarget = document.querySelector('[data-invoice-form-target="financialExpenses"]')
    if (financialExpensesTarget) {
      financialExpensesTarget.textContent = `€${financialExpenses.toFixed(2)}`
    }

    const reimbursableExpensesTarget = document.querySelector('[data-invoice-form-target="reimbursableExpenses"]')
    if (reimbursableExpensesTarget) {
      reimbursableExpensesTarget.textContent = `€${reimbursableExpenses.toFixed(2)}`
    }

    const grossBeforeTaxesTarget = document.querySelector('[data-invoice-form-target="grossBeforeTaxes"]')
    if (grossBeforeTaxesTarget) {
      grossBeforeTaxesTarget.textContent = `€${grossBeforeTaxes.toFixed(2)}`
    }

    const withholdingTarget = document.querySelector('[data-invoice-form-target="withholding"]')
    if (withholdingTarget) {
      withholdingTarget.textContent = withholdingAmount > 0 ? `-€${withholdingAmount.toFixed(2)}` : '-€0.00'
    }
  }

  updateBuyer(event) {
    const selection = event.target.value

    if (!selection) {
      // Clear both hidden fields
      if (this.hasBuyerPartyIdTarget) this.buyerPartyIdTarget.value = ''
      if (this.hasBuyerContactIdTarget) this.buyerContactIdTarget.value = ''
      return
    }

    // Parse the selection format: "type:id"
    const [type, id] = selection.split(':')

    if (type === 'company') {
      // Set company ID and clear contact ID
      if (this.hasBuyerPartyIdTarget) this.buyerPartyIdTarget.value = id
      if (this.hasBuyerContactIdTarget) this.buyerContactIdTarget.value = ''
    } else if (type === 'contact') {
      // Set contact ID and clear company ID
      if (this.hasBuyerContactIdTarget) this.buyerContactIdTarget.value = id
      if (this.hasBuyerPartyIdTarget) this.buyerPartyIdTarget.value = ''
    }
  }

  async updateCompany(event) {
    const companyId = event.target.value

    if (!companyId) {
      this.hideContactField()
      return
    }

    // Load company contacts
    try {
      await this.loadCompanyContacts(companyId)
      this.showContactField()
    } catch (error) {
      console.error('Error loading company contacts:', error)
      this.hideContactField()
    }
  }

  async loadCompanyContacts(companyId) {
    // Get CSRF token for Rails
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
    
    const response = await fetch(`/api/v1/companies/${companyId}/contacts`, {
      headers: {
        'X-CSRF-Token': csrfToken,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }
    })
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`)
    }
    
    const data = await response.json()
    
    // Update the contact select dropdown
    if (this.hasContactSelectTarget) {
      this.updateContactOptions(data.contacts || [])
    }
  }

  updateContactOptions(contacts) {
    const selectElement = this.contactSelectTarget
    
    // Clear existing options except the first (blank option)
    while (selectElement.children.length > 1) {
      selectElement.removeChild(selectElement.lastChild)
    }
    
    // Add new contact options
    contacts.forEach(contact => {
      const option = document.createElement('option')
      option.value = contact.id
      option.textContent = contact.name
      selectElement.appendChild(option)
    })
  }

  showContactField() {
    if (this.hasContactFieldTarget) {
      this.contactFieldTarget.style.display = 'block'
    }
  }

  hideContactField() {
    if (this.hasContactFieldTarget) {
      this.contactFieldTarget.style.display = 'none'
    }
    
    // Clear the contact selection
    if (this.hasContactSelectTarget) {
      this.contactSelectTarget.value = ''
    }
  }

  openContactModal(event) {
    event.preventDefault()
    const companyId = document.querySelector('select[name="invoice[buyer_party_id]"]')?.value
    
    if (companyId) {
      // Open the company contacts management page in a new tab
      window.open(`/companies/${companyId}/company_contacts`, '_blank')
    } else {
      alert('Please select a company first')
    }
  }

  async onSeriesChange(event) {
    const seriesId = event.target.value
    if (!seriesId) {
      this.clearInvoiceNumber()
      return
    }

    try {
      // Get the selected option to extract series data
      const selectedOption = event.target.selectedOptions[0]
      const seriesText = selectedOption.text
      const seriesCode = seriesText.split(' - ')[0] // Extract series code from "FC - Factura Comercial"
      
      // Get current year (you might want to make this configurable)
      const currentYear = new Date().getFullYear()
      
      // Show loading state
      this.showLoadingState()
      
      // Fetch next available number from API
      const nextNumber = await this.fetchNextAvailableNumber(seriesCode, currentYear)
      
      if (nextNumber) {
        this.updateInvoiceNumber(nextNumber, seriesCode)
      } else {
        this.showErrorState("Unable to generate invoice number")
      }
      
    } catch (error) {
      console.error('Error fetching next available number:', error)
      this.showErrorState("Error generating invoice number")
    }
  }

  async fetchNextAvailableNumber(seriesCode, year) {
    // First try to determine series type from code
    const seriesType = this.getSeriesTypeFromCode(seriesCode)
    
    // Make API call to the client's local API endpoint
    const params = new URLSearchParams({
      series_type: seriesType,
      year: year
    })
    
    // Get CSRF token for Rails
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
    
    const response = await fetch(`/api/v1/invoice_numbering/next_available?${params}`, {
      headers: {
        'X-CSRF-Token': csrfToken,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }
    })
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`)
    }
    
    const data = await response.json()
    
    // Find the next number for the selected series
    if (data.data && data.data.attributes && data.data.attributes.available_numbers) {
      const availableNumbers = data.data.attributes.available_numbers
      // available_numbers is an object with series codes as keys
      const seriesNumbers = availableNumbers[seriesCode]
      if (seriesNumbers && seriesNumbers.length > 0) {
        // Return the sequence number from the first (and usually only) entry
        return seriesNumbers[0].sequence_number
      }
    }
    
    return null
  }

  getSeriesTypeFromCode(seriesCode) {
    // Map series codes to types based on common patterns
    const codeMapping = {
      'FC': 'commercial',
      'PF': 'proforma', 
      'CR': 'credit_note',
      'DB': 'debit_note',
      'SI': 'simplified',
      'RE': 'rectificative'
    }
    
    return codeMapping[seriesCode] || 'commercial'
  }

  updateInvoiceNumber(nextNumber, seriesCode) {
    if (this.hasInvoiceNumberTarget) {
      const formattedNumber = `${seriesCode}-${String(nextNumber).padStart(4, '0')}`
      this.invoiceNumberTarget.value = formattedNumber
      this.invoiceNumberTarget.classList.remove('border-red-300', 'text-red-900', 'bg-red-50')
      this.invoiceNumberTarget.classList.add('bg-gray-50')
    }
  }

  clearInvoiceNumber() {
    if (this.hasInvoiceNumberTarget) {
      this.invoiceNumberTarget.value = ''
      this.invoiceNumberTarget.placeholder = 'Select a series first'
    }
  }

  showLoadingState() {
    if (this.hasInvoiceNumberTarget) {
      this.invoiceNumberTarget.value = ''
      this.invoiceNumberTarget.placeholder = 'Generating number...'
      this.invoiceNumberTarget.classList.add('animate-pulse')
    }
  }

  showErrorState(message) {
    if (this.hasInvoiceNumberTarget) {
      this.invoiceNumberTarget.value = ''
      this.invoiceNumberTarget.placeholder = message
      this.invoiceNumberTarget.classList.remove('animate-pulse', 'bg-gray-50')
      this.invoiceNumberTarget.classList.add('border-red-300', 'text-red-900', 'bg-red-50')
    }
  }

  storeAllSeriesOptions() {
    const allOptions = Array.from(this.seriesSelectTarget.options).map(option => ({
      value: option.value,
      text: option.text,
      seriesCode: option.text.split(' - ')[0], // Extract series code like "PF" from "PF - Proforma 2025"
      selected: option.selected
    }))
    this.allSeriesValue = allOptions
  }

  onInvoiceTypeChange(event) {
    const invoiceType = event.target.value
    this.filterSeriesByType(invoiceType)
    // Clear invoice number when type changes
    this.clearInvoiceNumber()
  }

  filterSeriesByType(invoiceType) {
    if (!this.hasSeriesSelectTarget || !this.allSeriesValue) {
      return
    }

    // Determine which series codes are valid for the selected invoice type
    const validSeriesCodes = this.getValidSeriesCodesForType(invoiceType)

    // Clear all options
    this.seriesSelectTarget.innerHTML = ''

    // Add blank option first
    const blankOption = document.createElement('option')
    blankOption.value = ''
    blankOption.text = 'Select invoice series'
    this.seriesSelectTarget.appendChild(blankOption)

    // Add filtered valid series options
    const validOptions = this.allSeriesValue.filter(seriesOption =>
      seriesOption.value !== '' && validSeriesCodes.includes(seriesOption.seriesCode)
    )

    validOptions.forEach(seriesOption => {
      const option = document.createElement('option')
      option.value = seriesOption.value
      option.text = seriesOption.text
      this.seriesSelectTarget.appendChild(option)
    })

    // Auto-select if there's only one valid option
    if (validOptions.length === 1) {
      this.seriesSelectTarget.value = validOptions[0].value
      // Trigger change event to update invoice number
      this.seriesSelectTarget.dispatchEvent(new Event('change'))
    }
  }

  getValidSeriesCodesForType(invoiceType) {
    // Map invoice types to their corresponding series codes
    const typeToSeriesMapping = {
      'invoice': ['FC'], // Regular invoices use FC (Factura Comercial)
      'proforma': ['PF'], // Proforma invoices use PF (Proforma)
      'credit_note': ['CR'], // Credit notes use CR (Nota de Crédito)
      'debit_note': ['DB'] // Debit notes use DB (Nota de Débito)
    }

    return typeToSeriesMapping[invoiceType] || ['FC'] // Default to FC if type is unknown
  }

  // Tax Context Methods

  onEstablishmentChange(event) {
    const establishmentId = event.target.value

    if (!establishmentId) {
      this.clearTaxJurisdiction()
      return
    }

    this.updateTaxJurisdictionDisplay(establishmentId)

    if (this.hasAutoTaxCalculateTarget && this.autoTaxCalculateTarget.checked) {
      this.calculateTaxContext()
    }
  }

  updateTaxJurisdictionDisplay(establishmentId) {
    // Find the establishment data from company establishments
    const establishment = this.getEstablishmentById(establishmentId)

    if (establishment && establishment.tax_jurisdiction) {
      const jurisdiction = establishment.tax_jurisdiction
      const jurisdictionText = `${jurisdiction.country_name} (${jurisdiction.code})`

      if (this.hasTaxJurisdictionTarget) {
        this.taxJurisdictionTarget.innerHTML = `
          <div class="flex items-center">
            <div class="flex-1">
              <div class="font-medium text-gray-900">${jurisdictionText}</div>
              <div class="text-xs text-gray-500">${jurisdiction.regime_type || 'Standard'} Tax Regime</div>
            </div>
            <div class="ml-2">
              ${jurisdiction.is_eu ?
                '<span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">EU</span>' :
                '<span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-800">Non-EU</span>'
              }
            </div>
          </div>
        `
      }
    } else {
      this.clearTaxJurisdiction()
    }
  }

  clearTaxJurisdiction() {
    if (this.hasTaxJurisdictionTarget) {
      this.taxJurisdictionTarget.innerHTML = `
        <div class="text-sm text-gray-500">Select an establishment to see tax jurisdiction</div>
      `
    }
  }

  getEstablishmentById(establishmentId) {
    // This would typically come from a data attribute or API call
    // For now, we'll make an API call to get establishment details
    const establishments = this.companyEstablishmentsValue || []
    return establishments.find(est => est.id.toString() === establishmentId.toString())
  }

  toggleBuyerLocation(event) {
    event.preventDefault()

    if (this.hasBuyerLocationFieldsTarget) {
      const isHidden = this.buyerLocationFieldsTarget.classList.contains('hidden')

      if (isHidden) {
        this.buyerLocationFieldsTarget.classList.remove('hidden')
        this.buyerLocationToggleTarget.innerHTML = `
          <svg class="w-3 h-3 mr-1" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
          Cancel
        `
      } else {
        this.buyerLocationFieldsTarget.classList.add('hidden')
        this.buyerLocationToggleTarget.innerHTML = `
          <svg class="w-3 h-3 mr-1" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
          </svg>
          Override
        `
        // Clear override fields
        const countrySelect = document.querySelector('select[name="invoice[buyer_country_override]"]')
        const cityInput = document.querySelector('input[name="invoice[buyer_city_override]"]')
        if (countrySelect) countrySelect.value = ''
        if (cityInput) cityInput.value = ''
      }
    }
  }

  onBuyerLocationChange() {
    if (this.hasAutoTaxCalculateTarget && this.autoTaxCalculateTarget.checked) {
      this.calculateTaxContext()
    }
  }

  async calculateTaxContext(event) {
    if (event) event.preventDefault()

    try {
      // Clear previous errors
      this.clearValidationErrors()

      // Validate tax context fields before making API call
      const validationErrors = this.validateTaxContextFields()
      if (validationErrors.length > 0) {
        this.displayValidationErrors(validationErrors)
        return
      }

      this.showTaxCalculationLoading()

      const taxContextData = await this.resolveTaxContext()

      if (taxContextData && taxContextData.tax_context) {
        this.updateTaxContextDisplay(taxContextData.tax_context)
        this.storeTaxContextData(taxContextData.tax_context)
        this.showTaxCalculationSuccess()

        // Log tax context resolution for debugging
        console.log('Tax context resolved successfully:', {
          establishment: taxContextData.establishment?.name,
          cross_border: taxContextData.tax_context.cross_border,
          eu_transaction: taxContextData.tax_context.eu_transaction,
          reverse_charge: taxContextData.tax_context.reverse_charge
        })
      } else {
        this.showTaxCalculationError('Unable to resolve tax context - invalid response format')
      }

    } catch (error) {
      console.error('Tax context calculation error:', error)

      // Display user-friendly error messages
      const errorMessage = error.message || 'Error calculating tax context'
      this.showTaxCalculationError(errorMessage)

      // Log detailed error for debugging
      console.error('Detailed error:', {
        message: error.message,
        stack: error.stack,
        timestamp: new Date().toISOString()
      })
    }
  }

  async resolveTaxContext() {
    const establishmentId = this.hasEstablishmentSelectTarget ? this.establishmentSelectTarget.value : null

    // Validate establishment is selected
    if (!establishmentId) {
      throw new Error('Please select a company establishment for tax calculation')
    }

    const buyerCountry = document.querySelector('select[name="invoice[buyer_country_override]"]')?.value
    const buyerCity = document.querySelector('input[name="invoice[buyer_city_override]"]')?.value

    // Prepare buyer location data
    let buyerLocation = null
    if (buyerCountry || buyerCity) {
      // Validate country code format
      if (buyerCountry && buyerCountry.length !== 3) {
        throw new Error('Invalid country code format. Expected 3-letter code (e.g., ESP, FRA)')
      }

      buyerLocation = {
        country: buyerCountry,
        city: buyerCity
      }
    }

    // Get product types from line items with validation
    const productTypes = this.extractProductTypesFromLines()

    const requestData = {
      establishment_id: establishmentId,
      buyer_location: buyerLocation,
      product_types: productTypes
    }

    // Get CSRF token for Rails
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')

    if (!csrfToken) {
      throw new Error('CSRF token not found. Please refresh the page and try again.')
    }

    try {
      const controller = new AbortController()
      const timeoutId = setTimeout(() => controller.abort(), 15000) // 15 second timeout

      const response = await fetch('/api/v1/tax/resolve_context', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': csrfToken,
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify(requestData),
        signal: controller.signal
      })

      clearTimeout(timeoutId)

      if (!response.ok) {
        let errorMessage = `Tax calculation failed (${response.status})`

        try {
          const errorData = await response.json()
          if (errorData.errors && errorData.errors.length > 0) {
            errorMessage = errorData.errors[0].detail || errorData.errors[0].title || errorMessage
          } else if (errorData.error) {
            errorMessage = errorData.error
          }
        } catch (parseError) {
          // Use default error message if JSON parsing fails
        }

        throw new Error(errorMessage)
      }

      const data = await response.json()

      // Validate response structure
      if (!data || !data.data || !data.data.attributes) {
        throw new Error('Invalid response format from tax service')
      }

      return data.data.attributes

    } catch (error) {
      if (error.name === 'AbortError') {
        throw new Error('Tax calculation request timed out. Please check your connection and try again.')
      }
      throw error
    }
  }

  extractProductTypesFromLines() {
    const productTypes = new Set(['goods']) // Default

    // Extract product types from line items
    const lineItems = document.querySelectorAll('[data-line-index]')

    lineItems.forEach(lineItem => {
      const description = lineItem.querySelector('[name*="[description]"]')?.value || ''
      const productCode = lineItem.querySelector('[name*="[product_code]"]')?.value || ''

      // Simple classification based on keywords
      const combinedText = `${description} ${productCode}`.toLowerCase()

      if (combinedText.includes('service') || combinedText.includes('consulting') ||
          combinedText.includes('support') || combinedText.includes('maintenance')) {
        productTypes.add('services')
      }

      if (combinedText.includes('digital') || combinedText.includes('software') ||
          combinedText.includes('license') || combinedText.includes('subscription')) {
        productTypes.add('digital_services')
      }

      if (combinedText.includes('training') || combinedText.includes('education') ||
          combinedText.includes('course')) {
        productTypes.add('education')
      }
    })

    return Array.from(productTypes)
  }

  // Tax-specific validation methods
  validateTaxContextFields() {
    const errors = []

    // Validate establishment selection for tax calculations
    if (this.hasAutoTaxCalculateTarget && this.autoTaxCalculateTarget.checked) {
      const establishmentId = this.hasEstablishmentSelectTarget ? this.establishmentSelectTarget.value : null

      if (!establishmentId) {
        errors.push({
          field: 'establishment_id',
          message: 'Company establishment is required for automatic tax calculations',
          element: this.establishmentSelectTarget
        })
      }
    }

    // Validate buyer location override fields
    const buyerCountry = document.querySelector('select[name="invoice[buyer_country_override]"]')?.value
    const buyerCity = document.querySelector('input[name="invoice[buyer_city_override]"]')?.value

    if (buyerCountry || buyerCity) {
      if (buyerCountry && buyerCountry.length !== 3) {
        errors.push({
          field: 'buyer_country_override',
          message: 'Invalid country code. Use 3-letter format (ESP, FRA, DEU)',
          element: document.querySelector('select[name="invoice[buyer_country_override]"]')
        })
      }

      if (buyerCity && buyerCity.trim().length === 0) {
        errors.push({
          field: 'buyer_city_override',
          message: 'City cannot be empty when country is specified',
          element: document.querySelector('input[name="invoice[buyer_city_override]"]')
        })
      }
    }

    // Validate line items for tax calculation
    const lineItems = document.querySelectorAll('[data-line-index]')
    let hasValidLines = false

    lineItems.forEach((lineItem, index) => {
      const description = lineItem.querySelector('[name*="[description]"]')?.value?.trim()
      const quantity = parseFloat(lineItem.querySelector('[name*="[quantity]"]')?.value || 0)
      const unitPrice = parseFloat(lineItem.querySelector('[name*="[unit_price]"]')?.value || 0)
      const taxRate = parseFloat(lineItem.querySelector('[name*="[tax_rate]"]')?.value || 0)

      if (description && quantity > 0 && unitPrice > 0) {
        hasValidLines = true

        // Validate tax rate range
        if (taxRate < 0 || taxRate > 100) {
          errors.push({
            field: `invoice_lines[${index}][tax_rate]`,
            message: `Tax rate must be between 0% and 100% (Line ${index + 1})`,
            element: lineItem.querySelector('[name*="[tax_rate]"]')
          })
        }

        // Validate discount percentage
        const discountPercentage = parseFloat(lineItem.querySelector('[name*="[discount_percentage]"]')?.value || 0)
        if (discountPercentage < 0 || discountPercentage > 100) {
          errors.push({
            field: `invoice_lines[${index}][discount_percentage]`,
            message: `Discount must be between 0% and 100% (Line ${index + 1})`,
            element: lineItem.querySelector('[name*="[discount_percentage]"]')
          })
        }
      }
    })

    if (!hasValidLines && this.hasAutoTaxCalculateTarget && this.autoTaxCalculateTarget.checked) {
      errors.push({
        field: 'invoice_lines',
        message: 'At least one valid line item is required for tax calculations',
        element: document.querySelector('[data-invoice-form-target="lineItems"]')
      })
    }

    return errors
  }

  displayValidationErrors(errors) {
    // Clear previous error displays
    this.clearValidationErrors()

    if (errors.length === 0) return

    // Display errors near their fields
    errors.forEach(error => {
      if (error.element) {
        this.addFieldError(error.element, error.message)
      }
    })

    // Show summary error message
    const errorMessages = errors.map(e => e.message).join(', ')
    this.showTaxCalculationError(`Validation failed: ${errorMessages}`)
  }

  addFieldError(element, message) {
    // Remove existing error for this field
    const existingError = element.parentNode.querySelector('.tax-field-error')
    if (existingError) {
      existingError.remove()
    }

    // Add error styling to field
    element.classList.add('border-red-500', 'focus:border-red-500', 'focus:ring-red-500')

    // Add error message
    const errorDiv = document.createElement('div')
    errorDiv.className = 'tax-field-error mt-1 text-sm text-red-600'
    errorDiv.textContent = message
    element.parentNode.appendChild(errorDiv)
  }

  clearValidationErrors() {
    // Remove error styling from all tax-related fields
    const errorFields = document.querySelectorAll('.border-red-500')
    errorFields.forEach(field => {
      field.classList.remove('border-red-500', 'focus:border-red-500', 'focus:ring-red-500')
    })

    // Remove all error messages
    const errorMessages = document.querySelectorAll('.tax-field-error')
    errorMessages.forEach(error => error.remove())
  }

  // Performance optimization methods

  // Debounced tax context calculation
  onEstablishmentChangeDebounced(event) {
    const establishmentId = event.target.value

    // Clear existing timer
    if (this.debounceTimers.has('establishment')) {
      clearTimeout(this.debounceTimers.get('establishment'))
    }

    // Set new debounced timer
    const timerId = setTimeout(() => {
      this.onEstablishmentChange(event)
      this.debounceTimers.delete('establishment')
    }, 300) // 300ms debounce

    this.debounceTimers.set('establishment', timerId)
  }

  // Cached establishment loading
  async loadEstablishmentWithCache(establishmentId) {
    if (this.establishmentCache.has(establishmentId)) {
      return this.establishmentCache.get(establishmentId)
    }

    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')

      const response = await fetch(`/api/v1/company_establishments?establishment_id=${establishmentId}`, {
        headers: {
          'X-CSRF-Token': csrfToken,
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        }
      })

      if (response.ok) {
        const data = await response.json()
        const establishment = data.establishments?.find(est => est.id.toString() === establishmentId.toString())

        if (establishment) {
          // Cache for 5 minutes
          this.establishmentCache.set(establishmentId, establishment)
          setTimeout(() => this.establishmentCache.delete(establishmentId), 5 * 60 * 1000)
          return establishment
        }
      }
    } catch (error) {
      console.warn('Failed to load establishment from API:', error)
    }

    return null
  }

  // Create signature for tax calculation request to avoid duplicate calls
  createTaxCalculationSignature() {
    const establishmentId = this.hasEstablishmentSelectTarget ? this.establishmentSelectTarget.value : null
    const buyerCountry = document.querySelector('select[name="invoice[buyer_country_override]"]')?.value || ''
    const buyerCity = document.querySelector('input[name="invoice[buyer_city_override]"]')?.value || ''
    const productTypes = this.extractProductTypesFromLines()

    return JSON.stringify({
      establishmentId,
      buyerCountry,
      buyerCity,
      productTypes: productTypes.sort()
    })
  }

  // Cache cleanup on disconnect
  disconnect() {
    // Clear all caches
    this.taxContextCache.clear()
    this.establishmentCache.clear()
    this.requestCache.clear()

    // Clear timers
    this.debounceTimers.forEach(timerId => clearTimeout(timerId))
    this.debounceTimers.clear()
  }

  updateTaxContextDisplay(taxContextData) {
    // Update tax context details
    if (this.hasTransactionTypeTarget) {
      const transactionType = taxContextData.cross_border ?
        (taxContextData.eu_transaction ? 'Intra-EU' : 'International') : 'Domestic'
      this.transactionTypeTarget.textContent = transactionType
    }

    if (this.hasCrossBorderTarget) {
      this.crossBorderTarget.textContent = taxContextData.cross_border ? 'Yes' : 'No'
    }

    if (this.hasEuTransactionTarget) {
      this.euTransactionTarget.textContent = taxContextData.eu_transaction ? 'Yes' : 'No'
    }

    if (this.hasReverseChargeTarget) {
      this.reverseChargeTarget.textContent = taxContextData.reverse_charge ? 'Required' : 'Not required'
    }

    // Show tax context details
    if (this.hasTaxContextDetailsTarget) {
      this.taxContextDetailsTarget.classList.remove('hidden')
    }
  }

  storeTaxContextData(taxContextData) {
    // Store tax context data in hidden fields
    if (this.hasTaxContextEstablishmentIdTarget) {
      this.taxContextEstablishmentIdTarget.value = taxContextData.establishment?.id || ''
    }

    if (this.hasTaxContextCrossBorderTarget) {
      this.taxContextCrossBorderTarget.value = taxContextData.cross_border || false
    }

    if (this.hasTaxContextEuTransactionTarget) {
      this.taxContextEuTransactionTarget.value = taxContextData.eu_transaction || false
    }

    if (this.hasTaxContextReverseChargeTarget) {
      this.taxContextReverseChargeTarget.value = taxContextData.reverse_charge || false
    }

    // Store full tax context data
    this.taxContextDataValue = taxContextData
  }

  showTaxCalculationLoading() {
    if (this.hasTaxContextStatusTarget) {
      this.taxContextStatusTarget.textContent = 'Calculating tax context...'
    }

    if (this.hasTaxContextIndicatorTarget) {
      this.taxContextIndicatorTarget.innerHTML = `
        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
          <svg class="animate-spin -ml-1 mr-1.5 h-3 w-3 text-yellow-800" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          Calculating
        </span>
      `
    }

    if (this.hasCalculateTaxButtonTarget) {
      this.calculateTaxButtonTarget.disabled = true
    }
  }

  showTaxCalculationSuccess() {
    if (this.hasTaxContextStatusTarget) {
      this.taxContextStatusTarget.textContent = 'Tax context calculated successfully'
    }

    if (this.hasTaxContextIndicatorTarget) {
      this.taxContextIndicatorTarget.innerHTML = `
        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
          <svg class="-ml-1 mr-1.5 h-3 w-3 text-green-800" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
          </svg>
          Calculated
        </span>
      `
    }

    if (this.hasCalculateTaxButtonTarget) {
      this.calculateTaxButtonTarget.disabled = false
    }
  }

  showTaxCalculationError(message) {
    if (this.hasTaxContextStatusTarget) {
      this.taxContextStatusTarget.textContent = message
    }

    if (this.hasTaxContextIndicatorTarget) {
      this.taxContextIndicatorTarget.innerHTML = `
        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
          <svg class="-ml-1 mr-1.5 h-3 w-3 text-red-800" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
          </svg>
          Error
        </span>
      `
    }

    if (this.hasCalculateTaxButtonTarget) {
      this.calculateTaxButtonTarget.disabled = false
    }
  }

  async refreshTaxContext(event) {
    if (event) event.preventDefault()

    // Refresh company establishments and recalculate tax context
    try {
      await this.loadCompanyEstablishments()

      if (this.hasEstablishmentSelectTarget && this.establishmentSelectTarget.value) {
        this.onEstablishmentChange({ target: this.establishmentSelectTarget })
      }

    } catch (error) {
      console.error('Error refreshing tax context:', error)
    }
  }

  async loadCompanyEstablishments() {
    // Get CSRF token for Rails
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')

    const response = await fetch('/api/v1/company_establishments', {
      headers: {
        'X-CSRF-Token': csrfToken,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }
    })

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`)
    }

    const data = await response.json()
    this.companyEstablishmentsValue = data.establishments || []
  }
}