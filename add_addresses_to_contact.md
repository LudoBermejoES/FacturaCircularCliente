# Multiple Addresses for Company Contacts - Client Implementation Plan

## Overview

This document outlines the plan to enhance the client-side interface for managing multiple addresses per company contact. While the API backend already fully supports this feature, the client currently only handles a single address per contact.

## Current State Analysis

### Backend Support (Already Complete)
- ✅ API endpoints for CRUD operations on contact addresses
- ✅ `CompanyContactAddress` model with multiple address types
- ✅ Default address management with automatic handling
- ✅ Routes: `/api/v1/companies/:company_id/contacts/:contact_id/addresses/*`

### Client Current Implementation
- ❌ Forms only support single address (hardcoded as `addresses[0]`)
- ❌ No UI for managing multiple addresses
- ❌ No address list view per contact
- ❌ No add/remove address functionality

## Implementation Plan

### Phase 1: Update Contact Views Structure

#### 1.1 Create Address Management Views
```
app/views/company_contact_addresses/
├── index.html.erb    # List all addresses for a contact
├── new.html.erb      # Add new address form
├── edit.html.erb     # Edit existing address
└── _form.html.erb    # Shared address form partial
```

#### 1.2 Update Existing Contact Views
- **Edit View**: Remove embedded single address form
- **New View**: Remove address fields, create contact first then add addresses
- **Index View**: Add "Manage Addresses" link for each contact

### Phase 2: Create Address Controller

#### 2.1 New Controller: `CompanyContactAddressesController`
```ruby
# app/controllers/company_contact_addresses_controller.rb
class CompanyContactAddressesController < ApplicationController
  before_action :set_company
  before_action :set_contact
  before_action :set_address, only: [:edit, :update, :destroy, :set_default]

  def index
    # GET /companies/:company_id/contacts/:contact_id/addresses
    @addresses = CompanyContactAddressService.all(
      company_id: @company[:id],
      contact_id: @contact[:id],
      token: current_token
    )
  end

  def new
    # GET /companies/:company_id/contacts/:contact_id/addresses/new
    @address = default_address_attributes
  end

  def create
    # POST /companies/:company_id/contacts/:contact_id/addresses
  end

  def edit
    # GET /companies/:company_id/contacts/:contact_id/addresses/:id/edit
  end

  def update
    # PATCH /companies/:company_id/contacts/:contact_id/addresses/:id
  end

  def destroy
    # DELETE /companies/:company_id/contacts/:contact_id/addresses/:id
  end

  def set_default
    # POST /companies/:company_id/contacts/:contact_id/addresses/:id/set_default
  end
end
```

### Phase 3: Create Address Service

#### 3.1 New Service: `CompanyContactAddressService`
```ruby
# app/services/company_contact_address_service.rb
class CompanyContactAddressService < ApiService
  def self.all(company_id:, contact_id:, token:)
    get("/companies/#{company_id}/contacts/#{contact_id}/addresses", token: token)
  end

  def self.find(company_id:, contact_id:, id:, token:)
    get("/companies/#{company_id}/contacts/#{contact_id}/addresses/#{id}", token: token)
  end

  def self.create(company_id:, contact_id:, params:, token:)
    post("/companies/#{company_id}/contacts/#{contact_id}/addresses",
         body: format_address_payload(params),
         token: token)
  end

  def self.update(company_id:, contact_id:, id:, params:, token:)
    patch("/companies/#{company_id}/contacts/#{contact_id}/addresses/#{id}",
          body: format_address_payload(params),
          token: token)
  end

  def self.destroy(company_id:, contact_id:, id:, token:)
    delete("/companies/#{company_id}/contacts/#{contact_id}/addresses/#{id}", token: token)
  end

  private

  def self.format_address_payload(params)
    {
      data: {
        type: 'company_contact_addresses',
        attributes: {
          street_address: params[:street_address],
          city: params[:city],
          state_province: params[:state_province],
          postal_code: params[:postal_code],
          country_code: params[:country_code],
          address_type: params[:address_type],
          is_default: params[:is_default]
        }
      }
    }
  end
end
```

### Phase 4: Update Routes

```ruby
# config/routes.rb
resources :companies do
  resources :company_contacts do
    member do
      post :activate
      post :deactivate
    end
    resources :addresses, controller: 'company_contact_addresses' do
      member do
        post :set_default
      end
    end
  end
end
```

### Phase 5: Create Address Views

