# Cross-border transaction validation service
# Handles complex tax validation rules for multi-jurisdiction transactions

class CrossBorderTaxValidator
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  # Transaction attributes
  attribute :seller_jurisdiction_code, :string
  attribute :buyer_jurisdiction_code, :string
  attribute :seller_establishment, :string
  attribute :buyer_location, :string
  attribute :transaction_amount, :decimal
  attribute :product_types, array: true, default: []
  attribute :buyer_type, :string # 'business' or 'consumer'
  attribute :invoice_lines, array: true, default: []
  attribute :transaction_date, :date, default: -> { Date.current }

  # Validation results
  attr_reader :validation_results, :warnings, :recommendations, :required_documents

  # EU country codes for reference
  EU_COUNTRIES = %w[
    AUT BEL BGR HRV CYP CZE DNK EST FIN FRA DEU GRC HUN IRL ITA LVA LTU LUX
    MLT NLD POL PRT ROU SVK SVN ESP SWE
  ].freeze

  # Supported jurisdictions in our system
  SUPPORTED_JURISDICTIONS = %w[ESP PRT POL MEX].freeze

  def initialize(attributes = {})
    super
    @validation_results = {}
    @warnings = []
    @recommendations = []
    @required_documents = []
  end

  def validate_transaction
    reset_validation_state

    # Core validation checks
    validate_jurisdiction_support
    validate_transaction_type
    validate_eu_rules if eu_transaction?
    validate_export_rules if export_transaction?
    validate_digital_services if digital_services?
    validate_threshold_requirements
    validate_documentation_requirements
    validate_tax_registration_requirements

    # Generate summary
    generate_validation_summary

    self
  end

  def valid_transaction?
    validate_transaction unless @validation_results.present?
    !@validation_results.values.any? { |result| result[:status] == 'error' }
  end

  def cross_border?
    seller_jurisdiction_code != buyer_jurisdiction_code
  end

  def eu_transaction?
    cross_border? &&
    EU_COUNTRIES.include?(seller_jurisdiction_code) &&
    EU_COUNTRIES.include?(buyer_jurisdiction_code)
  end

  def export_transaction?
    cross_border? && (
      !EU_COUNTRIES.include?(seller_jurisdiction_code) ||
      !EU_COUNTRIES.include?(buyer_jurisdiction_code)
    )
  end

  def digital_services?
    product_types.include?('digital_services') ||
    product_types.include?('software') ||
    invoice_lines.any? { |line| digital_service_keywords.any? { |keyword| line[:description]&.downcase&.include?(keyword) } }
  end

  def reverse_charge_required?
    validate_transaction unless @validation_results.present?
    @validation_results.dig(:reverse_charge, :required) == true
  end

  def tax_exemption_applicable?
    validate_transaction unless @validation_results.present?
    @validation_results.dig(:tax_exemption, :applicable) == true
  end

  private

  def reset_validation_state
    @validation_results = {}
    @warnings = []
    @recommendations = []
    @required_documents = []
  end

  def validate_jurisdiction_support
    unsupported = []
    unsupported << seller_jurisdiction_code unless SUPPORTED_JURISDICTIONS.include?(seller_jurisdiction_code)
    unsupported << buyer_jurisdiction_code unless SUPPORTED_JURISDICTIONS.include?(buyer_jurisdiction_code)

    if unsupported.any?
      @validation_results[:jurisdiction_support] = {
        status: 'warning',
        message: "Unsupported jurisdictions: #{unsupported.join(', ')}",
        details: "Limited validation available for these jurisdictions"
      }
    else
      @validation_results[:jurisdiction_support] = {
        status: 'success',
        message: 'All jurisdictions supported'
      }
    end
  end

  def validate_transaction_type
    if cross_border?
      if eu_transaction?
        @validation_results[:transaction_type] = {
          status: 'info',
          type: 'intra_eu',
          message: 'Intra-EU transaction detected',
          details: 'Special EU tax rules apply'
        }
      else
        @validation_results[:transaction_type] = {
          status: 'info',
          type: 'export',
          message: 'Export transaction detected',
          details: 'Export tax exemption may apply'
        }
      end
    else
      @validation_results[:transaction_type] = {
        status: 'info',
        type: 'domestic',
        message: 'Domestic transaction',
        details: 'Standard domestic tax rules apply'
      }
    end
  end

  def validate_eu_rules
    return unless eu_transaction?

    # B2B vs B2C rules
    if buyer_type == 'business'
      validate_b2b_eu_transaction
    else
      validate_b2c_eu_transaction
    end
  end

  def validate_b2b_eu_transaction
    @validation_results[:reverse_charge] = {
      status: 'info',
      required: true,
      message: 'Reverse charge mechanism applies',
      details: 'Customer pays VAT in their country'
    }

    @validation_results[:tax_exemption] = {
      status: 'success',
      applicable: true,
      message: 'Intra-EU supply exemption applies',
      details: 'Zero-rated for VAT in seller country'
    }

    @required_documents.push(
      'Valid VAT number verification',
      'Proof of goods movement within EU',
      'Invoice with correct reverse charge mention'
    )

    @recommendations.push(
      'Verify buyer VAT number through VIES system',
      'Include reverse charge clause on invoice',
      'Maintain proof of intra-EU supply'
    )
  end

  def validate_b2c_eu_transaction
    # Distance selling rules for B2C
    distance_selling_threshold = get_distance_selling_threshold(buyer_jurisdiction_code)

    @validation_results[:distance_selling] = {
      status: 'warning',
      threshold: distance_selling_threshold,
      message: 'B2C distance selling rules may apply',
      details: "Check if annual sales to #{buyer_jurisdiction_code} exceed €#{distance_selling_threshold}"
    }

    if digital_services?
      @validation_results[:oss_requirement] = {
        status: 'info',
        required: true,
        message: 'OSS (One Stop Shop) registration may be required',
        details: 'For digital services to EU consumers'
      }
    end

    @recommendations.push(
      'Monitor distance selling thresholds',
      'Consider OSS registration for digital services',
      'Apply destination country VAT rate if threshold exceeded'
    )
  end

  def validate_export_rules
    return unless export_transaction?

    @validation_results[:export_exemption] = {
      status: 'success',
      applicable: true,
      message: 'Export tax exemption applicable',
      details: 'Zero-rated for domestic VAT'
    }

    @required_documents.push(
      'Export declaration',
      'Proof of export (shipping documents)',
      'Customer purchase order'
    )

    # Special rules for digital services exports
    if digital_services?
      @validation_results[:digital_export] = {
        status: 'warning',
        message: 'Digital services export rules apply',
        details: 'May be subject to destination country tax rules'
      }
    end

    @recommendations.push(
      'Maintain export documentation',
      'Verify customer location for digital services',
      'Consider local tax registration requirements'
    )
  end

  def validate_digital_services
    return unless digital_services?

    @validation_results[:digital_services] = {
      status: 'info',
      message: 'Digital services detected',
      details: 'Special VAT rules apply for digital services'
    }

    if cross_border?
      @validation_results[:digital_vat_location] = {
        status: 'warning',
        message: 'Digital services VAT location rules apply',
        details: 'VAT typically due in customer location country'
      }

      @recommendations.push(
        'Determine customer location for VAT purposes',
        'Consider local VAT registration',
        'Apply destination country VAT rate'
      )
    end
  end

  def validate_threshold_requirements
    # VAT registration thresholds
    thresholds = get_vat_thresholds

    thresholds.each do |jurisdiction, threshold|
      if transaction_amount && transaction_amount >= threshold[:registration]
        @validation_results["#{jurisdiction}_vat_threshold"] = {
          status: 'warning',
          message: "VAT registration threshold approached in #{jurisdiction}",
          threshold: threshold[:registration],
          details: "Consider local VAT registration"
        }
      end
    end
  end

  def validate_documentation_requirements
    base_documents = ['Commercial invoice', 'Contract/Purchase order']
    @required_documents.concat(base_documents)

    if cross_border?
      @required_documents << 'Proof of customer location'

      if transaction_amount && transaction_amount > 1000
        @required_documents << 'Customer identification documents'
      end
    end

    @validation_results[:documentation] = {
      status: 'info',
      message: "#{@required_documents.size} documents required",
      documents: @required_documents
    }
  end

  def validate_tax_registration_requirements
    registrations_needed = []

    if eu_transaction? && buyer_type == 'consumer'
      # Check distance selling thresholds
      threshold = get_distance_selling_threshold(buyer_jurisdiction_code)
      registrations_needed << "VAT registration in #{buyer_jurisdiction_code} (if threshold exceeded)"
    end

    if digital_services? && cross_border?
      registrations_needed << "OSS registration (for EU digital services)"
      registrations_needed << "Local tax registration in #{buyer_jurisdiction_code} (alternative to OSS)"
    end

    if export_transaction? && transaction_amount && transaction_amount > 10000
      registrations_needed << "Local tax registration may be required in #{buyer_jurisdiction_code}"
    end

    if registrations_needed.any?
      @validation_results[:tax_registration] = {
        status: 'warning',
        message: 'Tax registration requirements detected',
        requirements: registrations_needed
      }
    else
      @validation_results[:tax_registration] = {
        status: 'success',
        message: 'No additional tax registrations required'
      }
    end
  end

  def generate_validation_summary
    error_count = @validation_results.values.count { |r| r[:status] == 'error' }
    warning_count = @validation_results.values.count { |r| r[:status] == 'warning' }

    @validation_results[:summary] = {
      status: error_count > 0 ? 'error' : (warning_count > 0 ? 'warning' : 'success'),
      total_checks: @validation_results.size - 1, # Exclude summary itself
      errors: error_count,
      warnings: warning_count,
      recommendations_count: @recommendations.size,
      documents_required: @required_documents.size
    }
  end

  def digital_service_keywords
    %w[software license subscription saas digital download streaming consulting training support maintenance]
  end

  def get_distance_selling_threshold(country_code)
    # Simplified thresholds - in practice these vary by country
    case country_code
    when 'ESP' then 35000
    when 'PRT' then 35000
    when 'POL' then 160000
    else 10000 # EU default
    end
  end

  def get_vat_thresholds
    {
      'ESP' => { registration: 0, distance_selling: 35000 },
      'PRT' => { registration: 12500, distance_selling: 35000 },
      'POL' => { registration: 200000, distance_selling: 160000 },
      'MEX' => { registration: 0, distance_selling: 0 }
    }
  end
end