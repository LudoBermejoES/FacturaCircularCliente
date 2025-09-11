import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["lineItems", "lineItemTemplate", "subtotal", "tax", "total", "addButton"]
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

  updateCompany(event) {
    const companyId = event.target.value
    if (!companyId) return
    
    // Here you could fetch company details and update payment terms, etc.
    // For now, we'll just log it
    console.log('Company selected:', companyId)
  }
}