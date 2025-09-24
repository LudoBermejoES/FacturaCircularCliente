import { Page, Locator } from '@playwright/test';
import { BasePage } from './base.page';

export class WorkflowPage extends BasePage {
  // SLA Status Elements
  readonly slaStatusBadge: Locator;
  readonly slaDetailsSection: Locator;
  readonly slaProgressBar: Locator;
  readonly slaDeadlineText: Locator;
  readonly slaTimeInState: Locator;

  // Workflow elements
  readonly statusBadge: Locator;
  readonly transitionButtons: Locator;
  readonly workflowHistory: Locator;
  readonly availableTransitions: Locator;

  // Invoice list elements
  readonly invoiceRows: Locator;
  readonly slaIndicators: Locator;

  constructor(page: Page) {
    super(page);

    // SLA Status Elements
    this.slaStatusBadge = page.locator('[data-testid="sla-status"], .sla-status');
    this.slaDetailsSection = page.locator('[data-testid="sla-details"], .sla-details-section');
    this.slaProgressBar = page.locator('[data-testid="sla-progress"], .sla-progress-bar');
    this.slaDeadlineText = page.locator('[data-testid="sla-deadline"], .sla-deadline');
    this.slaTimeInState = page.locator('[data-testid="time-in-state"], .time-in-state');

    // Workflow elements
    this.statusBadge = page.locator('[data-testid="workflow-status"], .workflow-status');
    this.transitionButtons = page.locator('button[data-transition], .transition-button');
    this.workflowHistory = page.locator('[data-testid="workflow-history"], .workflow-history');
    this.availableTransitions = page.locator('[data-testid="available-transitions"], .available-transitions');

    // Invoice list elements
    this.invoiceRows = page.locator('tbody tr[data-invoice-id], tr.invoice-row');
    this.slaIndicators = page.locator('[data-testid="sla-indicator"], .sla-indicator');
  }

  /**
   * Navigate to invoice workflow page
   */
  async gotoInvoiceWorkflow(invoiceId: string) {
    await this.navigate(`/invoices/${invoiceId}/workflow`);
    await this.waitForPageReady();
  }

  /**
   * Navigate to invoices list
   */
  async gotoInvoicesList() {
    await this.navigate('/invoices');
    await this.waitForPageReady();
  }

  /**
   * Get SLA status for an invoice
   */
  async getSLAStatus(): Promise<{
    status: string;
    color: 'green' | 'yellow' | 'red' | 'gray';
    message: string;
  }> {
    const statusText = await this.slaStatusBadge.textContent() || '';
    const classes = await this.slaStatusBadge.getAttribute('class') || '';

    let color: 'green' | 'yellow' | 'red' | 'gray' = 'gray';
    if (classes.includes('green')) color = 'green';
    else if (classes.includes('yellow')) color = 'yellow';
    else if (classes.includes('red')) color = 'red';

    return {
      status: statusText.trim(),
      color,
      message: statusText.trim(),
    };
  }

  /**
   * Get SLA details
   */
  async getSLADetails(): Promise<{
    timeInState: string;
    deadline: string;
    progress: number;
    isOverdue: boolean;
  } | null> {
    if (!(await this.slaDetailsSection.isVisible())) {
      return null;
    }

    const timeInState = await this.slaTimeInState.textContent() || '';
    const deadline = await this.slaDeadlineText.textContent() || '';

    // Get progress percentage from progress bar
    const progressBar = await this.slaProgressBar.getAttribute('style') || '';
    const widthMatch = progressBar.match(/width:\s*(\d+)%/);
    const progress = widthMatch ? parseInt(widthMatch[1]) : 0;

    // Check if overdue by color class
    const progressClasses = await this.slaProgressBar.getAttribute('class') || '';
    const isOverdue = progressClasses.includes('red') || progressClasses.includes('danger');

    return {
      timeInState: timeInState.replace(/Time in current state:\s*/, '').trim(),
      deadline: deadline.replace(/Deadline:\s*/, '').trim(),
      progress,
      isOverdue,
    };
  }

  /**
   * Get SLA indicator for a specific invoice in the list
   */
  async getInvoiceSLAIndicator(invoiceNumber: string): Promise<{
    text: string;
    color: 'green' | 'yellow' | 'red' | 'gray';
  }> {
    const row = this.page.locator(`tr:has-text("${invoiceNumber}")`);
    const indicator = row.locator('[data-testid="sla-indicator"], .sla-indicator').first();

    const text = await indicator.textContent() || '';
    const classes = await indicator.getAttribute('class') || '';

    let color: 'green' | 'yellow' | 'red' | 'gray' = 'gray';
    if (classes.includes('green')) color = 'green';
    else if (classes.includes('yellow')) color = 'yellow';
    else if (classes.includes('red')) color = 'red';

    return { text: text.trim(), color };
  }

  /**
   * Check if SLA is approaching deadline (warning state)
   */
  async isSLAWarning(): Promise<boolean> {
    const status = await this.getSLAStatus();
    return status.color === 'yellow';
  }

  /**
   * Check if SLA is overdue
   */
  async isSLAOverdue(): Promise<boolean> {
    const status = await this.getSLAStatus();
    return status.color === 'red';
  }

  /**
   * Get all invoice SLA indicators from the list
   */
  async getAllInvoiceSLAIndicators(): Promise<Array<{
    invoiceNumber: string;
    slaText: string;
    slaColor: 'green' | 'yellow' | 'red' | 'gray';
  }>> {
    const rows = await this.invoiceRows.all();
    const indicators = [];

    for (const row of rows) {
      const invoiceNumber = await row.locator('td:first-child').textContent() || '';
      const indicator = row.locator('[data-testid="sla-indicator"], .sla-indicator').first();

      if (await indicator.isVisible()) {
        const text = await indicator.textContent() || '';
        const classes = await indicator.getAttribute('class') || '';

        let color: 'green' | 'yellow' | 'red' | 'gray' = 'gray';
        if (classes.includes('green')) color = 'green';
        else if (classes.includes('yellow')) color = 'yellow';
        else if (classes.includes('red')) color = 'red';

        indicators.push({
          invoiceNumber: invoiceNumber.trim(),
          slaText: text.trim(),
          slaColor: color,
        });
      }
    }

    return indicators;
  }

  /**
   * Perform workflow transition
   */
  async performTransition(transitionName: string) {
    const button = this.page.locator(`button:has-text("${transitionName}")`);
    await button.click();
    await this.waitForAPIResponse('/api/v1/workflows/transition');
  }

  /**
   * Get available workflow transitions
   */
  async getAvailableTransitions(): Promise<string[]> {
    const buttons = await this.transitionButtons.all();
    const transitions = [];

    for (const button of buttons) {
      const text = await button.textContent();
      if (text) transitions.push(text.trim());
    }

    return transitions;
  }

  /**
   * Get current workflow status
   */
  async getCurrentStatus(): Promise<string> {
    return await this.statusBadge.textContent() || '';
  }

  /**
   * Wait for SLA to update
   */
  async waitForSLAUpdate() {
    await this.page.waitForTimeout(1000);
    await this.page.waitForSelector('[data-testid="sla-status"]', { state: 'visible' });
  }
}