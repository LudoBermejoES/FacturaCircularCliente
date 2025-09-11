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
end