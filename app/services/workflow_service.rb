class WorkflowService < ApiService
  def self.history(invoice_id, token:)
    get("/invoices/#{invoice_id}/workflow_history", token: token)
  end
  
  def self.available_transitions(invoice_id, token:)
    get("/invoices/#{invoice_id}/available_transitions", token: token)
  end
  
  def self.transition(invoice_id, status:, comment: nil, token:)
    body = {
      status: status,
      comment: comment
    }.compact
    
    patch("/invoices/#{invoice_id}/status", body: body, token: token)
  end
  
  def self.bulk_transition(invoice_ids:, status:, comment: nil, token:)
    body = {
      invoice_ids: invoice_ids,
      status: status,
      comment: comment
    }.compact
    
    post("/invoices/bulk_status", body: body, token: token)
  end
  
  def self.rules(token:)
    get("/workflow_rules", token: token)
  end
  
  def self.create_rule(params, token:)
    post("/workflow_rules", body: params, token: token)
  end
  
  def self.update_rule(id, params, token:)
    put("/workflow_rules/#{id}", body: params, token: token)
  end
  
  def self.delete_rule(id, token:)
    delete("/workflow_rules/#{id}", token: token)
  end
  
  def self.templates(token:)
    get("/workflow_templates", token: token)
  end
  
  def self.create_template(params, token:)
    post("/workflow_templates", body: params, token: token)
  end
  
  def self.apply_template(invoice_id, template_id, token:)
    post("/invoices/#{invoice_id}/apply_workflow_template", 
         body: { template_id: template_id }, 
         token: token)
  end
end