# FacturaCircular Cliente - Implementation Plan

## Project Overview

This Rails web application serves as the **client interface** for the FacturaCircular API. It provides a comprehensive web UI for users to manage invoices, companies, workflows, and all other API functionality through an intuitive browser-based interface.

## Architecture

- **Frontend**: Rails 8 web application with Tailwind CSS and Hotwire
- **Backend Communication**: HTTP client consuming FacturaCircular API at `http://localhost:3001/api/v1`
- **Authentication**: JWT token management with secure session handling
- **Real-time Updates**: Turbo Streams for live updates and notifications

## Essential API Documentation Resources

Before implementing any feature, developers should reference these comprehensive API documentation resources:

### 🔗 Primary API References
1. **Swagger/OpenAPI Documentation** 
   - **Location**: `/Users/ludo/code/albaranes/swagger/v1/swagger.yaml`
   - **Purpose**: Complete API specification with 69 documented endpoints
   - **Usage**: Reference for exact request/response formats, validation rules, and error codes
   - **Access**: Available at http://localhost:3001/api-docs when API server is running

2. **Complete API Usage Guide**
   - **Location**: `/Users/ludo/code/albaranes/HOW_TO_API.md`
   - **Purpose**: Step-by-step tutorials with working examples in Python, JavaScript, and Bash
   - **Contains**: Authentication flows, invoice management workflows, tax calculations, error handling patterns
   - **Value**: Real working code examples for every API endpoint

3. **Detailed Technical Documentation**
   - **Location**: `/Users/ludo/code/albaranes/docs/plan/` (21 comprehensive documents)
   - **Key Files for Client Development**:
     - `08-api-endpoints.md` - Complete REST API reference
     - `06-authentication-and-security.md` - JWT implementation details
     - `11-invoice-status-workflow.md` - Workflow state machine logic
     - `14-tax-calculations.md` - Spanish tax system implementation

### 📋 How to Use These Resources During Development

#### For Authentication Implementation (Phase 1)
```bash
# Reference these files:
1. /Users/ludo/code/albaranes/HOW_TO_API.md (sections 2-3: Authentication)
2. /Users/ludo/code/albaranes/swagger/v1/swagger.yaml (auth endpoints)
3. /Users/ludo/code/albaranes/docs/plan/06-authentication-and-security.md

# Working examples available for:
- Login flow with email/password
- JWT token refresh mechanism  
- Error handling for auth failures
```

#### For Invoice Management (Phase 4)
```bash
# Reference these files:
1. /Users/ludo/code/albaranes/HOW_TO_API.md (sections 4-5: Invoice Management)
2. /Users/ludo/code/albaranes/swagger/v1/swagger.yaml (invoice endpoints)
3. /Users/ludo/code/albaranes/docs/plan/11-invoice-status-workflow.md

# Working examples available for:
- Creating invoices with line items
- Tax calculations and validation
- Status transitions and workflow management
- Facturae XML generation
```

#### For Company Management (Phase 3)
```bash
# Reference these files:
1. /Users/ludo/code/albaranes/HOW_TO_API.md (section 6: Company Management)
2. /Users/ludo/code/albaranes/swagger/v1/swagger.yaml (company endpoints)

# Working examples available for:
- Company CRUD operations
- Address management
- Spanish tax ID validation
```

### 🛠 Implementation Strategy Using Documentation

**Step 1**: Always start with Swagger docs to understand the endpoint structure
**Step 2**: Use HOW_TO_API.md examples as implementation templates  
**Step 3**: Reference detailed docs for business logic understanding
**Step 4**: Test against live API at http://localhost:3001/api/v1

### 📊 API Coverage Verification
The client should implement web interfaces for all 69 documented API endpoints:
- ✅ Authentication endpoints (5)
- ✅ Company management endpoints (8) 
- ✅ Invoice management endpoints (12)
- ✅ Workflow management endpoints (6)
- ✅ Tax calculation endpoints (5)
- ✅ User management endpoints (4)
- ✅ Additional utility endpoints (29)

## Implementation Phases

### Phase 1: Authentication & Authorization 🔐
**Estimated Time: 3-5 days**

#### 1.1 User Authentication System
- [ ] **Login/Logout Pages**
  - Create `AuthController` with login/logout actions
  - Design responsive login form with Tailwind CSS
  - Implement JWT token handling and storage
  - Add "Remember Me" functionality
  - Handle authentication errors gracefully

- [ ] **Password Management**
  - Password reset request page
  - Password change functionality
  - Password strength validation
  - Secure token handling for reset flows

- [ ] **Session Management**
  - JWT token refresh mechanism
  - Automatic logout on token expiration
  - Secure session storage (encrypted cookies)
  - CSRF protection integration

