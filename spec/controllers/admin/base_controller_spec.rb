require 'rails_helper'

RSpec.describe Admin::BaseController, type: :controller do
  controller(Admin::BaseController) do
    def index
      render plain: 'Admin access granted'
    end
  end

  before do
    routes.draw { get 'index' => 'admin/base#index' }
  end

  describe 'authentication and authorization' do
    context 'when user is not logged in' do
      it 'redirects to login page' do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when user is logged in but not superadmin' do
      let(:user) { create(:user, role: 'user') }

      before { sign_in user }

      it 'redirects to root path with access denied message' do
        get :index
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Access denied. Superadmin privileges required.')
      end

      it 'logs the unauthorized access attempt' do
        expect(Rails.logger).to receive(:warn).with("Unauthorized admin access attempt by user #{user.id}")
        get :index
      end
    end

    context 'when user is admin but not superadmin' do
      let(:admin_user) { create(:user, role: 'admin') }

      before { sign_in admin_user }

      it 'redirects to root path with access denied message' do
        get :index
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Access denied. Superadmin privileges required.')
      end
    end

    context 'when user is superadmin' do
      let(:superadmin) { create(:user, role: 'superadmin') }

      before { sign_in superadmin }

      it 'allows access to admin area' do
        get :index
        expect(response).to have_http_status(:success)
        expect(response.body).to eq('Admin access granted')
      end

      it 'uses admin layout' do
        get :index
        expect(response).to render_template(layout: 'admin')
      end

      it 'sets admin session timeout' do
        get :index
        expect(session[:admin_last_activity]).to be_present
        expect(session[:admin_last_activity]).to be_within(5.seconds).of(Time.current.to_i)
      end
    end
  end

  describe 'session timeout handling' do
    let(:superadmin) { create(:user, role: 'superadmin') }

    before { sign_in superadmin }

    context 'when session is within timeout period' do
      it 'allows access and updates last activity' do
        session[:admin_last_activity] = 1.hour.ago.to_i
        
        get :index
        expect(response).to have_http_status(:success)
        expect(session[:admin_last_activity]).to be_within(5.seconds).of(Time.current.to_i)
      end
    end

    context 'when session has expired' do
      it 'resets session and redirects to login' do
        session[:admin_last_activity] = 3.hours.ago.to_i
        
        get :index
        expect(response).to redirect_to(new_user_session_path)
        expect(flash[:alert]).to eq('Admin session expired. Please log in again.')
        expect(session[:admin_last_activity]).to be_nil
      end
    end
  end

  describe 'helper methods' do
    let(:superadmin) { create(:user, role: 'superadmin') }

    before { sign_in superadmin }

    describe '#current_admin' do
      it 'returns current user when superadmin' do
        get :index
        expect(controller.send(:current_admin)).to eq(superadmin)
      end
    end

    describe '#admin_breadcrumbs' do
      it 'initializes with dashboard breadcrumb' do
        get :index
        breadcrumbs = controller.send(:admin_breadcrumbs)
        expect(breadcrumbs).to eq([{ name: 'Dashboard', path: admin_dashboard_path }])
      end
    end

    describe '#add_breadcrumb' do
      it 'adds breadcrumb to the list' do
        get :index
        controller.send(:add_breadcrumb, 'Users', '/admin/users')
        breadcrumbs = controller.send(:admin_breadcrumbs)
        expect(breadcrumbs.last).to eq({ name: 'Users', path: '/admin/users' })
      end
    end
  end
end