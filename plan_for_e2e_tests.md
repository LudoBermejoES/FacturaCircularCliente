# E2E Testing Migration Plan: From RSpec/Capybara to Playwright

## Executive Summary

This document outlines a comprehensive plan to migrate the FacturaCircular client application's end-to-end tests from RSpec/Capybara with Selenium to Playwright, addressing current timeout issues and improving test reliability, speed, and maintainability.

## Current Problems with RSpec/Capybara + Selenium

### 1. Timeout Issues
- Selenium Grid connection timeouts in Docker environment
- Capybara server boot timeouts (especially with Puma)
- WebDriver session creation delays
- Network communication overhead between containers

### 2. Complexity
- Multiple layers of abstraction (RSpec → Capybara → Selenium → Chrome)
- Complex configuration for Docker networking
- Difficult debugging when tests fail
- Flaky tests due to timing issues

### 3. Performance
- Slow test execution
- Heavy resource consumption
- Long startup times for test server

## Why Playwright?

### Advantages
1. **Built for Modern Web Apps**: Native support for SPAs, async operations, and complex interactions
2. **Better Performance**: Direct browser communication without WebDriver protocol
3. **Superior Debugging**: Trace viewer, screenshots, videos, and step-by-step debugging
4. **Auto-waiting**: Intelligent waiting for elements, reducing flakiness
5. **Multiple Browser Support**: Chromium, Firefox, and WebKit in one tool
6. **Docker-friendly**: Official Docker images with all dependencies
7. **Parallel Execution**: Built-in support for parallel test execution
8. **Network Interception**: Mock API calls directly without additional tools

## Migration Strategy

### Phase 1: Setup Playwright Infrastructure (Week 1)

#### 1.1 Docker Setup
```yaml
# docker-compose.yml addition
services:
  playwright:
    container_name: factura-circular-playwright
    build:
      context: .
      dockerfile: Dockerfile.playwright
    volumes:
      - ./e2e:/app/e2e
      - ./playwright-report:/app/playwright-report
      - ./test-results:/app/test-results
    environment:
      - BASE_URL=http://web:3000
      - API_URL=http://albaranes-api:3000/api/v1
      - CI=${CI:-false}
    networks:
      - factura-shared
    command: npx playwright test
```

#### 1.2 Dockerfile for Playwright
```dockerfile
# Dockerfile.playwright
FROM mcr.microsoft.com/playwright:v1.40.0-focal

WORKDIR /app

# Copy package files
COPY e2e/package*.json ./

# Install dependencies
RUN npm ci

# Copy test files
COPY e2e/ .

# Install browsers
RUN npx playwright install
```

#### 1.3 Project Structure
```
client/
├── e2e/
│   ├── tests/
│   │   ├── auth/
│   │   │   ├── login.spec.ts
│   │   │   └── logout.spec.ts
│   │   ├── invoices/
│   │   │   ├── create-invoice.spec.ts
│   │   │   ├── invoice-calculations.spec.ts
│   │   │   └── invoice-workflow.spec.ts
│   │   ├── workflows/
│   │   │   └── sla-tracking.spec.ts
│   │   └── smoke/
│   │       └── critical-path.spec.ts
│   ├── fixtures/
│   │   ├── auth.fixture.ts
│   │   ├── api-mocks.fixture.ts
│   │   └── test-data.fixture.ts
│   ├── pages/
│   │   ├── base.page.ts
│   │   ├── login.page.ts
│   │   ├── invoice.page.ts
│   │   └── dashboard.page.ts
│   ├── utils/
│   │   ├── helpers.ts
│   │   └── api-client.ts
│   ├── playwright.config.ts
│   ├── package.json
│   └── tsconfig.json
```

### Phase 2: Core Test Implementation (Week 2)

#### 2.1 Playwright Configuration
```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['html'],
    ['json', { outputFile: 'test-results/results.json' }],
    ['junit', { outputFile: 'test-results/junit.xml' }],
  ],
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3002',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    actionTimeout: 15000,
    navigationTimeout: 30000,
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'mobile',
      use: { ...devices['iPhone 13'] },
    },
  ],
  webServer: process.env.CI ? undefined : {
    command: 'npm run dev',
    port: 3002,
    timeout: 120 * 1000,
    reuseExistingServer: !process.env.CI,
  },
});
```

#### 2.2 Page Object Model Example
```typescript
// pages/invoice.page.ts
import { Page, Locator } from '@playwright/test';

export class InvoicePage {
  readonly page: Page;
  readonly addLineButton: Locator;
  readonly generalDiscountsInput: Locator;
  readonly generalSurchargesInput: Locator;
  readonly subtotalDisplay: Locator;
  readonly totalDisplay: Locator;

  constructor(page: Page) {
    this.page = page;
    this.addLineButton = page.getByRole('button', { name: 'Add Line' });
    this.generalDiscountsInput = page.getByLabel('General Discounts');
    this.generalSurchargesInput = page.getByLabel('General Surcharges');
    this.subtotalDisplay = page.getByTestId('subtotal-amount');
    this.totalDisplay = page.getByTestId('total-amount');
  }

  async addInvoiceLine(description: string, quantity: number, price: number) {
    await this.addLineButton.click();
    const lastRow = this.page.locator('tbody tr').last();
    await lastRow.getByLabel('Item description').fill(description);
    await lastRow.getByLabel('Qty').fill(quantity.toString());
    await lastRow.getByLabel('Unit Price').fill(price.toString());
  }

  async setGlobalFinancials(discounts: number, surcharges: number) {
    await this.generalDiscountsInput.fill(discounts.toString());
    await this.generalSurchargesInput.fill(surcharges.toString());
  }

  async waitForCalculation() {
    // Wait for the calculation to complete
    await this.page.waitForFunction(() => {
      const total = document.querySelector('[data-testid="total-amount"]');
      return total && !total.classList.contains('calculating');
    });
  }
}
```

