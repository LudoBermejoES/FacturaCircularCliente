class AddressValidator
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  attribute :address, :string
  attribute :post_code, :string
  attribute :town, :string
  attribute :province, :string
  attribute :country_code, :string
  attribute :address_type, :string
  attribute :is_default, :boolean

  validates :address, presence: true
  validates :post_code, presence: true
  validates :town, presence: true
  validates :province, presence: true
  validates :country_code, presence: true
  validates :address_type, presence: true, inclusion: { in: %w[legal billing shipping] }
  validates :post_code, zipcode: { country_code_attribute: :alpha2_country_code }, if: :country_code_present?

  def alpha2_country_code
    return nil if country_code.blank?
    convert_to_alpha2(country_code)
  end

  def self.validate_params(params)
    validator = new(params)
    validator.valid? ? { valid: true } : { valid: false, errors: validator.errors.full_messages }
  end

  def self.validate_zipcode(post_code, country_code)
    return { valid: false, error: "Post code is required" } if post_code.blank?
    return { valid: false, error: "Country code is required" } if country_code.blank?
    
    # Convert 3-letter country code to 2-letter if needed
    country_code_2 = new.send(:convert_to_alpha2, country_code)
    return { valid: false, error: "Invalid country code" } if country_code_2.nil?
    
    if ValidatesZipcode.valid?(post_code, country_code_2)
      { valid: true, formatted: ValidatesZipcode.format(post_code, country_code_2) }
    else
      { valid: false, error: "Invalid postal code for #{country_code}" }
    end
  end

  private

  def country_code_present?
    country_code.present?
  end

  def convert_to_alpha2(country_code)
    # Map common 3-letter codes to 2-letter codes used by validates_zipcode
    country_mapping = {
      'ESP' => 'ES',  # Spain
      'USA' => 'US',  # United States
      'GBR' => 'GB',  # United Kingdom
      'FRA' => 'FR',  # France
      'DEU' => 'DE',  # Germany
      'ITA' => 'IT',  # Italy
      'PRT' => 'PT',  # Portugal
      'NLD' => 'NL',  # Netherlands
      'BEL' => 'BE',  # Belgium
      'CHE' => 'CH',  # Switzerland
      'AUT' => 'AT',  # Austria
      'POL' => 'PL',  # Poland
      'CZE' => 'CZ',  # Czech Republic
      'SVK' => 'SK',  # Slovakia
      'HUN' => 'HU',  # Hungary
      'ROU' => 'RO',  # Romania
      'BGR' => 'BG',  # Bulgaria
      'HRV' => 'HR',  # Croatia
      'SVN' => 'SI',  # Slovenia
      'GRC' => 'GR',  # Greece
      'CYP' => 'CY',  # Cyprus
      'MLT' => 'MT',  # Malta
      'LUX' => 'LU',  # Luxembourg
      'EST' => 'EE',  # Estonia
      'LVA' => 'LV',  # Latvia
      'LTU' => 'LT',  # Lithuania
      'FIN' => 'FI',  # Finland
      'SWE' => 'SE',  # Sweden
      'DNK' => 'DK',  # Denmark
      'NOR' => 'NO',  # Norway
      'ISL' => 'IS',  # Iceland
      'IRL' => 'IE',  # Ireland
      'CAN' => 'CA',  # Canada
      'MEX' => 'MX',  # Mexico
      'BRA' => 'BR',  # Brazil
      'ARG' => 'AR',  # Argentina
      'COL' => 'CO',  # Colombia
      'CHL' => 'CL',  # Chile
      'PER' => 'PE',  # Peru
      'URY' => 'UY',  # Uruguay
      'PRY' => 'PY',  # Paraguay
      'BOL' => 'BO',  # Bolivia
      'ECU' => 'EC',  # Ecuador
      'VEN' => 'VE',  # Venezuela
      'JPN' => 'JP',  # Japan
      'KOR' => 'KR',  # South Korea
      'CHN' => 'CN',  # China
      'IND' => 'IN',  # India
      'AUS' => 'AU',  # Australia
      'NZL' => 'NZ',  # New Zealand
      'ZAF' => 'ZA',  # South Africa
      'MAR' => 'MA',  # Morocco
      'TUN' => 'TN',  # Tunisia
      'EGY' => 'EG',  # Egypt
      'TUR' => 'TR',  # Turkey
      'ISR' => 'IL',  # Israel
      'SAU' => 'SA',  # Saudi Arabia
      'ARE' => 'AE',  # United Arab Emirates
      'RUS' => 'RU',  # Russia
      'UKR' => 'UA',  # Ukraine
      'BLR' => 'BY',  # Belarus
      'MDA' => 'MD',  # Moldova
      'SRB' => 'RS',  # Serbia
      'MNE' => 'ME',  # Montenegro
      'MKD' => 'MK',  # North Macedonia
      'ALB' => 'AL',  # Albania
      'BIH' => 'BA',  # Bosnia and Herzegovina
      'XKX' => 'XK'   # Kosovo
    }
    
    # If it's already 2 letters, return as is
    return country_code.upcase if country_code.length == 2
    
    # Otherwise convert from 3-letter to 2-letter
    country_mapping[country_code.upcase]
  end
end