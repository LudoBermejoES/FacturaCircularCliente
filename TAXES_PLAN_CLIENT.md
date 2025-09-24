# Tax System Modernization - Client Implementation Plan

## Overview
This document outlines the client-side implementation plan for the multi-jurisdiction tax system modernization supporting Spain, Portugal, Poland, and Mexico. The client application must be updated to work with the new API endpoints and provide user interfaces for managing tax jurisdictions, establishments, and enhanced tax calculations.

## Phase 1: Service Layer Updates

### 1.1 New Service Classes

#### TaxJurisdictionsService
```ruby
class TaxJurisdictionsService < ApiService
  class << self
    def all(token:, params: {})
      response = get("/tax_jurisdictions", token: token, params: params)
      transform_tax_jurisdictions_response(response)
    end

    def find(id:, token:)
      response = get("/tax_jurisdictions/#{id}", token: token)
      transform_tax_jurisdiction_response(response)
    end

    def rates(jurisdiction_id:, token:, params: {})
      response = get("/tax_jurisdictions/#{jurisdiction_id}/tax_rates", token: token, params: params)
      transform_tax_rates_response(response)
    end

    private

    def transform_tax_jurisdictions_response(response)
      jurisdictions = []
      if response[:data].is_a?(Array)
        jurisdictions = response[:data].map do |jurisdiction_data|
          transform_jurisdiction_attributes(jurisdiction_data)
        end
      end
      { jurisdictions: jurisdictions, meta: response[:meta] }
    end

    def transform_jurisdiction_attributes(jurisdiction_data)
      attributes = jurisdiction_data[:attributes] || {}
      {
        id: jurisdiction_data[:id].to_i,
        name: attributes[:name],
        code: attributes[:code],
        country_code: attributes[:country_code],
        currency_code: attributes[:currency_code],
        is_active: attributes[:is_active],
        settings: attributes[:settings] || {}
      }
    end
  end
end
```

#### CompanyEstablishmentsService
```ruby
class CompanyEstablishmentsService < ApiService
  class << self
    def all(company_id:, token:, params: {})
      response = get("/companies/#{company_id}/establishments", token: token, params: params)
      transform_establishments_response(response)
    end

    def find(company_id:, id:, token:)
      response = get("/companies/#{company_id}/establishments/#{id}", token: token)
      transform_establishment_response(response)
    end

    def create(company_id:, params:, token:)
      api_params = map_establishment_params(params)
      request_body = {
        data: {
          type: 'company_establishments',
          attributes: api_params
        }
      }
      post("/companies/#{company_id}/establishments", token: token, body: request_body)
    end

    def update(company_id:, id:, params:, token:)
      api_params = map_establishment_params(params)
      put("/companies/#{company_id}/establishments/#{id}", token: token, body: {
        data: {
          type: 'company_establishments',
          attributes: api_params
        }
      })
    end

    def destroy(company_id:, id:, token:)
      delete("/companies/#{company_id}/establishments/#{id}", token: token)
    end

    private

    def map_establishment_params(params)
      {
        name: params[:name],
        establishment_type: params[:establishment_type],
        tax_jurisdiction_id: params[:tax_jurisdiction_id],
        street_address: params[:street_address],
        city: params[:city],
        state_province: params[:state_province],
        postal_code: params[:postal_code],
        country_code: params[:country_code],
        is_active: params[:is_active],
        is_headquarters: params[:is_headquarters],
        tax_settings: params[:tax_settings] || {}
      }.compact
    end
  end
end
```

### 1.2 Enhanced Existing Services

#### CompaniesService Updates
```ruby
# Add establishment loading to CompaniesService.find
def find(id, token:)
  response = get("/companies/#{id}", token: token)

  if response[:data]
    company_data = transform_company_attributes(response[:data])

    # Load establishments
    begin
      establishments_response = CompanyEstablishmentsService.all(
        company_id: id,
        token: token
      )
      company_data[:establishments] = establishments_response[:establishments] || []
    rescue => e
      Rails.logger.error "Failed to load company establishments: #{e.message}"
      company_data[:establishments] = []
    end

    company_data
  else
    response
  end
end
```

