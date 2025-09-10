require 'rails_helper'

RSpec.describe Admin::NotificationsController, type: :controller do
  let(:superadmin) { create(:user, role: 'superadmin') }
  let(:regular_user) { create(:user, role: 'user') }

  before do
    sign_in superadmin
  end

  describe 'GET #index' do
    let!(:notifications) { create_list(:admin_notification, 3) }

    it 'returns successful response' do
      get :index
      expect(response).to be_successful
    end

    it 'assigns notifications' do
      get :index
      expect(assigns(:notifications)).to match_array(notifications)
    end

    it 'assigns stats' do
      create(:admin_notification, :unread)
      create(:admin_notification, :read)
      
      get :index
      
      stats = assigns(:stats)
      expect(stats[:total]).to eq(5) # 3 + 2 new ones
      expect(stats[:unread]).to eq(4) # 3 original + 1 unread
    end

    context 'with filters' do
      let!(:high_priority) { create(:admin_notification, priority: 'high') }
      let!(:normal_priority) { create(:admin_notification, priority: 'normal') }

      it 'filters by priority' do
        get :index, params: { priority: 'high' }
        expect(assigns(:notifications)).to include(high_priority)
        expect(assigns(:notifications)).not_to include(normal_priority)
      end

      it 'filters by status' do
        unread = create(:admin_notification, :unread)
        read = create(:admin_notification, :read)
        
        get :index, params: { status: 'unread' }
        expect(assigns(:notifications)).to include(unread)
        expect(assigns(:notifications)).not_to include(read)
      end

      it 'filters by event type' do
        user_reg = create(:admin_notification, event_type: 'user_registered')
        trial_exp = create(:admin_notification, event_type: 'trial_expired')
        
        get :index, params: { event_type: 'user_registered' }
        expect(assigns(:notifications)).to include(user_reg)
        expect(assigns(:notifications)).not_to include(trial_exp)
      end
    end
  end

  describe 'GET #show' do
    let(:notification) { create(:admin_notification, :unread) }

    it 'returns successful response' do
      get :show, params: { id: notification.id }
      expect(response).to be_successful
    end

    it 'marks notification as read' do
      expect {
        get :show, params: { id: notification.id }
      }.to change { notification.reload.read? }.from(false).to(true)
    end
  end

  describe 'PATCH #mark_as_read' do
    let(:notification) { create(:admin_notification, :unread) }

    it 'marks notification as read' do
      expect {
        patch :mark_as_read, params: { id: notification.id }
      }.to change { notification.reload.read? }.from(false).to(true)
    end

    it 'responds with turbo stream' do
      patch :mark_as_read, params: { id: notification.id }
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end
  end

  describe 'PATCH #mark_all_as_read' do
    let!(:unread_notifications) { create_list(:admin_notification, 3, :unread) }

    it 'marks all notifications as read' do
      expect {
        patch :mark_all_as_read
      }.to change { AdminNotification.unread.count }.from(3).to(0)
    end

    it 'responds with turbo stream' do
      patch :mark_all_as_read
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end
  end

  describe 'DELETE #destroy' do
    let!(:notification) { create(:admin_notification) }

    it 'destroys the notification' do
      expect {
        delete :destroy, params: { id: notification.id }
      }.to change(AdminNotification, :count).by(-1)
    end

    it 'responds with turbo stream' do
      delete :destroy, params: { id: notification.id }
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end
  end

  describe 'GET #stats' do
    before do
      create_list(:admin_notification, 2, created_at: 1.day.ago)
      create_list(:admin_notification, 3, created_at: 2.days.ago, priority: 'high')
    end

    it 'returns stats as JSON' do
      get :stats, format: :json
      expect(response).to be_successful
      expect(response.media_type).to eq('application/json')
    end

    it 'includes daily stats' do
      get :stats, format: :json
      data = JSON.parse(response.body)
      expect(data).to have_key('daily_stats')
      expect(data).to have_key('priority_distribution')
      expect(data).to have_key('user_activity')
    end
  end

  describe 'authorization' do
    context 'when user is not superadmin' do
      before do
        sign_out superadmin
        sign_in regular_user
      end

      it 'denies access to index' do
        get :index
        expect(response).to have_http_status(:not_found)
      end

      it 'denies access to show' do
        notification = create(:admin_notification)
        get :show, params: { id: notification.id }
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when user is not signed in' do
      before { sign_out superadmin }

      it 'redirects to sign in' do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end