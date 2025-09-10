# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::UsersController, type: :controller do
  let(:superadmin) { create(:user, role: 'superadmin') }
  let(:regular_user) { create(:user, role: 'user') }
  let(:target_user) { create(:user, role: 'user') }

  before do
    sign_in superadmin
  end

  describe 'GET #index' do
    it 'returns a successful response' do
      get :index
      expect(response).to be_successful
    end

    it 'assigns users' do
      get :index
      expect(assigns(:users)).to be_present
    end
  end

  describe 'GET #show' do
    it 'returns a successful response' do
      get :show, params: { id: target_user.id }
      expect(response).to be_successful
    end

    it 'assigns the user' do
      get :show, params: { id: target_user.id }
      expect(assigns(:user)).to eq(target_user)
    end
  end

  describe 'GET #new' do
    it 'returns a successful response' do
      get :new
      expect(response).to be_successful
    end

    it 'assigns a new user' do
      get :new
      expect(assigns(:user)).to be_a_new(User)
    end
  end

  describe 'GET #edit' do
    it 'returns a successful response' do
      get :edit, params: { id: target_user.id }
      expect(response).to be_successful
    end

    it 'assigns the user' do
      get :edit, params: { id: target_user.id }
      expect(assigns(:user)).to eq(target_user)
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        user: {
          first_name: 'John',
          last_name: 'Doe',
          email: 'john.doe@example.com',
          role: 'user',
          subscription_tier: 'freemium'
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new user' do
        expect {
          post :create, params: valid_params
        }.to change(User, :count).by(1)
      end

      it 'redirects to the user show page' do
        post :create, params: valid_params
        expect(response).to redirect_to(admin_user_path(User.last))
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          user: {
            first_name: '',
            last_name: '',
            email: 'invalid-email',
            role: 'user'
          }
        }
      end

      it 'does not create a new user' do
        expect {
          post :create, params: invalid_params
        }.not_to change(User, :count)
      end

      it 'renders the new template' do
        post :create, params: invalid_params
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'PATCH #update' do
    let(:valid_params) do
      {
        id: target_user.id,
        user: {
          first_name: 'Updated Name',
          role: 'admin'
        }
      }
    end

    context 'with valid parameters' do
      it 'updates the user' do
        patch :update, params: valid_params
        target_user.reload
        expect(target_user.first_name).to eq('Updated Name')
        expect(target_user.role).to eq('admin')
      end

      it 'redirects to the user show page' do
        patch :update, params: valid_params
        expect(response).to redirect_to(admin_user_path(target_user))
      end
    end
  end

  describe 'POST #suspend' do
    let(:suspend_params) do
      {
        id: target_user.id,
        suspension_reason: 'Violation of terms'
      }
    end

    it 'suspends the user' do
      post :suspend, params: suspend_params
      target_user.reload
      expect(target_user.suspended?).to be true
      expect(target_user.suspended_reason).to eq('Violation of terms')
    end

    it 'redirects to the user show page' do
      post :suspend, params: suspend_params
      expect(response).to redirect_to(admin_user_path(target_user))
    end
  end

  describe 'POST #reactivate' do
    before do
      target_user.suspend!('Test suspension')
    end

    it 'reactivates the user' do
      post :reactivate, params: { id: target_user.id }
      target_user.reload
      expect(target_user.suspended?).to be false
    end

    it 'redirects to the user show page' do
      post :reactivate, params: { id: target_user.id }
      expect(response).to redirect_to(admin_user_path(target_user))
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes the user' do
      user_to_delete = create(:user, role: 'user')
      expect {
        delete :destroy, params: { id: user_to_delete.id }
      }.to change(User, :count).by(-1)
    end

    it 'redirects to the users index' do
      delete :destroy, params: { id: target_user.id }
      expect(response).to redirect_to(admin_users_path)
    end
  end

  describe 'POST #bulk_suspend' do
    let(:user_ids) { create_list(:user, 3).map(&:id) }
    let(:bulk_params) do
      {
        user_ids: user_ids,
        suspension_reason: 'Bulk suspension test'
      }
    end

    it 'suspends multiple users' do
      post :bulk_suspend, params: bulk_params
      
      User.where(id: user_ids).each do |user|
        expect(user.reload.suspended?).to be true
        expect(user.suspended_reason).to eq('Bulk suspension test')
      end
    end

    it 'returns success response' do
      post :bulk_suspend, params: bulk_params
      expect(response).to redirect_to(admin_users_path)
      expect(flash[:notice]).to include('3 users suspended successfully')
    end

    it 'handles partial failures' do
      # Make one user a superadmin (cannot be suspended)
      User.find(user_ids.first).update!(role: 'superadmin')
      
      post :bulk_suspend, params: bulk_params
      expect(flash[:alert]).to include('1 user could not be suspended')
    end
  end

  describe 'POST #bulk_delete' do
    let(:user_ids) { create_list(:user, 3).map(&:id) }
    let(:bulk_params) do
      {
        user_ids: user_ids,
        confirm: 'true'
      }
    end

    it 'deletes multiple users with confirmation' do
      expect {
        post :bulk_delete, params: bulk_params
      }.to change(User, :count).by(-3)
    end

    it 'requires confirmation' do
      post :bulk_delete, params: { user_ids: user_ids }
      expect(response).to redirect_to(admin_users_path)
      expect(flash[:alert]).to include('confirmation required')
    end

    it 'prevents deleting superadmins' do
      User.find(user_ids.first).update!(role: 'superadmin')
      
      post :bulk_delete, params: bulk_params
      expect(flash[:alert]).to include('Superadmin users cannot be deleted')
    end
  end

  describe 'GET #export' do
    before do
      create_list(:user, 5, :with_forms)
    end

    it 'exports users as CSV' do
      get :export, params: { format: :csv }
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include('text/csv')
    end

    it 'includes proper CSV headers' do
      get :export, params: { format: :csv }
      csv_content = response.body
      expect(csv_content).to include('Email,Name,Role,Subscription Tier,Created At,Last Activity')
    end

    it 'filters exported data' do
      get :export, params: { 
        format: :csv, 
        role: 'user',
        created_after: 1.week.ago.to_date
      }
      expect(response).to have_http_status(:success)
    end
  end

  describe 'error handling and edge cases' do
    it 'handles invalid user IDs gracefully' do
      expect {
        get :show, params: { id: 'invalid-uuid' }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'handles database errors during creation' do
      allow_any_instance_of(UserManagementService).to receive(:create_user).and_return(
        double(success?: false, errors: double(full_messages: ['Database error']))
      )

      post :create, params: {
        user: { email: 'test@example.com', first_name: 'Test', last_name: 'User' }
      }

      expect(response).to render_template(:new)
      expect(flash[:alert]).to include('Database error')
    end

    it 'handles concurrent user modifications' do
      # Simulate stale object error
      allow_any_instance_of(User).to receive(:update!).and_raise(
        ActiveRecord::StaleObjectError.new(target_user, 'update')
      )

      patch :update, params: {
        id: target_user.id,
        user: { first_name: 'Updated' }
      }

      expect(response).to redirect_to(admin_user_path(target_user))
      expect(flash[:alert]).to include('modified by another user')
    end

    it 'prevents self-suspension' do
      post :suspend, params: {
        id: superadmin.id,
        suspension_reason: 'Self suspension attempt'
      }

      expect(response).to redirect_to(admin_user_path(superadmin))
      expect(flash[:alert]).to include('cannot suspend your own account')
    end

    it 'prevents self-deletion' do
      delete :destroy, params: { id: superadmin.id }

      expect(response).to redirect_to(admin_user_path(superadmin))
      expect(flash[:alert]).to include('cannot delete your own account')
    end

    it 'prevents role escalation beyond current user level' do
      sign_out superadmin
      sign_in admin

      post :create, params: {
        user: {
          email: 'test@example.com',
          first_name: 'Test',
          last_name: 'User',
          role: 'superadmin'
        }
      }

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to include('insufficient privileges')
    end
  end

  describe 'performance and pagination' do
    before do
      create_list(:user, 50, :with_forms)
    end

    it 'paginates user listing efficiently' do
      get :index, params: { page: 1, per_page: 20 }
      
      expect(assigns(:users).count).to eq(20)
      expect(response).to be_successful
    end

    it 'handles search queries efficiently' do
      expect {
        get :index, params: { search: 'test' }
      }.to make_database_queries(count: 1..5)
    end

    it 'includes related data efficiently' do
      expect {
        get :index
      }.to make_database_queries(count: 1..5) # Should use includes to avoid N+1
    end
  end

  describe 'audit logging' do
    it 'logs user creation' do
      expect {
        post :create, params: {
          user: {
            email: 'audit@example.com',
            first_name: 'Audit',
            last_name: 'User',
            role: 'user'
          }
        }
      }.to change(AuditLog, :count).by(1)

      audit_log = AuditLog.last
      expect(audit_log.action).to eq('user_created')
      expect(audit_log.user_id).to eq(superadmin.id)
    end

    it 'logs user updates' do
      expect {
        patch :update, params: {
          id: target_user.id,
          user: { first_name: 'Updated' }
        }
      }.to change(AuditLog, :count).by(1)

      audit_log = AuditLog.last
      expect(audit_log.action).to eq('user_updated')
      expect(audit_log.target_id).to eq(target_user.id)
    end

    it 'logs user suspensions' do
      expect {
        post :suspend, params: {
          id: target_user.id,
          suspension_reason: 'Policy violation'
        }
      }.to change(AuditLog, :count).by(1)

      audit_log = AuditLog.last
      expect(audit_log.action).to eq('user_suspended')
      expect(audit_log.details['reason']).to eq('Policy violation')
    end

    it 'logs user deletions' do
      user_to_delete = create(:user)
      
      expect {
        delete :destroy, params: { id: user_to_delete.id }
      }.to change(AuditLog, :count).by(1)

      audit_log = AuditLog.last
      expect(audit_log.action).to eq('user_deleted')
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

      it 'redirects unauthorized users from all actions' do
        actions = [:show, :new, :edit, :create, :update, :suspend, :reactivate, :destroy]
        
        actions.each do |action|
          case action
          when :create
            post action, params: { user: { email: 'test@example.com' } }
          when :update, :show, :edit, :suspend, :reactivate, :destroy
            send(action == :destroy ? :delete : (action == :create ? :post : :get), 
                 action, params: { id: target_user.id })
          else
            get action
          end
          
          expect(response).to redirect_to(root_path)
        end
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

      it 'allows viewing individual users' do
        get :show, params: { id: target_user.id }
        expect(response).to be_successful
      end

      it 'prevents creating superadmin users' do
        post :create, params: {
          user: {
            email: 'test@example.com',
            first_name: 'Test',
            last_name: 'User',
            role: 'superadmin'
          }
        }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include('insufficient privileges')
      end

      it 'prevents modifying other admins' do
        another_admin = create(:user, role: 'admin')
        
        patch :update, params: {
          id: another_admin.id,
          user: { first_name: 'Updated' }
        }
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
end