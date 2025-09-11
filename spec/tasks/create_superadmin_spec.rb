require 'rails_helper'
require 'rake'

RSpec.describe 'users:create_superadmin', type: :task do
  before(:all) do
    Rails.application.load_tasks
  end

  let(:task) { Rake::Task['users:create_superadmin'] }
  let(:email) { 'test-superadmin@example.com' }
  let(:password) { 'TestPassword123!' }

  before do
    task.reenable
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
    
    # Clean up any existing user with this email
    User.where(email: email).destroy_all
  end

  around do |example|
    original_email = ENV['EMAIL']
    original_password = ENV['PASSWORD']
    
    ENV['EMAIL'] = email
    ENV['PASSWORD'] = password
    
    example.run
    
    ENV['EMAIL'] = original_email
    ENV['PASSWORD'] = original_password
  end

  describe 'successful superadmin creation' do
    it 'creates a superadmin user with correct attributes' do
      expect { 
        expect { task.invoke }.to exit_with_code(0)
      }.to output(/✓ Superadmin user created successfully!/).to_stdout
      
      user = User.find_by(email: email)
      expect(user).to be_present
      expect(user.role).to eq('superadmin')
      expect(user.subscription_tier).to eq('premium')
      expect(user.first_name).to eq('Super')
      expect(user.last_name).to eq('Admin')
      expect(user.active).to be true
    end

    it 'logs successful creation' do
      expect { task.invoke }.to exit_with_code(0)
      
      expect(Rails.logger).to have_received(:info).with("Starting superadmin creation process for email: #{email}")
      expect(Rails.logger).to have_received(:info).with(/Superadmin user created successfully - ID: .+, Email: #{Regexp.escape(email)}/)
    end

    it 'finds existing user instead of creating duplicate' do
      existing_user = create(:user, email: email, role: 'user')
      
      expect { 
        expect { task.invoke }.to exit_with_code(0)
      }.to output(/✓ Superadmin user created successfully!/).to_stdout
      
      existing_user.reload
      expect(existing_user.role).to eq('superadmin')
      expect(existing_user.subscription_tier).to eq('premium')
      expect(User.where(email: email).count).to eq(1)
    end
  end

  describe 'Redis connectivity handling' do
    context 'when Redis error occurs during user creation' do
      before do
        # Mock a Redis error during user save
        allow_any_instance_of(User).to receive(:save).and_raise(Redis::CannotConnectError.new('Connection refused'))
      end

      it 'handles Redis error gracefully and reports success' do
        expect { 
          expect { task.invoke }.to exit_with_code(0)
        }.to output(/⚠ Warning: Redis connectivity issue detected/).to_stdout
        
        expect(Rails.logger).to have_received(:warn).with(/Redis connectivity issue during superadmin creation/)
      end
    end
  end

  describe 'error handling' do
    context 'when user validation fails' do
      before do
        allow_any_instance_of(User).to receive(:save).and_return(false)
        allow_any_instance_of(User).to receive(:errors).and_return(
          double(full_messages: ['Email has already been taken'])
        )
      end

      it 'reports validation errors and exits with error code' do
        expect { task.invoke }.to exit_with_code(1)
        
        expect(Rails.logger).to have_received(:error).with('Superadmin creation failed: Email has already been taken')
      end
    end

    context 'when unexpected error occurs' do
      let(:unexpected_error) { StandardError.new('Unexpected database error') }

      before do
        allow_any_instance_of(User).to receive(:save).and_raise(unexpected_error)
      end

      it 'logs error details and sends to Sentry if available' do
        # Mock Sentry
        stub_const('Sentry', double)
        allow(Sentry).to receive(:capture_exception)

        expect { task.invoke }.to exit_with_code(1)

        expect(Rails.logger).to have_received(:error).with('Unexpected error during superadmin creation: Unexpected database error')
        expect(Rails.logger).to have_received(:error).with("Email: #{email}")
        expect(Sentry).to have_received(:capture_exception).with(
          unexpected_error,
          extra: {
            context: 'superadmin_creation_task',
            email: email,
            user_id: nil
          }
        )
      end

      it 'handles error gracefully when Sentry is not available' do
        expect { task.invoke }.to exit_with_code(1)

        expect(Rails.logger).to have_received(:error).with('Unexpected error during superadmin creation: Unexpected database error')
      end
    end
  end


end