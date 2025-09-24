# FacturaCircular Cliente – Agent Handbook

This document is your briefing for working on the Rails client that consumes the FacturaCircular API. It captures the context, workflows, conventions, and commands you will need so you can focus on the task instead of rediscovering project details.

## 1. System Snapshot
- **Repo**: `/Users/ludo/code/facturaCircularCliente` (also symlinked from `/Users/ludo/code/albaranes/client`).
- **Purpose**: Full-stack Rails 8 UI that talks to the API-only backend in `/Users/ludo/code/albaranes`.
- **Frontend stack**: Rails 8.0.2.1, Ruby 3.4.5, Hotwire (Turbo + Stimulus with import maps), Tailwind CSS 4.
- **Persistence**: No local database; every CRUD action goes through the backend API.
- **Authentication**: JWT tokens issued by the API. Tokens + company context live in the Rails session.
- **Default ports**: API on `3001`, client on `3002` (when using Docker compose).

## 2. Environment & Startup
1. **Backend first**: Bring up the API project in `/Users/ludo/code/albaranes` (`docker-compose up -d`). The client expects the backend to be reachable.
2. **Configure API base URL**: Set `API_BASE_URL` (or `FACTURACIRCULAR_API_URL`) to the API root. Example `.env` snippet:
   ```bash
   API_BASE_URL=http://localhost:3001/api/v1
   ```
3. **Docker workflow** (recommended):
   ```bash
   cd /Users/ludo/code/facturaCircularCliente
   docker-compose up -d
   # Visit http://localhost:3002
   ```
4. **Native workflow**:
   ```bash
   bundle install
   bin/dev          # or rails server -p 3002
   ```
5. **Console access**:
   ```bash
   docker-compose exec web bundle exec rails console
   ```

## 3. Project Layout Cheat Sheet
```
app/
  controllers/            Web controllers orchestrating API calls
  controllers/api/v1/     Lightweight JSON endpoints used by the UI (requires login)
  services/               HTTParty-based clients for backend resources
  javascript/controllers/ Stimulus controllers (Turbo-ready interactions)
  views/                  ERB views + partials
config/
  routes.rb               Web + helper JSON routes
  importmap.rb            Stimulus dependencies
spec/                     RSpec suite (services, controllers, features, etc.)
e2e/                      Playwright end-to-end tests + page objects
Dockerfile*, docker-compose.yml   Containers for web and Playwright
HOW_TO_TEST.md            Full testing instructions
FIXING_TESTS.md           Known issues and workarounds
```

## 4. Authentication & Session Flow
- Login form posts to `SessionsController#create`, which calls `AuthService.login` (proxy to `POST /auth/login`).
- On success, the session stores `access_token`, `refresh_token`, user info, and the list of companies.
- `ApplicationController` guards every request using `authenticate_user!`.
  - Tokens are validated via `AuthService.validate_token`.
  - If validation fails, `AuthService.refresh_token` tries to refresh using the `refresh_token`.
- Company context is switchable (`CompaniesController#switch` -> `POST /auth/switch_company`). Users with >1 company get redirected to a selector.

## 5. Service Layer (API Clients)
Every network call funnels through `ApiService` (HTTParty). Key services:
- `AuthService`: login, refresh, logout, switch_company, user_companies.
- `CompanyService`: companies CRUD, addresses, contacts, user membership, invoice series.
- `InvoiceService`: invoices list/show/create/update/freeze/convert plus JSON:API response reshaping for the UI.
- `InvoiceSeriesService`, `InvoiceNumberingService`: numbering utilities.
- `ProductService`, `TaxRateService`, `WorkflowService`, `WorkflowDefinitionService`, etc. (see `app/services`).
- Each service adapts JSON:API payloads into Ruby hashes the controllers/views expect. Many helpers add compatibility aliases (e.g., mapping `document_type` to `invoice_type`).
- When you add a new API interaction, create/extend a service method so controllers stay thin.

## 6. Web Controllers & UI Responsibilities
- Controllers live under `app/controllers`. They assemble params, invoke service methods, and render views.
- Most actions rescue `ApiService::AuthenticationError` to force re-login and `ApiService::ApiError` to surface backend issues.
- Example flows:
  - `InvoicesController`: handles listing, forms, freeze, download actions. Delegates to `InvoiceService` and `WorkflowService`.
  - `CompaniesController`: handles company selection and management, including nested addresses/contacts and user assignments.
  - `WorkflowDefinitionsController` + nested `workflow_states/` and `workflow_transitions/`: manage workflow templates by calling the backend definitions endpoints.
  - `TaxRatesController`, `TaxCalculationsController`: front-end wrappers for tax rate listings and calculator endpoints.
