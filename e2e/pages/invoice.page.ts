import { Page, Locator } from '@playwright/test';
import { BasePage } from './base.page';

export class InvoicePage extends BasePage {
  // Form fields
  readonly buyerSelect: Locator;
  readonly seriesSelect: Locator;
  readonly workflowSelect: Locator;
  readonly statusSelect: Locator;
  readonly descriptionInput: Locator;

  // Line items
  readonly addLineButton: Locator;
  readonly lineItems: Locator;

  // Global financial fields
  readonly generalDiscountsInput: Locator;
  readonly generalSurchargesInput: Locator;
  readonly financialExpensesInput: Locator;
  readonly reimbursableExpensesInput: Locator;
  readonly withholdingAmountInput: Locator;
  readonly paymentInKindInput: Locator;

  // Totals display
  readonly subtotalDisplay: Locator;
  readonly taxDisplay: Locator;
  readonly totalDisplay: Locator;
  readonly grossBeforeTaxesDisplay: Locator;

  // Actions
  readonly saveButton: Locator;
  readonly submitButton: Locator;
  readonly cancelButton: Locator;

  constructor(page: Page) {
    super(page);

    // Form fields
    this.buyerSelect = page.locator('select#invoice_buyer_id, #buyer_select');
    this.seriesSelect = page.locator('select#invoice_invoice_series_id, #series_select');
    this.workflowSelect = page.locator('select#invoice_workflow_id, #workflow_select');
    this.statusSelect = page.locator('select#invoice_status, #status_select');
    this.descriptionInput = page.locator('textarea#invoice_description, #description');

    // Line items
    this.addLineButton = page.locator('button:has-text("Add Line"), button:has-text("Add Item")');
    this.lineItems = page.locator('tbody tr[data-line-item], .invoice-line-item');

    // Global financial fields
    this.generalDiscountsInput = page.locator('#invoice_total_general_discounts, input[name*="general_discounts"]');
    this.generalSurchargesInput = page.locator('#invoice_total_general_surcharges, input[name*="general_surcharges"]');
    this.financialExpensesInput = page.locator('#invoice_total_financial_expenses, input[name*="financial_expenses"]');
    this.reimbursableExpensesInput = page.locator('#invoice_total_reimbursable_expenses, input[name*="reimbursable_expenses"]');
    this.withholdingAmountInput = page.locator('#invoice_withholding_amount, input[name*="withholding_amount"]');
    this.paymentInKindInput = page.locator('#invoice_payment_in_kind_amount, input[name*="payment_in_kind"]');

    // Totals display
    this.subtotalDisplay = page.locator('[data-testid="subtotal-amount"], .subtotal-amount, dd:has-text("Subtotal")');
    this.taxDisplay = page.locator('[data-testid="tax-amount"], .tax-amount, dd:has-text("Tax")');
    this.totalDisplay = page.locator('[data-testid="total-amount"], .total-amount, dd:has-text("Total")');
    this.grossBeforeTaxesDisplay = page.locator('[data-testid="gross-before-taxes"], .gross-before-taxes, dd:has-text("Gross Before Taxes")');

    // Actions
    this.saveButton = page.locator('button:has-text("Save"), input[type="submit"][value*="Save"]');
    this.submitButton = page.locator('button:has-text("Submit"), button:has-text("Create Invoice")');
    this.cancelButton = page.locator('button:has-text("Cancel"), a:has-text("Cancel")');
  }

  /**
   * Navigate to new invoice page
   */
  async gotoNew() {
    await this.navigate('/invoices/new');
    await this.waitForPageReady();
  }

  /**
   * Navigate to edit invoice page
   */
  async gotoEdit(invoiceId: string) {
    await this.navigate(`/invoices/${invoiceId}/edit`);
    await this.waitForPageReady();
  }

  /**
   * Navigate to invoice list
   */
  async gotoList() {
    await this.navigate('/invoices');
    await this.waitForPageReady();
  }

  /**
   * Add an invoice line item
   */
  async addInvoiceLine(description: string, quantity: number, unitPrice: number, taxRate: number = 21) {
    await this.addLineButton.click();
    await this.page.waitForTimeout(500); // Wait for line to be added

    const lastRow = this.lineItems.last();
    await lastRow.locator('input[name*="description"], textarea[name*="description"]').fill(description);
    await lastRow.locator('input[name*="quantity"]').fill(quantity.toString());
    await lastRow.locator('input[name*="unit_price"]').fill(unitPrice.toString());
    await lastRow.locator('input[name*="tax_rate"]').fill(taxRate.toString());

    // Trigger calculation
    await lastRow.locator('input[name*="unit_price"]').blur();
    await this.page.waitForTimeout(300); // Wait for calculation
  }

