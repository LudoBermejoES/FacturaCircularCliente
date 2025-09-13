# FacturaCircular Cliente - Rails Web Application

##

## Available Test Users

The following users are created by the seed data and available for testing:

### 🔧 **Admin User**
- **Email**: `admin@example.com`
- **Password**: `password123`
- **Role**: `admin`
- **Permissions**: `manage_all`
- **Access**: Full system administration

### 👥 **Manager User**
- **Email**: `manager@example.com`
- **Password**: `password123`
- **Role**: `manager`
- **Permissions**: `manage_invoices`, `approve_invoices`
- **Access**: Invoice management and approval workflows

### 👤 **Regular User**
- **Email**: `user@example.com`
- **Password**: `password123`
- **Role**: `viewer`
- **Permissions**: `view_invoices`
- **Access**: Read-only access to invoices

### 🔐 **Service Account**
- **Email**: `service@example.com`
- **Password**: `ServicePass123!`
- **Type**: `service_account`
- **Role**: `admin`
- **Access**: API access with generated API key/secret for programmatic integration


## Project Overview

FacturaCircular Cliente is a **Rails 8 web application** that provides a comprehensive user interface for the FacturaCircular Invoice Management API. This client application enables users to manage invoices, companies, workflows, and all API functionality through an intuitive web browser interface.

## Core Purpose

This application serves as the **frontend client** that consumes the FacturaCircular API (located at `/Users/ludo/code/albaranes`). Users interact with this web interface to:
- Authenticate and manage their sessions
- Create, edit, and manage invoices through forms
- Handle company information and addresses
- Navigate complex invoice workflows
- Generate reports and export data
- Manage Spanish tax compliance (Facturae XML)

## Related Projects & Dependencies

### API Backend
- **Location**: `/Users/ludo/code/albaranes`
- **Purpose**: Complete invoice management API with JWT authentication
- **API Base URL**: Inside Docker: `http://albaranes-api:3000/api/v1` (from host: `http://albaranes-api:3000/api/v1`)
- **Documentation**: 
  - API Endpoints: `/Users/ludo/code/albaranes/docs/plan/08-api-endpoints.md`
  - Authentication: `/Users/ludo/code/albaranes/docs/plan/06-authentication-and-security.md`
  - Complete API Guide: `/Users/ludo/code/albaranes/HOW_TO_API.md`
  - Swagger Documentation: `/Users/ludo/code/albaranes/swagger/v1/swagger.yaml`

### Key API Resources to Understand
```bash
# Essential files to understand the API this client consumes:
/Users/ludo/code/albaranes/HOW_TO_API.md                    # Complete API usage guide
/Users/ludo/code/albaranes/docs/plan/                       # Complete API documentation
/Users/ludo/code/albaranes/config/routes.rb                 # All available API endpoints
/Users/ludo/code/albaranes/app/controllers/api/v1/          # API controller implementations
/Users/ludo/code/albaranes/swagger/v1/swagger.yaml          # API specification
```

## Project Architecture

### Technology Stack
- **Framework**: Rails 8.0.2.1 (full web application, NOT API-only)
- **Ruby Version**: 3.4.5
- **Styling**: Tailwind CSS v4
- **JavaScript**: Hotwire (Turbo + Stimulus) with Import Maps
- **HTTP Client**: Will consume FacturaCircular API via HTTP requests
- **Authentication**: JWT token management (consuming API auth endpoints)
- **Database**: None (stateless client, all data comes from API)

### Key Directories Structure
```
├── app/
│   ├── controllers/           # Web controllers (NOT API controllers)
│   ├── views/                # ERB templates for web pages
│   ├── javascript/           # Stimulus controllers for interactivity
│   │   └── controllers/      # Dynamic form handling, AJAX, etc.
│   ├── assets/
│   │   └── stylesheets/      # Additional CSS beyond Tailwind
│   └── services/             # API client services (HTTP requests)
├── config/
│   ├── routes.rb             # Web application routes
│   └── importmap.rb          # JavaScript import configuration
├── PLAN.md                   # Complete implementation roadmap
└── README.md                 # Setup and usage instructions
```

## Implementation Plan

### Current Status
- ✅ Rails 8 web application created with modern stack
- ✅ Docker configuration complete
- ✅ Tailwind CSS + Hotwire configured
- ✅ Development environment ready
- 📋 **Next**: Follow PLAN.md for systematic feature implementation

### Implementation Roadmap
**Reference**: `PLAN.md` in this directory contains the complete 9-phase implementation plan:

