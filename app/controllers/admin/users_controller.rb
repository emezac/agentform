# frozen_string_literal: true

# Admin controller for managing users
class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [:show, :edit, :update, :suspend, :reactivate, :send_password_reset, :destroy]

  # GET /admin/users
  def index
    @service = UserManagementService.new(
      current_user: current_user,
      filters: filter_params
    )
    
    result = @service.list_users
    
    if result.success?
      @users = result.result[:users]
      @total_count = result.result[:total_count]
      @current_page = result.result[:current_page]
      @per_page = result.result[:per_page]
      @total_pages = result.result[:total_pages]
    else
      flash[:error] = result.errors.full_messages.join(', ')
      @users = User.none.page(1)
      @total_count = 0
      @current_page = 1
      @per_page = 25
      @total_pages = 0
    end
  end

  # GET /admin/users/:id
  def show
    @service = UserManagementService.new(
      current_user: current_user,
      user_id: @user.id
    )
    
    result = @service.get_user_details
    
    if result.success?
      @user_details = result.result
    else
      flash[:error] = result.errors.full_messages.join(', ')
      redirect_to admin_users_path
    end
  end

  # GET /admin/users/new
  def new
    @user = User.new
  end

  # POST /admin/users
  def create
    @service = UserManagementService.new(
      current_user: current_user,
      user_params: user_params
    )
    
    result = @service.create_user
    
    if result.success?
      flash[:success] = result.result[:message]
      redirect_to admin_user_path(result.result[:user])
    else
      @user = User.new(user_params)
      flash.now[:error] = result.errors.full_messages.join(', ')
      render :new, status: :unprocessable_entity
    end
  end

  # GET /admin/users/:id/edit
  def edit
    # @user is set by before_action
  end

  # PATCH/PUT /admin/users/:id
  def update
    @service = UserManagementService.new(
      current_user: current_user,
      user_id: @user.id,
      user_params: user_params
    )
    
    result = @service.update_user
    
    if result.success?
      flash[:success] = result.result[:message]
      redirect_to admin_user_path(@user)
    else
      flash.now[:error] = result.errors.full_messages.join(', ')
      render :edit, status: :unprocessable_entity
    end
  end

  # POST /admin/users/:id/suspend
  def suspend
    @service = UserManagementService.new(
      current_user: current_user,
      user_id: @user.id,
      suspension_reason: params[:suspension_reason]
    )
    
    result = @service.suspend_user
    
    if result.success?
      flash[:success] = result.result[:message]
    else
      flash[:error] = result.errors.full_messages.join(', ')
    end
    
    redirect_to admin_user_path(@user)
  end

  # POST /admin/users/:id/reactivate
  def reactivate
    @service = UserManagementService.new(
      current_user: current_user,
      user_id: @user.id
    )
    
    result = @service.reactivate_user
    
    if result.success?
      flash[:success] = result.result[:message]
    else
      flash[:error] = result.errors.full_messages.join(', ')
    end
    
    redirect_to admin_user_path(@user)
  end

  # POST /admin/users/:id/send_password_reset
  def send_password_reset
    @service = UserManagementService.new(
      current_user: current_user,
      user_id: @user.id
    )
    
    result = @service.send_password_reset
    
    respond_to do |format|
      format.json do
        if result.success?
          render json: { success: true, message: result.result[:message] }
        else
          render json: { success: false, error: result.errors.full_messages.join(', ') }
        end
      end
    end
  end

  # DELETE /admin/users/:id
  def destroy
    @service = UserManagementService.new(
      current_user: current_user,
      user_id: @user.id,
      transfer_data: params[:transfer_data] == 'true'
    )
    
    result = @service.delete_user
    
    if result.success?
      flash[:success] = result.result[:message]
      redirect_to admin_users_path
    else
      flash[:error] = result.errors.full_messages.join(', ')
      redirect_to admin_user_path(@user)
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'User not found'
    redirect_to admin_users_path
  end

  def user_params
    permitted = params.require(:user).permit(
      :email, :first_name, :last_name, :role, :subscription_tier,
      :password, :password_confirmation
    )
    
    # Validate required parameters for creation
    if action_name == 'create'
      validate_admin_params(permitted, [:email, :first_name, :last_name, :role])
    end
    
    # Additional validation
    validate_admin_params(permitted)
    
    permitted
  end

  def filter_params
    permitted = params.permit(:search, :role, :tier, :status, :page, :per_page, :created_after, :created_before)
    
    # Validate filter parameters
    if permitted[:page].present?
      permitted[:page] = [permitted[:page].to_i, 1].max
    end
    
    if permitted[:per_page].present?
      permitted[:per_page] = [permitted[:per_page].to_i.clamp(1, 100), 25].min
    end
    
    if permitted[:role].present?
      validate_role(permitted[:role])
    end
    
    if permitted[:tier].present?
      validate_subscription_tier(permitted[:tier])
    end
    
    permitted
  end
end