#### InvoicesService Updates
```ruby
# Enhanced invoice creation with tax context
def create(company_id:, params:, token:)
  # Include tax context information
  api_params = map_invoice_params(params)
  api_params[:tax_jurisdiction_id] = params[:tax_jurisdiction_id] if params[:tax_jurisdiction_id]
  api_params[:establishment_id] = params[:establishment_id] if params[:establishment_id]

  request_body = {
    data: {
      type: 'invoices',
      attributes: api_params,
      relationships: build_invoice_relationships(params)
    }
  }

  post("/companies/#{company_id}/invoices", token: token, body: request_body)
end

# Tax calculation endpoint
def calculate_taxes(company_id:, invoice_data:, token:)
  post("/companies/#{company_id}/invoices/calculate_taxes", token: token, body: {
    data: {
      type: 'tax_calculation',
      attributes: invoice_data
    }
  })
end
```

## Phase 2: Controller Updates

### 2.1 New Controllers

#### TaxJurisdictionsController
```ruby
class TaxJurisdictionsController < ApplicationController
  before_action :authenticate_user!

  def index
    begin
      response = TaxJurisdictionsService.all(token: current_token)
      @jurisdictions = response[:jurisdictions] || []
      @total_count = response[:meta] ? response[:meta][:total] : 0
    rescue ApiService::ApiError => e
      @jurisdictions = []
      flash.now[:alert] = "Error loading tax jurisdictions: #{e.message}"
    end
  end

  def show
    begin
      @jurisdiction = TaxJurisdictionsService.find(id: params[:id], token: current_token)

      # Load tax rates for this jurisdiction
      rates_response = TaxJurisdictionsService.rates(
        jurisdiction_id: params[:id],
        token: current_token
      )
      @tax_rates = rates_response[:tax_rates] || []
    rescue ApiService::ApiError => e
      redirect_to tax_jurisdictions_path, alert: "Tax jurisdiction not found: #{e.message}"
    end
  end
end
```

#### CompanyEstablishmentsController
```ruby
class CompanyEstablishmentsController < ApplicationController
  before_action :set_company
  before_action :set_establishment, only: [:show, :edit, :update, :destroy]

  def index
    begin
      response = CompanyEstablishmentsService.all(
        company_id: @company[:id],
        token: current_token
      )
      @establishments = response[:establishments] || []
    rescue ApiService::ApiError => e
      @establishments = []
      flash.now[:alert] = "Error loading establishments: #{e.message}"
    end
  end

  def new
    @establishment = {
      name: '',
      establishment_type: 'branch',
      tax_jurisdiction_id: nil,
      street_address: '',
      city: '',
      state_province: '',
      postal_code: '',
      country_code: 'ESP',
      is_active: true,
      is_headquarters: false
    }
    load_tax_jurisdictions
  end

  def create
    begin
      CompanyEstablishmentsService.create(
        company_id: @company[:id],
        params: establishment_params,
        token: current_token
      )
      redirect_to company_establishments_path(@company[:id]),
                  notice: 'Establishment was successfully created.'
    rescue ApiService::ValidationError => e
      @establishment = establishment_params
      @errors = e.errors
      load_tax_jurisdictions
      flash.now[:alert] = 'There were errors creating the establishment.'
      render :new, status: :unprocessable_content
    end
  end

  private

  def load_tax_jurisdictions
    begin
      response = TaxJurisdictionsService.all(token: current_token)
      @tax_jurisdictions = response[:jurisdictions] || []
    rescue ApiService::ApiError
      @tax_jurisdictions = []
    end
  end

  def establishment_params
    params.require(:establishment).permit(
      :name, :establishment_type, :tax_jurisdiction_id,
      :street_address, :city, :state_province, :postal_code, :country_code,
      :is_active, :is_headquarters, tax_settings: {}
    )
  end
end
```

### 2.2 Enhanced Invoice Controllers