1. **Phase 1: Authentication & Authorization** (JWT integration with API)
2. **Phase 2: Core Dashboard & Navigation** (main UI structure)  
3. **Phase 3: Company Management** (companies and addresses)
4. **Phase 4: Invoice Management** (complete invoice CRUD)
5. **Phase 5: Workflow Management** (status transitions)
6. **Phase 6: Tax Management** (Spanish tax compliance)
7. **Phase 7: Reporting & Analytics** (data visualization)
8. **Phase 8: Real-time Features** (Turbo Streams)
9. **Phase 9: Advanced Features & Polish** (UX enhancements)

## Development Guidelines

### API Integration Patterns
```ruby
# Service classes for API communication
class ApiService
  BASE_URL = 'http://albaranes-api:3000/api/v1'
  
  def self.get(endpoint, token:)
    # HTTP client calls to FacturaCircular API
  end
end

# Resource-specific services
class InvoiceService < ApiService
  def self.all(token:, filters: {})
  def self.find(id, token:)
  def self.create(params, token:)
end
```

### Controller Pattern
```ruby
class InvoicesController < ApplicationController
  before_action :authenticate_user!
  
  def index
    @invoices = InvoiceService.all(token: current_user.access_token)
  rescue ApiService::AuthenticationError
    redirect_to login_path
  end
end
```

### Key Files to Create/Modify During Development

#### Authentication System
- `app/controllers/sessions_controller.rb` - Login/logout handling
- `app/controllers/application_controller.rb` - Authentication helpers
- `app/services/auth_service.rb` - JWT token management

#### API Integration
- `app/services/api_service.rb` - Base HTTP client
- `app/services/invoice_service.rb` - Invoice API calls
- `app/services/company_service.rb` - Company API calls
- `app/services/workflow_service.rb` - Workflow API calls

#### Web Controllers  
- `app/controllers/dashboard_controller.rb` - Main dashboard
- `app/controllers/invoices_controller.rb` - Invoice management
- `app/controllers/companies_controller.rb` - Company management
- `app/controllers/workflows_controller.rb` - Workflow management

#### Views & Components
- `app/views/layouts/application.html.erb` - Main layout
- `app/views/dashboard/` - Dashboard views
- `app/views/invoices/` - Invoice CRUD views
- `app/views/companies/` - Company management views

#### JavaScript Interactivity
- `app/javascript/controllers/invoice_form_controller.js` - Dynamic invoice forms
- `app/javascript/controllers/workflow_controller.js` - Workflow interactions
- `app/javascript/controllers/search_controller.js` - Search functionality

## External API Endpoints Used by This Client

This section documents all external API endpoints consumed by this Rails client application from the FacturaCircular API backend.

### 🔐 Authentication Endpoints

| Endpoint | Method | Purpose | Used In |
|----------|--------|---------|---------|
| `/auth/login` | POST | User authentication with email/password | Login form, session creation |
| `/auth/refresh` | POST | Refresh expired JWT access tokens | Automatic token renewal |
| `/auth/logout` | POST | Invalidate user session | Logout functionality |
| `/auth/validate` | GET | Validate current JWT token | Session validation, auth checks |

### 🏢 Company Management Endpoints

| Endpoint | Method | Purpose | Used In |
|----------|--------|---------|---------|
| `/companies` | GET | List all companies with filters | Companies index page |
| `/companies/:id` | GET | Get specific company details | Company show/edit pages |
| `/companies` | POST | Create new company | New company form |
| `/companies/:id` | PUT | Update company information | Edit company form |
| `/companies/:id` | DELETE | Delete a company | Company deletion |
| `/companies/search` | GET | Search companies by query | Company search feature |
| `/companies/:id/addresses` | GET | List company addresses | Address management |
| `/companies/:id/addresses` | POST | Add address to company | New address form |
| `/companies/:id/addresses/:id` | PUT | Update company address | Edit address form |
| `/companies/:id/addresses/:id` | DELETE | Remove company address | Address deletion |

### 📄 Invoice Management Endpoints

| Endpoint | Method | Purpose | Used In |
|----------|--------|---------|---------|
| `/invoices` | GET | List invoices with filters | Invoices index, dashboard |
| `/invoices/:id` | GET | Get invoice details | Invoice show/edit pages |
| `/invoices` | POST | Create new invoice | New invoice form |
| `/invoices/:id` | PUT | Update invoice | Edit invoice form |
| `/invoices/:id` | DELETE | Delete invoice | Invoice deletion |
| `/invoices/:id/freeze` | POST | Freeze invoice (make immutable) | Invoice freeze action |
| `/invoices/:id/unfreeze` | POST | Unfreeze invoice | Invoice unfreeze action |
| `/invoices/:id/send_email` | POST | Email invoice to recipient | Send invoice by email |
| `/invoices/:id/status` | PATCH | Update invoice status | Status transitions |
| `/invoices/:id/pdf` | GET | Download invoice as PDF | PDF export |
| `/invoices/:id/facturae` | GET | Download Facturae XML | Spanish tax compliance export |
| `/invoices/:id/invoice_lines` | POST | Add line item to invoice | Invoice line management |
| `/invoices/:id/invoice_lines/:id` | PUT | Update invoice line item | Edit line item |
| `/invoices/:id/invoice_lines/:id` | DELETE | Remove line item | Delete line item |
| `/invoices/calculate_taxes` | POST | Calculate taxes for invoice | Tax calculation |
| `/invoices/:id/workflow_history` | GET | Get workflow history | Workflow tracking |
| `/invoices/statistics` | GET | Get invoice statistics | Analytics/reporting |
| `/invoices/stats` | GET | Get dashboard statistics | Dashboard widgets |

