# Quick API Reference for Client Development

This document provides quick access to the most commonly used API endpoints while developing the FacturaCircular Cliente web interface.

## 🔗 Full Documentation Links

- **Complete API Guide**: `/Users/ludo/code/albaranes/HOW_TO_API.md`
- **Swagger Documentation**: `/Users/ludo/code/albaranes/swagger/v1/swagger.yaml`
- **Live API Docs**: Inside Docker: http://albaranes-api:3000/api-docs; from host: http://albaranes-api:3000/api-docs

## 🔑 Authentication Endpoints

### Login
```
POST /api/v1/auth/login
Content-Type: application/json

{
  "grant_type": "password",
  "email": "user@example.com", 
  "password": "password123"
}

Response: { "access_token": "...", "refresh_token": "...", "token_type": "Bearer" }
```

### Token Refresh
```
POST /api/v1/auth/refresh
Authorization: Bearer <refresh_token>

Response: { "access_token": "...", "token_type": "Bearer" }
```

### Logout
```
POST /api/v1/auth/logout
Authorization: Bearer <access_token>
```

## 🏢 Company Management

### List Companies
```
GET /api/v1/companies
Authorization: Bearer <access_token>
```

### Create Company
```
POST /api/v1/companies
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "data": {
    "type": "companies",
    "attributes": {
      "corporate_name": "Company Name S.L.",
      "tax_identification_number": "B12345678",
      "person_type_code": "J",
      "residence_type_code": "R",
      "email": "contact@company.com",
      "address": "Street Name 123",
      "postal_code": "28001",
      "town": "Madrid",
      "province": "Madrid",
      "country_code": "ESP"
    }
  }
}
```

### Company Addresses
```
GET /api/v1/companies/:id/addresses
POST /api/v1/companies/:id/addresses
PUT /api/v1/companies/:id/addresses/:address_id
DELETE /api/v1/companies/:id/addresses/:address_id
```

## 📄 Invoice Management

### List Invoices
```
GET /api/v1/invoices?page=1&per_page=25&status=draft
Authorization: Bearer <access_token>
```

### Create Invoice
```
POST /api/v1/invoices
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "data": {
    "type": "invoices",
    "attributes": {
      "invoice_series_code": "FC2024",
      "invoice_number": "001",
      "document_type": "FC",
      "document_class": "OO",
      "issue_date": "2024-01-15",
      "currency_code": "EUR",
      "language_code": "es"
    },
    "relationships": {
      "seller_party": {
        "data": { "type": "companies", "id": "1" }
      },
      "buyer_party": {
        "data": { "type": "companies", "id": "2" }
      }
    }
  }
}
```

### Invoice Actions
```
POST /api/v1/invoices/:id/freeze          # Make invoice immutable (requires approved status)
POST /api/v1/invoices/:id/convert         # Convert proforma to regular invoice
PATCH /api/v1/invoices/:id/status         # Change workflow status
GET /api/v1/invoices/:id/facturae         # Download Facturae XML

# Note: Freeze requires invoice to be in 'approved' status or higher
# Convert only works for proforma invoices (document_type: 'FP')
```

### Invoice Line Items
```
GET /api/v1/invoices/:id/lines            # List line items
POST /api/v1/invoices/:id/lines           # Add line item (auto line_number)
PUT /api/v1/invoices/:id/lines/:line_id   # Update line item
DELETE /api/v1/invoices/:id/lines/:line_id # Remove line item

# Add line item example:
POST /api/v1/invoices/:id/lines
{
  "data": {
    "type": "invoice_lines",
    "attributes": {
      "item_description": "Service description",
      "quantity": 10,
      "unit_price_without_tax": 100.00
    }
  }
}
```

### Invoice Taxes
```
GET /api/v1/invoices/:id/taxes            # List tax items
POST /api/v1/invoices/:id/taxes/recalculate # Recalculate taxes
```

## ⚡ Workflow Management

### Available Transitions
```
GET /api/v1/invoices/:id/workflow/available_transitions
Authorization: Bearer <access_token>

Response: [
  {
    "from": "draft",
    "to": "pending_review", 
    "label": "Submit for Review",
    "requires_comment": false
  }
]
```

