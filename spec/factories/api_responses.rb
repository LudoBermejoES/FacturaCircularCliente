FactoryBot.define do
  factory :company_response, class: Hash do
    id { Faker::Number.number(digits: 3) }
    name { Faker::Company.name }
    tax_id { "B#{Faker::Number.number(digits: 8)}" }
    email { Faker::Internet.email }
    phone { Faker::PhoneNumber.phone_number }
    
    initialize_with { attributes }
  end
  
  factory :invoice_response, class: Hash do
    id { Faker::Number.number(digits: 3) }
    invoice_number { "INV-#{Faker::Number.number(digits: 4)}" }
    status { %w[draft sent paid].sample }
    total { Faker::Commerce.price(range: 100..10000) }
    company { association :company_response }
    company_id { Faker::Number.number(digits: 3) }
    
    initialize_with { attributes }
  end
  
  factory :user_response, class: Hash do
    id { Faker::Number.number(digits: 3) }
    email { Faker::Internet.email }
    name { Faker::Name.name }
    
    initialize_with { attributes }
  end
  
  factory :auth_response, class: Hash do
    access_token { "token_#{Faker::Alphanumeric.alphanumeric(number: 32)}" }
    refresh_token { "refresh_#{Faker::Alphanumeric.alphanumeric(number: 32)}" }
    user { association :user_response }
    
    initialize_with { attributes }
  end
  
  factory :invoice_line_response, class: Hash do
    id { Faker::Number.number(digits: 3) }
    description { Faker::Commerce.product_name }
    quantity { Faker::Number.between(from: 1, to: 100) }
    unit_price { Faker::Commerce.price(range: 10..1000) }
    tax_rate { [10, 21].sample }
    discount_percentage { [0, 5, 10, 15].sample }

    initialize_with { attributes }
  end

  factory :product_response, class: Hash do
    id { Faker::Number.number(digits: 3) }
    sku { "PRD-#{Faker::Number.number(digits: 3)}" }
    name { Faker::Commerce.product_name }
    description { Faker::Lorem.sentence }
    is_active { true }
    base_price { Faker::Commerce.price(range: 10..1000).to_f }
    currency_code { 'EUR' }
    tax_rate { [0, 4, 10, 21].sample.to_f }
    created_at { 1.week.ago.iso8601 }
    updated_at { 1.day.ago.iso8601 }
    price_with_tax { (base_price * (1 + tax_rate / 100.0)).round(2) }
    display_name { "#{sku} - #{name}" }
    formatted_price { "#{currency_code} #{base_price}" }

    # Tax helper computed attributes
    standard_tax { tax_rate == 21 }
    reduced_tax { tax_rate == 10 }
    super_reduced_tax { tax_rate == 4 }
    tax_exempt { tax_rate == 0 }

    # Tax description based on rate
    tax_description do
      case tax_rate
      when 21 then 'Standard (21%)'
      when 10 then 'Reduced (10%)'
      when 4 then 'Super Reduced (4%)'
      when 0 then 'Exempt (0%)'
      else "Custom (#{tax_rate}%)"
      end
    end

    initialize_with { attributes }

    trait :inactive do
      is_active { false }
    end

    trait :standard_tax do
      tax_rate { 21.0 }
    end

    trait :reduced_tax do
      tax_rate { 10.0 }
    end

    trait :super_reduced_tax do
      tax_rate { 4.0 }
    end

    trait :tax_exempt do
      tax_rate { 0.0 }
    end
  end
  
  factory :workflow_history_response, class: Hash do
    history do 
      [
        {
          id: Faker::Number.number(digits: 3),
          status: 'draft',
          user_name: Faker::Name.name,
          comment: 'Invoice created',
          created_at: 2.days.ago.iso8601
        },
        {
          id: Faker::Number.number(digits: 3),
          status: 'sent',
          user_name: Faker::Name.name,
          comment: 'Invoice sent to customer',
          created_at: 1.day.ago.iso8601
        }
      ]
    end
    
    initialize_with { attributes[:history] }
  end
  
  factory :workflow_transitions_response, class: Hash do
    available_transitions do
      [
        { status: 'approved', label: 'Approve Invoice' },
        { status: 'rejected', label: 'Reject Invoice' },
        { status: 'paid', label: 'Mark as Paid' }
      ]
    end
    
    initialize_with { attributes[:available_transitions] }
  end
  
  factory :tax_rate_response, class: Hash do
    id { Faker::Number.number(digits: 3) }
    name { "IVA #{rate}%" }
    rate { [10, 21].sample }
    region { 'ES' }
    tax_type { 'VAT' }
    description { "Spanish VAT at #{rate}%" }
    
    initialize_with { attributes }
  end
  
  factory :company_contact_response, class: Hash do
    id { Faker::Number.number(digits: 3) }
    name { Faker::Name.first_name }
    first_surname { Faker::Name.last_name }
    second_surname { Faker::Name.last_name }
    email { Faker::Internet.email }
    telephone { Faker::PhoneNumber.phone_number }
    contact_details { Faker::Job.title }
    is_active { [true, false].sample }
    full_name { "#{name} #{first_surname} #{second_surname}".strip }
    
    initialize_with { attributes }
  end
  
  factory :tax_calculation_response, class: Hash do
    subtotal { Faker::Commerce.price(range: 100..1000) }
    tax_amount { subtotal * 0.21 }
    total { subtotal + tax_amount }
    breakdown do
      [
        {
          tax_rate: 21,
          taxable_amount: subtotal,
          tax_amount: tax_amount
        }
      ]
    end

    initialize_with { attributes }
  end

  factory :address_response, class: Hash do
    id { Faker::Number.number(digits: 3) }
    street_address { "#{Faker::Address.street_name} #{Faker::Address.building_number}" }
    city { Faker::Address.city }
    state_province { Faker::Address.state }
    postal_code { Faker::Address.zip_code }
    country_code { ['ESP', 'FRA', 'DEU', 'ITA'].sample }
    country_name do
      case country_code
      when 'ESP' then 'Spain'
      when 'FRA' then 'France'
      when 'DEU' then 'Germany'
      when 'ITA' then 'Italy'
      else 'Unknown'
      end
    end
    address_type { ['billing', 'shipping'].sample }
    is_default { [true, false].sample }
    display_type { address_type.capitalize }
    full_address { "#{street_address}, #{postal_code} #{city}, #{state_province}, #{country_name}" }
    full_address_with_country { full_address }
    created_at { 1.week.ago.iso8601 }
    updated_at { 1.day.ago.iso8601 }

    initialize_with { attributes }

    trait :billing do
      address_type { 'billing' }
      display_type { 'Billing' }
    end

    trait :shipping do
      address_type { 'shipping' }
      display_type { 'Shipping' }
    end

    trait :default do
      is_default { true }
    end

    trait :non_default do
      is_default { false }
    end

    trait :spanish do
      country_code { 'ESP' }
      country_name { 'Spain' }
      state_province { ['Madrid', 'Barcelona', 'Valencia', 'Sevilla'].sample }
      postal_code { "#{Faker::Number.number(digits: 2)}#{Faker::Number.number(digits: 3)}" }
    end
  end
end