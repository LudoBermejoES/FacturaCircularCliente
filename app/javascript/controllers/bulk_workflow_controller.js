import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="bulk-workflow"
export default class extends Controller {
  static targets = ["selectAll", "invoiceCheckbox", "bulkActions", "selectedCount", "statusSelect", "commentField"]

  connect() {
    this.updateBulkActions()
  }

  toggleAll() {
    const isChecked = this.selectAllTarget.checked
    this.invoiceCheckboxTargets.forEach(checkbox => {
      checkbox.checked = isChecked
    })
    this.updateBulkActions()
  }

  toggleInvoice() {
    const checkedCount = this.getSelectedInvoices().length
    const totalCount = this.invoiceCheckboxTargets.length

    // Update select all checkbox state
    if (checkedCount === 0) {
      this.selectAllTarget.checked = false
      this.selectAllTarget.indeterminate = false
    } else if (checkedCount === totalCount) {
      this.selectAllTarget.checked = true
      this.selectAllTarget.indeterminate = false
    } else {
      this.selectAllTarget.checked = false
      this.selectAllTarget.indeterminate = true
    }

    this.updateBulkActions()
  }

  updateBulkActions() {
    const selectedInvoices = this.getSelectedInvoices()
    const count = selectedInvoices.length

    if (count > 0) {
      this.bulkActionsTarget.classList.remove('hidden')
      this.selectedCountTarget.textContent = count
    } else {
      this.bulkActionsTarget.classList.add('hidden')
    }
  }

  getSelectedInvoices() {
    return this.invoiceCheckboxTargets.filter(checkbox => checkbox.checked)
  }

  showBulkModal() {
    const selectedInvoices = this.getSelectedInvoices()
    if (selectedInvoices.length === 0) {
      alert('Please select at least one invoice')
      return
    }

    // Show the bulk transition modal
    const modal = document.getElementById('bulk-workflow-modal')
    if (modal) {
      modal.classList.remove('hidden')

      // Focus on status select
      if (this.hasStatusSelectTarget) {
        this.statusSelectTarget.focus()
      }
    }
  }

  hideBulkModal() {
    const modal = document.getElementById('bulk-workflow-modal')
    if (modal) {
      modal.classList.add('hidden')

      // Reset form
      if (this.hasStatusSelectTarget) {
        this.statusSelectTarget.value = ''
      }
      if (this.hasCommentFieldTarget) {
        this.commentFieldTarget.value = ''
      }
    }
  }

  submitBulkTransition(event) {
    event.preventDefault()

    const selectedInvoices = this.getSelectedInvoices()
    const status = this.hasStatusSelectTarget ? this.statusSelectTarget.value : ''
    const comment = this.hasCommentFieldTarget ? this.commentFieldTarget.value : ''

    if (selectedInvoices.length === 0) {
      alert('Please select at least one invoice')
      return
    }

    if (!status) {
      alert('Please select a status')
      return
    }

    // Create form data
    const formData = new FormData()

    selectedInvoices.forEach(checkbox => {
      formData.append('invoice_ids[]', checkbox.value)
    })

    formData.append('status', status)
    if (comment) {
      formData.append('comment', comment)
    }

    // Add CSRF token
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
    if (csrfToken) {
      formData.append('authenticity_token', csrfToken)
    }

    // Submit the form
    const form = event.target.closest('form')
    if (form) {
      // Show loading state
      const submitButton = form.querySelector('button[type="submit"]')
      if (submitButton) {
        submitButton.disabled = true
        submitButton.innerHTML = `
          <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          Processing...
        `
      }

      fetch(form.action, {
        method: 'POST',
        body: formData,
        headers: {
          'X-Requested-With': 'XMLHttpRequest'
        }
      }).then(response => {
        if (response.ok) {
          window.location.reload()
        } else {
          throw new Error('Request failed')
        }
      }).catch(error => {
        console.error('Bulk transition failed:', error)
        alert('Failed to update invoices. Please try again.')

        // Reset button state
        if (submitButton) {
          submitButton.disabled = false
          submitButton.innerHTML = 'Update Invoices'
        }
      })
    }
  }

  // Handle escape key to close modal
  handleKeydown(event) {
    if (event.key === 'Escape') {
      this.hideBulkModal()
    }
  }
}