### Workflow History
```
GET /api/v1/workflow_history?invoice_id=:id
Authorization: Bearer <access_token>
```

### Workflow Definitions
```
GET /api/v1/companies/:id/workflow_definitions
Authorization: Bearer <access_token>
```

## 💰 Tax Endpoints

### Tax Rates
```
GET /api/v1/tax/rates
Authorization: Bearer <access_token>
```

### Calculate Tax
```
POST /api/v1/tax/calculate/:invoice_id
Authorization: Bearer <access_token>
```

### Validate Tax
```
POST /api/v1/tax/validate/:invoice_id
Authorization: Bearer <access_token>
```

## 👤 User Management

### Get Profile
```
GET /api/v1/users/profile
Authorization: Bearer <access_token>
```

### Update Profile
```
PUT /api/v1/users/profile
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "data": {
    "attributes": {
      "email": "newemail@example.com",
      "name": "Updated Name"
    }
  }
}
```

## 🚨 Common Error Responses

### 401 Unauthorized
```json
{
  "errors": [
    {
      "status": "401",
      "title": "Unauthorized", 
      "detail": "Invalid or expired token",
      "code": "UNAUTHORIZED"
    }
  ]
}
```

### 403 Forbidden
```json
{
  "errors": [
    {
      "status": "403",
      "title": "Forbidden",
      "detail": "You are not authorized to perform this action",
      "code": "FORBIDDEN"
    }
  ]
}
```

### 409 Conflict
```json
{
  "errors": [
    {
      "status": "409",
      "title": "Conflict",
      "detail": "Company cannot be deleted due to existing invoices",
      "code": "CANNOT_DELETE"
    }
  ]
}
```

### 422 Validation Error (Rails 8: unprocessable_content)
```json
{
  "errors": [
    {
      "status": "422",
      "title": "Validation Error",
      "detail": "Email can't be blank",
      "source": { "pointer": "/data/attributes/email" },
      "code": "VALIDATION_ERROR"
    }
  ]
}
```

### 500 Server Error
```json
{
  "errors": [
    {
      "status": "500",
      "title": "Internal Server Error",
      "detail": "Something went wrong"
    }
  ]
}
```

## 🔧 Development Tips

### Headers for All Authenticated Requests
```
Authorization: Bearer <access_token>
Content-Type: application/json
Accept: application/json
```

### Testing with curl
```bash
# Set base URL
# Inside Docker: export API_BASE_URL=http://albaranes-api:3000/api/v1
# From host:     export API_BASE_URL=http://albaranes-api:3000/api/v1

# Login and get token
TOKEN=$(curl -s -X POST "$API_BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"grant_type":"password","email":"admin@example.com","password":"password123"}' \
  | jq -r .access_token)

# Use token for API calls
curl -H "Authorization: Bearer $TOKEN" \
  "$API_BASE_URL/companies"
```

### JSON:API Format
Most endpoints follow JSON:API specification with data wrapped in:
```json
{
  "data": {
    "attributes": { ... },
    "relationships": { ... }
  },
  "included": [...],
  "meta": { "pagination": {...} }
}
```

## ⚠️ Important API Changes (Sept 2025)

### Request Format
- All POST/PUT/PATCH requests must include `"type"` in the data object
- Company creation now requires full address fields (address, postal_code, town, province, country_code)
- Country code must be 3 letters (e.g., "ESP" not "ES")
- Invoice relationships use separate `relationships` object, not attributes

### Status Codes
- Rails 8 uses `:unprocessable_content` (422) instead of `:unprocessable_entity`
- Frozen invoice operations return 403 Forbidden, not 422
- Company deletion with invoices returns 409 Conflict, not 422

### Business Rules
- Invoices must be in 'approved' status before freezing
- Proforma invoices use different series codes (e.g., "PF2024" vs "FC2024")
- Invoice lines get automatic line numbers if not provided
- All invoice lines currently use 21% tax rate (hardcoded)

---
*For complete examples and detailed explanations, see `/Users/ludo/code/albaranes/HOW_TO_API.md`*