#### InvoicesController Updates
```ruby
# Enhanced new action with tax context
def new
  @invoice = initialize_new_invoice
  load_invoice_dependencies
  load_tax_context
end

# Enhanced create with tax calculation
def create
  begin
    # Pre-calculate taxes if requested
    if params[:calculate_taxes]
      tax_response = InvoicesService.calculate_taxes(
        company_id: @company[:id],
        invoice_data: invoice_params,
        token: current_token
      )
      @calculated_taxes = tax_response[:data][:attributes] if tax_response[:data]
    end

    response = InvoicesService.create(
      company_id: @company[:id],
      params: invoice_params,
      token: current_token
    )

    redirect_to company_invoice_path(@company[:id], response[:data][:id]),
                notice: 'Invoice was successfully created.'
  rescue ApiService::ValidationError => e
    @invoice = invoice_params
    @errors = e.errors
    load_invoice_dependencies
    load_tax_context
    flash.now[:alert] = 'There were errors creating the invoice.'
    render :new, status: :unprocessable_content
  end
end

private

def load_tax_context
  # Load tax jurisdictions
  begin
    jurisdictions_response = TaxJurisdictionsService.all(token: current_token)
    @tax_jurisdictions = jurisdictions_response[:jurisdictions] || []
  rescue ApiService::ApiError
    @tax_jurisdictions = []
  end

  # Load company establishments
  begin
    establishments_response = CompanyEstablishmentsService.all(
      company_id: @company[:id],
      token: current_token
    )
    @establishments = establishments_response[:establishments] || []
  rescue ApiService::ApiError
    @establishments = []
  end
end

def invoice_params
  params.require(:invoice).permit(
    :invoice_number, :invoice_date, :due_date, :buyer_type, :buyer_id,
    :tax_jurisdiction_id, :establishment_id, :document_type, :status,
    :subtotal, :tax_amount, :total_amount, :currency_code, :exchange_rate,
    :notes, :terms_and_conditions, :payment_method, :bank_account,
    :invoice_series_id,
    invoice_lines_attributes: [
      :id, :line_number, :description, :quantity, :unit_price, :discount_percentage,
      :subtotal, :tax_rate, :tax_amount, :total, :product_code, :unit_of_measure,
      :_destroy
    ]
  )
end
```

## Phase 3: View Updates

### 3.1 Tax Jurisdiction Views

#### app/views/tax_jurisdictions/index.html.erb
```erb
<% content_for :title, "Tax Jurisdictions" %>

<div class="d-flex justify-content-between align-items-center mb-4">
  <h1>Tax Jurisdictions</h1>
</div>

<div class="card">
  <div class="card-body">
    <% if @jurisdictions.any? %>
      <div class="table-responsive">
        <table class="table table-striped">
          <thead>
            <tr>
              <th>Name</th>
              <th>Code</th>
              <th>Country</th>
              <th>Currency</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <% @jurisdictions.each do |jurisdiction| %>
              <tr>
                <td>
                  <%= link_to jurisdiction[:name], tax_jurisdiction_path(jurisdiction[:id]),
                              class: "text-decoration-none" %>
                </td>
                <td><span class="badge bg-secondary"><%= jurisdiction[:code] %></span></td>
                <td>
                  <i class="flag-icon flag-icon-<%= jurisdiction[:country_code].downcase %>"></i>
                  <%= jurisdiction[:country_code] %>
                </td>
                <td><%= jurisdiction[:currency_code] %></td>
                <td>
                  <% if jurisdiction[:is_active] %>
                    <span class="badge bg-success">Active</span>
                  <% else %>
                    <span class="badge bg-secondary">Inactive</span>
                  <% end %>
                </td>
                <td>
                  <%= link_to "View", tax_jurisdiction_path(jurisdiction[:id]),
                              class: "btn btn-sm btn-outline-primary" %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    <% else %>
      <div class="text-center py-5">
        <i class="fas fa-globe fa-3x text-muted mb-3"></i>
        <h5 class="text-muted">No tax jurisdictions found</h5>
      </div>
    <% end %>
  </div>
</div>
```

### 3.2 Company Establishment Views

