require 'rails_helper'

RSpec.feature 'Company Contact Address Management', type: :feature do
  let(:user) { build(:user_response) }
  let(:token) { 'test_access_token' }
  let(:company) { build(:company_response, id: 123, name: 'Test Company') }
  let(:contact) { build(:company_contact_response, id: 456, name: 'John Doe') }
  let(:billing_address) { build(:address_response, :billing, :default, id: 789) }
  let(:shipping_address) { build(:address_response, :shipping, :non_default, id: 790) }

  before do
    # Mock authentication
    allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:logged_in?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:current_token).and_return(token)

    # Mock service calls
    allow(CompanyService).to receive(:find).with('123', token: token).and_return(company)
    allow(CompanyContactService).to receive(:find).with('456', company_id: 123, token: token).and_return(contact)
  end

  describe 'Address listing' do
    context 'when contact has addresses' do
      let(:addresses_response) {
        {
          addresses: [billing_address, shipping_address],
          meta: { total: 2, page: 1, pages: 1 }
        }
      }

      before do
        allow(CompanyContactAddressService).to receive(:all)
          .with(company_id: 123, contact_id: 456, token: token)
          .and_return(addresses_response)
      end

      scenario 'displays all addresses with proper formatting' do
        visit company_company_contact_addresses_path(company[:id], contact[:id])

        expect(page).to have_content('Addresses for John Doe')
        expect(page).to have_content('2 addresses')

        # Check billing address
        within("[data-address-id='789']") do
          expect(page).to have_content('Billing')
          expect(page).to have_content('Default')
          expect(page).to have_content(billing_address[:street_address])
          expect(page).to have_content(billing_address[:city])
          expect(page).to have_content('Edit')
          expect(page).not_to have_content('Set as Default')
        end

        # Check shipping address
        within("[data-address-id='790']") do
          expect(page).to have_content('Shipping')
          expect(page).not_to have_content('Default')
          expect(page).to have_content(shipping_address[:street_address])
          expect(page).to have_content(shipping_address[:city])
          expect(page).to have_content('Edit')
          expect(page).to have_content('Set as Default')
          expect(page).to have_content('Delete')
        end
      end

      scenario 'provides navigation links' do
        visit company_company_contact_addresses_path(company[:id], contact[:id])

        expect(page).to have_link('Add Address', href: new_company_company_contact_address_path(company[:id], contact[:id]))
        expect(page).to have_link('Back to Contacts', href: company_company_contacts_path(company[:id]))
      end
    end

    context 'when contact has no addresses' do
      before do
        allow(CompanyContactAddressService).to receive(:all)
          .with(company_id: 123, contact_id: 456, token: token)
          .and_return({ addresses: [], meta: { total: 0, page: 1, pages: 0 } })
      end

      scenario 'displays empty state' do
        visit company_company_contact_addresses_path(company[:id], contact[:id])

        expect(page).to have_content('No addresses')
        expect(page).to have_content('Get started by adding an address')
        expect(page).to have_link('Add First Address', href: new_company_company_contact_address_path(company[:id], contact[:id]))
      end
    end

    context 'when API error occurs' do
      before do
        allow(CompanyContactAddressService).to receive(:all)
          .with(company_id: 123, contact_id: 456, token: token)
          .and_raise(ApiService::ApiError.new('Server error'))
      end

      scenario 'displays error message' do
        visit company_company_contact_addresses_path(company[:id], contact[:id])

        expect(page).to have_content('Error loading addresses: Server error')
      end
    end
  end

  describe 'Creating new address' do
    scenario 'displays new address form' do
      visit new_company_company_contact_address_path(company[:id], contact[:id])

      expect(page).to have_content('Add New Address')
      expect(page).to have_content('Add a new address for John Doe')

      # Check form fields
      expect(page).to have_field('Address Type')
      expect(page).to have_field('Street Address')
      expect(page).to have_field('City')
      expect(page).to have_field('Postal Code')
      expect(page).to have_field('State/Province')
      expect(page).to have_field('Country')
      expect(page).to have_field('Set as default address')

      expect(page).to have_button('Create Address')
      expect(page).to have_link('Cancel', href: company_company_contact_addresses_path(company[:id], contact[:id]))
    end

    context 'with valid data' do
      before do
        allow(CompanyContactAddressService).to receive(:create)
          .with(
            company_id: 123,
            contact_id: 456,
            params: instance_of(ActionController::Parameters),
            token: token
          )
          .and_return({ data: { id: 791 } })
      end

      scenario 'successfully creates address' do
        visit new_company_company_contact_address_path(company[:id], contact[:id])

        select 'Billing', from: 'Address Type'
        fill_in 'Street Address', with: 'Calle Gran Via 100'
        fill_in 'City', with: 'Madrid'
        fill_in 'Postal Code', with: '28013'
        select 'Spain', from: 'Country'
        check 'Set as default address'

        click_button 'Create Address'

        expect(page).to have_current_path(company_company_contact_addresses_path(company[:id], contact[:id]))
        expect(page).to have_content('Address was successfully created.')
      end
    end

    context 'with invalid data' do
      before do
        allow(CompanyContactAddressService).to receive(:create)
          .with(
            company_id: 123,
            contact_id: 456,
            params: instance_of(ActionController::Parameters),
            token: token
          )
          .and_raise(ApiService::ValidationError.new('Validation failed', { street_address: ['is required'] }))
      end

      scenario 'displays validation errors' do
        visit new_company_company_contact_address_path(company[:id], contact[:id])

        click_button 'Create Address'

        expect(page).to have_content('There were errors creating the address.')
        expect(page).to have_content('Street address is required')
      end
    end
  end

  describe 'Editing existing address' do
    before do
      allow(CompanyContactAddressService).to receive(:find)
        .with(company_id: 123, contact_id: 456, address_id: '789', token: token)
        .and_return(billing_address)
    end

    scenario 'displays edit address form with current values' do
      visit edit_company_company_contact_address_path(company[:id], contact[:id], billing_address[:id])

      expect(page).to have_content('Edit Address')
      expect(page).to have_content('Update address information for John Doe')

      # Check that current values are populated
      expect(page).to have_field('Street Address', with: billing_address[:street_address])
      expect(page).to have_field('City', with: billing_address[:city])
      expect(page).to have_field('Postal Code', with: billing_address[:postal_code])

      expect(page).to have_button('Update Address')
      expect(page).to have_link('Cancel', href: company_company_contact_addresses_path(company[:id], contact[:id]))
    end

    context 'with valid updates' do
      before do
        allow(CompanyContactAddressService).to receive(:update)
          .with(
            company_id: 123,
            contact_id: 456,
            address_id: billing_address[:id],
            params: instance_of(ActionController::Parameters),
            token: token
          )
          .and_return({ data: { id: 789 } })
      end

      scenario 'successfully updates address' do
        visit edit_company_company_contact_address_path(company[:id], contact[:id], billing_address[:id])

        fill_in 'Street Address', with: 'Updated Street 456'
        click_button 'Update Address'

        expect(page).to have_current_path(company_company_contact_addresses_path(company[:id], contact[:id]))
        expect(page).to have_content('Address was successfully updated.')
      end
    end
  end

  describe 'Deleting address', js: true do
    let(:addresses_response) {
      {
        addresses: [billing_address, shipping_address],
        meta: { total: 2, page: 1, pages: 1 }
      }
    }

    before do
      allow(CompanyContactAddressService).to receive(:all)
        .with(company_id: 123, contact_id: 456, token: token)
        .and_return(addresses_response)

      allow(CompanyContactAddressService).to receive(:delete)
        .with(company_id: 123, contact_id: 456, address_id: shipping_address[:id], token: token)
        .and_return(true)
    end

    scenario 'successfully deletes non-default address' do
      visit company_company_contact_addresses_path(company[:id], contact[:id])

      within("[data-address-id='#{shipping_address[:id]}']") do
        accept_confirm do
          click_button 'Delete'
        end
      end

      expect(page).to have_content('Address was successfully deleted.')
    end

    context 'when deletion fails' do
      before do
        allow(CompanyContactAddressService).to receive(:delete)
          .with(company_id: 123, contact_id: 456, address_id: billing_address[:id], token: token)
          .and_raise(ApiService::ApiError.new('Cannot delete default address'))
      end

      scenario 'displays error message' do
        visit company_company_contact_addresses_path(company[:id], contact[:id])

        within("[data-address-id='#{billing_address[:id]}']") do
          accept_confirm do
            click_button 'Delete'
          end
        end

        expect(page).to have_content('Error deleting address: Cannot delete default address')
      end
    end
  end

  describe 'Setting default address', js: true do
    let(:addresses_response) {
      {
        addresses: [billing_address, shipping_address],
        meta: { total: 2, page: 1, pages: 1 }
      }
    }

    before do
      allow(CompanyContactAddressService).to receive(:all)
        .with(company_id: 123, contact_id: 456, token: token)
        .and_return(addresses_response)

      allow(CompanyContactAddressService).to receive(:set_default)
        .with(company_id: 123, contact_id: 456, address_id: shipping_address[:id], token: token)
        .and_return({ data: { id: 790, attributes: { is_default: true } } })
    end

    scenario 'successfully sets address as default' do
      visit company_company_contact_addresses_path(company[:id], contact[:id])

      within("[data-address-id='#{shipping_address[:id]}']") do
        click_button 'Set as Default'
      end

      expect(page).to have_content('Address was successfully set as default.')
    end
  end

  describe 'Navigation and breadcrumbs' do
    scenario 'provides proper breadcrumb navigation' do
      visit company_company_contact_addresses_path(company[:id], contact[:id])

      expect(page).to have_link('Companies')
      expect(page).to have_link('Test Company')
      expect(page).to have_link('Contacts')
      expect(page).to have_content('Addresses')
    end
  end
end