#### 5.1 Address List View
```erb
<!-- app/views/company_contact_addresses/index.html.erb -->
<% breadcrumb ["Companies", companies_path],
              [@company[:name], company_path(@company[:id])],
              ["Contacts", company_company_contacts_path(@company[:id])],
              [@contact[:name], edit_company_company_contact_path(@company[:id], @contact[:id])],
              "Addresses" %>

<div class="space-y-6">
  <div class="sm:flex sm:items-center sm:justify-between">
    <h1 class="text-2xl font-bold">Addresses for <%= @contact[:name] %></h1>
    <%= link_to "Add Address",
        new_company_company_contact_address_path(@company[:id], @contact[:id]),
        class: "btn btn-primary" %>
  </div>

  <div class="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
    <% @addresses.each do |address| %>
      <div class="border rounded-lg p-4 <%= 'ring-2 ring-indigo-500' if address[:is_default] %>">
        <div class="flex justify-between items-start mb-2">
          <span class="badge <%= address_type_badge_class(address[:address_type]) %>">
            <%= address[:address_type].humanize %>
          </span>
          <% if address[:is_default] %>
            <span class="badge badge-success">Default</span>
          <% end %>
        </div>

        <address class="not-italic text-sm text-gray-600">
          <%= address[:street_address] %><br>
          <%= address[:city] %>, <%= address[:state_province] %><br>
          <%= address[:postal_code] %><br>
          <%= country_name(address[:country_code]) %>
        </address>

        <div class="mt-4 flex gap-2">
          <%= link_to "Edit",
              edit_company_company_contact_address_path(@company[:id], @contact[:id], address[:id]),
              class: "text-indigo-600 hover:text-indigo-900 text-sm" %>
          <% unless address[:is_default] %>
            <%= button_to "Set as Default",
                set_default_company_company_contact_address_path(@company[:id], @contact[:id], address[:id]),
                method: :post,
                class: "text-green-600 hover:text-green-900 text-sm" %>
          <% end %>
          <%= button_to "Delete",
              company_company_contact_address_path(@company[:id], @contact[:id], address[:id]),
              method: :delete,
              data: { confirm: "Are you sure?" },
              class: "text-red-600 hover:text-red-900 text-sm" %>
        </div>
      </div>
    <% end %>
  </div>

  <% if @addresses.empty? %>
    <div class="text-center py-12 bg-gray-50 rounded-lg">
      <p class="text-gray-500">No addresses found for this contact.</p>
      <%= link_to "Add First Address",
          new_company_company_contact_address_path(@company[:id], @contact[:id]),
          class: "btn btn-primary mt-4" %>
    </div>
  <% end %>
</div>
```

#### 5.2 Address Form Partial
```erb
<!-- app/views/company_contact_addresses/_form.html.erb -->
<%= form_with model: @address,
    url: @address[:id] ?
         company_company_contact_address_path(@company[:id], @contact[:id], @address[:id]) :
         company_company_contact_addresses_path(@company[:id], @contact[:id]),
    method: @address[:id] ? :patch : :post,
    local: true do |form| %>

  <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
    <!-- Address Type -->
    <div>
      <%= form.label :address_type, class: "label" %>
      <%= form.select :address_type,
          options_for_select([
            ["Billing", "billing"],
            ["Shipping", "shipping"]
          ], @address[:address_type]),
          { prompt: "Select type" },
          class: "form-select" %>
    </div>

    <!-- Default Address -->
    <div class="flex items-center pt-8">
      <%= form.check_box :is_default, class: "form-checkbox" %>
      <%= form.label :is_default, "Set as default address", class: "ml-2" %>
    </div>

    <!-- Street Address -->
    <div class="sm:col-span-2">
      <%= form.label :street_address, class: "label" %>
      <%= form.text_area :street_address,
          rows: 3,
          class: "form-textarea",
          required: true %>
    </div>

    <!-- City -->
    <div>
      <%= form.label :city, class: "label" %>
      <%= form.text_field :city, class: "form-input", required: true %>
    </div>

    <!-- Postal Code -->
    <div>
      <%= form.label :postal_code, class: "label" %>
      <%= form.text_field :postal_code, class: "form-input", required: true %>
    </div>

    <!-- State/Province -->
    <div>
      <%= form.label :state_province, class: "label" %>
      <%= form.text_field :state_province, class: "form-input" %>
    </div>

    <!-- Country -->
    <div>
      <%= form.label :country_code, "Country", class: "label" %>
      <%= form.select :country_code,
          options_for_select([
            ["Spain", "ESP"],
            ["France", "FRA"],
            ["Germany", "DEU"],
            ["Italy", "ITA"],
            ["Portugal", "PRT"],
            ["Netherlands", "NLD"],
            ["Belgium", "BEL"],
            ["United Kingdom", "GBR"]
          ], @address[:country_code] || "ESP"),
          {},
          class: "form-select",
          required: true %>
    </div>
  </div>

  <div class="mt-6 flex justify-end space-x-3">
    <%= link_to "Cancel",
        company_company_contact_addresses_path(@company[:id], @contact[:id]),
        class: "btn btn-secondary" %>
    <%= form.submit @address[:id] ? "Update Address" : "Create Address",
        class: "btn btn-primary" %>
  </div>
<% end %>
```

### Phase 6: Stimulus Controller for Dynamic Address Management