#### app/views/company_establishments/_form.html.erb
```erb
<%= form_with model: [@company[:id], @establishment],
              url: @establishment[:id] ?
                   company_establishment_path(@company[:id], @establishment[:id]) :
                   company_establishments_path(@company[:id]),
              method: @establishment[:id] ? :patch : :post,
              local: true,
              data: { controller: "establishment-form" } do |form| %>

  <% if @errors.present? %>
    <div class="alert alert-danger">
      <strong>Please correct the following errors:</strong>
      <ul class="mb-0 mt-2">
        <% @errors.each do |error| %>
          <li><%= error %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="row">
    <div class="col-md-6">
      <div class="mb-3">
        <%= form.label :name, class: "form-label required" %>
        <%= form.text_field :name, value: @establishment[:name],
                            class: "form-control", required: true %>
      </div>
    </div>

    <div class="col-md-6">
      <div class="mb-3">
        <%= form.label :establishment_type, class: "form-label required" %>
        <%= form.select :establishment_type,
                        options_for_select([
                          ['Headquarters', 'headquarters'],
                          ['Branch Office', 'branch'],
                          ['Warehouse', 'warehouse'],
                          ['Sales Office', 'sales_office'],
                          ['Manufacturing Plant', 'manufacturing'],
                          ['Service Center', 'service_center']
                        ], @establishment[:establishment_type]),
                        { prompt: 'Select establishment type' },
                        { class: "form-select", required: true } %>
      </div>
    </div>
  </div>

  <div class="mb-3">
    <%= form.label :tax_jurisdiction_id, class: "form-label required" %>
    <%= form.select :tax_jurisdiction_id,
                    options_from_collection_for_select(@tax_jurisdictions, :id, :name, @establishment[:tax_jurisdiction_id]),
                    { prompt: 'Select tax jurisdiction' },
                    { class: "form-select",
                      required: true,
                      data: {
                        controller: "tax-jurisdiction-selector",
                        action: "change->tax-jurisdiction-selector#updateTaxSettings"
                      } } %>
  </div>

  <!-- Address Fields -->
  <div class="row">
    <div class="col-md-12">
      <div class="mb-3">
        <%= form.label :street_address, class: "form-label required" %>
        <%= form.text_area :street_address, value: @establishment[:street_address],
                           class: "form-control", rows: 2, required: true %>
      </div>
    </div>
  </div>

  <div class="row">
    <div class="col-md-4">
      <div class="mb-3">
        <%= form.label :city, class: "form-label required" %>
        <%= form.text_field :city, value: @establishment[:city],
                            class: "form-control", required: true %>
      </div>
    </div>

    <div class="col-md-4">
      <div class="mb-3">
        <%= form.label :state_province, class: "form-label" %>
        <%= form.text_field :state_province, value: @establishment[:state_province],
                            class: "form-control" %>
      </div>
    </div>

    <div class="col-md-4">
      <div class="mb-3">
        <%= form.label :postal_code, class: "form-label required" %>
        <%= form.text_field :postal_code, value: @establishment[:postal_code],
                            class: "form-control", required: true %>
      </div>
    </div>
  </div>

  <div class="mb-3">
    <%= form.label :country_code, class: "form-label required" %>
    <%= form.select :country_code,
                    options_for_select([
                      ['Spain', 'ESP'],
                      ['Portugal', 'PRT'],
                      ['Poland', 'POL'],
                      ['Mexico', 'MEX']
                    ], @establishment[:country_code]),
                    {},
                    { class: "form-select", required: true } %>
  </div>

  <!-- Status Options -->
  <div class="row">
    <div class="col-md-6">
      <div class="mb-3 form-check">
        <%= form.check_box :is_active,
                           { checked: @establishment[:is_active] },
                           { class: "form-check-input" } %>
        <%= form.label :is_active, "Active establishment", class: "form-check-label" %>
      </div>
    </div>

    <div class="col-md-6">
      <div class="mb-3 form-check">
        <%= form.check_box :is_headquarters,
                           { checked: @establishment[:is_headquarters] },
                           { class: "form-check-input" } %>
        <%= form.label :is_headquarters, "Headquarters", class: "form-check-label" %>
      </div>
    </div>
  </div>

  <div class="d-flex justify-content-end gap-2">
    <%= link_to "Cancel", company_establishments_path(@company[:id]),
                class: "btn btn-secondary" %>
    <%= form.submit (@establishment[:id] ? "Update" : "Create") + " Establishment",
                    class: "btn btn-primary" %>
  </div>
<% end %>
```

