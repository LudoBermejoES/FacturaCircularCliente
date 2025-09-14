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
end