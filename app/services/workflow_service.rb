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
      data: {
        attributes: {
          status: status,
          comment: comment
        }.compact
      }
    }

    patch("/invoices/#{invoice_id}/status", body: body, token: token)
  end

  def self.definitions(token:)
    get('/workflow_definitions', token: token)
  end

  def self.definition(definition_id, token:)
    get("/workflow_definitions/#{definition_id}", token: token)
  end

  def self.create_definition(params, token:)
    body = {
      data: {
        attributes: params
      }
    }
    result = post('/workflow_definitions', body: body, token: token)
    Rails.logger.info "DEBUG: WorkflowService.create_definition returned: #{result.inspect}"
    result
  end

  def self.update_definition(definition_id, params, token:)
    body = {
      data: {
        attributes: params
      }
    }
    put("/workflow_definitions/#{definition_id}", body: body, token: token)
  end

  def self.delete_definition(definition_id, token:)
    delete("/workflow_definitions/#{definition_id}", token: token)
  end

  def self.definition_states(definition_id, token:)
    get("/workflow_definitions/#{definition_id}/states", token: token)
  end

  def self.definition_transitions(definition_id, token:)
    get("/workflow_definitions/#{definition_id}/transitions", token: token)
  end

  def self.bulk_transition(invoice_ids, status:, comment: nil, token:)
    body = {
      invoice_ids: invoice_ids,
      status: status,
      comment: comment
    }.compact

    post("/invoices/bulk_transition", body: body, token: token)
  end

  # Workflow States CRUD - Fixed URLs to match backend implementation
  def self.state(definition_id, state_id, token:)
    get("/workflow_definitions/#{definition_id}/states/#{state_id}", token: token)
  end

  def self.create_state(definition_id, params, token:)
    body = { workflow_state: params }
    post("/workflow_definitions/#{definition_id}/states", body: body, token: token)
  end

  def self.update_state(definition_id, state_id, params, token:)
    body = { workflow_state: params }
    put("/workflow_definitions/#{definition_id}/states/#{state_id}", body: body, token: token)
  end

  def self.delete_state(definition_id, state_id, token:)
    delete("/workflow_definitions/#{definition_id}/states/#{state_id}", token: token)
  end

  # Workflow Transitions CRUD - Fixed URLs and method naming
  def self.get_transition(definition_id, transition_id, token:)
    get("/workflow_definitions/#{definition_id}/transitions/#{transition_id}", token: token)
  end

  def self.create_transition(definition_id, params, token:)
    body = { workflow_transition: params }
    post("/workflow_definitions/#{definition_id}/transitions", body: body, token: token)
  end

  def self.update_transition(definition_id, transition_id, params, token:)
    body = { workflow_transition: params }
    put("/workflow_definitions/#{definition_id}/transitions/#{transition_id}", body: body, token: token)
  end

  def self.delete_transition(definition_id, transition_id, token:)
    delete("/workflow_definitions/#{definition_id}/transitions/#{transition_id}", token: token)
  end

  # Note: The following methods were removed as they don't exist in the API:
  # - rules, create_rule, update_rule, delete_rule (workflow rules CRUD)
  # - templates, create_template, apply_template (workflow templates)
  #
  # The API uses workflow_definitions instead of rules/templates.
end