### 3.3 Enhanced Invoice Forms

#### app/views/invoices/_tax_context_fields.html.erb
```erb
<div class="card mb-4" data-controller="tax-context">
  <div class="card-header">
    <h5 class="card-title mb-0">Tax Context</h5>
    <small class="text-muted">Select tax jurisdiction and establishment for accurate tax calculations</small>
  </div>
  <div class="card-body">
    <div class="row">
      <div class="col-md-6">
        <%= form.label :tax_jurisdiction_id, class: "form-label" %>
        <%= form.select :tax_jurisdiction_id,
                        options_from_collection_for_select(@tax_jurisdictions, :id, :name, @invoice[:tax_jurisdiction_id]),
                        { prompt: 'Auto-detect from establishment' },
                        { class: "form-select",
                          data: {
                            action: "change->tax-context#updateTaxRates",
                            tax_context_target: "jurisdiction"
                          } } %>
        <div class="form-text">Override automatic jurisdiction detection</div>
      </div>

      <div class="col-md-6">
        <%= form.label :establishment_id, class: "form-label" %>
        <%= form.select :establishment_id,
                        options_from_collection_for_select(@establishments, :id, :name, @invoice[:establishment_id]),
                        { prompt: 'Select establishment (optional)' },
                        { class: "form-select",
                          data: {
                            action: "change->tax-context#updateJurisdiction",
                            tax_context_target: "establishment"
                          } } %>
        <div class="form-text">Links to tax jurisdiction if selected</div>
      </div>
    </div>

    <!-- Tax Rate Preview -->
    <div class="mt-3" data-tax-context-target="preview" style="display: none;">
      <div class="alert alert-info">
        <strong>Tax Preview:</strong>
        <span data-tax-context-target="previewText"></span>
      </div>
    </div>
  </div>
</div>
```

## Phase 4: Stimulus Controllers

### 4.1 Tax Context Controller
```javascript
// app/javascript/controllers/tax_context_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["jurisdiction", "establishment", "preview", "previewText"]

  connect() {
    this.updateTaxRates()
  }

  updateTaxRates() {
    const jurisdictionId = this.jurisdictionTarget.value
    if (!jurisdictionId) {
      this.hidePreview()
      return
    }

    // Fetch tax rates for jurisdiction
    fetch(`/tax_jurisdictions/${jurisdictionId}/tax_rates`, {
      headers: {
        "Accept": "application/json",
        "X-Requested-With": "XMLHttpRequest"
      }
    })
    .then(response => response.json())
    .then(data => {
      this.displayTaxPreview(data.tax_rates)
    })
    .catch(error => {
      console.error("Error fetching tax rates:", error)
      this.hidePreview()
    })
  }

  updateJurisdiction() {
    const establishmentId = this.establishmentTarget.value
    if (!establishmentId) return

    // Find establishment's jurisdiction
    const establishmentOption = this.establishmentTarget.selectedOptions[0]
    const jurisdictionId = establishmentOption.dataset.jurisdictionId

    if (jurisdictionId) {
      this.jurisdictionTarget.value = jurisdictionId
      this.updateTaxRates()
    }
  }

  displayTaxPreview(taxRates) {
    if (taxRates && taxRates.length > 0) {
      const standardRate = taxRates.find(rate => rate.tax_type === 'vat') || taxRates[0]
      this.previewTextTarget.textContent = `Standard VAT: ${standardRate.rate}% (${standardRate.description})`
      this.previewTarget.style.display = 'block'
    } else {
      this.hidePreview()
    }
  }

  hidePreview() {
    this.previewTarget.style.display = 'none'
  }
}
```

