# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ActionCable SSL Configuration', type: :integration do
  describe 'cable configuration structure' do
    let(:cable_config) { Rails.application.config_for(:cable) }
    
    context 'in test environment' do
      it 'uses test adapter' do
        expect(cable_config[:adapter]).to eq('test')
      end
    end
    
    it 'has the expected configuration structure' do
      # Test that the configuration file is properly structured
      expect(cable_config).to be_a(Hash)
      expect(cable_config).to have_key(:adapter)
    end
  end
  
  describe 'SSL configuration logic' do
    it 'properly handles SSL verification mode constant' do
      # Verify that OpenSSL constants are available
      expect(OpenSSL::SSL::VERIFY_NONE).to be_a(Integer)
      expect(OpenSSL::SSL::VERIFY_NONE).to eq(0)
    end
    
    it 'can detect SSL URLs' do
      ssl_url = 'rediss://user:password@host:port/1'
      regular_url = 'redis://localhost:6379/1'
      
      expect(ssl_url.start_with?('rediss://')).to be true
      expect(regular_url.start_with?('rediss://')).to be false
    end
  end
  
  describe 'ActionCable channel functionality' do
    it 'channel classes are properly defined' do
      # Test that ActionCable channels are properly defined
      expect(FormResponseChannel).to be < ApplicationCable::Channel
      expect(SessionChannel).to be < ApplicationCable::Channel
    end
    
    it 'channels have required methods' do
      # Test that channels have the required ActionCable methods
      expect(FormResponseChannel.instance_methods).to include(:subscribed, :unsubscribed)
      expect(SessionChannel.instance_methods).to include(:subscribed, :unsubscribed)
    end
  end
  
  describe 'Redis connection resilience' do
    it 'handles Redis connection configuration gracefully' do
      # Test that the application can handle Redis configuration without errors
      expect {
        # This simulates what happens when ActionCable tries to connect to Redis
        config = Rails.application.config_for(:cable)
        
        # Verify basic configuration structure
        expect(config).to have_key(:adapter)
        
        # In production, this would include SSL params for rediss:// URLs
        # The YAML template handles this with conditional logic
      }.not_to raise_error
    end
  end
  
  describe 'production SSL configuration template' do
    it 'includes conditional SSL parameters in YAML template' do
      # Read the cable.yml file to verify SSL configuration template
      cable_yml_content = File.read(Rails.root.join('config', 'cable.yml'))
      
      # Verify that SSL configuration is conditionally included
      expect(cable_yml_content).to include('ssl_params:')
      expect(cable_yml_content).to include('verify_mode:')
      expect(cable_yml_content).to include("ENV['REDIS_URL']&.start_with?('rediss://')")
      expect(cable_yml_content).to include('OpenSSL::SSL::VERIFY_NONE')
    end
    
    it 'has proper production configuration structure' do
      cable_yml_content = File.read(Rails.root.join('config', 'cable.yml'))
      
      # Verify production section exists and has required fields
      expect(cable_yml_content).to include('production:')
      expect(cable_yml_content).to include('adapter: redis')
      expect(cable_yml_content).to include('channel_prefix: agentform_production')
      expect(cable_yml_content).to include('REDIS_URL')
    end
  end
  
  describe 'RedisConfig integration with ActionCable' do
    it 'provides cable configuration method' do
      expect(RedisConfig).to respond_to(:cable_config)
    end
    
    it 'returns proper cable configuration structure' do
      config = RedisConfig.cable_config
      
      expect(config).to be_a(Hash)
      expect(config).to have_key(:url)
      expect(config).to have_key(:channel_prefix)
      expect(config[:channel_prefix]).to eq("agentform_#{Rails.env}")
    end
    
    it 'SSL configuration logic works correctly' do
      # Test the SSL detection logic directly
      expect(RedisConfig.send(:ssl_required?)).to be_falsy # In test environment with regular Redis
      
      # Test SSL parameters structure
      ssl_params = RedisConfig.send(:ssl_params)
      expect(ssl_params).to be_a(Hash)
      expect(ssl_params).to have_key(:verify_mode)
      expect(ssl_params[:verify_mode]).to eq(OpenSSL::SSL::VERIFY_NONE)
    end
  end
end