import { Page, Route } from '@playwright/test';

/**
 * Mock API responses for testing
 */
export async function mockAPIEndpoints(page: Page) {
  const apiUrl = process.env.API_URL || 'http://localhost:3000/api/v1';

  // Mock companies endpoint
  await page.route(`${apiUrl}/companies`, async (route: Route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        companies: [
          { id: 1, corporate_name: 'Tech Solutions SL', trade_name: 'TechSol' },
          { id: 2, corporate_name: 'Green Waste Management', trade_name: 'GreenWaste' },
          { id: 3, corporate_name: 'Consulting Partners', trade_name: 'ConsultPart' },
        ],
      }),
    });
  });

  // Mock company contacts endpoint
  await page.route(`${apiUrl}/company_contacts`, async (route: Route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        company_contacts: [
          { id: 1, name: 'DataCenter Barcelona', display_name: 'DataCenter Barcelona (Contact)' },
          { id: 2, name: 'CloudTech Solutions', display_name: 'CloudTech Solutions (Contact)' },
          { id: 3, name: 'EcoRecycling Madrid', display_name: 'EcoRecycling Madrid (Contact)' },
        ],
      }),
    });
  });

  // Mock invoice series endpoint
  await page.route(`${apiUrl}/invoice_series`, async (route: Route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        series: [
          { id: 1, series_code: 'FC', series_name: 'Facturas Comerciales 2025' },
          { id: 2, series_code: 'PF', series_name: 'Proforma 2025' },
          { id: 3, series_code: 'CR', series_name: 'Notas de Crédito 2025' },
        ],
      }),
    });
  });

  // Mock workflows endpoint
  await page.route(`${apiUrl}/workflows`, async (route: Route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        workflows: [
          { id: 1, name: 'Simple Invoice Workflow', code: 'simple_invoice_workflow' },
          { id: 2, name: 'Complex Approval Workflow', code: 'complex_approval_workflow' },
          { id: 3, name: 'Direct Approval', code: 'direct_approval' },
        ],
      }),
    });
  });

  // Mock invoice creation
  await page.route(`${apiUrl}/invoices`, async (route: Route) => {
    if (route.request().method() === 'POST') {
      await route.fulfill({
        status: 201,
        contentType: 'application/json',
        body: JSON.stringify({
          data: {
            id: '123',
            type: 'invoices',
            attributes: {
              invoice_number: 'FC-2025-0001',
              status: 'draft',
              total: 121.00,
              subtotal: 100.00,
              tax_total: 21.00,
            },
          },
        }),
      });
    } else {
      // GET request - list invoices
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          invoices: [],
          meta: { total: 0, page: 1, pages: 1 },
        }),
      });
    }
  });
}

/**
 * Mock specific invoice with SLA data
 */
export async function mockInvoiceWithSLA(page: Page, invoiceId: string) {
  const apiUrl = process.env.API_URL || 'http://localhost:3000/api/v1';

  await page.route(`${apiUrl}/invoices/${invoiceId}`, async (route: Route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        id: invoiceId,
        invoice_number: 'INV-001',
        status: 'pending_review',
        workflow: {
          entered_current_state_at: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(), // 2 hours ago
          sla_deadline: new Date(Date.now() + 4 * 60 * 60 * 1000).toISOString(), // 4 hours from now
          is_overdue: false,
        },
        total: 1000.00,
        subtotal: 826.45,
        tax_total: 173.55,
      }),
    });
  });
}

/**
 * Mock authentication endpoints
 */
export async function mockAuthEndpoints(page: Page) {
  const apiUrl = process.env.API_URL || 'http://localhost:3000/api/v1';

  // Mock login endpoint
  await page.route(`${apiUrl}/auth/login`, async (route: Route) => {
    const postData = route.request().postDataJSON();

    if (postData.email === 'admin@example.com' && postData.password === 'password123') {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          token: 'mock_jwt_token',
          user: {
            id: 1,
            email: 'admin@example.com',
            name: 'Admin User',
            role: 'admin',
            company_id: 1,
          },
        }),
      });
    } else {
      await route.fulfill({
        status: 401,
        contentType: 'application/json',
        body: JSON.stringify({
          error: 'Invalid credentials',
        }),
      });
    }
  });

  // Mock logout endpoint
  await page.route(`${apiUrl}/auth/logout`, async (route: Route) => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        message: 'Logged out successfully',
      }),
    });
  });
}

/**
 * Helper to setup all common mocks
 */
export async function setupCommonMocks(page: Page) {
  await mockAuthEndpoints(page);
  await mockAPIEndpoints(page);
}