#### 2.3 Test Example
```typescript
// tests/invoices/invoice-calculations.spec.ts
import { test, expect } from '@playwright/test';
import { InvoicePage } from '../../pages/invoice.page';
import { authenticateUser } from '../../fixtures/auth.fixture';

test.describe('Invoice Global Financial Calculations', () => {
  test.beforeEach(async ({ page }) => {
    await authenticateUser(page);
    await page.goto('/invoices/new');
  });

  test('calculates totals with global financial fields', async ({ page }) => {
    const invoicePage = new InvoicePage(page);

    // Add a line item
    await invoicePage.addInvoiceLine('Software License', 1, 100);

    // Set global financial values
    await invoicePage.setGlobalFinancials(15.50, 8.75);

    // Wait for calculations
    await invoicePage.waitForCalculation();

    // Verify calculations
    await expect(invoicePage.subtotalDisplay).toHaveText('€100.00');
    await expect(invoicePage.totalDisplay).toHaveText('€93.25');
  });
});
```

### Phase 3: API Mocking and Test Data (Week 2)

#### 3.1 API Mock Setup
```typescript
// fixtures/api-mocks.fixture.ts
import { Page } from '@playwright/test';

export async function mockAPIEndpoints(page: Page) {
  // Mock companies endpoint
  await page.route('**/api/v1/companies', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        companies: [
          { id: 1, corporate_name: 'TechSol', trade_name: 'TechSol' }
        ]
      })
    });
  });

  // Mock invoice series
  await page.route('**/api/v1/invoice_series', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        series: [
          { id: 1, series_code: 'FC', series_name: 'Commercial Invoices 2025' }
        ]
      })
    });
  });
}
```

### Phase 4: Migration Execution (Week 3)

#### 4.1 Test Migration Priority
1. **Critical Path Tests** (Day 1-2)
   - Login/Logout
   - Create basic invoice
   - View invoice list

2. **Feature Tests** (Day 3-4)
   - Invoice calculations
   - Workflow transitions
   - SLA tracking

3. **Edge Cases** (Day 5)
   - Error handling
   - Validation
   - Permission checks

#### 4.2 Parallel Development Approach
- Keep RSpec tests running during migration
- Run both test suites in CI initially
- Gradually deprecate RSpec tests as Playwright tests prove stable

### Phase 5: CI/CD Integration (Week 3)

#### 5.1 GitHub Actions Workflow
```yaml
name: E2E Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Start services
        run: docker-compose up -d web api

      - name: Wait for services
        run: |
          docker-compose run --rm playwright npx wait-on \
            http://web:3000 \
            http://api:3000/health \
            -t 60000

      - name: Run Playwright tests
        run: docker-compose run --rm playwright

      - name: Upload test results
        uses: actions/upload-artifact@v3
        if: always()
        with:
          name: playwright-report
          path: playwright-report/
```

### Phase 6: Monitoring and Optimization (Week 4)

#### 6.1 Test Performance Metrics
- Track test execution time
- Monitor flaky test rate
- Measure test coverage

#### 6.2 Debugging Tools Setup
- Configure trace viewer
- Set up video recording for failures
- Implement screenshot comparison tests

## Implementation Commands

### Local Development
```bash
# Install Playwright locally for development
cd client/e2e
npm init -y
npm install --save-dev @playwright/test typescript @types/node

# Install browsers
npx playwright install

# Run tests locally
npx playwright test

# Run with UI mode for debugging
npx playwright test --ui

# Run specific test file
npx playwright test tests/invoices/invoice-calculations.spec.ts

# Generate test code with codegen
npx playwright codegen http://localhost:3002
```

### Docker Execution
```bash
# Build Playwright container
docker-compose build playwright

# Run all tests
docker-compose run --rm playwright

# Run specific test
docker-compose run --rm playwright npx playwright test tests/invoices/invoice-calculations.spec.ts

# Run with specific browser
docker-compose run --rm playwright npx playwright test --project=chromium

# Debug mode with headed browser
docker-compose run --rm -e HEADED=1 playwright npx playwright test --headed

# Open HTML report
docker-compose run --rm playwright npx playwright show-report
```

## Success Metrics

### Performance Targets
- Test execution time: < 5 minutes for full suite
- Parallel execution: 4-8 workers
- Retry success rate: > 95%
- False positive rate: < 1%

### Coverage Goals
- Critical user paths: 100%
- Feature coverage: 80%
- Edge cases: 60%

## Rollback Plan

If Playwright adoption faces issues:
1. Keep RSpec tests as backup for 30 days
2. Document any Playwright-specific issues
3. Maintain dual test execution in CI
4. Gradual rollback with feature flags if needed

## Timeline Summary

| Week | Phase | Deliverables |
|------|-------|-------------|
| 1 | Infrastructure Setup | Docker config, Playwright setup, Project structure |
| 2 | Core Implementation | Page objects, Basic tests, API mocking |
| 3 | Migration & CI/CD | Test migration, GitHub Actions, Parallel execution |
| 4 | Optimization | Performance tuning, Debugging tools, Documentation |

## Conclusion

Migrating to Playwright will provide:
- **Better reliability**: No more timeout issues
- **Faster execution**: 3-5x speed improvement
- **Easier debugging**: Built-in trace viewer and screenshots
- **Lower maintenance**: Auto-waiting and better selectors
- **Modern tooling**: TypeScript, parallel execution, API mocking

The migration can be completed in 4 weeks with minimal disruption to ongoing development.