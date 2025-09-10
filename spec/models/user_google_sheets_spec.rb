require 'rails_helper'

RSpec.describe User, type: :model do
  describe '#can_use_google_sheets?' do
    context 'when user is premium' do
      let(:user) { create(:user, subscription_tier: 'premium') }
      
      it 'returns true' do
        expect(user.can_use_google_sheets?).to be true
      end
    end
    
    context 'when user is admin' do
      let(:user) { create(:user, role: 'admin', subscription_tier: 'basic') }
      
      it 'returns true' do
        expect(user.can_use_google_sheets?).to be true
      end
    end
    
    context 'when user is superadmin' do
      let(:user) { create(:user, role: 'superadmin', subscription_tier: 'basic') }
      
      it 'returns true' do
        expect(user.can_use_google_sheets?).to be true
      end
    end
    
    context 'when user is basic' do
      let(:user) { create(:user, subscription_tier: 'basic', role: 'user') }
      
      it 'returns false' do
        expect(user.can_use_google_sheets?).to be false
      end
    end
    
    context 'when user has invalid subscription tier' do
      let(:user) { create(:user, subscription_tier: 'basic', role: 'user') }
      
      it 'returns false for basic users' do
        expect(user.can_use_google_sheets?).to be false
      end
    end
  end
end