### 4.2 Enhanced Invoice Line Calculator
```javascript
// app/javascript/controllers/invoice_calculator_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["lineSubtotal", "lineTaxRate", "lineTaxAmount", "lineTotal",
                   "invoiceSubtotal", "invoiceTaxAmount", "invoiceTotal"]
  static values = {
    jurisdictionId: String,
    taxRates: Array
  }

  connect() {
    this.loadTaxRates()
  }

  jurisdictionIdValueChanged() {
    this.loadTaxRates()
  }

  loadTaxRates() {
    if (!this.jurisdictionIdValue) return

    fetch(`/tax_jurisdictions/${this.jurisdictionIdValue}/tax_rates`, {
      headers: {
        "Accept": "application/json",
        "X-Requested-With": "XMLHttpRequest"
      }
    })
    .then(response => response.json())
    .then(data => {
      this.taxRatesValue = data.tax_rates || []
      this.updateAllTaxRates()
    })
    .catch(error => {
      console.error("Error loading tax rates:", error)
    })
  }

  updateAllTaxRates() {
    this.lineTaxRateTargets.forEach(taxRateField => {
      const lineContainer = taxRateField.closest('[data-line-index]')
      if (lineContainer) {
        this.updateLineTaxRate(taxRateField, lineContainer)
      }
    })
  }

  updateLineTaxRate(taxRateField, lineContainer) {
    const productCode = lineContainer.querySelector('[name*="[product_code]"]')?.value
    const defaultRate = this.getDefaultTaxRate(productCode)

    if (defaultRate && !taxRateField.value) {
      taxRateField.value = defaultRate.rate
      this.calculateLineTotal(lineContainer)
    }
  }

  getDefaultTaxRate(productCode) {
    if (!this.taxRatesValue.length) return null

    // Find specific rate for product code or return standard VAT
    return this.taxRatesValue.find(rate =>
      rate.tax_type === 'vat' && rate.is_active
    ) || this.taxRatesValue[0]
  }

  calculateLineTotal(lineContainer) {
    const quantity = parseFloat(lineContainer.querySelector('[name*="[quantity]"]')?.value || 0)
    const unitPrice = parseFloat(lineContainer.querySelector('[name*="[unit_price]"]')?.value || 0)
    const discountPercentage = parseFloat(lineContainer.querySelector('[name*="[discount_percentage]"]')?.value || 0)
    const taxRate = parseFloat(lineContainer.querySelector('[name*="[tax_rate]"]')?.value || 0)

    const subtotal = quantity * unitPrice
    const discountAmount = subtotal * (discountPercentage / 100)
    const discountedSubtotal = subtotal - discountAmount
    const taxAmount = discountedSubtotal * (taxRate / 100)
    const total = discountedSubtotal + taxAmount

    // Update line fields
    lineContainer.querySelector('[name*="[subtotal]"]').value = discountedSubtotal.toFixed(2)
    lineContainer.querySelector('[name*="[tax_amount]"]').value = taxAmount.toFixed(2)
    lineContainer.querySelector('[name*="[total]"]').value = total.toFixed(2)

    this.updateInvoiceTotals()
  }

  updateInvoiceTotals() {
    let invoiceSubtotal = 0
    let invoiceTaxAmount = 0

    document.querySelectorAll('[data-line-index]').forEach(lineContainer => {
      const subtotal = parseFloat(lineContainer.querySelector('[name*="[subtotal]"]')?.value || 0)
      const taxAmount = parseFloat(lineContainer.querySelector('[name*="[tax_amount]"]')?.value || 0)

      invoiceSubtotal += subtotal
      invoiceTaxAmount += taxAmount
    })

    const invoiceTotal = invoiceSubtotal + invoiceTaxAmount

    // Update invoice total fields
    this.invoiceSubtotalTarget.textContent = invoiceSubtotal.toFixed(2)
    this.invoiceTaxAmountTarget.textContent = invoiceTaxAmount.toFixed(2)
    this.invoiceTotalTarget.textContent = invoiceTotal.toFixed(2)

    // Update hidden form fields
    document.querySelector('input[name="invoice[subtotal]"]').value = invoiceSubtotal.toFixed(2)
    document.querySelector('input[name="invoice[tax_amount]"]').value = invoiceTaxAmount.toFixed(2)
    document.querySelector('input[name="invoice[total_amount]"]').value = invoiceTotal.toFixed(2)
  }
}
```

