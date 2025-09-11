import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "baseAmount", "taxRate", "discount",
    "baseResult", "discountResult", "subtotalResult", 
    "taxResult", "totalResult", "taxRateLabel"
  ]
  
  connect() {
    this.calculate()
  }
  
  calculate() {
    const baseAmount = parseFloat(this.baseAmountTarget.value) || 0
    const taxRate = parseFloat(this.taxRateTarget.value) || 0
    const discountPercentage = parseFloat(this.discountTarget.value) || 0
    
    // Calculate discount amount
    const discountAmount = baseAmount * (discountPercentage / 100)
    
    // Calculate subtotal (base - discount)
    const subtotal = baseAmount - discountAmount
    
    // Calculate tax on subtotal
    const taxAmount = subtotal * (taxRate / 100)
    
    // Calculate total
    const total = subtotal + taxAmount
    
    // Update display
    this.baseResultTarget.textContent = this.formatCurrency(baseAmount)
    this.discountResultTarget.textContent = `-${this.formatCurrency(discountAmount)}`
    this.subtotalResultTarget.textContent = this.formatCurrency(subtotal)
    this.taxResultTarget.textContent = this.formatCurrency(taxAmount)
    this.totalResultTarget.textContent = this.formatCurrency(total)
    this.taxRateLabelTarget.textContent = `${taxRate}%`
    
    // Update colors based on amounts
    if (discountAmount > 0) {
      this.discountResultTarget.classList.add("text-red-600")
    } else {
      this.discountResultTarget.classList.remove("text-red-600")
    }
  }
  
  formatCurrency(amount) {
    return new Intl.NumberFormat('es-ES', {
      style: 'currency',
      currency: 'EUR',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(amount)
  }
}