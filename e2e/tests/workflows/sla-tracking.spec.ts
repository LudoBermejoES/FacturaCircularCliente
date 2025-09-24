import { test, expect } from '../../fixtures/auth.fixture';
import { WorkflowPage } from '../../pages/workflow.page';
import { Page } from '@playwright/test';

// Mock time for consistent SLA calculations
const MOCK_CURRENT_TIME = new Date('2024-01-15T10:00:00Z');

test.describe('SLA Tracking System', () => {
  let workflowPage: WorkflowPage;

  test.beforeEach(async ({ authenticatedPage }) => {
    workflowPage = new WorkflowPage(authenticatedPage);

    // Mock time for consistent SLA calculations
    await authenticatedPage.addInitScript(() => {
      const mockDate = new Date('2024-01-15T10:00:00Z');
      Date.now = () => mockDate.getTime();
      Date.prototype.getTime = function() { return mockDate.getTime(); };
    });

    // Setup API mocks with SLA data
    await setupSLAMocks(authenticatedPage);
  });

  test.describe('SLA indicators on invoices index page', () => {
    test('displays correct SLA status indicators for different invoice states', async () => {
      await workflowPage.gotoInvoicesList();

      // Check normal SLA indicator (green - 4 hours remaining)
      const normalSLA = await workflowPage.getInvoiceSLAIndicator('INV-001');
      expect(normalSLA.text).toContain('Due in 4 hours');
      expect(normalSLA.color).toBe('green');

      // Check overdue SLA indicator (red - 1 hour overdue)
      const overdueSLA = await workflowPage.getInvoiceSLAIndicator('INV-002');
      expect(overdueSLA.text).toContain('Overdue by 1 hour');
      expect(overdueSLA.color).toBe('red');

      // Check invoice without SLA (gray)
      const noSLA = await workflowPage.getInvoiceSLAIndicator('INV-004');
      expect(noSLA.text).toContain('No SLA');
      expect(noSLA.color).toBe('gray');
    });

    test('displays warning indicator for approaching deadlines', async () => {
      await workflowPage.gotoInvoicesList();

      // Check warning SLA indicator (yellow - 30 minutes remaining)
      const warningSLA = await workflowPage.getInvoiceSLAIndicator('INV-003');
      expect(warningSLA.text).toContain('Due in 30 minutes');
      expect(warningSLA.color).toBe('yellow');
    });

    test('applies correct styling based on time remaining', async () => {
      await workflowPage.gotoInvoicesList();

      const allIndicators = await workflowPage.getAllInvoiceSLAIndicators();

      // Find specific invoices and verify their styling
      const inv001 = allIndicators.find(i => i.invoiceNumber.includes('INV-001'));
      const inv002 = allIndicators.find(i => i.invoiceNumber.includes('INV-002'));
      const inv003 = allIndicators.find(i => i.invoiceNumber.includes('INV-003'));

      expect(inv001?.slaColor).toBe('green'); // Normal
      expect(inv002?.slaColor).toBe('red');   // Overdue
      expect(inv003?.slaColor).toBe('yellow'); // Warning
    });
  });

  test.describe('detailed SLA information on workflow page', () => {
    test('displays comprehensive SLA details for active invoices', async () => {
      await workflowPage.gotoInvoiceWorkflow('1');

      // Check SLA status section
      const status = await workflowPage.getSLAStatus();
      expect(status.message).toContain('Due in 4 hours');
      expect(status.color).toBe('green');

      // Check detailed SLA section
      const details = await workflowPage.getSLADetails();
      expect(details).not.toBeNull();
      expect(details!.timeInState).toContain('2 hours');
      expect(details!.deadline).toContain('Jan 15, 2024');
      expect(details!.deadline).toContain('14:00'); // Should be 2:00 PM
      expect(details!.isOverdue).toBe(false);
      expect(details!.progress).toBeGreaterThanOrEqual(0);
      expect(details!.progress).toBeLessThanOrEqual(100);
    });

    test('displays overdue SLA details with correct styling', async () => {
      await workflowPage.gotoInvoiceWorkflow('2');

      // Check overdue status
      const status = await workflowPage.getSLAStatus();
      expect(status.message).toContain('Overdue by 1 hour');
      expect(status.color).toBe('red');

      // Check detailed SLA section shows as overdue
      const details = await workflowPage.getSLADetails();
      expect(details).not.toBeNull();
      expect(details!.isOverdue).toBe(true);
    });

    test('handles invoices without SLA deadline', async () => {
      await workflowPage.gotoInvoiceWorkflow('4');

      // Should show "No SLA" status
      const status = await workflowPage.getSLAStatus();
      expect(status.message).toContain('No SLA');
      expect(status.color).toBe('gray');

      // Should not show detailed SLA section
      const details = await workflowPage.getSLADetails();
      expect(details).toBeNull();
    });

    test('calculates and displays correct progress percentage', async () => {
      // Mock invoice that's 50% through its SLA period
      await workflowPage.gotoInvoiceWorkflow('5');

      const details = await workflowPage.getSLADetails();
      expect(details).not.toBeNull();

      // Progress should be around 50% (2 hours passed out of 4 hours total)
      expect(details!.progress).toBeGreaterThanOrEqual(45);
      expect(details!.progress).toBeLessThanOrEqual(55);
    });
  });

  test.describe('edge cases and error handling', () => {
    test('handles missing workflow data gracefully', async () => {
      // Mock invoice without workflow data
      await workflowPage.page.route('**/api/v1/invoices/6', async route => {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({
            id: '6',
            invoice_number: 'INV-006',
            status: 'draft',
            // No workflow key
          }),
        });
      });

      await workflowPage.gotoInvoiceWorkflow('6');

      // Should not show SLA section at all
      await expect(workflowPage.slaStatusBadge).not.toBeVisible();
      await expect(workflowPage.slaDetailsSection).not.toBeVisible();
    });

    test('updates SLA status after workflow transition', async () => {
      await workflowPage.gotoInvoiceWorkflow('1');

      // Get initial status
      const initialStatus = await workflowPage.getSLAStatus();
      expect(initialStatus.color).toBe('green');

      // Mock transition response with new SLA
      await workflowPage.page.route('**/api/v1/workflows/transition', async route => {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({
            success: true,
            workflow: {
              entered_current_state_at: new Date().toISOString(),
              sla_deadline: new Date(Date.now() + 1 * 60 * 60 * 1000).toISOString(), // 1 hour from now
              is_overdue: false,
            },
          }),
        });
      });

      // Perform transition if available
      const transitions = await workflowPage.getAvailableTransitions();
      if (transitions.length > 0) {
        await workflowPage.performTransition(transitions[0]);
        await workflowPage.waitForSLAUpdate();

        // Check updated status
        const updatedStatus = await workflowPage.getSLAStatus();
        expect(updatedStatus.message).toContain('Due in');
      }
    });
  });
});