### 💰 Tax Management Endpoints

| Endpoint | Method | Purpose | Used In |
|----------|--------|---------|---------|
| `/tax_rates` | GET | List all tax rates | Tax rates index |
| `/tax_rates/:id` | GET | Get specific tax rate | Tax rate details |
| `/tax_rates` | POST | Create new tax rate | New tax rate form |
| `/tax_rates/:id` | PUT | Update tax rate | Edit tax rate form |
| `/tax_rates/:id` | DELETE | Delete tax rate | Tax rate deletion |
| `/tax_rates/regional` | GET | Get regional tax variations | Regional tax management |
| `/tax_rates/irpf` | GET | Get IRPF rates (Spanish) | Spanish tax compliance |
| `/tax_calculations` | POST | Perform tax calculation | Tax calculator |
| `/invoices/:id/calculate_tax` | POST | Calculate tax for invoice | Invoice tax calculation |
| `/invoices/:id/recalculate_tax` | POST | Recalculate invoice taxes | Tax recalculation |
| `/invoices/:id/validate_tax` | POST | Validate invoice tax compliance | Tax validation |
| `/tax_validations/tax_id` | POST | Validate Spanish tax ID (NIF/CIF) | Tax ID validation |
| `/tax_exemptions` | GET | List tax exemptions | Tax exemption management |
| `/tax_exemptions` | POST | Create tax exemption | New exemption form |
| `/invoices/:id/apply_exemption` | POST | Apply exemption to invoice | Apply tax exemption |
| `/tax_reports/summary` | GET | Tax summary report | Tax reporting |
| `/tax_reports/vat` | GET | VAT report | VAT reporting |
| `/tax_reports/modelo_303` | GET | Spanish Modelo 303 report | Spanish tax forms |
| `/tax_reports/modelo_347` | GET | Spanish Modelo 347 report | Spanish tax forms |

### ⚙️ Workflow Management Endpoints

| Endpoint | Method | Purpose | Used In |
|----------|--------|---------|---------|
| `/invoices/:id/workflow_history` | GET | Get invoice workflow history | Workflow tracking |
| `/invoices/:id/available_transitions` | GET | Get available status transitions | Status change UI |
| `/invoices/:id/status` | PATCH | Transition invoice status | Status updates |
| `/invoices/bulk_status` | POST | Bulk status update | Bulk operations |
| `/workflow_rules` | GET | List workflow rules | Workflow configuration |
| `/workflow_rules` | POST | Create workflow rule | New rule form |
| `/workflow_rules/:id` | PUT | Update workflow rule | Edit rule form |
| `/workflow_rules/:id` | DELETE | Delete workflow rule | Rule deletion |
| `/workflow_templates` | GET | List workflow templates | Template management |
| `/workflow_templates` | POST | Create workflow template | New template form |
| `/invoices/:id/apply_workflow_template` | POST | Apply template to invoice | Template application |

### 📊 Key Features by Controller

#### TaxCalculationsController
- **Tax calculation form**: Uses `/tax_calculations` for manual calculations
- **Invoice tax calculation**: Uses `/invoices/:id/calculate_tax` and `/invoices/:id/recalculate_tax`
- **Tax validation**: Uses `/tax_validations/tax_id` and `/invoices/:id/validate_tax`

#### TaxRatesController
- **CRUD operations**: Full management of tax rates
- **Regional rates**: Special handling for Canary Islands, Ceuta, Melilla
- **IRPF rates**: Spanish income tax retention rates

### 🔄 API Integration Patterns

All API calls follow these patterns:
1. **Authentication**: Every request includes `Authorization: Bearer <token>` header
2. **Error Handling**: 
   - 401: Triggers token refresh or redirect to login
   - 422: Shows validation errors in forms
   - 500: Shows error page with retry option
3. **Response Format**: JSON for all endpoints except PDF/XML downloads
4. **Base URL**: `http://albaranes-api:3000/api/v1` (Docker internal)

