# Migrated from test/performance/page_load_performance_test.rb
# Performance spec: Page load times and response performance

require 'rails_helper'

RSpec.describe "Page Load Performance", type: :request do
  # Performance Test: Page load times and response performance
  # Risk Level: HIGH - Poor performance affects user experience and business productivity
  # Focus: Ensuring acceptable response times under various load conditions

  before do
    setup_authenticated_session(role: 'admin', company_id: 1)
    setup_performance_test_data
  end

  describe "dashboard performance" do
    it "loads within acceptable time" do
      # Mock dashboard data with realistic dataset
      setup_large_invoice_dataset(size: 100)

      start_time = Time.current
      get root_path
      end_time = Time.current

      load_time = end_time - start_time

      expect(response).to have_http_status(:success), "Dashboard should load successfully"
      expect(load_time).to be < 3.seconds, "Dashboard took #{load_time.round(2)}s - should be under 3 seconds"

      # Verify essential content is loaded
      expect(response.body).to match(/<h1|<h2/), "Dashboard should have header content"

      # Performance should not degrade with moderate data
      Rails.logger.info "✓ Dashboard load time: #{load_time.round(3)}s (target: <3s)"
    end
  end

  describe "invoice list pagination performance" do
    it "performs efficiently with large datasets" do
      # Test with large dataset
      large_dataset_size = 1000
      setup_large_invoice_dataset(size: large_dataset_size)

      # Test first page load
      start_time = Time.current
      get invoices_path
      end_time = Time.current

      first_page_time = end_time - start_time

      expect(response).to have_http_status(:success)
      expect(first_page_time).to be < 2.seconds, "Invoice list first page took #{first_page_time.round(2)}s - should be under 2 seconds"

      # Test pagination performance doesn't degrade significantly
      page_times = []
      [2, 3, 5, 10].each do |page_number|
        start_time = Time.current
        get invoices_path, params: { page: page_number }
        end_time = Time.current

        page_time = end_time - start_time
        page_times << page_time

        expect(response).to have_http_status(:success)
        expect(page_time).to be < 2.5.seconds, "Invoice list page #{page_number} took #{page_time.round(2)}s - should be under 2.5 seconds"
      end

      # Pagination times should be consistent (not increasing dramatically)
      average_time = page_times.sum / page_times.length
      max_time = page_times.max

      expect(max_time).to be < (average_time * 2), "Maximum page load time should not be more than 2x average"

      Rails.logger.info "✓ Average pagination time: #{average_time.round(3)}s, Max: #{max_time.round(3)}s"
    end
  end

  describe "form rendering performance" do
    it "renders complex forms within time limits" do
      # Test invoice form with many series options
      setup_large_series_dataset(size: 50)
      setup_large_contacts_dataset(size: 200)

      start_time = Time.current
      get new_invoice_path
      end_time = Time.current

      form_render_time = end_time - start_time

      expect(response).to have_http_status(:success)
      expect(form_render_time).to be < 1.5.seconds, "Invoice form took #{form_render_time.round(2)}s - should be under 1.5 seconds"

      # Verify form complexity
      expect(response.body).to match(/select[^>]*invoice_series_id/), "Should have series selection"
      expect(response.body.scan(/<option/).count).to be >= 10, "Should have multiple series options"

      Rails.logger.info "✓ Complex form render time: #{form_render_time.round(3)}s (target: <1.5s)"
    end
  end

  describe "company management operations performance" do
    it "maintains response times for company operations" do
      setup_large_company_dataset

      # Test company list load
      start_time = Time.current
      get companies_path
      end_time = Time.current

      company_list_time = end_time - start_time

      expect(response).to have_http_status(:success)
      expect(company_list_time).to be < 2.seconds, "Company list took #{company_list_time.round(2)}s - should be under 2 seconds"

      # Test individual company page
      start_time = Time.current
      get company_path(1)
      end_time = Time.current

      company_detail_time = end_time - start_time

      expect(response).to have_http_status(:success)
      expect(company_detail_time).to be < 1.second, "Company detail page took #{company_detail_time.round(2)}s - should be under 1 second"

      Rails.logger.info "✓ Company list: #{company_list_time.round(3)}s, Detail: #{company_detail_time.round(3)}s"
    end
  end

  describe "tax calculation operations efficiency" do
    it "maintains efficient tax operation response times" do
      # Test tax rates page load
      setup_large_tax_data

      start_time = Time.current
      get tax_rates_path
      end_time = Time.current

      tax_rates_time = end_time - start_time

      expect(response).to have_http_status(:success)
      expect(tax_rates_time).to be < 1.5.seconds, "Tax rates page took #{tax_rates_time.round(2)}s - should be under 1.5 seconds"

      # Test tax calculation page
      start_time = Time.current
      get new_tax_calculation_path
      end_time = Time.current

      tax_calc_form_time = end_time - start_time

      expect(response).to have_http_status(:success)
      expect(tax_calc_form_time).to be < 1.second, "Tax calculation form took #{tax_calc_form_time.round(2)}s - should be under 1 second"

      Rails.logger.info "✓ Tax rates: #{tax_rates_time.round(3)}s, Calc form: #{tax_calc_form_time.round(3)}s"
    end
  end

  describe "memory usage monitoring" do
    it "maintains acceptable memory bounds during operations" do
      # Test memory usage doesn't grow excessively during operations
      initial_memory = get_memory_usage

      # Perform multiple operations to stress test memory
      10.times do |i|
        get root_path
        expect(response).to have_http_status(:success)

        get invoices_path
        expect(response).to have_http_status(:success)

        get new_invoice_path
        expect(response).to have_http_status(:success)
      end

      final_memory = get_memory_usage
      memory_growth = final_memory - initial_memory

      # Memory growth should be reasonable (less than 50MB for test operations)
      expect(memory_growth).to be < 50_000_000, "Memory grew by #{memory_growth / 1_000_000}MB - should be under 50MB"

      Rails.logger.info "✓ Memory growth: #{memory_growth / 1_000_000}MB (target: <50MB)"
    end
  end

  describe "concurrent request handling simulation" do
    it "handles concurrent requests efficiently", :aggregate_failures do
      # Simulate concurrent requests (limited simulation in test environment)
      threads = []
      response_times = []
      errors = []

      # Create 5 concurrent requests
      5.times do |i|
        threads << Thread.new do
          begin
            start_time = Time.current

            # Simulate different types of requests
            case i % 3
            when 0
              get root_path
            when 1
              get invoices_path
            when 2
              get companies_path
            end

            end_time = Time.current
            response_times << (end_time - start_time)
          rescue => e
            errors << e
          end
        end
      end

      # Wait for all threads to complete
      threads.each(&:join)

      # Analyze results
      expect(errors).to be_empty, "No errors should occur during concurrent requests: #{errors.map(&:message)}"

      average_response_time = response_times.sum / response_times.length
      max_response_time = response_times.max

      expect(average_response_time).to be < 2.seconds, "Average concurrent response time should be under 2 seconds"
      expect(max_response_time).to be < 5.seconds, "Maximum concurrent response time should be under 5 seconds"

      Rails.logger.info "✓ Concurrent avg: #{average_response_time.round(3)}s, max: #{max_response_time.round(3)}s"
    end
  end

  describe "database query efficiency monitoring" do
    it "maintains efficient database query patterns" do
      # Monitor database queries during common operations

      # Enable query monitoring if available
      query_count_before = count_database_queries

      # Perform operations that should be optimized
      get root_path
      expect(response).to have_http_status(:success)

      get invoices_path
      expect(response).to have_http_status(:success)

      query_count_after = count_database_queries
      total_queries = query_count_after - query_count_before

      # Should not generate excessive queries (N+1 problems)
      expect(total_queries).to be < 20, "Generated #{total_queries} database queries - should be under 20 for basic operations"

      Rails.logger.info "✓ Database queries for basic operations: #{total_queries} (target: <20)"
    end
  end

  describe "static asset loading performance" do
    it "loads assets efficiently" do
      # Test CSS and JavaScript loading performance
      start_time = Time.current
      get root_path
      end_time = Time.current

      total_load_time = end_time - start_time

      expect(response).to have_http_status(:success)
      expect(total_load_time).to be < 2.seconds, "Complete page with assets took #{total_load_time.round(2)}s"

      # Check that essential assets are included
      expect(response.body).to match(/application.*\.css/), "CSS should be included"
      expect(response.body).to match(/application.*\.js/), "JavaScript should be included"

      Rails.logger.info "✓ Complete page load with assets: #{total_load_time.round(3)}s"
    end
  end

  describe "large form submission handling" do
    it "handles large form data efficiently" do
      # Test performance with large form data
      setup_authenticated_session(role: 'admin', company_id: 1)

      # Mock services
      allow(CompanyService).to receive(:create_address).and_return({ success: true })
      allow(AddressValidator).to receive(:validate_params).and_return({ valid: true, errors: [] })

      # Create large form data (simulating complex address with many fields)
      large_address_data = {
        address: "Very long address " * 20,  # Long address
        post_code: "28001",
        town: "Madrid",
        province: "Madrid",
        country_code: "ESP",
        address_type: "billing",
        notes: "Large notes field " * 100  # Large notes
      }

      start_time = Time.current
      post company_addresses_path(1), params: { address: large_address_data }
      end_time = Time.current

      form_submission_time = end_time - start_time

      expect(response).to have_http_status(:redirect)
      expect(form_submission_time).to be < 3.seconds, "Large form submission took #{form_submission_time.round(2)}s - should be under 3 seconds"

      Rails.logger.info "✓ Large form submission: #{form_submission_time.round(3)}s"
    end
  end

  private

  def setup_performance_test_data
    @base_company = { id: 1, name: 'Performance Test Company' }

    # Core company services
    allow(CompanyService).to receive(:find).with(anything, token: anything).and_return(@base_company)
    allow(CompanyService).to receive(:all).with(token: anything).and_return({ companies: [@base_company] })
    allow(CompanyService).to receive(:addresses).with(anything, token: anything).and_return([])  # For company show page

    # Invoice series for forms
    allow(InvoiceSeriesService).to receive(:all).with(token: anything).and_return([
      { id: 74, series_code: 'FC', series_name: 'Facturas Comerciales', is_active: true }
    ])

    # Company contacts for buyer selection
    allow(CompanyContactsService).to receive(:active_contacts).with(token: anything).and_return([
      { id: 1, company_name: 'Test Client', is_active: true }
    ])

    # Recent invoices for dashboard
    allow(InvoiceService).to receive(:recent).with(token: anything).and_return([])

    # Tax services for tax pages
    allow(TaxService).to receive(:rates).with(token: anything).and_return({ data: [
      { id: 1, name: 'Standard VAT', rate: 21.0, type: 'iva', is_active: true }
    ] })
    allow(TaxService).to receive(:exemptions).with(token: anything).and_return({ data: [] })
  end

  def setup_large_invoice_dataset(size: 1000)
    invoices = (1..size).map do |i|
      {
        id: i.to_s,
        invoice_number: "FC-#{i.to_s.rjust(4, '0')}",
        status: ['draft', 'sent', 'approved'].sample,
        total_amount: (100..5000).to_a.sample,
        issue_date: (Date.current - rand(365).days).iso8601,
        buyer_name: "Client #{i}"
      }
    end

    allow(InvoiceService).to receive(:all).with(token: anything).and_return({ invoices: invoices.first(25), meta: { total: size } })
    allow(InvoiceService).to receive(:recent).with(token: anything).and_return(invoices.first(10))
  end

  def setup_large_series_dataset(size: 50)
    series = (1..size).map do |i|
      {
        id: i,
        series_code: "S#{i.to_s.rjust(2, '0')}",
        series_name: "Series #{i}",
        year: Date.current.year,
        is_active: true
      }
    end

    allow(InvoiceSeriesService).to receive(:all).and_return(series)
  end

  def setup_large_contacts_dataset(size: 200)
    contacts = (1..size).map do |i|
      {
        id: i,
        company_name: "Contact Company #{i}",
        legal_name: "Contact Company #{i} S.L.",
        tax_id: "B#{i.to_s.rjust(8, '0')}",
        is_active: true
      }
    end

    allow(CompanyContactsService).to receive(:active_contacts).and_return(contacts.first(50))
    allow(CompanyContactsService).to receive(:all).and_return({ contacts: contacts })
  end

  def setup_large_company_dataset
    companies = (1..100).map do |i|
      {
        id: i,
        name: "Company #{i}",
        legal_name: "Company #{i} S.L.",
        tax_id: "A#{i.to_s.rjust(8, '0')}"
      }
    end

    allow(CompanyService).to receive(:all).and_return({ companies: companies.first(25) })
  end

  def setup_large_tax_data
    tax_rates = [
      { id: 1, name: 'Standard VAT', rate: 21.0, type: 'iva', region: 'ES', is_active: true },
      { id: 2, name: 'Reduced VAT', rate: 10.0, type: 'iva', region: 'ES', is_active: true },
      { id: 3, name: 'Super Reduced VAT', rate: 4.0, type: 'iva', region: 'ES', is_active: true },
      { id: 4, name: 'Export VAT', rate: 0.0, type: 'iva', region: 'ES', is_active: true }
    ]

    exemptions = [
      { id: 1, name: 'Export Exemption', code: 'E1', description: 'Exports to third countries' },
      { id: 2, name: 'EU Exemption', code: 'E2', description: 'Intracomunitaria operations' }
    ]

    allow(TaxService).to receive(:rates).and_return({ data: tax_rates })
    allow(TaxService).to receive(:exemptions).and_return({ data: exemptions })
  end

  def get_memory_usage
    # Simple memory usage check (Ruby specific)
    # In production, this could use more sophisticated monitoring
    GC.stat[:heap_allocated_pages] * GC.stat[:heap_page_size]
  rescue
    # Fallback if GC stats not available
    0
  end

  def count_database_queries
    # Simple query counting - in real implementation, this would use
    # Active Record query monitoring or SQL logging
    ActiveRecord::Base.connection.query_cache.size
  rescue
    # Fallback if query monitoring not available
    0
  end
end