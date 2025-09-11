class WorkflowService < ApiService
  # Workflow endpoints that actually exist in the API
  
  def self.history(token:, params: {})
    get('/workflow_history', token: token, params: params)
  end
  
  def self.available_transitions(invoice_id, token:)
    get("/invoices/#{invoice_id}/workflow/available_transitions", token: token)
  end
  
  def self.transition(invoice_id, status:, comment: nil, token:)
    body = {
      status: status,
      comment: comment
    }.compact
    
    patch("/invoices/#{invoice_id}/status", body: body, token: token)
  end
  
  def self.definitions(token:)
    get('/workflow_definitions', token: token)
  end
  
  def self.definition_states(definition_id, token:)
    get("/workflow_definitions/#{definition_id}/states", token: token)
  end
  
  def self.definition_transitions(definition_id, token:)
    get("/workflow_definitions/#{definition_id}/transitions", token: token)
  end
  
  # Note: The following methods were removed as they don't exist in the API:
  # - bulk_transition (bulk status updates)
  # - rules, create_rule, update_rule, delete_rule (workflow rules CRUD)
  # - templates, create_template, apply_template (workflow templates)
  # 
  # The API uses workflow_definitions instead of rules/templates.
  # Bulk operations are not supported by the API.
end