### Reference Files for API Integration
- **Complete API Guide**: `/Users/ludo/code/albaranes/HOW_TO_API.md`
- **API Routes**: `/Users/ludo/code/albaranes/config/routes.rb` 
- **Request/Response Examples**: `/Users/ludo/code/albaranes/spec/requests/api/v1/`

## Development Workflow

### Starting Development
1. **Review API Documentation** in `/Users/ludo/code/albaranes/HOW_TO_API.md`
2. **Start API Server**: `cd /Users/ludo/code/albaranes && docker-compose up`
3. **Start Client App**: `cd /Users/ludo/code/facturaCircularCliente && docker-compose up`
4. **Follow PLAN.md** for systematic feature implementation

### Testing Strategy
- **Manual Testing**: Inside Docker use `http://albaranes-api:3000/api/v1`; from host use `http://albaranes-api:3000/api/v1`
- **Integration Testing**: Test complete user workflows
- **API Interaction Testing**: Verify HTTP client error handling

### Key Development Principles
1. **Stateless Client**: All data comes from API, no local database
2. **JWT Authentication**: Secure token storage and refresh handling  
3. **Error Handling**: Graceful API error handling and user feedback
4. **Responsive Design**: Mobile-first approach with Tailwind
5. **Real-time Updates**: Use Turbo Streams for dynamic updates

## Important Notes for Development

### Authentication Flow
1. User logs in via web form → POST to `/api/v1/auth/login`
2. Store JWT tokens securely in encrypted session
3. Include `Authorization: Bearer <token>` in all API requests
4. Handle token refresh automatically
5. Redirect to login on 401 responses

### Data Flow Pattern
```
User Interaction → Web Controller → API Service → FacturaCircular API → Response → View Rendering
```

### Error Handling Strategy
- **401 Unauthorized**: Redirect to login page
- **422 Validation Errors**: Display form errors to user
- **500 Server Errors**: Show friendly error page with retry option
- **Network Errors**: Show connection error with manual retry

### Security Considerations
- Never store API credentials in client code
- Use encrypted session storage for JWT tokens
- Implement CSRF protection for forms
- Sanitize all user inputs before API calls
- Use HTTPS in production

## File Search Quick Reference

### When Working on Authentication
```bash
# API auth documentation
/Users/ludo/code/albaranes/docs/plan/06-authentication-and-security.md
/Users/ludo/code/albaranes/app/controllers/api/v1/authentication_controller.rb
/Users/ludo/code/albaranes/HOW_TO_API.md # Section: Authentication
```

### When Working on Invoices
```bash
# API invoice endpoints
/Users/ludo/code/albaranes/app/controllers/api/v1/invoices_controller.rb
/Users/ludo/code/albaranes/app/models/invoice.rb
/Users/ludo/code/albaranes/docs/plan/11-invoice-status-workflow.md
```

### When Working on Companies  
```bash
# API company endpoints
/Users/ludo/code/albaranes/app/controllers/api/v1/companies_controller.rb
/Users/ludo/code/albaranes/app/models/company.rb
```

### When Working on Workflows
```bash
# API workflow endpoints
/Users/ludo/code/albaranes/app/controllers/api/v1/workflow_*
/Users/ludo/code/albaranes/docs/plan/11-invoice-status-workflow.md
```

## Development Environment

### Running Both Applications
```bash
# Terminal 1: Start API server
cd /Users/ludo/code/albaranes
docker-compose up

# Terminal 2: Start web client
cd /Users/ludo/code/facturaCircularCliente  
docker-compose up

# Access points:
# API (inside Docker): http://albaranes-api:3000/api/v1
# API (from host):     http://albaranes-api:3000/api/v1
# Web Client: http://localhost:3002
```

### Useful Development Commands
```bash
# API server commands
cd /Users/ludo/code/albaranes
docker-compose exec web bundle exec rails console
docker-compose logs -f web

# Client app commands  
cd /Users/ludo/code/facturaCircularCliente
docker-compose exec web bundle exec rails console
docker-compose exec web bash
```

---

## Success Criteria

A successful implementation will provide:
- 🔐 **Secure authentication** with the FacturaCircular API
- 📄 **Complete invoice management** through web forms
- 🏢 **Company and address management** interfaces  
- ⚡ **Workflow visualization** and status management
- 💰 **Tax calculation** and compliance features
- 📊 **Reporting and export** capabilities
- 📱 **Responsive design** for all devices
- 🚀 **Fast, intuitive user experience** with Hotwire

---
*This document serves as the development guide for building the FacturaCircular web client. Always refer to the API documentation in `/Users/ludo/code/albaranes/` when implementing features.*
