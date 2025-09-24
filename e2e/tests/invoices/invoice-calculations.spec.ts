import { test, expect } from '../../fixtures/auth.fixture';
import { InvoicePage } from '../../pages/invoice.page';
import { setupCommonMocks } from '../../fixtures/api-mocks.fixture';

test.describe('Invoice Global Financial Calculations', () => {
  let invoicePage: InvoicePage;

  test.beforeEach(async ({ authenticatedPage }) => {
    // Setup API mocks
    await setupCommonMocks(authenticatedPage);

    invoicePage = new InvoicePage(authenticatedPage);
    await invoicePage.gotoNew();
  });

  test('JavaScript calculations update totals when global financial fields change', async () => {
    // Add a line item first to have a base subtotal
    await invoicePage.addInvoiceLine('Software License', 1, 100, 21);

    // Wait for line item calculations to complete
    await invoicePage.waitForCalculation();

    // Verify initial subtotal
    const initialTotals = await invoicePage.getTotals();
    expect(initialTotals.subtotal).toBe(100);

    // Test General Discounts calculation
    await invoicePage.setGlobalFinancials({ generalDiscounts: 15.50 });
    let totals = await invoicePage.getTotals();

    // Gross Before Taxes = 100 - 15.50 = 84.50
    expect(totals.grossBeforeTaxes).toBeCloseTo(84.50, 2);

    // Test General Surcharges calculation
    await invoicePage.setGlobalFinancials({ generalSurcharges: 8.75 });
    totals = await invoicePage.getTotals();

    // Gross Before Taxes = 100 - 15.50 + 8.75 = 93.25
    expect(totals.grossBeforeTaxes).toBeCloseTo(93.25, 2);

    // Test Financial Expenses calculation
    await invoicePage.setGlobalFinancials({ financialExpenses: 12.25 });
    totals = await invoicePage.getTotals();

    // Gross Before Taxes = 100 - 15.50 + 8.75 + 12.25 = 105.50
    expect(totals.grossBeforeTaxes).toBeCloseTo(105.50, 2);

    // Test Reimbursable Expenses calculation
    await invoicePage.setGlobalFinancials({ reimbursableExpenses: 22.00 });
    totals = await invoicePage.getTotals();

    // Gross Before Taxes = 100 - 15.50 + 8.75 + 12.25 + 22.00 = 127.50
    expect(totals.grossBeforeTaxes).toBeCloseTo(127.50, 2);

    // Test Withholding Amount calculation
    await invoicePage.setGlobalFinancials({ withholdingAmount: 18.50 });
    totals = await invoicePage.getTotals();

    // Verify final calculations
    // Gross Before Taxes = 100 - 15.50 + 8.75 + 12.25 + 22.00 = 127.50
    expect(totals.grossBeforeTaxes).toBeCloseTo(127.50, 2);

    // Tax on original subtotal = 100 * 0.21 = 21.00
    expect(totals.tax).toBeCloseTo(21.00, 2);

    // Total = 127.50 + 21.00 - 18.50 = 130.00
    expect(totals.total).toBeCloseTo(130.00, 2);

    // Test Payment in Kind (shouldn't affect totals in current implementation)
    await invoicePage.setGlobalFinancials({ paymentInKind: 5.00 });
    totals = await invoicePage.getTotals();

    // Total should remain the same
    expect(totals.total).toBeCloseTo(130.00, 2);
  });

  test('Calculations handle decimal values correctly', async () => {
    // Add a line item
    await invoicePage.addInvoiceLine('Test Service', 1, 99.99, 21);

    // Test with decimal values
    await invoicePage.setGlobalFinancials({
      generalDiscounts: 12.34,
      generalSurcharges: 5.67,
      financialExpenses: 8.90,
      reimbursableExpenses: 3.21,
      withholdingAmount: 7.89,
    });

    const totals = await invoicePage.getTotals();

    // Verify complex calculation: 99.99 - 12.34 + 5.67 + 8.90 + 3.21 = 105.43
    expect(totals.grossBeforeTaxes).toBeCloseTo(105.43, 2);

    // Tax = 99.99 * 0.21 = 20.9979 ≈ 21.00
    expect(totals.tax).toBeCloseTo(21.00, 2);

    // Total = 105.43 + 21.00 - 7.89 = 118.54
    expect(totals.total).toBeCloseTo(118.54, 2);
  });

  test('Calculations handle zero and empty values correctly', async () => {
    // Add a line item
    await invoicePage.addInvoiceLine('Test Service', 1, 100, 21);

    // Test with zero values
    await invoicePage.setGlobalFinancials({
      generalDiscounts: 0,
      generalSurcharges: 0,
    });

    let totals = await invoicePage.getTotals();

    // Should calculate normally with zeros
    expect(totals.grossBeforeTaxes).toBe(100);
    expect(totals.total).toBe(121);

    // Clear fields (empty values should default to 0)
    await invoicePage.generalDiscountsInput.clear();
    await invoicePage.generalSurchargesInput.clear();
    await invoicePage.waitForCalculation();

    totals = await invoicePage.getTotals();

    // Should still calculate correctly
    expect(totals.grossBeforeTaxes).toBe(100);
    expect(totals.total).toBe(121);
  });

  test('Multiple line items interact correctly with global financial fields', async () => {
    // Add first line item
    await invoicePage.addInvoiceLine('Software License', 1, 100, 21);

    // Add second line item
    await invoicePage.addInvoiceLine('Support Service', 2, 50, 21);

    // Wait for calculations
    await invoicePage.waitForCalculation();

    // Subtotal should be 100 + 100 = 200
    let totals = await invoicePage.getTotals();
    expect(totals.subtotal).toBe(200);

    // Add global financial adjustments
    await invoicePage.setGlobalFinancials({
      generalDiscounts: 20.00,
      generalSurcharges: 10.00,
      financialExpenses: 15.00,
    });

    totals = await invoicePage.getTotals();

    // Verify calculations with multiple line items
    // Gross Before Taxes = 200 - 20 + 10 + 15 = 205
    expect(totals.grossBeforeTaxes).toBe(205);

    // Tax on original subtotal = 200 * 0.21 = 42.00
    expect(totals.tax).toBe(42);

    // Total = 205 + 42 = 247.00
    expect(totals.total).toBe(247);
  });

  test('Color coding works for different field types', async () => {
    // Add a line item
    await invoicePage.addInvoiceLine('Test Service', 1, 100, 21);

    // Fill in values
    await invoicePage.setGlobalFinancials({
      generalDiscounts: 10.00,
      generalSurcharges: 5.00,
      withholdingAmount: 8.00,
    });

    // Check that discounts show as negative (red text)
    const discountsDisplay = invoicePage.page.locator('dd:has-text("-€10.00")');
    await expect(discountsDisplay).toBeVisible();
    const discountsClasses = await discountsDisplay.getAttribute('class');
    expect(discountsClasses).toContain('text-red');

    // Check that surcharges show as positive (green text)
    const surchargesDisplay = invoicePage.page.locator('dd:has-text("+€5.00")');
    await expect(surchargesDisplay).toBeVisible();
    const surchargesClasses = await surchargesDisplay.getAttribute('class');
    expect(surchargesClasses).toContain('text-green');

    // Check that withholding shows as negative (red text)
    const withholdingDisplay = invoicePage.page.locator('dd:has-text("-€8.00")');
    await expect(withholdingDisplay).toBeVisible();
    const withholdingClasses = await withholdingDisplay.getAttribute('class');
    expect(withholdingClasses).toContain('text-red');
  });

  test('Form validation for global financial fields', async () => {
    // Add a line item
    await invoicePage.addInvoiceLine('Test Service', 1, 100, 21);

    // Test that fields have correct HTML5 validation attributes
    await expect(invoicePage.generalDiscountsInput).toHaveAttribute('min', '0');
    await expect(invoicePage.generalSurchargesInput).toHaveAttribute('min', '0');
    await expect(invoicePage.financialExpensesInput).toHaveAttribute('min', '0');
    await expect(invoicePage.reimbursableExpensesInput).toHaveAttribute('min', '0');
    await expect(invoicePage.withholdingAmountInput).toHaveAttribute('min', '0');
    await expect(invoicePage.paymentInKindInput).toHaveAttribute('min', '0');

    // Test various valid numeric formats
    await invoicePage.setGlobalFinancials({
      generalDiscounts: 123.45,
      generalSurcharges: 0.99,
      financialExpenses: 1000,
      reimbursableExpenses: 0,
    });

    // All values should be accepted and displayed
    await expect(invoicePage.generalDiscountsInput).toHaveValue('123.45');
    await expect(invoicePage.generalSurchargesInput).toHaveValue('0.99');
    await expect(invoicePage.financialExpensesInput).toHaveValue('1000');
    await expect(invoicePage.reimbursableExpensesInput).toHaveValue('0');
  });
});