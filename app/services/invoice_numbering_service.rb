class InvoiceNumberingService < ApiService
  class << self
    # Get next available invoice numbers for a given year and series type
    def next_available(token:, year:, series_type:)
      params = {
        year: year,
        series_type: series_type
      }
      
      response = get('/invoice_numbering/next_available', token: token, params: params)
      response.dig(:data, :attributes) || {}
    end
    
    # Assign a number to an invoice
    def assign(token:, invoice_id:, series_code:, year:)
      body = {
        data: {
          type: 'invoice_numbering_assignment',
          attributes: {
            invoice_id: invoice_id,
            series_code: series_code,
            year: year
          }
        }
      }
      
      response = post('/invoice_numbering/assign', token: token, body: body)
      response[:data]
    end
    
    # Get assignment history for an invoice
    def assignment_history(token:, invoice_id:)
      params = { invoice_id: invoice_id }
      response = get('/invoice_numbering/assignment_history', token: token, params: params)
      response.dig(:data) || []
    end
    
    # Unassign a number from an invoice
    def unassign(token:, invoice_id:, reason:)
      body = {
        data: {
          type: 'invoice_numbering_unassignment',
          attributes: {
            invoice_id: invoice_id,
            reason: reason
          }
        }
      }
      
      response = post('/invoice_numbering/unassign', token: token, body: body)
      response[:data]
    end
    
    # Reserve a number temporarily
    def reserve(token:, series_code:, year:, reserved_for_minutes: 15)
      body = {
        data: {
          type: 'invoice_numbering_reservation',
          attributes: {
            series_code: series_code,
            year: year,
            reserved_for_minutes: reserved_for_minutes
          }
        }
      }
      
      response = post('/invoice_numbering/reserve', token: token, body: body)
      response[:data]
    end
  end
end