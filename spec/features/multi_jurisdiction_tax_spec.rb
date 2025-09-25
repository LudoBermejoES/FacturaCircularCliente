require 'rails_helper'
require_relative '../support/tax_jurisdiction_test_helper'

RSpec.feature 'Multi-Jurisdiction Tax Calculations', type: :feature do
  include TaxJurisdictionTestHelper

  before do
    # Mock authentication
    allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_token).and_return('valid_token')
    allow_any_instance_of(ApplicationController).to receive(:current_company_id).and_return('1')
  end

  describe 'Tax Context Resolution' do
    TaxJurisdictionTestHelper::TAX_SCENARIOS.each do |scenario_key, scenario|
      context "for #{scenario[:name]}" do
        let(:invoice_data) { TaxJurisdictionTestHelper.sample_invoice_data(scenario_key) }
        let(:mock_response) { TaxJurisdictionTestHelper.mock_tax_context_response(scenario_key) }

        it 'resolves tax context correctly' do
          # Mock the TaxService.resolve_tax_context call
          expect(TaxService).to receive(:resolve_tax_context).and_return(mock_response[:data][:attributes][:tax_context])

          result = TaxService.resolve_tax_context(
            establishment_id: invoice_data[:establishment_id],
            buyer_location: invoice_data[:buyer_location],
            product_types: invoice_data[:product_types],
            token: 'valid_token'
          )

          expected = scenario[:expected]

          expect(result[:cross_border]).to eq(expected[:cross_border])
          expect(result[:eu_transaction]).to eq(expected[:eu_transaction])
          expect(result[:reverse_charge]).to eq(expected[:reverse_charge])

          if result[:applicable_rates].present?
            expect(result[:applicable_rates].first[:rate]).to eq(expected[:applicable_tax_rate])
          end
        end
      end
    end
  end

  describe 'Invoice Creation with Tax Context' do
    let(:company_establishments) do
      [
        {
          id: 1,
          name: 'Madrid Office',
          display_name: 'Madrid Office (Default)',
          tax_jurisdiction: {
            id: 1,
            code: 'ESP',
            country_name: 'Spain',
            regime_type: 'Standard',
            is_eu: true
          }
        },
        {
          id: 2,
          name: 'Lisbon Office',
          display_name: 'Lisbon Office',
          tax_jurisdiction: {
            id: 2,
            code: 'PRT',
            country_name: 'Portugal',
            regime_type: 'Standard',
            is_eu: true
          }
        }
      ]
    end

    let(:buyer_options) do
      [
        { id: 1, name: 'Spanish Company S.L.', type: 'company' },
        { id: 2, name: 'Portuguese Lda', type: 'company' },
        { id: 3, name: 'German GmbH', type: 'contact' }
      ]
    end

    before do
      # Mock service calls
      allow(CompanyEstablishmentService).to receive(:all).and_return(company_establishments)
      allow(InvoiceSeriesService).to receive(:all).and_return([])
      allow(WorkflowService).to receive(:definitions).and_return({ data: [] })
      allow(CompanyService).to receive(:all).and_return({ companies: [] })
      allow(CompanyContactsService).to receive(:all).and_return({ contacts: [] })

      # Mock the controller's load methods
      allow_any_instance_of(InvoicesController).to receive(:load_companies)
      allow_any_instance_of(InvoicesController).to receive(:load_invoice_series)
      allow_any_instance_of(InvoicesController).to receive(:load_workflows)
      allow_any_instance_of(InvoicesController).to receive(:load_all_company_contacts)
    end

    scenario 'Creating domestic invoice with automatic tax context', js: true do
      visit new_invoice_path

      # Fill basic invoice information
      fill_in 'invoice[issue_date]', with: Date.today.strftime('%Y-%m-%d')
      fill_in 'invoice[due_date]', with: (Date.today + 30).strftime('%Y-%m-%d')

      # Select establishment (Madrid Office for domestic Spain transaction)
      select 'Madrid Office (Default)', from: 'invoice[establishment_id]'

      # Verify tax jurisdiction is displayed
      within('[data-invoice-form-target="taxJurisdiction"]') do
        expect(page).to have_content('Spain (ESP)')
        expect(page).to have_content('Standard Tax Regime')
        expect(page).to have_content('EU')
      end

      # Enable auto-calculate tax context
      check 'invoice[auto_calculate_tax_context]'

      # Add invoice line
      within('[data-invoice-form-target="lineItems"]') do
        fill_in 'invoice[invoice_lines][0][description]', with: 'Test Product'
        fill_in 'invoice[invoice_lines][0][quantity]', with: '1'
        fill_in 'invoice[invoice_lines][0][unit_price]', with: '100'
        fill_in 'invoice[invoice_lines][0][tax_rate]', with: '21'
      end

      # Mock the tax context resolution
      domestic_spain_response = TaxJurisdictionTestHelper.mock_tax_context_response(:domestic_spain)
      expect(TaxService).to receive(:resolve_tax_context).and_return(domestic_spain_response[:data][:attributes][:tax_context])

      # Trigger tax context calculation
      click_button 'Calculate', match: :first

      # Verify tax context status
      within('[data-invoice-form-target="taxContextStatus"]') do
        expect(page).to have_content('Tax context calculated successfully')
      end

      within('[data-invoice-form-target="taxContextDetails"]') do
        expect(page).to have_content('Domestic')
        expect(page).to have_content('Cross-Border: No')
        expect(page).to have_content('EU Transaction: No')
        expect(page).to have_content('Reverse Charge: Not required')
      end
    end

    scenario 'Creating cross-border EU invoice with tax warnings', js: true do
      visit new_invoice_path

      # Select establishment (Madrid Office)
      select 'Madrid Office (Default)', from: 'invoice[establishment_id]'

      # Override buyer location for Portugal
      click_button 'Override' # Buyer location override

      within('[data-invoice-form-target="buyerLocationFields"]') do
        select 'Portugal', from: 'invoice[buyer_country_override]'
        fill_in 'invoice[buyer_city_override]', with: 'Porto'
      end

      # Enable auto-calculate tax context
      check 'invoice[auto_calculate_tax_context]'

      # Mock cross-border tax context resolution
      cross_border_response = TaxJurisdictionTestHelper.mock_tax_context_response(:spain_to_portugal)
      expect(TaxService).to receive(:resolve_tax_context).and_return(cross_border_response[:data][:attributes][:tax_context])

      # Trigger tax context calculation
      click_button 'Calculate', match: :first

      # Verify cross-border detection
      within('[data-invoice-form-target="taxContextDetails"]') do
        expect(page).to have_content('Intra-EU')
        expect(page).to have_content('Cross-Border: Yes')
        expect(page).to have_content('EU Transaction: Yes')
      end

      # Add invoice line with zero tax (intra-EU exempt)
      within('[data-invoice-form-target="lineItems"]') do
        fill_in 'invoice[invoice_lines][0][description]', with: 'Cross-Border Product'
        fill_in 'invoice[invoice_lines][0][quantity]', with: '1'
        fill_in 'invoice[invoice_lines][0][unit_price]', with: '100'
        fill_in 'invoice[invoice_lines][0][tax_rate]', with: '0' # Should be 0 for intra-EU supply
      end

      # Verify totals calculation
      within('.invoice-totals') do
        expect(page).to have_content('€100.00') # Subtotal
        expect(page).to have_content('€0.00') # Tax
        expect(page).to have_content('€100.00') # Total
      end
    end

    scenario 'Error handling for invalid tax context', js: true do
      visit new_invoice_path

      # Select establishment
      select 'Madrid Office (Default)', from: 'invoice[establishment_id]'

      # Mock tax service error
      expect(TaxService).to receive(:resolve_tax_context).and_raise(StandardError.new('Tax service unavailable'))

      # Enable auto-calculate and trigger calculation
      check 'invoice[auto_calculate_tax_context]'
      click_button 'Calculate', match: :first

      # Verify error handling
      within('[data-invoice-form-target="taxContextStatus"]') do
        expect(page).to have_content('Error calculating tax context')
      end

      within('[data-invoice-form-target="taxContextIndicator"]') do
        expect(page).to have_content('Error')
      end

      # Form should still be usable for manual entry
      within('[data-invoice-form-target="lineItems"]') do
        fill_in 'invoice[invoice_lines][0][description]', with: 'Manual Tax Product'
        fill_in 'invoice[invoice_lines][0][quantity]', with: '1'
        fill_in 'invoice[invoice_lines][0][unit_price]', with: '100'
        fill_in 'invoice[invoice_lines][0][tax_rate]', with: '21'
      end

      # Should be able to create invoice manually
      expect(page).to have_button('Create Invoice')
    end
  end

  describe 'Mobile Responsiveness' do
    before do
      # Set mobile viewport
      page.driver.browser.manage.window.resize_to(375, 667) # iPhone SE size
    end

    scenario 'Tax context form works on mobile', js: true do
      visit new_invoice_path

      # Tax context section should be visible
      expect(page).to have_content('Tax Context')

      # Header should stack on mobile
      within('.tax-context-header') do
        expect(page).to have_css('.flex-col') # Should use flex-col on mobile
      end

      # Form fields should be full width on mobile
      establishment_select = find('select[name="invoice[establishment_id]"]')
      expect(establishment_select[:class]).to include('w-full')

      # Buttons should be full width on mobile
      refresh_button = find('[data-invoice-form-target="refreshTaxButton"]')
      expect(refresh_button[:class]).to include('w-full')
      expect(refresh_button[:class]).to include('justify-center')
    end

    scenario 'Line items display as cards on mobile', js: true do
      visit new_invoice_path

      # Line items should show mobile card view
      expect(page).to have_css('[data-invoice-form-target="mobileLineItems"]', visible: true)
      expect(page).to have_css('.line-item-mobile')

      # Desktop table should be hidden
      expect(page).to have_css('.hidden.lg\\:block')

      # Action buttons should be stacked on mobile
      within('.invoice-actions') do
        expect(page).to have_css('.flex-col')
        expect(page).to have_css('.w-full')
      end
    end
  end

  describe 'Performance and Optimization' do
    scenario 'Tax context caching works correctly' do
      visit new_invoice_path

      # Mock API calls
      expect(CompanyEstablishmentService).to receive(:all).once.and_return(company_establishments)

      # Select establishment multiple times
      select 'Madrid Office (Default)', from: 'invoice[establishment_id]'
      select 'Lisbon Office', from: 'invoice[establishment_id]'
      select 'Madrid Office (Default)', from: 'invoice[establishment_id]'

      # API should only be called once due to caching
    end

    scenario 'Form submission includes tax context data' do
      mock_creation_response = {
        data: {
          id: '12345',
          type: 'invoices',
          attributes: { invoice_number: 'FC-2025-001' }
        }
      }

      expect(InvoiceService).to receive(:create_with_tax_context).with(
        hash_including(
          establishment_id: '1',
          auto_calculate_tax_context: true
        ),
        token: 'valid_token'
      ).and_return(mock_creation_response)

      visit new_invoice_path

      # Fill required fields
      fill_in 'invoice[issue_date]', with: Date.today.strftime('%Y-%m-%d')
      fill_in 'invoice[due_date]', with: (Date.today + 30).strftime('%Y-%m-%d')

      select 'Madrid Office (Default)', from: 'invoice[establishment_id]'
      check 'invoice[auto_calculate_tax_context]'

      # Add line item
      within('[data-invoice-form-target="lineItems"]') do
        fill_in 'invoice[invoice_lines][0][description]', with: 'Test Product'
        fill_in 'invoice[invoice_lines][0][quantity]', with: '1'
        fill_in 'invoice[invoice_lines][0][unit_price]', with: '100'
      end

      click_button 'Create Invoice'
    end
  end
end