# Quick API Reference for Client Development

This document provides quick access to the most commonly used API endpoints while developing the FacturaCircular Cliente web interface.

## 🔗 Full Documentation Links

- **Complete API Guide**: `/Users/ludo/code/albaranes/HOW_TO_API.md`
- **Swagger Documentation**: `/Users/ludo/code/albaranes/swagger/v1/swagger.yaml`
- **Live API Docs**: http://localhost:3001/api-docs (when API server running)

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
    "attributes": {
      "name": "Company Name",
      "tax_id": "B12345678",
      "country": "ES",
      "email": "contact@company.com"
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
    "attributes": {
      "seller_party_id": 1,
      "buyer_party_id": 2,
      "invoice_series_code": "A",
      "invoice_number": "001",
      "document_type": "FC",
      "document_class": "OO",
      "issue_date": "2024-01-15",
      "currency_code": "EUR",
      "language_code": "es"
    }
  }
}
```

### Invoice Actions
```
POST /api/v1/invoices/:id/freeze          # Make invoice immutable
POST /api/v1/invoices/:id/convert         # Convert invoice type  
PATCH /api/v1/invoices/:id/status         # Change workflow status
GET /api/v1/invoices/:id/facturae         # Download Facturae XML
```

### Invoice Line Items
```
GET /api/v1/invoices/:id/lines            # List line items
POST /api/v1/invoices/:id/lines           # Add line item
PUT /api/v1/invoices/:id/lines/:line_id   # Update line item
DELETE /api/v1/invoices/:id/lines/:line_id # Remove line item
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
      "detail": "Invalid or expired token"
    }
  ]
}
```

### 422 Validation Error
```json
{
  "errors": [
    {
      "status": "422",
      "title": "Validation Error",
      "detail": "Email can't be blank",
      "source": { "pointer": "/data/attributes/email" }
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
# Login and get token
TOKEN=$(curl -s -X POST http://localhost:3001/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"grant_type":"password","email":"admin@example.com","password":"password123"}' \
  | jq -r .access_token)

# Use token for API calls
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:3001/api/v1/companies
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

---
*For complete examples and detailed explanations, see `/Users/ludo/code/albaranes/HOW_TO_API.md`*