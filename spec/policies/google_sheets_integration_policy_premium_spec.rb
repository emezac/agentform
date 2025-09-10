require 'rails_helper'

RSpec.describe GoogleSheetsIntegrationPolicy, type: :policy do
  subject { described_class }

  let(:form) { create(:form, user: user) }
  let(:integration) { create(:google_sheets_integration, form: form) }

  context 'with premium user' do
    let(:user) { create(:user, subscription_tier: 'premium') }

    permissions :show?, :create?, :update?, :destroy?, :export?, :toggle_auto_sync?, :test_connection? do
      it 'grants access' do
        expect(subject).to permit(user, integration)
        expect(subject).to permit(user, form) # for create action
      end
    end
  end

  context 'with admin user' do
    let(:user) { create(:user, role: 'admin', subscription_tier: 'basic') }

    permissions :show?, :create?, :update?, :destroy?, :export?, :toggle_auto_sync?, :test_connection? do
      it 'grants access' do
        expect(subject).to permit(user, integration)
        expect(subject).to permit(user, form) # for create action
      end
    end
  end

  context 'with basic user' do
    let(:user) { create(:user, subscription_tier: 'basic', role: 'user') }

    permissions :show?, :create?, :update?, :destroy?, :export?, :toggle_auto_sync?, :test_connection? do
      it 'denies access' do
        expect(subject).not_to permit(user, integration)
        expect(subject).not_to permit(user, form) # for create action
      end
    end
  end

  context 'with another basic user' do
    let(:user) { create(:user, subscription_tier: 'basic', role: 'user') }

    permissions :show?, :create?, :update?, :destroy?, :export?, :toggle_auto_sync?, :test_connection? do
      it 'denies access' do
        expect(subject).not_to permit(user, integration)
        expect(subject).not_to permit(user, form) # for create action
      end
    end
  end

  context 'with different user (not owner)' do
    let(:user) { create(:user, subscription_tier: 'premium') }
    let(:other_user) { create(:user, subscription_tier: 'premium') }
    let(:other_form) { create(:form, user: other_user) }
    let(:other_integration) { create(:google_sheets_integration, form: other_form) }

    permissions :show?, :create?, :update?, :destroy?, :export?, :toggle_auto_sync?, :test_connection? do
      it 'denies access even with premium' do
        expect(subject).not_to permit(user, other_integration)
        expect(subject).not_to permit(user, other_form)
      end
    end
  end
end