```javascript
// app/javascript/controllers/contact_addresses_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["addressList", "addressForm", "defaultBadge"]
  static values = {
    companyId: Number,
    contactId: Number
  }

  connect() {
    console.log("Contact addresses controller connected")
  }

  async setDefault(event) {
    event.preventDefault()
    const addressId = event.currentTarget.dataset.addressId
    const url = `/companies/${this.companyIdValue}/contacts/${this.contactIdValue}/addresses/${addressId}/set_default`

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': this.csrfToken,
          'Accept': 'application/json'
        }
      })

      if (response.ok) {
        // Update UI to reflect new default
        this.updateDefaultBadges(addressId)
        this.showNotification('Default address updated')
      }
    } catch (error) {
      console.error('Error setting default address:', error)
    }
  }

  updateDefaultBadges(newDefaultId) {
    this.defaultBadgeTargets.forEach(badge => {
      const addressId = badge.dataset.addressId
      if (addressId === newDefaultId) {
        badge.classList.remove('hidden')
      } else {
        badge.classList.add('hidden')
      }
    })
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]').content
  }
}
```

### Phase 7: Update Contact Views to Link to Addresses

#### 7.1 Update Contact Edit View
```erb
<!-- app/views/company_contacts/edit.html.erb -->
<!-- Remove the address section and add link instead -->
<div class="border-t border-gray-200 pt-6">
  <div class="flex justify-between items-center mb-4">
    <h4 class="text-lg font-medium text-gray-900">Addresses</h4>
    <%= link_to "Manage Addresses",
        company_company_contact_addresses_path(@company[:id], @contact[:id]),
        class: "text-indigo-600 hover:text-indigo-900" %>
  </div>

  <% if @contact[:addresses] && @contact[:addresses].any? %>
    <div class="bg-gray-50 p-4 rounded-lg">
      <% default_address = @contact[:addresses].find { |a| a[:is_default] } || @contact[:addresses].first %>
      <p class="text-sm font-medium text-gray-900">Default Address:</p>
      <address class="mt-1 text-sm text-gray-600 not-italic">
        <%= default_address[:street_address] %><br>
        <%= default_address[:city] %>, <%= default_address[:postal_code] %><br>
        <%= country_name(default_address[:country_code]) %>
      </address>
    </div>
  <% else %>
    <p class="text-sm text-gray-500">No addresses configured.</p>
  <% end %>
</div>
```

#### 7.2 Update Contact Index View
```erb
<!-- app/views/company_contacts/index.html.erb -->
<!-- Add address count and management link -->
<div class="text-sm text-gray-500">
  <%= pluralize(contact[:addresses]&.size || 0, 'address') %>
  <%= link_to "Manage",
      company_company_contact_addresses_path(@company[:id], contact[:id]),
      class: "ml-2 text-indigo-600 hover:text-indigo-900" %>
</div>
```

### Phase 8: Testing Plan

#### 8.1 RSpec Tests
```ruby
# spec/controllers/company_contact_addresses_controller_spec.rb
# spec/services/company_contact_address_service_spec.rb
```

#### 8.2 E2E Tests
```javascript
// e2e/tests/contact-addresses.spec.js
// Test complete address management workflow
```

## Migration Strategy

### Step 1: Deploy API Changes (Already Complete)
- ✅ Backend fully supports multiple addresses

### Step 2: Client Backward Compatibility
1. Keep existing single address support in forms temporarily
2. Deploy new address management UI alongside
3. Migrate existing addresses through new UI

### Step 3: Remove Legacy Code
1. Remove single address fields from contact forms
2. Update all references to use new address management

## UI/UX Improvements

### Address Type Icons
- 📍 Billing Address
- 📦 Shipping Address
- 🏢 Headquarters
- 🏪 Branch Office

### Quick Actions
- One-click "Set as Default"
- Copy address to clipboard
- Duplicate address with modifications

### Validation Enhancements
- Real-time postal code validation
- Country-specific address format hints
- Duplicate address detection

## Benefits

### For Users
- ✅ Manage unlimited addresses per contact
- ✅ Clear default address designation
- ✅ Different address types for different purposes
- ✅ Better invoice accuracy with proper addresses

### For Business
- ✅ Improved data quality
- ✅ Reduced invoice errors
- ✅ Better compliance with shipping requirements
- ✅ Enhanced customer relationship management

## Timeline

### Week 1
- [ ] Create controller and service
- [ ] Set up routes
- [ ] Basic CRUD views

### Week 2
- [ ] Stimulus controller for dynamic UI
- [ ] Update existing contact views
- [ ] Add validation and error handling

### Week 3
- [ ] Testing (RSpec + E2E)
- [ ] UI polish and improvements
- [ ] Documentation update

## Success Criteria

- [ ] Users can add/edit/delete multiple addresses per contact
- [ ] Default address is clearly indicated and manageable
- [ ] Address types are properly categorized
- [ ] All operations work smoothly with the API
- [ ] No regression in existing contact functionality
- [ ] Tests provide >90% coverage of new features

## Notes

- The API fully supports this feature already - no backend changes needed
- Focus on progressive enhancement - don't break existing functionality
- Consider adding address templates for common formats
- Future enhancement: Address validation service integration

---
*This plan ensures the client interface matches the robust multiple address support already available in the API backend.*