/**
 * Setup mock data for SLA testing
 */
async function setupSLAMocks(page: Page) {
  const apiUrl = process.env.API_URL || 'http://localhost:3000/api/v1';

  // Mock invoice list with SLA data
  await page.route(`${apiUrl}/invoices`, async route => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        invoices: [
          {
            id: '1',
            invoice_number: 'INV-001',
            status: 'pending_review',
            workflow: {
              entered_current_state_at: '2024-01-15T08:00:00Z', // 2 hours ago
              sla_deadline: '2024-01-15T14:00:00Z', // 4 hours from now
              is_overdue: false,
            },
          },
          {
            id: '2',
            invoice_number: 'INV-002',
            status: 'pending_review',
            workflow: {
              entered_current_state_at: '2024-01-14T08:00:00Z', // Yesterday
              sla_deadline: '2024-01-15T09:00:00Z', // 1 hour ago (overdue)
              is_overdue: true,
            },
          },
          {
            id: '3',
            invoice_number: 'INV-003',
            status: 'pending_review',
            workflow: {
              entered_current_state_at: '2024-01-15T08:00:00Z',
              sla_deadline: '2024-01-15T10:30:00Z', // 30 minutes from now
              is_overdue: false,
            },
          },
          {
            id: '4',
            invoice_number: 'INV-004',
            status: 'draft',
            workflow: {
              entered_current_state_at: '2024-01-15T08:00:00Z',
              // No sla_deadline
            },
          },
        ],
        meta: { total: 4, page: 1, pages: 1 },
      }),
    });
  });

  // Mock individual invoice endpoints
  const invoiceData = [
    {
      id: '1',
      invoice_number: 'INV-001',
      status: 'pending_review',
      workflow: {
        entered_current_state_at: '2024-01-15T08:00:00Z',
        sla_deadline: '2024-01-15T14:00:00Z',
        is_overdue: false,
      },
    },
    {
      id: '2',
      invoice_number: 'INV-002',
      status: 'pending_review',
      workflow: {
        entered_current_state_at: '2024-01-14T08:00:00Z',
        sla_deadline: '2024-01-15T09:00:00Z',
        is_overdue: true,
      },
    },
    {
      id: '3',
      invoice_number: 'INV-003',
      status: 'pending_review',
      workflow: {
        entered_current_state_at: '2024-01-15T08:00:00Z',
        sla_deadline: '2024-01-15T10:30:00Z',
        is_overdue: false,
      },
    },
    {
      id: '4',
      invoice_number: 'INV-004',
      status: 'draft',
      workflow: {
        entered_current_state_at: '2024-01-15T08:00:00Z',
      },
    },
    {
      id: '5',
      invoice_number: 'INV-005',
      status: 'pending_review',
      workflow: {
        entered_current_state_at: '2024-01-15T08:00:00Z', // 2 hours ago
        sla_deadline: '2024-01-15T12:00:00Z', // 2 hours from now (50% through 4-hour SLA)
        is_overdue: false,
      },
    },
  ];

  for (const invoice of invoiceData) {
    await page.route(`${apiUrl}/invoices/${invoice.id}`, async route => {
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(invoice),
      });
    });
  }

  // Mock workflow endpoints
  await page.route(`${apiUrl}/workflows/available_transitions`, async route => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        available_transitions: [
          { name: 'Approve', to_state: 'approved' },
          { name: 'Reject', to_state: 'rejected' },
        ],
      }),
    });
  });

  await page.route(`${apiUrl}/workflows/history`, async route => {
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify([]),
    });
  });
}