#### 1.2 User Profile Management
- [ ] **Profile Pages**
  - View current user profile
  - Edit profile information
  - Update password functionality
  - Profile picture upload (if supported by API)

### Phase 2: Core Dashboard & Navigation 📊
**Estimated Time: 2-3 days**

#### 2.1 Main Dashboard
- [ ] **Dashboard Layout**
  - Responsive navigation with mobile hamburger menu
  - Sidebar navigation for main sections
  - Breadcrumb navigation for deep pages
  - User menu with logout option

- [ ] **Dashboard Widgets**
  - Invoice statistics overview
  - Recent invoices list
  - Workflow status summaries
  - Quick action buttons

#### 2.2 Global Components
- [ ] **Reusable Components**
  - API error handling and display
  - Loading states with Stimulus controllers
  - Confirmation modals
  - Toast notifications
  - Pagination component

### Phase 3: Company Management 🏢
**Estimated Time: 4-6 days**

#### 3.1 Company CRUD Operations
- [ ] **Company List Page**
  - Searchable and filterable company table
  - Pagination for large datasets
  - Quick actions (edit, delete, view)
  - Bulk operations support

- [ ] **Company Forms**
  - Create new company form with validation
  - Edit existing company details
  - Address management (nested forms)
  - Tax information fields (Spanish compliance)

- [ ] **Company Detail Pages**
  - Complete company information display
  - Associated invoices listing
  - Workflow definitions for company
  - Address management interface

#### 3.2 Address Management
- [ ] **Address CRUD**
  - Add/edit/remove addresses for companies
  - Address validation (Spanish postal codes)
  - Default address selection
  - Geographic information display

### Phase 4: Invoice Management 📄
**Estimated Time: 8-12 days**

#### 4.1 Invoice Listing & Search
- [ ] **Invoice List Page**
  - Advanced filtering (status, date range, company, amount)
  - Sortable columns
  - Search by invoice number or description
  - Export functionality (PDF, CSV)
  - Bulk operations

#### 4.2 Invoice Creation & Editing
- [ ] **Invoice Forms**
  - Step-by-step invoice creation wizard
  - Company selection with search
  - Invoice line item management (dynamic add/remove)
  - Tax calculation integration
  - Document upload support
  - Draft saving functionality

- [ ] **Invoice Lines Management**
  - Dynamic line item addition/removal
  - Product/service selection
  - Quantity and price management
  - Tax rate selection per line
  - Discount application

#### 4.3 Invoice Detail & Actions
- [ ] **Invoice Detail Pages**
  - Complete invoice information display
  - PDF preview/download
  - Facturae XML download
  - Action buttons (freeze, convert, etc.)
  - Comments and notes section

- [ ] **Invoice Actions**
  - Freeze invoice functionality
  - Convert between invoice types
  - Status transition controls
  - Email sending interface
  - Payment tracking

### Phase 5: Workflow Management ⚡
**Estimated Time: 6-8 days**

#### 5.1 Workflow Visualization
- [ ] **Workflow Dashboard**
  - Visual workflow diagrams
  - Current status indicators
  - Available transitions display
  - Workflow history timeline

#### 5.2 Status Management
- [ ] **Status Transitions**
  - Workflow transition forms
  - Approval/rejection interfaces
  - Comment requirements for transitions
  - Role-based transition controls
  - SLA tracking displays

#### 5.3 Workflow History
- [ ] **History & Audit Trail**
  - Complete workflow history display
  - User action tracking
  - Timestamp and reason logging
  - Filterable history views

### Phase 6: Tax Management 💰
**Estimated Time: 4-5 days**

#### 6.1 Tax Configuration
- [ ] **Tax Rate Management**
  - View available tax rates
  - Tax exemption handling
  - Regional tax variations (IGIC for Canary Islands)

#### 6.2 Tax Calculations
- [ ] **Tax Processing**
  - Real-time tax calculation displays
  - Tax validation interfaces
  - Tax recalculation triggers
  - Tax breakdown visualization

### Phase 7: Reporting & Analytics 📈
**Estimated Time: 5-7 days**

#### 7.1 Financial Reports
- [ ] **Report Generation**
  - Invoice summary reports
  - Tax reports for accounting
  - Company performance metrics
  - Workflow efficiency analytics

#### 7.2 Data Export
- [ ] **Export Functionality**
  - Excel/CSV exports
  - PDF report generation
  - Facturae XML batch exports
  - Custom date range selections

### Phase 8: Real-time Features & Notifications 🔔
**Estimated Time: 3-4 days**

