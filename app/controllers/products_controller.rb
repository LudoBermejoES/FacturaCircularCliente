class ProductsController < ApplicationController
  before_action :set_product, only: [:show, :edit, :update, :destroy, :activate, :deactivate, :duplicate]
  before_action :check_permission_to_create, only: [:new, :create]
  before_action :check_permission_to_edit, only: [:edit, :update, :destroy]

  def index
    @page = params[:page] || 1
    @per_page = params[:per_page] || 25
    @filters = {
      search: params[:search],
      is_active: params[:is_active],
      tax_rate: params[:tax_rate]
    }.compact

    begin
      response = ProductService.all(
        token: current_token,
        params: {
          page: @page,
          per_page: @per_page,
          **@filters
        }
      )

      @products = response[:products] || []
      @total_count = response[:meta] ? response[:meta][:total_count] : 0
      @current_page = response[:meta][:current_page] if response[:meta]
      @total_pages = response[:meta][:page_count] if response[:meta]

      # Load statistics for dashboard
      @statistics = {
        total_products: @total_count,
        active_products: @products.count { |p| p[:is_active] },
        inactive_products: @products.count { |p| !p[:is_active] }
      }
    rescue ApiService::ApiError => e
      @products = []
      @statistics = {}
      flash.now[:alert] = "Error loading products: #{e.message}"
    end
  end

  def show
    # Product details are already loaded in set_product
  end

  def new
    @product = {
      sku: '',
      name: '',
      description: '',
      base_price: 0.0,
      tax_rate: 21.0,
      currency_code: 'EUR',
      is_active: true
    }
  end

  def create
    begin
      Rails.logger.info "DEBUG: ProductsController#create - Starting"
      Rails.logger.info "DEBUG: Product params: #{product_params.inspect}"

      response = ProductService.create(product_params, token: current_token)
      Rails.logger.info "DEBUG: ProductService.create returned: #{response.inspect}"

      # Handle AJAX requests differently
      if request.xhr?
        render json: response, status: :created
      else
        redirect_to product_path(response[:id]), notice: 'Product created successfully'
      end
    rescue ApiService::ValidationError => e
      Rails.logger.info "DEBUG: ValidationError caught: #{e.message}"
      Rails.logger.info "DEBUG: ValidationError errors: #{e.errors.inspect}"
      @product = product_params

      # Parse API errors into a format the view can understand
      @errors = parse_validation_errors(e.errors)
      Rails.logger.info "DEBUG: Parsed errors: #{@errors.inspect}"

      if request.xhr?
        render json: { errors: @errors }, status: :unprocessable_entity
      else
        flash.now[:alert] = 'Please fix the errors below.'
        render :new, status: :unprocessable_content
      end
    rescue ApiService::ApiError => e
      Rails.logger.info "DEBUG: ApiError caught: #{e.message}"
      @product = product_params

      if request.xhr?
        render json: { errors: [e.message] }, status: :unprocessable_entity
      else
        flash.now[:alert] = "Error creating product: #{e.message}"
        render :new, status: :unprocessable_content
      end
    rescue => e
      Rails.logger.error "DEBUG: Unexpected error in create: #{e.class} - #{e.message}"
      Rails.logger.error "DEBUG: Backtrace: #{e.backtrace.first(5).join("\n")}"
      @product = product_params

      if request.xhr?
        render json: { errors: ["Unexpected error: #{e.message}"] }, status: :internal_server_error
      else
        flash.now[:alert] = "Unexpected error: #{e.message}"
        render :new, status: :unprocessable_content
      end
    end
  end

  def edit
    # Product data is already loaded in set_product
  end

  def update
    begin
      Rails.logger.info "DEBUG: ProductsController#update - Starting"
      Rails.logger.info "DEBUG: Product params: #{product_params.inspect}"

      response = ProductService.update(@product[:id], product_params, token: current_token)
      Rails.logger.info "DEBUG: ProductService.update returned: #{response.inspect}"
      redirect_to product_path(@product[:id]), notice: 'Product updated successfully'
    rescue ApiService::ValidationError => e
      Rails.logger.info "DEBUG: ValidationError caught: #{e.message}"
      Rails.logger.info "DEBUG: ValidationError errors: #{e.errors.inspect}"

      # Parse API errors into a format the view can understand
      @errors = parse_validation_errors(e.errors)
      Rails.logger.info "DEBUG: Parsed errors: #{@errors.inspect}"

      flash.now[:alert] = 'Please fix the errors below.'
      render :edit, status: :unprocessable_content
    rescue ApiService::ApiError => e
      Rails.logger.info "DEBUG: ApiError caught: #{e.message}"
      flash.now[:alert] = "Error updating product: #{e.message}"
      render :edit, status: :unprocessable_content
    rescue => e
      Rails.logger.error "DEBUG: Unexpected error in update: #{e.class} - #{e.message}"
      Rails.logger.error "DEBUG: Backtrace: #{e.backtrace.first(5).join("\n")}"
      flash.now[:alert] = "Unexpected error: #{e.message}"
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    begin
      ProductService.destroy(@product[:id], token: current_token)
      redirect_to products_path, notice: 'Product deleted successfully'
    rescue ApiService::ApiError => e
      redirect_to products_path, alert: "Error deleting product: #{e.message}"
    end
  end

  def search
    @query = params[:q] || ''
    @results = []

    if @query.present? && @query.length >= 2
      begin
        response = ProductService.search(@query, token: current_token)
        @results = response[:products] || []
      rescue ApiService::ApiError => e
        @results = []
        flash.now[:alert] = "Error searching products: #{e.message}"
      end
    end

    # Return JSON for AJAX requests
    if request.xhr?
      render json: @results.map { |product|
        {
          id: product[:id],
          sku: product[:sku],
          name: product[:name],
          description: product[:description],
          base_price: product[:base_price],
          tax_rate: product[:tax_rate],
          display_name: product[:display_name],
          formatted_price: product[:formatted_price]
        }
      }
    else
      # Regular HTML response for search page
      render :search
    end
  end

  def activate
    begin
      ProductService.update(@product[:id], { is_active: true }, token: current_token)
      redirect_to products_path, notice: 'Product activated successfully'
    rescue ApiService::ApiError => e
      redirect_to products_path, alert: "Error activating product: #{e.message}"
    end
  end

  def deactivate
    begin
      ProductService.update(@product[:id], { is_active: false }, token: current_token)
      redirect_to products_path, notice: 'Product deactivated successfully'
    rescue ApiService::ApiError => e
      redirect_to products_path, alert: "Error deactivating product: #{e.message}"
    end
  end

  def duplicate
    begin
      # Create a new product based on the existing one
      new_product_params = {
        sku: "#{@product[:sku]}-COPY",
        name: "#{@product[:name]} (Copy)",
        description: @product[:description],
        base_price: @product[:base_price],
        tax_rate: @product[:tax_rate],
        currency_code: @product[:currency_code],
        is_active: false # Start as inactive
      }

      response = ProductService.create(new_product_params, token: current_token)
      redirect_to edit_product_path(response[:id]), notice: 'Product duplicated successfully. Please review and activate.'
    rescue ApiService::ApiError => e
      redirect_to products_path, alert: "Error duplicating product: #{e.message}"
    end
  end

  private

  def set_product
    begin
      @product = ProductService.find(params[:id], token: current_token)
      Rails.logger.info "DEBUG: set_product - @product = #{@product.inspect}"
    rescue ApiService::ApiError => e
      redirect_to products_path, alert: "Product not found: #{e.message}"
    end
  end

  def product_params
    params.require(:product).permit(
      :sku, :name, :description, :base_price, :tax_rate, :currency_code, :is_active
    )
  end

  def check_permission_to_create
    unless can?(:create, :products)
      redirect_to dashboard_path, alert: "You don't have permission to create products."
    end
  end

  def check_permission_to_edit
    unless can?(:edit, :products)
      redirect_to dashboard_path, alert: "You don't have permission to edit products."
    end
  end

  # Parse API validation errors into a format the view can understand
  # API errors come in format: [{status: "422", source: {pointer: "/data/attributes/sku"}, title: "Validation Error", detail: "SKU can't be blank", code: "VALIDATION_ERROR"}]
  # We need to convert to: {"sku" => ["can't be blank"]}
  def parse_validation_errors(api_errors)
    errors = {}

    return errors unless api_errors.is_a?(Array)

    api_errors.each do |error|
      next unless error.is_a?(Hash) && error[:source] && error[:source][:pointer] && error[:detail]

      # Extract field name from pointer like "/data/attributes/sku"
      pointer = error[:source][:pointer]
      if pointer.match(%r{/data/attributes/(.+)})
        field_name = $1
        message = error[:detail]

        # Remove field name from the beginning of the message if it's there
        # "SKU can't be blank" -> "can't be blank"
        field_label = field_name.humanize.downcase
        message = message.gsub(/^#{Regexp.escape(field_label)}\s+/i, '')

        errors[field_name] ||= []
        errors[field_name] << message
      end
    end

    errors
  end
end