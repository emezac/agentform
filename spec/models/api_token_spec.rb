# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApiToken, type: :model do
  # Shared examples
  it_behaves_like "a timestamped model"
  it_behaves_like "a uuid model"

  # Associations
  describe "associations" do
    it { should belong_to(:user) }
  end

  # Validations
  describe "validations" do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:token) }
    it { should validate_uniqueness_of(:token) }
  end

  # Callbacks
  describe "callbacks" do
    describe "before_create" do
      it "generates token automatically" do
        token = build(:api_token, token: nil)
        token.save!
        
        expect(token.token).to be_present
        expect(token.token.length).to be > 20
      end

      it "does not override existing token" do
        existing_token = "existing_token_123"
        token = build(:api_token, token: existing_token)
        token.save!
        
        expect(token.token).to eq(existing_token)
      end

      it "ensures token uniqueness" do
        # Mock SecureRandom to return duplicate first, then unique
        allow(SecureRandom).to receive(:urlsafe_base64).and_return('duplicate_token', 'unique_token')
        
        # Create first token with the duplicate
        create(:api_token, token: 'duplicate_token')
        
        # Second token should get the unique one
        token = build(:api_token, token: nil)
        token.save!
        
        expect(token.token).to eq('unique_token')
      end
    end
  end

  # Scopes
  describe "scopes" do
    let!(:active_token) { create(:api_token, active: true) }
    let!(:inactive_token) { create(:api_token, active: false) }
    let!(:expired_token) { create(:api_token, :expired) }
    let!(:valid_token) { create(:api_token, active: true, expires_at: 1.day.from_now) }
    let!(:recent_token) { create(:api_token, created_at: 1.hour.ago) }
    let!(:old_token) { create(:api_token, created_at: 1.week.ago) }

    describe ".active" do
      it "returns only active tokens" do
        expect(ApiToken.active).to include(active_token, valid_token)
        expect(ApiToken.active).not_to include(inactive_token)
      end
    end

    describe ".expired" do
      it "returns only expired tokens" do
        expect(ApiToken.expired).to include(expired_token)
        expect(ApiToken.expired).not_to include(active_token, valid_token)
      end
    end

    describe ".valid" do
      it "returns active and non-expired tokens" do
        expect(ApiToken.valid).to include(active_token, valid_token)
        expect(ApiToken.valid).not_to include(inactive_token, expired_token)
      end
    end

    describe ".recent" do
      it "orders by created_at descending" do
        results = ApiToken.recent
        expect(results.first.created_at).to be >= results.last.created_at
      end
    end
  end

  # Instance Methods
  describe "#active?" do
    it "returns true for active non-expired token" do
      token = create(:api_token, active: true, expires_at: 1.day.from_now)
      expect(token.active?).to be true
    end

    it "returns false for inactive token" do
      token = create(:api_token, active: false)
      expect(token.active?).to be false
    end

    it "returns false for expired token" do
      token = create(:api_token, :expired)
      expect(token.active?).to be false
    end
  end

  describe "#expired?" do
    it "returns true when expires_at is in the past" do
      token = create(:api_token, :expired)
      expect(token.expired?).to be true
    end

    it "returns false when expires_at is in the future" do
      token = create(:api_token, expires_at: 1.day.from_now)
      expect(token.expired?).to be false
    end

    it "returns false when expires_at is nil" do
      token = create(:api_token, expires_at: nil)
      expect(token.expired?).to be false
    end
  end

  describe "#can_access?" do
    context "with no permissions (full access)" do
      let(:token) { create(:api_token, permissions: {}) }

      it "allows access to any resource and action" do
        expect(token.can_access?('forms', 'create')).to be true
        expect(token.can_access?('users', 'destroy')).to be true
      end
    end

    context "with array permissions" do
      let(:token) { create(:api_token, permissions: { 'forms' => ['index', 'show'] }) }

      it "allows access to permitted actions" do
        expect(token.can_access?('forms', 'index')).to be true
        expect(token.can_access?('forms', 'show')).to be true
      end

      it "denies access to non-permitted actions" do
        expect(token.can_access?('forms', 'create')).to be false
        expect(token.can_access?('forms', 'destroy')).to be false
      end

      it "denies access to non-permitted resources" do
        expect(token.can_access?('users', 'index')).to be false
      end
    end

    context "with hash permissions" do
      let(:token) { create(:api_token, permissions: { 'forms' => { 'index' => true, 'create' => false } }) }

      it "allows access when permission is true" do
        expect(token.can_access?('forms', 'index')).to be true
      end

      it "denies access when permission is false" do
        expect(token.can_access?('forms', 'create')).to be false
      end
    end

    context "with boolean permissions" do
      let(:token) { create(:api_token, permissions: { 'forms' => true, 'users' => false }) }

      it "allows full access when permission is true" do
        expect(token.can_access?('forms', 'any_action')).to be true
      end

      it "denies access when permission is false" do
        expect(token.can_access?('users', 'any_action')).to be false
      end
    end

    it "denies access for inactive tokens" do
      token = create(:api_token, active: false, permissions: {})
      expect(token.can_access?('forms', 'index')).to be false
    end
  end

  describe "#record_usage!" do
    it "increments usage count and updates last_used_at" do
      token = create(:api_token, usage_count: 5, last_used_at: nil)
      
      expect {
        token.record_usage!
      }.to change { token.reload.usage_count }.from(5).to(6)
        .and change { token.reload.last_used_at }.from(nil)
      
      expect(token.last_used_at).to be_within(1.second).of(Time.current)
    end
  end

  describe "#revoke!" do
    it "sets token as inactive" do
      token = create(:api_token, active: true)
      
      token.revoke!
      
      expect(token.reload.active).to be false
    end
  end

  describe "#extend_expiration" do
    it "extends expiration by specified duration" do
      original_expiration = 1.day.from_now
      token = create(:api_token, expires_at: original_expiration)
      
      token.extend_expiration(1.week)
      
      expect(token.reload.expires_at).to be_within(1.second).of(original_expiration + 1.week)
    end

    it "sets expiration when token has no expiration" do
      token = create(:api_token, expires_at: nil)
      
      token.extend_expiration(1.week)
      
      expect(token.reload.expires_at).to be_within(1.second).of(Time.current + 1.week)
    end
  end

  describe "#usage_summary" do
    it "returns comprehensive usage information" do
      token = create(:api_token, :recently_used, name: 'Test Token')
      summary = token.usage_summary
      
      expect(summary).to include(:name, :token_preview, :created_at, :last_used_at, :usage_count, :expires_at, :active, :permissions)
      expect(summary[:name]).to eq('Test Token')
      expect(summary[:token_preview]).to match(/\A.{8}\.\.\.\z/)
      expect(summary[:active]).to be true
    end
  end

  describe "#permissions_summary" do
    it "returns 'Full access' for empty permissions" do
      token = create(:api_token, permissions: {})
      expect(token.permissions_summary).to eq('Full access')
    end

    it "summarizes array permissions" do
      token = create(:api_token, permissions: { 'forms' => ['index', 'show'] })
      expect(token.permissions_summary).to eq('forms: index, show')
    end

    it "summarizes boolean permissions" do
      token = create(:api_token, permissions: { 'forms' => true, 'users' => false })
      summary = token.permissions_summary
      expect(summary).to include('forms: full access')
      expect(summary).not_to include('users')
    end

    it "summarizes hash permissions" do
      token = create(:api_token, permissions: { 'forms' => { 'index' => true, 'create' => true, 'destroy' => false } })
      summary = token.permissions_summary
      expect(summary).to include('forms: index, create')
      expect(summary).not_to include('destroy')
    end
  end

  # Class Methods
  describe ".authenticate" do
    let!(:valid_token) { create(:api_token, token: 'valid_token_123', active: true) }
    let!(:inactive_token) { create(:api_token, token: 'inactive_token_123', active: false) }

    it "returns token for valid token string" do
      result = ApiToken.authenticate('valid_token_123')
      expect(result).to eq(valid_token)
    end

    it "records usage when token is found" do
      expect {
        ApiToken.authenticate('valid_token_123')
      }.to change { valid_token.reload.usage_count }.by(1)
    end

    it "handles Bearer prefix" do
      result = ApiToken.authenticate('Bearer valid_token_123')
      expect(result).to eq(valid_token)
    end

    it "returns nil for inactive token" do
      result = ApiToken.authenticate('inactive_token_123')
      expect(result).to be_nil
    end

    it "returns nil for non-existent token" do
      result = ApiToken.authenticate('non_existent_token')
      expect(result).to be_nil
    end

    it "returns nil for blank token" do
      expect(ApiToken.authenticate('')).to be_nil
      expect(ApiToken.authenticate(nil)).to be_nil
    end
  end

  describe ".create_for_user" do
    let(:user) { create(:user) }

    it "creates token with specified parameters" do
      token = ApiToken.create_for_user(
        user, 
        name: 'Test API Token',
        expires_in: 1.week,
        permissions: { 'forms' => ['index'] }
      )
      
      expect(token.user).to eq(user)
      expect(token.name).to eq('Test API Token')
      expect(token.expires_at).to be_within(1.second).of(Time.current + 1.week)
      expect(token.permissions).to eq({ 'forms' => ['index'] })
    end

    it "creates token without expiration when expires_in is nil" do
      token = ApiToken.create_for_user(user, name: 'Permanent Token')
      expect(token.expires_at).to be_nil
    end
  end

  describe ".cleanup_expired" do
    it "deactivates expired tokens" do
      expired_token = create(:api_token, :expired, active: true)
      valid_token = create(:api_token, active: true, expires_at: 1.day.from_now)
      
      ApiToken.cleanup_expired
      
      expect(expired_token.reload.active).to be false
      expect(valid_token.reload.active).to be true
    end
  end

  # Permission Templates
  describe "permission templates" do
    describe ".readonly_permissions" do
      it "returns read-only permissions structure" do
        permissions = ApiToken.readonly_permissions
        
        expect(permissions['forms']).to eq(['index', 'show'])
        expect(permissions['responses']).to eq(['index', 'show'])
        expect(permissions['analytics']).to eq(['show'])
      end
    end

    describe ".full_permissions" do
      it "returns full access permissions structure" do
        permissions = ApiToken.full_permissions
        
        expect(permissions['forms']).to be true
        expect(permissions['responses']).to be true
        expect(permissions['analytics']).to be true
        expect(permissions['users']).to eq(['show', 'update'])
      end
    end

    describe ".forms_only_permissions" do
      it "returns forms-focused permissions structure" do
        permissions = ApiToken.forms_only_permissions
        
        expect(permissions['forms']).to be true
        expect(permissions['responses']).to eq(['create', 'show'])
        expect(permissions['analytics']).to be_nil
      end
    end
  end

  # Token Generation
  describe "token generation" do
    it "generates unique tokens" do
      token1 = create(:api_token)
      token2 = create(:api_token)
      
      expect(token1.token).not_to eq(token2.token)
    end

    it "generates URL-safe tokens" do
      token = create(:api_token)
      
      # URL-safe base64 should not contain +, /, or =
      expect(token.token).not_to include('+', '/', '=')
    end

    it "generates tokens of appropriate length" do
      token = create(:api_token)
      
      # 32 bytes base64 encoded should be around 43 characters
      expect(token.token.length).to be >= 40
    end
  end
end