## Phase 5: Routes Updates

### 5.1 New Routes
```ruby
# config/routes.rb additions
Rails.application.routes.draw do
  # Tax Jurisdictions (read-only)
  resources :tax_jurisdictions, only: [:index, :show] do
    member do
      get :tax_rates
    end
  end

  # Companies with establishments
  resources :companies do
    resources :establishments, controller: 'company_establishments'

    resources :invoices do
      collection do
        post :calculate_taxes
      end
    end
  end

  # API routes for AJAX requests
  namespace :api do
    namespace :v1 do
      resources :tax_jurisdictions, only: [:index, :show] do
        resources :tax_rates, only: [:index]
      end
    end
  end
end
```

## Phase 6: Testing Updates

### 6.1 Service Tests
```ruby
# spec/services/tax_jurisdictions_service_spec.rb
require 'rails_helper'

RSpec.describe TaxJurisdictionsService, type: :service do
  let(:token) { 'valid_token' }

  describe '.all' do
    it 'fetches all tax jurisdictions' do
      # Mock API response
      api_response = {
        data: [
          {
            id: '1',
            attributes: {
              name: 'Spain',
              code: 'ESP',
              country_code: 'ESP',
              currency_code: 'EUR',
              is_active: true
            }
          }
        ],
        meta: { total: 1 }
      }

      allow(TaxJurisdictionsService).to receive(:get).and_return(api_response)

      result = TaxJurisdictionsService.all(token: token)

      expect(result[:jurisdictions]).to have(1).item
      expect(result[:jurisdictions].first[:name]).to eq('Spain')
    end
  end
end
```

### 6.2 Controller Tests
```ruby
# spec/controllers/company_establishments_controller_spec.rb
require 'rails_helper'

RSpec.describe CompanyEstablishmentsController, type: :controller do
  let(:company) { { id: 1, name: 'Test Company' } }

  before do
    allow(CompanyService).to receive(:find).and_return(company)
    allow(controller).to receive(:current_token).and_return('valid_token')
    allow(controller).to receive(:authenticate_user!).and_return(true)
  end

  describe 'GET #index' do
    it 'loads company establishments' do
      establishments_response = {
        establishments: [
          { id: 1, name: 'Headquarters', establishment_type: 'headquarters' }
        ]
      }

      allow(CompanyEstablishmentsService).to receive(:all).and_return(establishments_response)

      get :index, params: { company_id: 1 }

      expect(response).to be_successful
      expect(assigns(:establishments)).to have(1).item
    end
  end
end
```

## Phase 7: Migration Timeline

### Week 1: Foundation
- [ ] Create new service classes
- [ ] Update existing services with tax context
- [ ] Add basic tax jurisdiction views
- [ ] Write service tests

### Week 2: UI Implementation
- [ ] Create establishment management UI
- [ ] Update invoice forms with tax context
- [ ] Implement Stimulus controllers
- [ ] Add responsive design elements

### Week 3: Integration
- [ ] Connect invoice creation with tax calculation
- [ ] Test multi-jurisdiction scenarios
- [ ] Add error handling and validation
- [ ] Performance optimization

### Week 4: Testing & Polish
- [ ] Comprehensive testing across jurisdictions
- [ ] UI/UX refinements
- [ ] Documentation updates
- [ ] Deployment preparation

## Dependencies
- API implementation completed (TAXES_PLAN_API.md)
- Database migrations applied
- Tax jurisdiction data seeded
- Updated API endpoints available

## Success Metrics
- [ ] All tax jurisdictions display correctly
- [ ] Establishment management works for all companies
- [ ] Invoice tax calculation accurate for each jurisdiction
- [ ] Responsive design works on mobile/tablet
- [ ] All tests pass with >95% coverage
- [ ] Performance remains acceptable (<2s page loads)

This client implementation plan ensures the frontend application can effectively utilize the enhanced multi-jurisdiction tax system while maintaining a clean, user-friendly interface for tax management and invoice processing.