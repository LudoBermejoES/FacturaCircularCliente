require 'rails_helper'

RSpec.describe InvoicesController, type: :controller do
  describe 'Global Financial Fields in Strong Parameters' do
    let(:controller) { InvoicesController.new }

    describe 'invoice_params method' do
      let(:params) do
        ActionController::Parameters.new(
          invoice: {
            invoice_number: 'FC-0004',
            status: 'draft',
            # Global financial fields
            total_general_discounts: '15.5',
            total_general_surcharges: '8.75',
            total_financial_expenses: '12.25',
            total_reimbursable_expenses: '22.0',
            withholding_amount: '18.5',
            payment_in_kind_amount: '5.0',
            # Other allowed fields
            currency_code: 'EUR',
            issue_date: '2025-09-23',
            # Unpermitted field (should be filtered out)
            malicious_field: 'should_not_be_permitted'
          }
        )
      end

      before do
        # Mock controller params
        allow(controller).to receive(:params).and_return(params)
      end

      it 'permits all global financial fields' do
        permitted_params = controller.send(:invoice_params)

        # Verify global financial fields are permitted
        expect(permitted_params[:total_general_discounts]).to eq('15.5')
        expect(permitted_params[:total_general_surcharges]).to eq('8.75')
        expect(permitted_params[:total_financial_expenses]).to eq('12.25')
        expect(permitted_params[:total_reimbursable_expenses]).to eq('22.0')
        expect(permitted_params[:withholding_amount]).to eq('18.5')
        expect(permitted_params[:payment_in_kind_amount]).to eq('5.0')
      end

      it 'filters out unpermitted parameters' do
        permitted_params = controller.send(:invoice_params)

        # Verify unpermitted field is filtered out
        expect(permitted_params).not_to have_key(:malicious_field)
      end

      it 'allows other standard invoice fields alongside global fields' do
        permitted_params = controller.send(:invoice_params)

        # Verify standard fields still work
        expect(permitted_params[:invoice_number]).to eq('FC-0004')
        expect(permitted_params[:status]).to eq('draft')
        expect(permitted_params[:issue_date]).to eq('2025-09-23')
      end

      it 'handles missing global financial fields gracefully' do
        minimal_params = ActionController::Parameters.new(
          invoice: {
            invoice_number: 'FC-0004',
            status: 'draft'
          }
        )

        allow(controller).to receive(:params).and_return(minimal_params)
        permitted_params = controller.send(:invoice_params)

        # Should work even without global fields
        expect(permitted_params[:invoice_number]).to eq('FC-0004')
        expect(permitted_params[:status]).to eq('draft')
      end

      it 'handles zero values for global financial fields' do
        zero_params = ActionController::Parameters.new(
          invoice: {
            invoice_number: 'FC-0004',
            total_general_discounts: '0.0',
            total_general_surcharges: '0.0',
            total_financial_expenses: '0.0',
            total_reimbursable_expenses: '0.0',
            withholding_amount: '0.0',
            payment_in_kind_amount: '0.0'
          }
        )

        allow(controller).to receive(:params).and_return(zero_params)
        permitted_params = controller.send(:invoice_params)

        # Verify zero values are preserved
        expect(permitted_params[:total_general_discounts]).to eq('0.0')
        expect(permitted_params[:total_general_surcharges]).to eq('0.0')
        expect(permitted_params[:total_financial_expenses]).to eq('0.0')
        expect(permitted_params[:total_reimbursable_expenses]).to eq('0.0')
        expect(permitted_params[:withholding_amount]).to eq('0.0')
        expect(permitted_params[:payment_in_kind_amount]).to eq('0.0')
      end
    end
  end
end