  /**
   * Remove an invoice line item
   */
  async removeInvoiceLine(index: number) {
    const removeButton = this.lineItems.nth(index).locator('button:has-text("Remove"), button.remove-line');
    await removeButton.click();
    await this.page.waitForTimeout(300); // Wait for recalculation
  }

  /**
   * Set global financial values
   */
  async setGlobalFinancials(options: {
    generalDiscounts?: number;
    generalSurcharges?: number;
    financialExpenses?: number;
    reimbursableExpenses?: number;
    withholdingAmount?: number;
    paymentInKind?: number;
  }) {
    if (options.generalDiscounts !== undefined) {
      await this.fillField(this.generalDiscountsInput, options.generalDiscounts.toString());
    }
    if (options.generalSurcharges !== undefined) {
      await this.fillField(this.generalSurchargesInput, options.generalSurcharges.toString());
    }
    if (options.financialExpenses !== undefined) {
      await this.fillField(this.financialExpensesInput, options.financialExpenses.toString());
    }
    if (options.reimbursableExpenses !== undefined) {
      await this.fillField(this.reimbursableExpensesInput, options.reimbursableExpenses.toString());
    }
    if (options.withholdingAmount !== undefined) {
      await this.fillField(this.withholdingAmountInput, options.withholdingAmount.toString());
    }
    if (options.paymentInKind !== undefined) {
      await this.fillField(this.paymentInKindInput, options.paymentInKind.toString());
    }

    // Trigger recalculation
    await this.page.keyboard.press('Tab');
    await this.waitForCalculation();
  }

  /**
   * Wait for calculation to complete
   */
  async waitForCalculation() {
    // Wait for any calculating class to be removed
    await this.page.waitForFunction(() => {
      const calculating = document.querySelector('.calculating, [data-calculating="true"]');
      return !calculating;
    }, { timeout: 5000 });

    await this.page.waitForTimeout(300); // Additional buffer
  }

  /**
   * Get total amounts
   */
  async getTotals() {
    await this.waitForCalculation();

    const extractAmount = async (locator: Locator): Promise<number> => {
      const text = await locator.textContent() || '0';
      // Extract number from text like "€100.00" or "Total: €100.00"
      const match = text.match(/[€$£]?\s*([\d,]+\.?\d*)/);
      return match ? parseFloat(match[1].replace(',', '')) : 0;
    };

    return {
      subtotal: await extractAmount(this.subtotalDisplay),
      tax: await extractAmount(this.taxDisplay),
      total: await extractAmount(this.totalDisplay),
      grossBeforeTaxes: await extractAmount(this.grossBeforeTaxesDisplay),
    };
  }

  /**
   * Select buyer
   */
  async selectBuyer(buyerName: string) {
    await this.buyerSelect.selectOption({ label: buyerName });
  }

  /**
   * Select invoice series
   */
  async selectSeries(seriesName: string) {
    await this.seriesSelect.selectOption({ label: seriesName });
  }

  /**
   * Select workflow
   */
  async selectWorkflow(workflowName: string) {
    await this.workflowSelect.selectOption({ label: workflowName });
  }

  /**
   * Save invoice
   */
  async save() {
    await this.saveButton.click();
    await this.waitForAPIResponse('/api/v1/invoices');
  }

  /**
   * Submit invoice
   */
  async submit() {
    await this.submitButton.click();
    await this.waitForAPIResponse('/api/v1/invoices');
  }

  /**
   * Create a complete invoice
   */
  async createCompleteInvoice(data: {
    buyer: string;
    series: string;
    workflow: string;
    description: string;
    lines: Array<{ description: string; quantity: number; unitPrice: number; taxRate?: number }>;
    globalFinancials?: {
      generalDiscounts?: number;
      generalSurcharges?: number;
      financialExpenses?: number;
      reimbursableExpenses?: number;
      withholdingAmount?: number;
      paymentInKind?: number;
    };
  }) {
    await this.gotoNew();

    await this.selectBuyer(data.buyer);
    await this.selectSeries(data.series);
    await this.selectWorkflow(data.workflow);
    await this.fillField(this.descriptionInput, data.description);

    for (const line of data.lines) {
      await this.addInvoiceLine(line.description, line.quantity, line.unitPrice, line.taxRate);
    }

    if (data.globalFinancials) {
      await this.setGlobalFinancials(data.globalFinancials);
    }

    await this.submit();
  }
}