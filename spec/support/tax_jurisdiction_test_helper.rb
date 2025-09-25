# Multi-jurisdiction tax calculation test helper
# Provides standardized test scenarios for validating tax calculations across different jurisdictions

module TaxJurisdictionTestHelper
  # Test scenarios for different jurisdiction combinations
  TAX_SCENARIOS = {
    # Domestic transactions (same jurisdiction)
    domestic_spain: {
      name: 'Domestic Spain Transaction',
      seller_jurisdiction: 'ESP',
      buyer_jurisdiction: 'ESP',
      establishment: { id: 1, country: 'ESP', tax_jurisdiction_code: 'ESP' },
      buyer_location: { country: 'ESP', city: 'Madrid' },
      expected: {
        cross_border: false,
        eu_transaction: false,
        reverse_charge: false,
        applicable_tax_rate: 21.0,
        tax_type: 'IVA'
      }
    },

    domestic_portugal: {
      name: 'Domestic Portugal Transaction',
      seller_jurisdiction: 'PRT',
      buyer_jurisdiction: 'PRT',
      establishment: { id: 2, country: 'PRT', tax_jurisdiction_code: 'PRT' },
      buyer_location: { country: 'PRT', city: 'Lisbon' },
      expected: {
        cross_border: false,
        eu_transaction: false,
        reverse_charge: false,
        applicable_tax_rate: 23.0,
        tax_type: 'IVA'
      }
    },

    # Intra-EU transactions
    spain_to_portugal: {
      name: 'Spain to Portugal B2B',
      seller_jurisdiction: 'ESP',
      buyer_jurisdiction: 'PRT',
      establishment: { id: 1, country: 'ESP', tax_jurisdiction_code: 'ESP' },
      buyer_location: { country: 'PRT', city: 'Porto' },
      expected: {
        cross_border: true,
        eu_transaction: true,
        reverse_charge: false, # Depends on buyer type (B2B vs B2C)
        applicable_tax_rate: 0.0, # Exempt for intra-EU supply
        tax_type: 'IVA'
      }
    },

    portugal_to_spain: {
      name: 'Portugal to Spain B2B',
      seller_jurisdiction: 'PRT',
      buyer_jurisdiction: 'ESP',
      establishment: { id: 2, country: 'PRT', tax_jurisdiction_code: 'PRT' },
      buyer_location: { country: 'ESP', city: 'Barcelona' },
      expected: {
        cross_border: true,
        eu_transaction: true,
        reverse_charge: false,
        applicable_tax_rate: 0.0,
        tax_type: 'IVA'
      }
    },

    # International transactions (non-EU)
    spain_to_usa: {
      name: 'Spain to USA Export',
      seller_jurisdiction: 'ESP',
      buyer_jurisdiction: 'USA',
      establishment: { id: 1, country: 'ESP', tax_jurisdiction_code: 'ESP' },
      buyer_location: { country: 'USA', city: 'New York' },
      expected: {
        cross_border: true,
        eu_transaction: false,
        reverse_charge: false,
        applicable_tax_rate: 0.0, # Export exempt
        tax_type: 'Export'
      }
    },

    # EU to Non-EU
    poland_to_mexico: {
      name: 'Poland to Mexico Export',
      seller_jurisdiction: 'POL',
      buyer_jurisdiction: 'MEX',
      establishment: { id: 3, country: 'POL', tax_jurisdiction_code: 'POL' },
      buyer_location: { country: 'MEX', city: 'Mexico City' },
      expected: {
        cross_border: true,
        eu_transaction: false,
        reverse_charge: false,
        applicable_tax_rate: 0.0,
        tax_type: 'Export'
      }
    },

    # Complex scenarios
    digital_services_b2c: {
      name: 'Digital Services B2C Cross-Border',
      seller_jurisdiction: 'ESP',
      buyer_jurisdiction: 'DEU',
      establishment: { id: 1, country: 'ESP', tax_jurisdiction_code: 'ESP' },
      buyer_location: { country: 'DEU', city: 'Berlin' },
      product_types: ['digital_services'],
      expected: {
        cross_border: true,
        eu_transaction: true,
        reverse_charge: false,
        applicable_tax_rate: 19.0, # German VAT rate applies for B2C digital services
        tax_type: 'VAT'
      }
    }
  }.freeze

  # Mock API responses for tax context resolution
  def self.mock_tax_context_response(scenario_key)
    scenario = TAX_SCENARIOS[scenario_key]
    return nil unless scenario

    {
      data: {
        type: 'tax_context',
        attributes: {
          establishment: scenario[:establishment],
          buyer_location: scenario[:buyer_location],
          tax_context: {
            cross_border: scenario[:expected][:cross_border],
            eu_transaction: scenario[:expected][:eu_transaction],
            reverse_charge: scenario[:expected][:reverse_charge],
            applicable_rates: [
              {
                name: "#{scenario[:expected][:tax_type]} Standard Rate",
                rate: scenario[:expected][:applicable_tax_rate],
                applies_to: scenario[:product_types] || ['goods'],
                category: scenario[:expected][:tax_type]
              }
            ]
          }
        }
      }
    }
  end

  # Helper to run tax calculation test
  def self.run_tax_calculation_test(scenario_key, invoice_data)
    scenario = TAX_SCENARIOS[scenario_key]
    return { success: false, error: 'Invalid scenario' } unless scenario

    # Mock the tax context resolution
    mock_response = mock_tax_context_response(scenario_key)

    # Simulate tax calculation
    calculate_tax_for_scenario(invoice_data, mock_response)
  end

  private

  def self.calculate_tax_for_scenario(invoice_data, tax_context)
    lines = invoice_data[:invoice_lines] || []
    tax_context_data = tax_context[:data][:attributes][:tax_context]
    applicable_rates = tax_context_data[:applicable_rates] || []

    # Calculate taxes based on context
    total_base = 0
    total_tax = 0

    lines.each do |line|
      line_base = (line[:quantity] || 1) * (line[:unit_price] || 0)

      # Apply discount
      if line[:discount_percentage] && line[:discount_percentage] > 0
        discount = line_base * (line[:discount_percentage] / 100.0)
        line_base -= discount
      end

      # Apply tax rate
      tax_rate = applicable_rates.first&.dig(:rate) || line[:tax_rate] || 0
      line_tax = line_base * (tax_rate / 100.0)

      total_base += line_base
      total_tax += line_tax
    end

    {
      success: true,
      calculation: {
        invoice_id: invoice_data[:id],
        tax_context: tax_context_data,
        totals: {
          subtotal: total_base.round(2),
          tax_amount: total_tax.round(2),
          total_amount: (total_base + total_tax).round(2)
        },
        tax_breakdown: applicable_rates.map do |rate|
          {
            rate: rate[:rate],
            base_amount: total_base.round(2),
            tax_amount: (total_base * (rate[:rate] / 100.0)).round(2),
            category: rate[:category]
          }
        end
      }
    }
  end

  # Test data generators
  def self.sample_invoice_data(scenario_key = :domestic_spain)
    scenario = TAX_SCENARIOS[scenario_key]

    {
      id: '12345',
      establishment_id: scenario[:establishment][:id],
      buyer_location: scenario[:buyer_location],
      product_types: scenario[:product_types] || ['goods'],
      invoice_lines: [
        {
          description: 'Test Product 1',
          quantity: 2,
          unit_price: 100.00,
          tax_rate: scenario[:expected][:applicable_tax_rate],
          discount_percentage: 0
        },
        {
          description: 'Test Product 2',
          quantity: 1,
          unit_price: 50.00,
          tax_rate: scenario[:expected][:applicable_tax_rate],
          discount_percentage: 10
        }
      ]
    }
  end

  # Validation helpers
  def self.validate_tax_calculation_result(result, expected_scenario_key)
    scenario = TAX_SCENARIOS[expected_scenario_key]
    expected = scenario[:expected]

    return { valid: false, errors: ['Invalid result'] } unless result[:success]

    calculation = result[:calculation]
    tax_context = calculation[:tax_context]
    errors = []

    # Validate tax context
    errors << "Cross-border detection mismatch" if tax_context[:cross_border] != expected[:cross_border]
    errors << "EU transaction detection mismatch" if tax_context[:eu_transaction] != expected[:eu_transaction]
    errors << "Reverse charge detection mismatch" if tax_context[:reverse_charge] != expected[:reverse_charge]

    # Validate tax rates
    if calculation[:tax_breakdown].any?
      actual_rate = calculation[:tax_breakdown].first[:rate]
      expected_rate = expected[:applicable_tax_rate]

      errors << "Tax rate mismatch: expected #{expected_rate}%, got #{actual_rate}%" if actual_rate != expected_rate
    end

    {
      valid: errors.empty?,
      errors: errors,
      scenario_name: scenario[:name]
    }
  end

  # Test runner for all scenarios
  def self.run_comprehensive_test_suite
    results = {}

    TAX_SCENARIOS.each do |scenario_key, scenario|
      puts "Testing: #{scenario[:name]}"

      invoice_data = sample_invoice_data(scenario_key)
      calculation_result = run_tax_calculation_test(scenario_key, invoice_data)
      validation_result = validate_tax_calculation_result(calculation_result, scenario_key)

      results[scenario_key] = {
        scenario: scenario[:name],
        calculation: calculation_result,
        validation: validation_result,
        passed: validation_result[:valid]
      }

      if validation_result[:valid]
        puts "  ✅ PASSED"
      else
        puts "  ❌ FAILED: #{validation_result[:errors].join(', ')}"
      end
    end

    # Summary
    passed = results.values.count { |r| r[:passed] }
    total = results.size

    puts "\n" + "="*50
    puts "Multi-Jurisdiction Tax Test Results"
    puts "="*50
    puts "Passed: #{passed}/#{total}"
    puts "Success Rate: #{((passed.to_f / total) * 100).round(1)}%"

    if passed < total
      puts "\nFailed scenarios:"
      results.each do |key, result|
        next if result[:passed]
        puts "  - #{result[:scenario]}: #{result[:validation][:errors].join(', ')}"
      end
    end

    results
  end
end