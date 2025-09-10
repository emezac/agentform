# frozen_string_literal: true

class Admin::DiscountCodesController < Admin::BaseController
  before_action :set_discount_code, only: [:show, :edit, :update, :destroy, :toggle_status]

  def index
    # Build optimized query with selective includes
    @discount_codes = DiscountCode.includes(:created_by)
                                  .select('discount_codes.*, COUNT(discount_code_usages.id) as usage_count')
                                  .left_joins(:discount_code_usages)
                                  .group('discount_codes.id')
                                  .order(created_at: :desc)
    
    # Apply filters if present
    if params[:status].present?
      case params[:status]
      when 'active'
        @discount_codes = @discount_codes.where(active: true)
      when 'inactive'
        @discount_codes = @discount_codes.where(active: false)
      when 'expired'
        @discount_codes = @discount_codes.where('expires_at < ?', Time.current)
      end
    end
    
    if params[:search].present?
      @discount_codes = @discount_codes.where('code ILIKE ?', "%#{params[:search]}%")
    end
    
    # Apply pagination
    @discount_codes = @discount_codes.page(params[:page]).per(20)
    
    # Load analytics data with caching
    @analytics = Rails.cache.fetch('admin_discount_analytics', expires_in: 5.minutes) do
      DiscountCode.usage_stats_summary
    end
    
    @top_codes = Rails.cache.fetch('admin_top_discount_codes', expires_in: 10.minutes) do
      DiscountCode.most_used(5)
    end
    
    @highest_revenue = Rails.cache.fetch('admin_highest_revenue_codes', expires_in: 10.minutes) do
      DiscountCode.highest_revenue_impact(5)
    end
  end

  def show
    @usage_stats = DiscountCodeService.new.get_usage_statistics(@discount_code)
    @recent_usages = @discount_code.discount_code_usages
                                   .includes(:user)
                                   .recent
                                   .limit(10)
  end

  def new
    @discount_code = DiscountCode.new
  end

  def create
    @discount_code = DiscountCode.new(discount_code_params)
    @discount_code.created_by = current_user

    if @discount_code.save
      # Log the creation
      AuditLog.create!(
        user: current_user,
        event_type: 'discount_code_created',
        details: {
          discount_code_id: @discount_code.id,
          code: @discount_code.code,
          discount_percentage: @discount_code.discount_percentage
        },
        ip_address: request.remote_ip
      )
      
      redirect_to admin_discount_code_path(@discount_code), 
                  notice: 'Discount code was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    old_attributes = @discount_code.attributes.dup
    
    if @discount_code.update(discount_code_params.except(:code))
      # Log the update
      changes = @discount_code.previous_changes.except('updated_at')
      if changes.any?
        AuditLog.create!(
          user: current_user,
          event_type: 'discount_code_updated',
          details: {
            discount_code_id: @discount_code.id,
            code: @discount_code.code,
            changes: changes
          },
          ip_address: request.remote_ip
        )
      end
      
      redirect_to admin_discount_code_path(@discount_code), 
                  notice: 'Discount code was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @discount_code.discount_code_usages.exists?
      redirect_to admin_discount_codes_path, 
                  alert: 'Cannot delete discount code that has been used.'
    else
      # Log the deletion
      AuditLog.create!(
        user: current_user,
        event_type: 'discount_code_deleted',
        details: {
          discount_code_id: @discount_code.id,
          code: @discount_code.code,
          discount_percentage: @discount_code.discount_percentage,
          usage_count: @discount_code.current_usage_count
        },
        ip_address: request.remote_ip
      )
      
      @discount_code.destroy
      redirect_to admin_discount_codes_path, 
                  notice: 'Discount code was successfully deleted.'
    end
  end

  def toggle_status
    old_status = @discount_code.active?
    @discount_code.update!(active: !@discount_code.active?)
    
    # Log the status change
    AuditLog.create!(
      user: current_user,
      event_type: 'discount_code_status_changed',
      details: {
        discount_code_id: @discount_code.id,
        code: @discount_code.code,
        from_status: old_status ? 'active' : 'inactive',
        to_status: @discount_code.active? ? 'active' : 'inactive'
      },
      ip_address: request.remote_ip
    )
    
    status_text = @discount_code.active? ? 'activated' : 'deactivated'
    redirect_to admin_discount_codes_path, 
                notice: "Discount code was successfully #{status_text}."
  end

  private

  def set_discount_code
    @discount_code = DiscountCode.find(params[:id])
  end

  def discount_code_params
    permitted = params.require(:discount_code).permit(:code, :discount_percentage, :max_usage_count, :expires_at, :active)
    
    # Validate required parameters for creation
    if action_name == 'create'
      validate_admin_params(permitted, [:code, :discount_percentage])
    end
    
    # Additional validation
    validate_admin_params(permitted)
    
    # Normalize and validate expires_at
    if permitted[:expires_at].present?
      begin
        expires_at = Time.zone.parse(permitted[:expires_at])
        if expires_at < Time.current
          raise ActionController::BadRequest.new("Expiration date cannot be in the past")
        end
        permitted[:expires_at] = expires_at
      rescue ArgumentError
        raise ActionController::BadRequest.new("Invalid expiration date format")
      end
    end
    
    permitted
  end
end