import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["companyName"]
  
  confirm(event) {
    // Get the company name from the row's company name link
    const row = event.target.closest('tr')
    const companyNameLink = row.querySelector('a[href*="/companies/"]')
    const companyName = companyNameLink ? companyNameLink.textContent.trim() : 'this company'
    
    // Show custom confirmation dialog
    const confirmed = confirm(`Switch to ${companyName}?`)
    
    if (!confirmed) {
      event.preventDefault()
      return false
    }
    
    return true
  }
}