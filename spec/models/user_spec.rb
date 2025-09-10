# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  # Include shared examples to test common model behaviors
  it_behaves_like "a timestamped model"
  it_behaves_like "a uuid model"
  it_behaves_like "an encryptable model", []

  describe "factory" do
    it "creates a valid user" do
      user = build(:user)
      expect(user).to be_valid
    end
    
    it "creates a user with admin trait" do
      admin = build(:user, :admin)
      expect(admin.role).to eq('admin')
    end
    
    it "creates a user with premium trait" do
      premium = build(:user, :premium)
      expect(premium.subscription_tier).to eq('premium')
      expect(premium.monthly_ai_limit).to eq(100.0)
    end
  end

  describe "validations" do
    subject { build(:user) }
    
    describe "email validation" do
      it { should validate_presence_of(:email) }
      it { should validate_uniqueness_of(:email).case_insensitive }
      
      it "validates email format" do
        valid_emails = [
          'user@example.com',
          'test.email+tag@domain.co.uk',
          'user123@test-domain.org'
        ]
        
        invalid_emails = [
          'invalid-email',
          '@domain.com',
          'user@',
          'user@.com',
          ''
        ]
        
        valid_emails.each do |email|
          user = build(:user, email: email)
          expect(user).to be_valid, "Expected #{email} to be valid"
        end
        
        invalid_emails.each do |email|
          user = build(:user, email: email)
          expect(user).not_to be_valid, "Expected #{email} to be invalid"
          expect(user.errors[:email]).to be_present
        end
      end
    end
    
    describe "password validation" do
      it "validates password strength through Devise" do
        # Devise default validation requires minimum 6 characters
        weak_passwords = ['123', 'abc12']
        
        weak_passwords.each do |password|
          user = build(:user, password: password, password_confirmation: password)
          expect(user).not_to be_valid, "Expected '#{password}' to be invalid"
          expect(user.errors[:password]).to be_present
        end
      end
      
      it "accepts strong passwords" do
        strong_passwords = [
          'SecurePassword123!',
          'MyStr0ngP@ssw0rd',
          'C0mpl3x!P@ssw0rd'
        ]
        
        strong_passwords.each do |password|
          user = build(:user, password: password, password_confirmation: password)
          expect(user).to be_valid, "Expected '#{password}' to be valid"
        end
      end
    end
    
    describe "name validation" do
      it { should validate_presence_of(:first_name) }
      it { should validate_presence_of(:last_name) }
      
      it "rejects blank names" do
        user = build(:user, first_name: '', last_name: '')
        expect(user).not_to be_valid
        expect(user.errors[:first_name]).to include("can't be blank")
        expect(user.errors[:last_name]).to include("can't be blank")
      end
      
      it "accepts names with spaces and special characters" do
        user = build(:user, first_name: "Mary Jane", last_name: "O'Connor-Smith")
        expect(user).to be_valid
      end
    end
  end
  
  describe "associations" do
    it { should have_many(:forms).dependent(:destroy) }
    it { should have_many(:api_tokens).dependent(:destroy) }
    it { should have_many(:form_responses).through(:forms) }
    
    describe "dependent destroy behavior" do
      it "destroys associated forms when user is destroyed" do
        user = create(:user)
        create(:form, user: user)
        
        expect { user.destroy }.to change { Form.count }.by(-1)
      end
      
      it "destroys associated api_tokens when user is destroyed" do
        user = create(:user)
        create(:api_token, user: user)
        
        expect { user.destroy }.to change { ApiToken.count }.by(-1)
      end
    end
  end
  
  describe "enums" do
    it "defines role enum with correct values" do
      expect(User.roles.keys).to contain_exactly('user', 'premium', 'admin')
    end
    
    describe "role transitions" do
      let(:user) { create(:user) }
      
      it "allows valid role transitions" do
        expect(user.user?).to be true
        
        user.role = 'premium'
        expect(user.premium?).to be true
        expect(user.user?).to be false
        
        user.role = 'admin'
        expect(user.admin?).to be true
        expect(user.premium?).to be false
      end
      
      it "provides predicate methods for each role" do
        user = build(:user, role: 'user')
        expect(user.user?).to be true
        expect(user.premium?).to be false
        expect(user.admin?).to be false
        
        user.role = 'premium'
        expect(user.user?).to be false
        expect(user.premium?).to be true
        expect(user.admin?).to be false
        
        user.role = 'admin'
        expect(user.user?).to be false
        expect(user.premium?).to be false
        expect(user.admin?).to be true
      end
      
      it "validates role values" do
        user = build(:user)
        expect { user.role = 'invalid_role' }.to raise_error(ArgumentError)
      end
    end
  end
  
  describe "callbacks" do
    describe "before_create :set_default_preferences" do
      it "sets default preferences on creation" do
        user = build(:user, preferences: nil, ai_settings: nil, ai_credits_limit: nil)
        user.save!
        
        expect(user.preferences).to be_present
        expect(user.preferences['theme']).to eq('light')
        expect(user.preferences['notifications']).to be_a(Hash)
        expect(user.preferences['dashboard']).to be_a(Hash)
      end
      
      it "sets default AI settings on creation" do
        user = build(:user, ai_settings: nil)
        user.save!
        
        expect(user.ai_settings).to be_present
        expect(user.ai_settings['auto_analysis']).to be true
        expect(user.ai_settings['confidence_threshold']).to eq(0.7)
        expect(user.ai_settings['preferred_model']).to eq('gpt-3.5-turbo')
        expect(user.ai_settings['max_tokens']).to eq(1000)
      end
      
      it "sets role-based AI credits limit on creation" do
        user_regular = build(:user, role: 'user', ai_credits_limit: nil)
        user_regular.save!
        expect(user_regular.ai_credits_limit).to eq(1000)
        
        user_premium = build(:user, role: 'premium', ai_credits_limit: nil)
        user_premium.save!
        expect(user_premium.ai_credits_limit).to eq(10000)
        
        user_admin = build(:user, role: 'admin', ai_credits_limit: nil)
        user_admin.save!
        expect(user_admin.ai_credits_limit).to eq(50000)
      end
      
      it "does not override existing preferences" do
        custom_preferences = { 'theme' => 'dark', 'custom_setting' => 'value' }
        user = build(:user, preferences: custom_preferences)
        user.save!
        
        expect(user.preferences['theme']).to eq('dark')
        expect(user.preferences['custom_setting']).to eq('value')
      end
    end
    
    describe "before_save :update_last_activity" do
      it "updates last_activity_at when user is modified" do
        user = create(:user)
        original_activity = user.last_activity_at
        
        travel 1.hour do
          user.update!(first_name: 'Updated')
          expect(user.last_activity_at).to be > original_activity
        end
      end
      
      it "does not update last_activity_at if no changes" do
        user = create(:user)
        original_activity = user.last_activity_at
        
        travel 1.hour do
          user.save!
          expect(user.last_activity_at).to eq(original_activity)
        end
      end
    end
  end
  
  describe "custom methods" do
    describe "#full_name" do
      it "returns the concatenated first and last name" do
        user = build(:user, first_name: "John", last_name: "Doe")
        expect(user.full_name).to eq("John Doe")
      end
      
      it "handles names with extra spaces" do
        user = build(:user, first_name: "  John  ", last_name: "  Doe  ")
        expect(user.full_name).to eq("John     Doe")
      end
      
      it "handles empty names gracefully" do
        user = build(:user, first_name: "", last_name: "Doe")
        expect(user.full_name).to eq("Doe")
        
        user = build(:user, first_name: "John", last_name: "")
        expect(user.full_name).to eq("John")
      end
    end
    
    describe "#ai_credits_remaining" do
      it "calculates remaining credits correctly" do
        user = create(:user, ai_credits_limit: 1000, ai_credits_used: 300)
        expect(user.ai_credits_remaining).to eq(700)
      end
      
      it "returns zero when credits are exhausted" do
        user = create(:user, ai_credits_limit: 1000, ai_credits_used: 1000)
        expect(user.ai_credits_remaining).to eq(0)
      end
      
      it "returns negative when over limit" do
        user = create(:user, ai_credits_limit: 1000, ai_credits_used: 1200)
        expect(user.ai_credits_remaining).to eq(-200)
      end
    end
    
    describe "#can_use_ai_features?" do
      it "returns true when user has credits and is active" do
        user = create(:user, ai_credits_limit: 1000, ai_credits_used: 500, active: true)
        expect(user.can_use_ai_features?).to be true
      end
      
      it "returns false when user has no credits remaining" do
        user = create(:user, ai_credits_limit: 1000, ai_credits_used: 1000, active: true)
        expect(user.can_use_ai_features?).to be false
      end
      
      it "returns false when user is inactive" do
        user = create(:user, ai_credits_limit: 1000, ai_credits_used: 500, active: false)
        expect(user.can_use_ai_features?).to be false
      end
    end
    
    describe "#consume_ai_credit" do
      let(:user) { create(:user, ai_credits_limit: 1000, ai_credits_used: 500) }
      
      it "consumes credits and returns true when successful" do
        expect(user.consume_ai_credit(100)).to be true
        expect(user.reload.ai_credits_used).to eq(600)
        expect(user.ai_credits_remaining).to eq(400)
      end
      
      it "uses default cost of 1 when no cost specified" do
        expect(user.consume_ai_credit).to be true
        expect(user.reload.ai_credits_used).to eq(501)
      end
      
      it "returns false when user cannot use AI features" do
        user.update!(ai_credits_used: 1000) # Exhaust credits
        expect(user.consume_ai_credit(1)).to be false
        expect(user.reload.ai_credits_used).to eq(1000) # No change
      end
      
      it "allows consuming credits up to the limit" do
        user.update!(ai_credits_used: 999)
        expect(user.consume_ai_credit(1)).to be true
        expect(user.reload.ai_credits_used).to eq(1000)
        expect(user.ai_credits_remaining).to eq(0)
      end
    end
    
    describe "#form_usage_stats" do
      let(:user) { create(:user) }
      
      it "returns correct stats when user has no forms" do
        stats = user.form_usage_stats
        
        expect(stats[:total_forms]).to eq(0)
        expect(stats[:published_forms]).to eq(0)
        expect(stats[:total_responses]).to eq(0)
        expect(stats[:avg_completion_rate]).to eq(0.0)
      end
      
      it "calculates stats correctly with forms and responses" do
        form1 = create(:form, user: user, status: 'published')
        create(:form, user: user, status: 'draft')
        form3 = create(:form, user: user, status: 'published')
        
        # Create some form responses
        create_list(:form_response, 3, form: form1)
        create_list(:form_response, 2, form: form3)
        
        stats = user.form_usage_stats
        
        expect(stats[:total_forms]).to eq(3)
        expect(stats[:published_forms]).to eq(2)
        expect(stats[:total_responses]).to eq(5)
      end
    end
    
    describe "#active?" do
      it "returns true for active users" do
        user = create(:user, active: true)
        expect(user.active?).to be true
      end
      
      it "returns false for inactive users" do
        user = create(:user, active: false)
        expect(user.active?).to be false
      end
    end
  end
  
  describe "encryption behavior" do
    it "includes Encryptable concern" do
      expect(User.ancestors).to include(Encryptable)
    end
    
    # Note: The User model doesn't have encrypted fields based on the Encryptable concern
    # The concern only encrypts api_keys, webhook_secrets, and integration_credentials
    # which are not present in the User model schema
    it "does not have encrypted fields in User model" do
      user = create(:user)
      
      # Verify that User model doesn't have the fields that would be encrypted
      expect(user).not_to respond_to(:api_keys)
      expect(user).not_to respond_to(:webhook_secrets)
      expect(user).not_to respond_to(:integration_credentials)
    end
  end
  
  describe "devise integration" do
    it "includes required Devise modules" do
      expect(User.devise_modules).to include(
        :database_authenticatable,
        :registerable,
        :recoverable,
        :rememberable,
        :validatable,
        :confirmable,
        :trackable
      )
    end
    
    it "tracks sign in information" do
      user = create(:user)
      
      expect(user).to respond_to(:sign_in_count)
      expect(user).to respond_to(:current_sign_in_at)
      expect(user).to respond_to(:last_sign_in_at)
      expect(user).to respond_to(:current_sign_in_ip)
      expect(user).to respond_to(:last_sign_in_ip)
    end
    
    it "handles email confirmation" do
      user = create(:user, :unconfirmed)
      
      expect(user.confirmed?).to be false
      expect(user.confirmation_token).to be_present
      
      user.confirm
      expect(user.confirmed?).to be true
    end
  end
  
  describe "scopes and class methods" do
    describe "role-based scopes" do
      before do
        create(:user, role: 'user')
        create(:user, role: 'premium')
        create(:user, role: 'admin')
      end
      
      it "filters users by role" do
        expect(User.where(role: 'admin').count).to eq(1)
        expect(User.where(role: 'premium').count).to eq(1)
        expect(User.where(role: 'user').count).to eq(1)
      end
    end
    
    describe "activity-based filtering" do
      it "filters active users" do
        active_user = create(:user, active: true)
        inactive_user = create(:user, active: false)
        
        active_users = User.where(active: true)
        expect(active_users).to include(active_user)
        expect(active_users).not_to include(inactive_user)
      end
    end
  end
  
  describe "data integrity" do
    it "maintains referential integrity with forms" do
      user = create(:user)
      form = create(:form, user: user)
      
      expect(form.user).to eq(user)
      expect(user.forms).to include(form)
    end
    
    it "maintains referential integrity with api_tokens" do
      user = create(:user)
      api_token = create(:api_token, user: user)
      
      expect(api_token.user).to eq(user)
      expect(user.api_tokens).to include(api_token)
    end
  end

  # Payment setup status methods
  describe "payment setup status methods" do
    let(:basic_user) { create(:user) }
    let(:premium_user) { create(:user, :premium) }
    let(:stripe_user) { create(:user, :stripe_configured) }
    let(:fully_configured_user) { create(:user, :premium, :stripe_configured) }

    describe "#payment_setup_status" do
      it "returns complete status hash for fully configured user" do
        status = fully_configured_user.payment_setup_status

        expect(status[:stripe_configured]).to be true
        expect(status[:premium_subscription]).to be true
        expect(status[:can_accept_payments]).to be true
        expect(status[:setup_completion_percentage]).to eq(100)
      end

      it "returns partial status for user with only Stripe configured" do
        status = stripe_user.payment_setup_status

        expect(status[:stripe_configured]).to be true
        expect(status[:premium_subscription]).to be false
        expect(status[:can_accept_payments]).to be false
        expect(status[:setup_completion_percentage]).to eq(50)
      end

      it "returns partial status for user with only Premium subscription" do
        status = premium_user.payment_setup_status

        expect(status[:stripe_configured]).to be false
        expect(status[:premium_subscription]).to be true
        expect(status[:can_accept_payments]).to be false
        expect(status[:setup_completion_percentage]).to eq(50)
      end

      it "returns incomplete status for basic user" do
        status = basic_user.payment_setup_status

        expect(status[:stripe_configured]).to be false
        expect(status[:premium_subscription]).to be false
        expect(status[:can_accept_payments]).to be false
        expect(status[:setup_completion_percentage]).to eq(0)
      end
    end

    describe "#calculate_setup_completion" do
      it "returns 100 when both Stripe and Premium are configured" do
        expect(fully_configured_user.calculate_setup_completion).to eq(100)
      end

      it "returns 50 when only Stripe is configured" do
        expect(stripe_user.calculate_setup_completion).to eq(50)
      end

      it "returns 50 when only Premium is configured" do
        expect(premium_user.calculate_setup_completion).to eq(50)
      end

      it "returns 0 when neither is configured" do
        expect(basic_user.calculate_setup_completion).to eq(0)
      end

      it "rounds to nearest integer" do
        # Test with a user that has partial setup (this is theoretical since we only have 2 steps)
        user = basic_user
        allow(user).to receive(:stripe_configured?).and_return(true)
        allow(user).to receive(:premium?).and_return(false)
        
        expect(user.calculate_setup_completion).to eq(50)
      end
    end
  end
end