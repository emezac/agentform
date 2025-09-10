class Integrations::GoogleSheetsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_form
  before_action :validate_premium_access
  before_action :set_integration, only: [:show, :update, :destroy, :export, :toggle_auto_sync]

  def show
    authorize @integration, :show?
    
    render json: {
      integration: @integration,
      spreadsheet_url: @integration&.spreadsheet_url,
      last_sync: @integration&.last_sync_at,
      sync_count: @integration&.sync_count || 0,
      error_message: @integration&.error_message
    }
  end

  def create
    authorize @form, :create?
    
    @integration = @form.build_google_sheets_integration(integration_params)
    
    if params[:create_new_spreadsheet]
      service = Integrations::GoogleSheetsService.new(@form)
      result = service.create_spreadsheet(params[:spreadsheet_title])
      
      if result.success?
        @integration.spreadsheet_id = result.value[:spreadsheet_id]
      else
        render json: { error: result.error }, status: :unprocessable_entity
        return
      end
    end

    if @integration.save
      # Initial export if requested
      if params[:export_existing]
        GoogleSheetsSyncJob.perform_later(@form.id, 'export_all')
      end

      render json: {
        integration: @integration,
        spreadsheet_url: @integration.spreadsheet_url,
        message: 'Google Sheets integration configured successfully'
      }
    else
      render json: { errors: @integration.errors }, status: :unprocessable_entity
    end
  end

  def update
    authorize @integration, :update?
    
    if @integration.update(integration_params)
      render json: {
        integration: @integration,
        message: 'Integration updated successfully'
      }
    else
      render json: { errors: @integration.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @integration, :destroy?
    
    @integration.destroy
    render json: { message: 'Google Sheets integration removed' }
  end

  def export
    authorize @integration, :export?
    
    unless @integration.can_sync?
      render json: { error: 'Integration is not active or properly configured' }, status: :unprocessable_entity
      return
    end

    GoogleSheetsSyncJob.perform_later(@form.id, 'export_all')
    
    render json: { 
      message: 'Export started. Your responses will be synced to Google Sheets shortly.',
      spreadsheet_url: @integration.spreadsheet_url
    }
  end

  def toggle_auto_sync
    authorize @integration, :toggle_auto_sync?
    
    @integration.update!(auto_sync: !@integration.auto_sync)
    
    render json: {
      auto_sync: @integration.auto_sync,
      message: @integration.auto_sync? ? 'Auto-sync enabled' : 'Auto-sync disabled'
    }
  end

  def test_connection
    authorize @form, :test_connection?
    
    service = Integrations::GoogleSheetsService.new(@form)
    
    begin
      # Try to create a test spreadsheet to verify credentials
      result = service.create_spreadsheet("Test - #{Time.current.to_i}")
      
      if result.success?
        render json: { 
          success: true, 
          message: 'Connection successful! Test spreadsheet created.',
          test_spreadsheet_url: "https://docs.google.com/spreadsheets/d/#{result.value[:spreadsheet_id]}/edit"
        }
      else
        render json: { success: false, error: result.error }
      end
    rescue => e
      render json: { success: false, error: "Connection failed: #{e.message}" }
    end
  end

  private

  def set_form
    @form = current_user.forms.find(params[:form_id])
  end

  def validate_premium_access
    unless current_user.can_use_google_sheets?
      render json: { 
        error: 'Premium subscription required',
        message: 'Google Sheets integration requires a Premium subscription',
        upgrade_url: subscription_management_path,
        required_plan: 'Premium'
      }, status: :forbidden
      return
    end
  end

  def set_integration
    @integration = @form.google_sheets_integration
    
    unless @integration
      render json: { error: 'No Google Sheets integration found' }, status: :not_found
    end
  end

  def integration_params
    params.require(:google_sheets_integration).permit(
      :spreadsheet_id, 
      :sheet_name, 
      :auto_sync,
      field_mapping: {}
    )
  end
end