- Mini JSON endpoints exist in `app/controllers/api/v1` for AJAX helpers (e.g., invoice numbering previews). They reuse authentication helpers.

## 7. Stimulus / Front-end Interactions
- Stimulus controllers live in `app/javascript/controllers/`.
  - `invoice_form_controller.js`: dynamic line items, totals, invoice series filtering, product insertion events.
  - `buyer_selection_controller.js`, `tax_calculator_controller.js`, `workflow_controller.js`, etc. manage interactive pieces.
- Turbo frames/streams are used across the UI. When adding new interactive features, prefer Stimulus actions + Turbo responses over custom JS frameworks.
- Tailwind 4 utilities drive styling (`app/assets/tailwind`). Keep UI changes utility-first and reuse existing classes when possible.

## 8. Coding Conventions & Tools
- Ruby style: Rubocop Rails Omakase (`bin/rubocop` with project `.rubocop.yml`).
- Stimulus: ES6 modules, class-based controllers, minimal DOM queries.
- Views: lean ERB templates with logic moved to helpers/services.
- Error handling: wrap API calls, surface user-friendly flash messages, log details with `Rails.logger`.
- When logging, follow the structured examples already in `ApiService`.

## 9. Development Workflow for New Features
1. **Sync with API contract**: Inspect backend docs (`/Users/ludo/code/albaranes/docs/plan/08-api-endpoints.md`, Swagger, etc.).
2. **Service first**: Add/extend a method in the relevant service to call the API endpoint. Handle JSON:API conversion there.
3. **Controller**: Wire the service call into the controller action, manage params/flash/redirects.
4. **Views/Stimulus**: Update ERB or Stimulus controllers to support new UI flows. Keep interactions declarative.
5. **Tests**:
   - Unit/service spec for the new service method (WebMock stubs).
   - Controller/feature spec if you introduced new routes or flows.
   - Update/extend Playwright tests if the user journey changed.
6. **Lint & verify**: Run Rubocop, RSpec, and relevant Playwright suites.
7. **Document**: Update user-facing docs or internal guides if behavior changed.

## 10. Testing Strategy (Summary)
Refer to `HOW_TO_TEST.md` for detail. Core commands:

### RSpec (inside Docker)
```bash
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec"        # Entire suite
docker-compose exec web bash -c "RAILS_ENV=test bundle exec rspec spec/services/"  # Services
```

### RSpec (local)
```bash
RAILS_ENV=test bundle exec rspec spec/controllers/invoices_controller_spec.rb
```

### Playwright E2E
```bash
./run-e2e-tests.sh                  # Docker runner
./run-e2e-tests.sh -b firefox       # Specific browser
cd e2e && npx playwright test       # Local run
```

### Lint
```bash
bin/rubocop
```

**Always** use `RAILS_ENV=test` for specs to avoid host authorization errors.

## 11. Seed & Demo Credentials
These mirror the backend seeds:
- Admin: `admin@example.com` / `password123`
- Manager: `manager@example.com` / `password123`
- Viewer: `user@example.com` / `password123`
- Service account: `service@example.com` / `ServicePass123!`

## 12. Common Pitfalls & Tips
- **Missing backend**: The client 500s if the API is down. Ensure `/Users/ludo/code/albaranes` is running.
- **Blocked host**: Run specs with `RAILS_ENV=test` or set `HOSTS` config to avoid host authorization issues.
- **Token expiry**: If you hit a 401 while browsing, the refresh logic should handle it. If not, clear the session (`logout`) and log in again.
- **JSON:API**: The backend responses are JSON:API. Keep conversions centralized in the service layer so controllers/views stay simple.
- **Stimulus events**: Most forms expect Stimulus controllers to manage UI state. When adding new fields, hook into existing controllers or add targets/actions.

## 13. Useful References
- Backend API docs: `/Users/ludo/code/albaranes/docs/plan/08-api-endpoints.md`
- Auth & security: `/Users/ludo/code/albaranes/docs/plan/06-authentication-and-security.md`
- Swagger: `/Users/ludo/code/albaranes/swagger/v1/swagger.yaml`
- Testing guides: `HOW_TO_TEST.md`, `FIXING_TESTS.md`, `plan_for_e2e_tests.md`
- Project overview (client): `README.md`, `CLAUDE.md`

Keep this handbook updated when architecture or workflows change so future agents can onboard instantly.
