require 'rails_helper'

RSpec.describe Admin::DashboardController, type: :controller do
  let(:superadmin) { create(:user, role: 'superadmin') }
  let(:regular_user) { create(:user, role: 'user') }

  describe 'GET #index' do
    context 'when user is a superadmin' do
      before do
        sign_in superadmin
      end

      it 'returns http success' do
        get :index
        expect(response).to have_http_status(:success)
      end

      it 'assigns dashboard stats' do
        get :index
        expect(assigns(:dashboard_stats)).to be_present
        expect(assigns(:dashboard_stats)).to have_key(:user_stats)
        expect(assigns(:dashboard_stats)).to have_key(:subscription_stats)
        expect(assigns(:dashboard_stats)).to have_key(:discount_code_stats)
        expect(assigns(:dashboard_stats)).to have_key(:recent_activity)
        expect(assigns(:dashboard_stats)).to have_key(:quick_actions)
      end

      it 'calls the dashboard agent' do
        agent_double = instance_double(Admin::DashboardAgent)
        expect(Admin::DashboardAgent).to receive(:new).and_return(agent_double)
        expect(agent_double).to receive(:get_dashboard_stats).and_return({
          user_stats: {},
          subscription_stats: {},
          discount_code_stats: {},
          recent_activity: [],
          quick_actions: []
        })

        get :index
      end
    end

    context 'when user is not a superadmin' do
      before do
        sign_in regular_user
      end

      it 'redirects to unauthorized' do
        get :index
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Access denied. Superadmin privileges required.')
      end
    end

    context 'when user is not signed in' do
      it 'redirects to sign in' do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end