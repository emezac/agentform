require 'rails_helper'

RSpec.describe 'Admin routes', type: :routing do
  include Rails.application.routes.url_helpers
  describe 'admin namespace constraints' do
    let(:user) { create(:user, role: 'user') }
    let(:admin) { create(:user, role: 'admin') }
    let(:superadmin) { create(:user, role: 'superadmin') }

    context 'with superadmin user' do
      before do
        allow_any_instance_of(ActionDispatch::Request).to receive(:env).and_return({
          'warden' => double(user: superadmin)
        })
      end

      it 'routes to admin dashboard' do
        expect(get: '/admin').to route_to(controller: 'admin/dashboard', action: 'index')
      end

      it 'routes to admin users' do
        expect(get: '/admin/users').to route_to(controller: 'admin/users', action: 'index')
      end

      it 'routes to admin discount codes' do
        expect(get: '/admin/discount_codes').to route_to(controller: 'admin/discount_codes', action: 'index')
      end
    end

    it 'generates correct admin paths' do
      expect(admin_root_path).to eq('/admin')
      expect(admin_dashboard_path).to eq('/admin/dashboard')
      expect(admin_users_path).to eq('/admin/users')
      expect(admin_discount_codes_path).to eq('/admin/discount_codes')
    end
  end
end