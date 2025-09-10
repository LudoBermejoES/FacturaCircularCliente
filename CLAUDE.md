# FacturaCircular Cliente - Rails Web Application

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
- **API Base URL**: `http://localhost:3001/api/v1`
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
  BASE_URL = 'http://localhost:3001/api/v1'
  
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

## Key API Endpoints This Client Will Use

### Authentication Endpoints
```
POST /api/v1/auth/login          # User login (get JWT tokens)
POST /api/v1/auth/refresh        # Refresh access token
POST /api/v1/auth/logout         # User logout
```

### Core Resource Endpoints
```
GET    /api/v1/companies         # List companies
POST   /api/v1/companies         # Create company
GET    /api/v1/companies/:id     # Show company
PUT    /api/v1/companies/:id     # Update company

GET    /api/v1/invoices          # List invoices  
POST   /api/v1/invoices          # Create invoice
GET    /api/v1/invoices/:id      # Show invoice
PUT    /api/v1/invoices/:id      # Update invoice
POST   /api/v1/invoices/:id/freeze # Freeze invoice

GET    /api/v1/workflow_history  # Workflow history
PATCH  /api/v1/invoices/:id/status # Status transitions
```

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
- **Manual Testing**: Use API running at `localhost:3001` 
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
# API: http://localhost:3001/api/v1
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