require 'rails_helper'

RSpec.describe ProductsController, type: :controller do
  let(:user) { build(:user_response) }
  let(:token) { 'test_access_token' }
  let(:product_id) { 123 }
  let(:base_url) { 'http://albaranes-api:3000/api/v1' }

  let(:product) { build(:product_response, id: product_id, sku: 'PRD-001', name: 'Test Product', base_price: 100.0, tax_rate: 21.0) }
  let(:inactive_product) { build(:product_response, :inactive, id: product_id + 1, sku: 'PRD-002', name: 'Inactive Product') }

  let(:product_params) do
    {
      sku: 'PRD-NEW',
      name: 'New Product',
      description: 'A new test product',
      base_price: 200.0,
      tax_rate: 21.0,
      currency_code: 'EUR',
      is_active: true
    }
  end

  before do
    # Mock authentication
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:logged_in?).and_return(true)
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_token).and_return(token)
    allow(controller).to receive(:can?).and_return(true)
  end

  describe 'GET #index' do
    context 'when successful' do
      before do
        allow(ProductService).to receive(:all).with(
          token: token,
          params: hash_including(page: 1, per_page: 25)
        ).and_return({
          products: [product, inactive_product],
          meta: {
            total_count: 2,
            current_page: 1,
            page_count: 1
          }
        })
      end

      it 'returns success' do
        get :index
        expect(response).to have_http_status(:success)
      end

      it 'assigns products' do
        get :index
        expect(assigns(:products)).to eq([product, inactive_product])
      end

      it 'assigns statistics' do
        get :index
        expect(assigns(:statistics)).to include(
          total_products: 2,
          active_products: 1,
          inactive_products: 1
        )
      end

      it 'handles pagination parameters' do
        allow(ProductService).to receive(:all).with(
          token: token,
          params: hash_including(page: '2', per_page: '10')
        ).and_return({
          products: [],
          meta: { total_count: 0, current_page: 2, page_count: 1 }
        })

        get :index, params: { page: 2, per_page: 10 }
        expect(response).to have_http_status(:success)
      end

      it 'handles filter parameters' do
        allow(ProductService).to receive(:all).with(
          token: token,
          params: hash_including(is_active: 'true', tax_rate: '21', page: 1, per_page: 25)
        ).and_return({
          products: [product],
          meta: { total_count: 1, current_page: 1, page_count: 1 }
        })

        get :index, params: { is_active: true, tax_rate: 21 }
        expect(response).to have_http_status(:success)
      end
    end

    context 'when API returns error' do
      before do
        allow(ProductService).to receive(:all)
          .and_raise(ApiService::ApiError.new('Internal Server Error'))
      end

      it 'handles error gracefully' do
        get :index
        expect(response).to have_http_status(:success)
        expect(assigns(:products)).to eq([])
        expect(flash[:alert]).to include('Error loading products')
      end
    end
  end

  describe 'GET #show' do
    context 'when successful' do
      before do
        allow(ProductService).to receive(:find)
          .with(product_id.to_s, token: token)
          .and_return(product)
      end

      it 'returns success' do
        get :show, params: { id: product_id }
        expect(response).to have_http_status(:success)
      end

      it 'assigns product' do
        get :show, params: { id: product_id }
        expect(assigns(:product)).to eq(product)
      end
    end

    context 'when product not found' do
      before do
        allow(ProductService).to receive(:find)
          .with(product_id.to_s, token: token)
          .and_raise(ApiService::ApiError.new('Not Found'))
      end

      it 'redirects to products index with error' do
        get :show, params: { id: product_id }
        expect(response).to redirect_to(products_path)
        expect(flash[:alert]).to include('Product not found')
      end
    end
  end

  describe 'GET #new' do
    it 'returns success' do
      get :new
      expect(response).to have_http_status(:success)
    end

    it 'assigns new product with defaults' do
      get :new
      expect(assigns(:product)).to include(
        sku: '',
        name: '',
        description: '',
        base_price: 0.0,
        tax_rate: 21.0,
        currency_code: 'EUR',
        is_active: true
      )
    end
  end

  describe 'POST #create' do
    context 'when successful' do
      before do
        allow(ProductService).to receive(:create)
          .with(instance_of(ActionController::Parameters), token: token)
          .and_return(product)
      end

      it 'creates product and redirects' do
        post :create, params: { product: product_params }
        expect(response).to redirect_to(product_path(product[:id]))
        expect(flash[:notice]).to eq('Product created successfully')
      end
    end

    context 'when validation fails' do
      let(:validation_errors) do
        [
          {
            status: '422',
            source: { pointer: '/data/attributes/sku' },
            title: 'Validation Error',
            detail: "SKU can't be blank",
            code: 'VALIDATION_ERROR'
          }
        ]
      end

      before do
        validation_error = ApiService::ValidationError.new('Validation failed', validation_errors)
        allow(ProductService).to receive(:create)
          .with(instance_of(ActionController::Parameters), token: token)
          .and_raise(validation_error)
      end

      it 'renders new template with errors' do
        post :create, params: { product: product_params.merge(sku: '') }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to render_template(:new)
        expect(assigns(:errors)).to include('sku' => ["can't be blank"])
        expect(flash[:alert]).to eq('Please fix the errors below.')
      end
    end

    context 'when API error occurs' do
      before do
        allow(ProductService).to receive(:create)
          .with(instance_of(ActionController::Parameters), token: token)
          .and_raise(ApiService::ApiError.new('Internal Server Error'))
      end

      it 'renders new template with error message' do
        post :create, params: { product: product_params }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to render_template(:new)
        expect(flash[:alert]).to include('Error creating product')
      end
    end
  end

  describe 'GET #edit' do
    before do
      allow(ProductService).to receive(:find)
        .with(product_id.to_s, token: token)
        .and_return(product)
    end

    it 'returns success' do
      get :edit, params: { id: product_id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns product' do
      get :edit, params: { id: product_id }
      expect(assigns(:product)).to eq(product)
    end
  end

  describe 'PATCH #update' do
    let(:updated_product) { product.merge(name: 'Updated Product Name') }

    before do
      # Mock the set_product method call
      allow(ProductService).to receive(:find)
        .with(product_id.to_s, token: token)
        .and_return(product)
    end

    context 'when successful' do
      before do
        allow(ProductService).to receive(:update)
          .with(product_id, instance_of(ActionController::Parameters), token: token)
          .and_return(updated_product)
      end

      it 'updates product and redirects' do
        patch :update, params: { id: product_id, product: { name: 'Updated Product Name' } }
        expect(response).to redirect_to(product_path(product_id))
        expect(flash[:notice]).to eq('Product updated successfully')
      end
    end

    context 'when validation fails' do
      let(:validation_errors) do
        [
          {
            status: '422',
            source: { pointer: '/data/attributes/base_price' },
            title: 'Validation Error',
            detail: 'Base price must be greater than or equal to 0',
            code: 'VALIDATION_ERROR'
          }
        ]
      end

      before do
        validation_error = ApiService::ValidationError.new('Validation failed', validation_errors)
        allow(ProductService).to receive(:update)
          .with(product_id, instance_of(ActionController::Parameters), token: token)
          .and_raise(validation_error)
      end

      it 'renders edit template with errors' do
        patch :update, params: { id: product_id, product: { base_price: -10 } }
        expect(response).to have_http_status(:unprocessable_content)
        expect(response).to render_template(:edit)
        expect(assigns(:errors)).to include('base_price' => ['must be greater than or equal to 0'])
        expect(flash[:alert]).to eq('Please fix the errors below.')
      end
    end
  end

  describe 'DELETE #destroy' do
    before do
      stub_request(:get, "#{base_url}/products/#{product_id}")
        .with(headers: { 'Authorization' => "Bearer #{token}" })
        .to_return(
          status: 200,
          body: product.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    context 'when successful' do
      before do
        stub_request(:delete, "#{base_url}/products/#{product_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 204)
      end

      it 'deletes product and redirects' do
        delete :destroy, params: { id: product_id }
        expect(response).to redirect_to(products_path)
        expect(flash[:notice]).to eq('Product deleted successfully')
      end
    end

    context 'when deletion fails' do
      before do
        stub_request(:delete, "#{base_url}/products/#{product_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 500, body: { error: 'Internal Server Error' }.to_json)
      end

      it 'redirects with error message' do
        delete :destroy, params: { id: product_id }
        expect(response).to redirect_to(products_path)
        expect(flash[:alert]).to include('Error deleting product')
      end
    end
  end

  describe 'GET #search' do
    let(:search_query) { 'test' }
    let(:search_results) { [product] }

    context 'when successful' do
      before do
        stub_request(:get, "#{base_url}/products/search")
          .with(
            headers: { 'Authorization' => "Bearer #{token}" },
            query: { q: search_query }
          )
          .to_return(
            status: 200,
            body: { data: [{ id: search_results.first[:id], type: 'products', attributes: search_results.first }] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns success for HTML request' do
        get :search, params: { q: search_query }
        expect(response).to have_http_status(:success)
        expect(assigns(:results)).to eq(search_results)
      end

      it 'returns JSON for AJAX request' do
        get :search, params: { q: search_query }, xhr: true
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include('application/json')
        json_response = JSON.parse(response.body, symbolize_names: true)
        expect(json_response).to be_an(Array)
        expect(json_response.first).to include(:id, :sku, :name, :display_name)
      end
    end

    context 'when query is too short' do
      it 'returns empty results' do
        get :search, params: { q: 'a' }
        expect(response).to have_http_status(:success)
        expect(assigns(:results)).to eq([])
      end
    end

    context 'when search fails' do
      before do
        stub_request(:get, "#{base_url}/products/search")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(status: 500, body: { error: 'Internal Server Error' }.to_json)
      end

      it 'handles error gracefully' do
        get :search, params: { q: search_query }
        expect(response).to have_http_status(:success)
        expect(assigns(:results)).to eq([])
        expect(flash[:alert]).to include('Error searching products')
      end
    end
  end

  describe 'POST #activate' do
    before do
      allow(ProductService).to receive(:find)
        .with(product_id.to_s, token: token)
        .and_return(inactive_product)
      allow(ProductService).to receive(:update)
        .with(inactive_product[:id], { is_active: true }, token: token)
        .and_return(inactive_product.merge(is_active: true))
    end

    it 'activates product and redirects' do
      post :activate, params: { id: product_id }
      expect(response).to redirect_to(products_path)
      expect(flash[:notice]).to eq('Product activated successfully')
    end
  end

  describe 'POST #deactivate' do
    before do
      allow(ProductService).to receive(:find)
        .with(product_id.to_s, token: token)
        .and_return(product)
      allow(ProductService).to receive(:update)
        .with(product[:id], { is_active: false }, token: token)
        .and_return(product.merge(is_active: false))
    end

    it 'deactivates product and redirects' do
      post :deactivate, params: { id: product_id }
      expect(response).to redirect_to(products_path)
      expect(flash[:notice]).to eq('Product deactivated successfully')
    end
  end

  describe 'POST #duplicate' do
    let(:duplicated_product) { build(:product_response, id: 999, sku: 'PRD-001-COPY', name: 'Test Product (Copy)', is_active: false) }
    let(:duplicate_params) do
      {
        sku: 'PRD-001-COPY',
        name: 'Test Product (Copy)',
        description: product[:description],
        base_price: product[:base_price],
        tax_rate: product[:tax_rate],
        currency_code: product[:currency_code],
        is_active: false
      }
    end

    before do
      allow(ProductService).to receive(:find)
        .with(product_id.to_s, token: token)
        .and_return(product)
      allow(ProductService).to receive(:create)
        .with(duplicate_params, token: token)
        .and_return(duplicated_product)
    end

    it 'duplicates product and redirects to edit' do
      post :duplicate, params: { id: product_id }
      expect(response).to redirect_to(edit_product_path(duplicated_product[:id]))
      expect(flash[:notice]).to eq('Product duplicated successfully. Please review and activate.')
    end
  end

  describe 'authorization' do
    context 'when user cannot create products' do
      before do
        allow(controller).to receive(:can?).with(:create, :products).and_return(false)
      end

      it 'redirects from new action' do
        get :new
        expect(response).to redirect_to(dashboard_path)
        expect(flash[:alert]).to include("You don't have permission to create products")
      end

      it 'redirects from create action' do
        post :create, params: { product: product_params }
        expect(response).to redirect_to(dashboard_path)
        expect(flash[:alert]).to include("You don't have permission to create products")
      end
    end

    context 'when user cannot edit products' do
      before do
        allow(controller).to receive(:can?).with(:edit, :products).and_return(false)
        stub_request(:get, "#{base_url}/products/#{product_id}")
          .with(headers: { 'Authorization' => "Bearer #{token}" })
          .to_return(
            status: 200,
            body: product.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'redirects from edit action' do
        get :edit, params: { id: product_id }
        expect(response).to redirect_to(dashboard_path)
        expect(flash[:alert]).to include("You don't have permission to edit products")
      end

      it 'redirects from update action' do
        patch :update, params: { id: product_id, product: { name: 'Updated' } }
        expect(response).to redirect_to(dashboard_path)
        expect(flash[:alert]).to include("You don't have permission to edit products")
      end

      it 'redirects from destroy action' do
        delete :destroy, params: { id: product_id }
        expect(response).to redirect_to(dashboard_path)
        expect(flash[:alert]).to include("You don't have permission to edit products")
      end
    end
  end
end