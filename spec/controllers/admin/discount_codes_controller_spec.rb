# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::DiscountCodesController, type: :controller do
  let(:superadmin) { create(:user, role: 'superadmin') }
  let(:admin) { create(:user, role: 'admin') }
  let(:regular_user) { create(:user, role: 'user') }
  let!(:discount_code) { create(:discount_code, created_by: superadmin, code: 'SAVE20') }

  before do
    sign_in superadmin
  end

  describe 'GET #index' do
    let!(:active_code) { create(:discount_code, created_by: superadmin, active: true) }
    let!(:inactive_code) { create(:discount_code, created_by: superadmin, active: false) }
    let!(:expired_code) { create(:discount_code, created_by: superadmin, expires_at: 1.day.ago) }

    it 'returns a successful response' do
      get :index
      expect(response).to be_successful
    end

    it 'assigns discount codes' do
      get :index
      expect(assigns(:discount_codes)).to be_present
      expect(assigns(:discount_codes).count).to be >= 4 # Including the let! discount_code
    end

    it 'filters by status when requested' do
      get :index, params: { status: 'active' }
      expect(assigns(:discount_codes).all?(&:active?)).to be true
    end

    it 'searches by code when requested' do
      get :index, params: { search: 'SAVE' }
      expect(assigns(:discount_codes).map(&:code)).to include('SAVE20')
    end

    it 'paginates results' do
      create_list(:discount_code, 25, created_by: superadmin)
      get :index, params: { page: 1, per_page: 10 }
      expect(assigns(:discount_codes).count).to eq(10)
    end
  end

  describe 'GET #show' do
    let!(:usage1) { create(:discount_code_usage, discount_code: discount_code) }
    let!(:usage2) { create(:discount_code_usage, discount_code: discount_code) }

    it 'returns a successful response' do
      get :show, params: { id: discount_code.id }
      expect(response).to be_successful
    end

    it 'assigns the discount code' do
      get :show, params: { id: discount_code.id }
      expect(assigns(:discount_code)).to eq(discount_code)
    end

    it 'assigns usage statistics' do
      get :show, params: { id: discount_code.id }
      expect(assigns(:usage_stats)).to be_present
      expect(assigns(:usage_stats)[:total_uses]).to eq(2)
    end

    it 'assigns recent usages' do
      get :show, params: { id: discount_code.id }
      expect(assigns(:recent_usages)).to be_present
      expect(assigns(:recent_usages).count).to eq(2)
    end

    context 'when discount code does not exist' do
      it 'returns 404' do
        expect {
          get :show, params: { id: 'nonexistent' }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'GET #new' do
    it 'returns a successful response' do
      get :new
      expect(response).to be_successful
    end

    it 'assigns a new discount code' do
      get :new
      expect(assigns(:discount_code)).to be_a_new(DiscountCode)
    end
  end

  describe 'GET #edit' do
    it 'returns a successful response' do
      get :edit, params: { id: discount_code.id }
      expect(response).to be_successful
    end

    it 'assigns the discount code' do
      get :edit, params: { id: discount_code.id }
      expect(assigns(:discount_code)).to eq(discount_code)
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        discount_code: {
          code: 'NEWCODE20',
          discount_percentage: 25,
          max_usage_count: 100,
          expires_at: 1.month.from_now,
          active: true
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new discount code' do
        expect {
          post :create, params: valid_params
        }.to change(DiscountCode, :count).by(1)
      end

      it 'sets the created_by to current user' do
        post :create, params: valid_params
        created_code = DiscountCode.last
        expect(created_code.created_by).to eq(superadmin)
      end

      it 'redirects to the discount code show page' do
        post :create, params: valid_params
        expect(response).to redirect_to(admin_discount_code_path(DiscountCode.last))
      end

      it 'sets a success flash message' do
        post :create, params: valid_params
        expect(flash[:notice]).to eq('Discount code created successfully.')
      end

      it 'normalizes the code to uppercase' do
        params = valid_params.deep_dup
        params[:discount_code][:code] = 'lowercase'
        
        post :create, params: params
        created_code = DiscountCode.last
        expect(created_code.code).to eq('LOWERCASE')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          discount_code: {
            code: '',
            discount_percentage: 150, # Invalid percentage
            max_usage_count: -1
          }
        }
      end

      it 'does not create a new discount code' do
        expect {
          post :create, params: invalid_params
        }.not_to change(DiscountCode, :count)
      end

      it 'renders the new template' do
        post :create, params: invalid_params
        expect(response).to render_template(:new)
      end

      it 'assigns errors to the discount code' do
        post :create, params: invalid_params
        expect(assigns(:discount_code).errors).to be_present
      end
    end

    context 'with duplicate code' do
      let(:duplicate_params) do
        {
          discount_code: {
            code: 'SAVE20', # Already exists
            discount_percentage: 15,
            max_usage_count: 50
          }
        }
      end

      it 'does not create a new discount code' do
        expect {
          post :create, params: duplicate_params
        }.not_to change(DiscountCode, :count)
      end

      it 'shows uniqueness error' do
        post :create, params: duplicate_params
        expect(assigns(:discount_code).errors[:code]).to include('has already been taken')
      end
    end
  end

  describe 'PATCH #update' do
    let(:valid_params) do
      {
        id: discount_code.id,
        discount_code: {
          discount_percentage: 30,
          max_usage_count: 200,
          expires_at: 2.months.from_now
        }
      }
    end

    context 'with valid parameters' do
      it 'updates the discount code' do
        patch :update, params: valid_params
        discount_code.reload
        expect(discount_code.discount_percentage).to eq(30)
        expect(discount_code.max_usage_count).to eq(200)
      end

      it 'redirects to the discount code show page' do
        patch :update, params: valid_params
        expect(response).to redirect_to(admin_discount_code_path(discount_code))
      end

      it 'sets a success flash message' do
        patch :update, params: valid_params
        expect(flash[:notice]).to eq('Discount code updated successfully.')
      end

      it 'does not allow updating the code' do
        params = valid_params.deep_dup
        params[:discount_code][:code] = 'NEWCODE'
        
        patch :update, params: params
        discount_code.reload
        expect(discount_code.code).to eq('SAVE20') # Should remain unchanged
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          id: discount_code.id,
          discount_code: {
            discount_percentage: 0, # Invalid
            max_usage_count: -5
          }
        }
      end

      it 'does not update the discount code' do
        original_percentage = discount_code.discount_percentage
        patch :update, params: invalid_params
        discount_code.reload
        expect(discount_code.discount_percentage).to eq(original_percentage)
      end

      it 'renders the edit template' do
        patch :update, params: invalid_params
        expect(response).to render_template(:edit)
      end
    end
  end

  describe 'POST #toggle_status' do
    context 'when code is active' do
      before { discount_code.update!(active: true) }

      it 'deactivates the code' do
        post :toggle_status, params: { id: discount_code.id }
        discount_code.reload
        expect(discount_code.active?).to be false
      end

      it 'returns success response' do
        post :toggle_status, params: { id: discount_code.id }
        expect(response).to have_http_status(:success)
      end

      it 'returns JSON with new status' do
        post :toggle_status, params: { id: discount_code.id }
        json_response = JSON.parse(response.body)
        expect(json_response['active']).to be false
        expect(json_response['message']).to include('deactivated')
      end
    end

    context 'when code is inactive' do
      before { discount_code.update!(active: false) }

      it 'activates the code' do
        post :toggle_status, params: { id: discount_code.id }
        discount_code.reload
        expect(discount_code.active?).to be true
      end

      it 'returns JSON with new status' do
        post :toggle_status, params: { id: discount_code.id }
        json_response = JSON.parse(response.body)
        expect(json_response['active']).to be true
        expect(json_response['message']).to include('activated')
      end
    end

    context 'when code has reached usage limit' do
      before do
        discount_code.update!(max_usage_count: 1, current_usage_count: 1, active: false)
      end

      it 'prevents reactivation' do
        post :toggle_status, params: { id: discount_code.id }
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('usage limit')
      end
    end

    context 'when code is expired' do
      before do
        discount_code.update!(expires_at: 1.day.ago, active: false)
      end

      it 'prevents reactivation' do
        post :toggle_status, params: { id: discount_code.id }
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to include('expired')
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:code_to_delete) { create(:discount_code, created_by: superadmin) }

    context 'when code has no usages' do
      it 'deletes the discount code' do
        expect {
          delete :destroy, params: { id: code_to_delete.id }
        }.to change(DiscountCode, :count).by(-1)
      end

      it 'redirects to the discount codes index' do
        delete :destroy, params: { id: code_to_delete.id }
        expect(response).to redirect_to(admin_discount_codes_path)
      end

      it 'sets a success flash message' do
        delete :destroy, params: { id: code_to_delete.id }
        expect(flash[:notice]).to eq('Discount code deleted successfully.')
      end
    end

    context 'when code has usages' do
      before do
        create(:discount_code_usage, discount_code: code_to_delete)
      end

      it 'does not delete the discount code' do
        expect {
          delete :destroy, params: { id: code_to_delete.id }
        }.not_to change(DiscountCode, :count)
      end

      it 'redirects with error message' do
        delete :destroy, params: { id: code_to_delete.id }
        expect(response).to redirect_to(admin_discount_code_path(code_to_delete))
        expect(flash[:alert]).to include('cannot be deleted because it has been used')
      end
    end
  end

  describe 'GET #export' do
    before do
      create_list(:discount_code, 3, created_by: superadmin)
      create_list(:discount_code_usage, 2, discount_code: discount_code)
    end

    it 'returns CSV data' do
      get :export, params: { format: :csv }
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include('text/csv')
    end

    it 'includes proper CSV headers' do
      get :export, params: { format: :csv }
      csv_content = response.body
      expect(csv_content).to include('Code,Discount Percentage,Max Usage,Current Usage,Active,Expires At,Revenue Impact')
    end

    it 'filters exported data by date range' do
      get :export, params: { 
        format: :csv, 
        start_date: 1.week.ago.to_date, 
        end_date: Date.current 
      }
      expect(response).to have_http_status(:success)
    end
  end

  describe 'authorization' do
    context 'when user is not a superadmin' do
      before do
        sign_out superadmin
        sign_in regular_user
      end

      it 'redirects unauthorized users from index' do
        get :index
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Access denied. Superadmin privileges required.')
      end

      it 'redirects unauthorized users from show' do
        get :show, params: { id: discount_code.id }
        expect(response).to redirect_to(root_path)
      end

      it 'redirects unauthorized users from create' do
        post :create, params: { discount_code: { code: 'TEST' } }
        expect(response).to redirect_to(root_path)
      end

      it 'redirects unauthorized users from update' do
        patch :update, params: { id: discount_code.id, discount_code: { discount_percentage: 10 } }
        expect(response).to redirect_to(root_path)
      end

      it 'redirects unauthorized users from destroy' do
        delete :destroy, params: { id: discount_code.id }
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user is an admin (not superadmin)' do
      before do
        sign_out superadmin
        sign_in admin
      end

      it 'allows read access' do
        get :index
        expect(response).to be_successful
      end

      it 'allows viewing individual codes' do
        get :show, params: { id: discount_code.id }
        expect(response).to be_successful
      end

      it 'prevents creating new codes' do
        post :create, params: { discount_code: { code: 'TEST' } }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include('Superadmin privileges required')
      end

      it 'prevents modifying codes' do
        patch :update, params: { id: discount_code.id, discount_code: { discount_percentage: 10 } }
        expect(response).to redirect_to(root_path)
      end

      it 'prevents deleting codes' do
        delete :destroy, params: { id: discount_code.id }
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user is not signed in' do
      before do
        sign_out superadmin
      end

      it 'redirects to sign in' do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'error handling' do
    it 'handles invalid discount code IDs gracefully' do
      expect {
        get :show, params: { id: 'invalid-uuid' }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'handles database errors during creation' do
      allow_any_instance_of(DiscountCode).to receive(:save).and_return(false)
      allow_any_instance_of(DiscountCode).to receive(:errors).and_return(
        double(full_messages: ['Database error'])
      )

      post :create, params: {
        discount_code: { code: 'TEST', discount_percentage: 20 }
      }

      expect(response).to render_template(:new)
    end

    it 'handles concurrent modifications' do
      # Simulate stale object error
      allow_any_instance_of(DiscountCode).to receive(:update!).and_raise(
        ActiveRecord::StaleObjectError.new(discount_code, 'update')
      )

      patch :update, params: {
        id: discount_code.id,
        discount_code: { discount_percentage: 25 }
      }

      expect(response).to redirect_to(admin_discount_code_path(discount_code))
      expect(flash[:alert]).to include('modified by another user')
    end
  end

  describe 'performance considerations' do
    it 'efficiently loads discount codes with usage counts' do
      create_list(:discount_code, 10, created_by: superadmin)

      expect {
        get :index
      }.to make_database_queries(count: 1..5) # Should be efficient with includes
    end

    it 'paginates large datasets' do
      create_list(:discount_code, 100, created_by: superadmin)

      get :index, params: { per_page: 20 }
      expect(assigns(:discount_codes).count).to eq(20)
    end
  end

  describe 'audit logging' do
    it 'logs discount code creation' do
      expect {
        post :create, params: {
          discount_code: { code: 'AUDIT', discount_percentage: 15 }
        }
      }.to change(AuditLog, :count).by(1)

      audit_log = AuditLog.last
      expect(audit_log.action).to eq('discount_code_created')
      expect(audit_log.user_id).to eq(superadmin.id)
    end

    it 'logs discount code updates' do
      expect {
        patch :update, params: {
          id: discount_code.id,
          discount_code: { discount_percentage: 25 }
        }
      }.to change(AuditLog, :count).by(1)

      audit_log = AuditLog.last
      expect(audit_log.action).to eq('discount_code_updated')
    end

    it 'logs discount code deletion attempts' do
      expect {
        delete :destroy, params: { id: discount_code.id }
      }.to change(AuditLog, :count).by(1)

      audit_log = AuditLog.last
      expect(audit_log.action).to eq('discount_code_deleted')
    end

    it 'logs status changes' do
      expect {
        post :toggle_status, params: { id: discount_code.id }
      }.to change(AuditLog, :count).by(1)

      audit_log = AuditLog.last
      expect(audit_log.action).to eq('discount_code_status_changed')
    end
  end
end