#### 8.1 Real-time Updates
- [ ] **Live Updates**
  - Turbo Stream integration for invoice updates
  - Real-time workflow status changes
  - Live notifications for actions
  - Auto-refresh for critical data

#### 8.2 Notification System
- [ ] **User Notifications**
  - In-app notification center
  - Email notification preferences
  - Workflow alert system
  - System maintenance notifications

### Phase 9: Advanced Features & Polish ✨
**Estimated Time: 4-6 days**

#### 9.1 User Experience Enhancements
- [ ] **UX Improvements**
  - Keyboard shortcuts for power users
  - Bulk action improvements
  - Advanced search interfaces
  - Favorite/bookmark system

#### 9.2 Performance & Security
- [ ] **Optimization**
  - API response caching
  - Optimistic UI updates
  - Security hardening
  - Performance monitoring

#### 9.3 Mobile Responsiveness
- [ ] **Mobile Experience**
  - Touch-optimized interfaces
  - Mobile navigation patterns
  - Responsive data tables
  - Mobile-specific workflows

## Technical Implementation Details

### API Integration Architecture
```ruby
# HTTP Client Service
class ApiClient
  def self.get(endpoint, params = {})
    # JWT authentication
    # Error handling
    # Response parsing
  end
end

# Resource Services
class InvoiceService < ApiClient
  def self.all(filters = {})
  def self.find(id)
  def self.create(params)
  # etc.
end
```

### Frontend Component Structure
```
app/
├── controllers/
│   ├── application_controller.rb      # Base authentication
│   ├── dashboard_controller.rb        # Main dashboard
│   ├── companies_controller.rb        # Company CRUD
│   ├── invoices_controller.rb         # Invoice management
│   ├── workflows_controller.rb        # Workflow management
│   └── auth_controller.rb             # Authentication
├── javascript/
│   ├── controllers/                   # Stimulus controllers
│   │   ├── invoice_form_controller.js
│   │   ├── workflow_controller.js
│   │   └── notification_controller.js
│   └── application.js
└── views/
    ├── layouts/
    │   └── application.html.erb       # Main layout
    ├── dashboard/
    ├── companies/
    ├── invoices/
    └── workflows/
```

### Key Stimulus Controllers Needed
- **InvoiceFormController**: Dynamic line items, tax calculations
- **WorkflowController**: Status transitions, approvals
- **SearchController**: Real-time search, filtering
- **NotificationController**: Toast notifications, alerts
- **ModalController**: Confirmation dialogs, forms

### HTTP Client Implementation
```ruby
class ApiService
  BASE_URL = 'http://localhost:3001/api/v1'
  
  private
  
  def authenticated_request(method, endpoint, params = {})
    response = HTTParty.send(method, "#{BASE_URL}#{endpoint}", {
      headers: {
        'Authorization' => "Bearer #{current_user.access_token}",
        'Content-Type' => 'application/json'
      },
      body: params.to_json
    })
    
    handle_response(response)
  end
  
  def handle_response(response)
    case response.code
    when 200..299
      JSON.parse(response.body)
    when 401
      redirect_to login_path
    when 422
      handle_validation_errors(response)
    else
      handle_api_error(response)
    end
  end
end
```

## Success Metrics

### Functional Requirements
- ✅ All API endpoints have corresponding UI interfaces
- ✅ Authentication flows work seamlessly
- ✅ Invoice management is intuitive and complete
- ✅ Workflow management provides clear status visibility
- ✅ Tax calculations are accurate and transparent

### Performance Requirements
- 📊 Page load times < 2 seconds
- 📊 API response handling < 500ms
- 📊 Mobile responsiveness on all devices
- 📊 99% uptime during business hours

### User Experience Requirements
- 👥 Intuitive navigation for non-technical users
- 👥 Clear error messages and guidance
- 👥 Consistent visual design language
- 👥 Accessibility compliance (WCAG 2.1)

## Risk Mitigation

### Technical Risks
- **API Changes**: Implement abstraction layer for API calls
- **Authentication Issues**: Robust token refresh and error handling
- **Performance**: Implement caching and pagination early

### Business Risks
- **User Adoption**: Focus on UX/UI design and user testing
- **Data Security**: Implement secure token storage and transmission
- **Compliance**: Ensure Spanish tax law compliance in UI

## Deployment Strategy

### Development Environment
- Local development with Docker
- API running on localhost:3001
- Client running on localhost:3002

### Staging Environment
- Containerized deployment
- SSL certificates for secure API communication
- Performance testing environment

### Production Environment
- High availability setup
- CDN for static assets
- Monitoring and alerting
- Automated backups

---
*Estimated Total Timeline: 12-16 weeks*
*Team Size: 2-3 developers + 1 designer*

---
*Generated with Claude Code - Ready for Implementation*