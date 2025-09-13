require 'rails_helper'

RSpec.describe CompaniesController, type: :controller do
  include AuthenticationHelper

  let(:company1) { { id: 1, name: 'TechSol', legal_name: 'Tech Solutions Inc.', tax_id: 'B12345678' } }
  let(:company2) { { id: 2, name: 'GreenWaste', legal_name: 'Green Waste Management S.L.', tax_id: 'B87654321' } }
  let(:user_with_single_company) { double('user', id: 1, companies: [company1]) }
  let(:user_with_multiple_companies) { double('user', id: 2, companies: [company1, company2]) }

  before do
    allow(controller).to receive(:logged_in?).and_return(true)
    allow(controller).to receive(:current_token).and_return('valid_token')
    allow(controller).to receive(:user_companies).and_return([company1, company2])
  end

  describe 'POST #switch' do
    let(:mock_auth_response) do
      {
        access_token: 'new_access_token',
        refresh_token: 'new_refresh_token',
        user: { company_name: 'TechSol' },
        company_id: 1,
        companies: [company1]
      }
    end

    before do
      allow(AuthService).to receive(:switch_company).and_return(mock_auth_response)
      allow(CompanyService).to receive(:find).and_return(company1)
    end

    context 'when switching to an authorized company' do
      it 'successfully switches to the company' do
        post :switch, params: { company_id: 1 }

        expect(AuthService).to have_received(:switch_company).with('valid_token', 1)
        expect(session[:access_token]).to eq('new_access_token')
        expect(session[:refresh_token]).to eq('new_refresh_token')
        expect(session[:company_id]).to eq(1)
        expect(response).to redirect_to(dashboard_path)
        expect(flash[:notice]).to eq('Successfully switched to TechSol')
      end

      it 'fetches company details for the success message' do
        post :switch, params: { company_id: 1 }

        expect(CompanyService).to have_received(:find).with(1, token: 'new_access_token')
      end

      it 'updates session with new company information' do
        post :switch, params: { company_id: 1 }

        expect(session[:companies]).to eq([company1])
      end
    end

    context 'when company_id is missing' do
      it 'redirects to select_company with alert' do
        post :switch, params: { company_id: '' }

        expect(response).to redirect_to(select_company_path)
        expect(flash[:alert]).to eq('Please select a company')
      end

      it 'does not call AuthService' do
        post :switch, params: { company_id: '' }

        expect(AuthService).not_to have_received(:switch_company)
      end
    end

    context 'when AuthService returns nil (permission denied)' do
      before do
        allow(AuthService).to receive(:switch_company).and_return(nil)
      end

      it 'redirects to select_company with alert' do
        post :switch, params: { company_id: 1 }

        expect(response).to redirect_to(select_company_path)
        expect(flash[:alert]).to eq('Failed to switch company')
      end

      it 'does not update session' do
        original_token = session[:access_token]
        post :switch, params: { company_id: 1 }

        expect(session[:access_token]).to eq(original_token)
      end
    end

    context 'when AuthService raises an error' do
      before do
        allow(AuthService).to receive(:switch_company).and_raise(StandardError.new('API Error'))
      end

      it 'redirects to select_company with error message' do
        post :switch, params: { company_id: 1 }

        expect(response).to redirect_to(select_company_path)
        expect(flash[:alert]).to eq('An error occurred while switching companies')
      end
    end

    context 'when CompanyService fails to fetch company details' do
      before do
        allow(CompanyService).to receive(:find).and_raise(StandardError.new('Company not found'))
      end

      it 'still switches successfully with fallback name' do
        post :switch, params: { company_id: 1 }

        expect(response).to redirect_to(dashboard_path)
        expect(flash[:notice]).to match(/Successfully switched to/)
      end

      it 'uses fallback company name' do
        post :switch, params: { company_id: 1 }

        # Should fall back to session data or default name
        expect(flash[:notice]).to include('Successfully switched to')
      end
    end
  end

  describe 'GET #select' do
    context 'when user has no companies' do
      before do
        allow(controller).to receive(:user_companies).and_return([])
      end

      it 'redirects to login with alert' do
        get :select

        expect(response).to redirect_to(login_path)
        expect(flash[:alert]).to eq('No companies found for your account')
      end
    end

    context 'when user has one company' do
      let(:mock_auth_response) do
        {
          access_token: 'new_access_token',
          refresh_token: 'new_refresh_token',
          user: { company_name: 'TechSol' },
          company_id: 1,
          companies: [company1]
        }
      end

      before do
        allow(controller).to receive(:user_companies).and_return([company1])
        allow(AuthService).to receive(:switch_company).and_return(mock_auth_response)
        allow(CompanyService).to receive(:find).and_return(company1)
      end

      it 'auto-switches to the only company' do
        get :select

        expect(AuthService).to have_received(:switch_company).with('valid_token', 1)
        expect(response).to redirect_to(dashboard_path)
      end
    end

    context 'when user has multiple companies' do
      before do
        allow(controller).to receive(:user_companies).and_return([company1, company2])
      end

      it 'renders the company selection page' do
        get :select

        expect(response).to render_template(:select)
        expect(assigns(:companies)).to eq([company1, company2])
      end
    end
  end

  describe 'company switching integration' do
    context 'complete switch workflow' do
      let(:mock_auth_response) do
        {
          access_token: 'new_access_token',
          refresh_token: 'new_refresh_token',
          user: { company_name: 'GreenWaste' },
          company_id: 2,
          companies: [company2]
        }
      end

      before do
        allow(AuthService).to receive(:switch_company).and_return(mock_auth_response)
        allow(CompanyService).to receive(:find).and_return(company2)
      end

      it 'completes full company switch process' do
        # Start switch
        post :switch, params: { company_id: 2 }

        # Verify all steps completed
        expect(AuthService).to have_received(:switch_company).with('valid_token', 2)
        expect(CompanyService).to have_received(:find).with(2, token: 'new_access_token')
        expect(session[:access_token]).to eq('new_access_token')
        expect(session[:company_id]).to eq(2)
        expect(response).to redirect_to(dashboard_path)
      end
    end
  end

  describe 'permission-based company filtering' do
    context 'when user has limited company access' do
      it 'should only see companies they have access to' do
        # This test verifies that the companies index only shows authorized companies
        # The actual filtering happens in the API via CompanyPolicy scope
        
        allow(CompanyService).to receive(:all).and_return({
          companies: [company1], # Only companies user has access to
          meta: { total: 1, page: 1, pages: 1 }
        })

        get :index

        expect(assigns(:companies)).to eq([company1])
        expect(assigns(:companies)).not_to include(company2)
      end
    end
  end
end