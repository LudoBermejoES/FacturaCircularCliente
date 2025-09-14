import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["lineItems", "lineItemTemplate", "subtotal", "tax", "total", "addButton", "seriesSelect", "invoiceNumber", "contactField", "contactSelect"]
  static values = { 
    lineIndex: Number,
    taxRate: { type: Number, default: 21 }
  }

  connect() {
    this.lineIndexValue = this.lineItemsTarget.querySelectorAll('.line-item').length
    if (this.lineIndexValue === 0) {
      this.addLineItem()
    }
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
    
    const total = subtotal + totalTax
    
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
}