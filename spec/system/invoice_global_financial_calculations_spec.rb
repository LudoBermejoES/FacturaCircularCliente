require 'rails_helper'

RSpec.describe 'Invoice Global Financial Calculations', type: :system do
  let(:user) { double('User', id: 1, role: 'admin', company_id: 1, name: 'Test User', email: 'test@example.com') }
  let(:token) { 'test_token_123' }

  before do
    driven_by(:selenium_chrome_headless)

    # Mock authentication
    allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:current_token).and_return(token)
    allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(true)

    # Mock service responses for form setup
    allow(CompanyService).to receive(:all).and_return({
      companies: [
        { id: 1, corporate_name: 'TechSol', trade_name: 'TechSol' }
      ]
    })

    allow(CompanyContactsService).to receive(:all).and_return({
      company_contacts: [
        { id: 13, name: 'DataCenter Barcelona', display_name: 'DataCenter Barcelona (Contact)' }
      ]
    })

    allow(InvoiceSeriesService).to receive(:all).and_return({
      series: [
        { id: 1, series_code: 'FC', series_name: 'Facturas Comerciales 2025' }
      ]
    })

    allow(WorkflowService).to receive(:all).and_return({
      workflows: [
        { id: 1, name: 'Simple Invoice Workflow', code: 'simple_invoice_workflow' }
      ]
    })

    allow(InvoiceService).to receive(:create).and_return({
      id: '5',
      invoice_number: 'FC-0004'
    })
  end

  describe 'Real-time Global Financial Calculations' do
    scenario 'JavaScript calculations update totals when global financial fields change' do
      visit new_invoice_path

      # Add a line item first to have a base subtotal
      click_button 'Add Line'
      within('tbody tr:first-child') do
        fill_in 'Item description', with: 'Software License'
        fill_in 'Qty', with: '1.0'
        fill_in 'Unit Price', with: '100.0'
        fill_in 'Tax %', with: '21.0'
      end

      # Wait for line item calculations to complete
      expect(page).to have_content('Subtotal: €100.00')

      # Test General Discounts calculation
      fill_in 'General Discounts', with: '15.50'
      # JavaScript should update the display
      expect(page).to have_content('General Discounts: -€15.50')

      # Test General Surcharges calculation
      fill_in 'General Surcharges', with: '8.75'
      expect(page).to have_content('General Surcharges: +€8.75')

      # Test Financial Expenses calculation
      fill_in 'Financial Expenses', with: '12.25'
      expect(page).to have_content('Financial Expenses: €12.25')

      # Test Reimbursable Expenses calculation
      fill_in 'Reimbursable Expenses', with: '22.00'
      expect(page).to have_content('Reimbursable Expenses: €22.00')

      # Test Withholding Amount calculation
      fill_in 'Withholding Amount', with: '18.50'
      expect(page).to have_content('Withholding: -€18.50')

      # Test Payment in Kind (shouldn't affect totals in current implementation)
      fill_in 'Payment in Kind', with: '5.00'

      # Verify final calculations
      # Gross Before Taxes = 100 - 15.50 + 8.75 + 12.25 + 22.00 = 127.50
      expect(page).to have_content('Gross Before Taxes: €127.50')

      # Tax on original subtotal = 100 * 0.21 = 21.00
      expect(page).to have_content('Tax: €21.00')

      # Total = 127.50 + 21.00 - 18.50 = 130.00
      expect(page).to have_content('Total: €130.00')
    end

    scenario 'Calculations handle decimal values correctly' do
      visit new_invoice_path

      # Add a line item
      click_button 'Add Line'
      within('tbody tr:first-child') do
        fill_in 'Item description', with: 'Test Service'
        fill_in 'Qty', with: '1.0'
        fill_in 'Unit Price', with: '99.99'
        fill_in 'Tax %', with: '21.0'
      end

      # Test with decimal values
      fill_in 'General Discounts', with: '12.34'
      fill_in 'General Surcharges', with: '5.67'
      fill_in 'Financial Expenses', with: '8.90'
      fill_in 'Reimbursable Expenses', with: '3.21'
      fill_in 'Withholding Amount', with: '7.89'

      # Verify decimal calculations
      expect(page).to have_content('General Discounts: -€12.34')
      expect(page).to have_content('General Surcharges: +€5.67')
      expect(page).to have_content('Financial Expenses: €8.90')
      expect(page).to have_content('Reimbursable Expenses: €3.21')
      expect(page).to have_content('Withholding: -€7.89')

      # Verify complex calculation: 99.99 - 12.34 + 5.67 + 8.90 + 3.21 = 105.43
      expect(page).to have_content('Gross Before Taxes: €105.43')
    end

    scenario 'Calculations handle zero and empty values correctly' do
      visit new_invoice_path

      # Add a line item
      click_button 'Add Line'
      within('tbody tr:first-child') do
        fill_in 'Item description', with: 'Test Service'
        fill_in 'Qty', with: '1.0'
        fill_in 'Unit Price', with: '100.0'
        fill_in 'Tax %', with: '21.0'
      end

      # Test with zero values
      fill_in 'General Discounts', with: '0'
      fill_in 'General Surcharges', with: '0.00'

      expect(page).to have_content('General Discounts: -€0.00')
      expect(page).to have_content('General Surcharges: +€0.00')

      # Test clearing fields (empty values)
      fill_in 'General Discounts', with: ''
      fill_in 'General Surcharges', with: ''

      # Should default to 0 for calculations
      expect(page).to have_content('General Discounts: -€0.00')
      expect(page).to have_content('General Surcharges: +€0.00')
    end

    scenario 'Color coding works for different field types' do
      visit new_invoice_path

      # Add a line item
      click_button 'Add Line'
      within('tbody tr:first-child') do
        fill_in 'Item description', with: 'Test Service'
        fill_in 'Qty', with: '1.0'
        fill_in 'Unit Price', with: '100.0'
        fill_in 'Tax %', with: '21.0'
      end

      # Fill in values and check for color coding
      fill_in 'General Discounts', with: '10.00'
      fill_in 'General Surcharges', with: '5.00'
      fill_in 'Withholding Amount', with: '8.00'

      # Check that discounts and withholding show as negative (red text)
      # and surcharges show as positive (green text)
      general_discounts_element = find('dd', text: '-€10.00')
      expect(general_discounts_element[:class]).to include('text-red-600')

      general_surcharges_element = find('dd', text: '+€5.00')
      expect(general_surcharges_element[:class]).to include('text-green-600')

      withholding_element = find('dd', text: '-€8.00')
      expect(withholding_element[:class]).to include('text-red-600')
    end

    scenario 'Multiple line items interact correctly with global financial fields' do
      visit new_invoice_path

      # Add first line item
      click_button 'Add Line'
      within('tbody tr:nth-child(1)') do
        fill_in 'Item description', with: 'Software License'
        fill_in 'Qty', with: '1.0'
        fill_in 'Unit Price', with: '100.0'
        fill_in 'Tax %', with: '21.0'
      end

      # Add second line item
      click_button 'Add Line'
      within('tbody tr:nth-child(2)') do
        fill_in 'Item description', with: 'Support Service'
        fill_in 'Qty', with: '2.0'
        fill_in 'Unit Price', with: '50.0'
        fill_in 'Tax %', with: '21.0'
      end

      # Subtotal should be 100 + 100 = 200
      expect(page).to have_content('Subtotal: €200.00')

      # Add global financial adjustments
      fill_in 'General Discounts', with: '20.00'
      fill_in 'General Surcharges', with: '10.00'
      fill_in 'Financial Expenses', with: '15.00'

      # Verify calculations with multiple line items
      # Gross Before Taxes = 200 - 20 + 10 + 15 = 205
      expect(page).to have_content('Gross Before Taxes: €205.00')

      # Tax on original subtotal = 200 * 0.21 = 42.00
      expect(page).to have_content('Tax: €42.00')

      # Total = 205 + 42 = 247.00
      expect(page).to have_content('Total: €247.00')
    end
  end

  describe 'Form Validation Integration' do
    scenario 'Global financial fields accept valid numeric input' do
      visit new_invoice_path

      # Test various valid numeric formats
      fill_in 'General Discounts', with: '123.45'
      fill_in 'General Surcharges', with: '0.99'
      fill_in 'Financial Expenses', with: '1000'
      fill_in 'Reimbursable Expenses', with: '0'

      # All values should be accepted
      expect(page).to have_field('General Discounts', with: '123.45')
      expect(page).to have_field('General Surcharges', with: '0.99')
      expect(page).to have_field('Financial Expenses', with: '1000')
      expect(page).to have_field('Reimbursable Expenses', with: '0')
    end

    scenario 'Global financial fields prevent negative values (via HTML5 min attribute)' do
      visit new_invoice_path

      # HTML5 number inputs with min="0" should prevent negative values
      general_discounts_field = find('#invoice_total_general_discounts')
      expect(general_discounts_field[:min]).to eq('0')

      general_surcharges_field = find('#invoice_total_general_surcharges')
      expect(general_surcharges_field[:min]).to eq('0')

      financial_expenses_field = find('#invoice_total_financial_expenses')
      expect(financial_expenses_field[:min]).to eq('0')

      reimbursable_expenses_field = find('#invoice_total_reimbursable_expenses')
      expect(reimbursable_expenses_field[:min]).to eq('0')

      withholding_amount_field = find('#invoice_withholding_amount')
      expect(withholding_amount_field[:min]).to eq('0')

      payment_in_kind_field = find('#invoice_payment_in_kind_amount')
      expect(payment_in_kind_field[:min]).to eq('0')
    end
  end
end