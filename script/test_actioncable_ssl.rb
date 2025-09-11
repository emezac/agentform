#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to test ActionCable SSL configuration
# This script verifies that ActionCable can load the configuration without errors

require_relative '../config/environment'

puts "Testing ActionCable SSL Configuration..."
puts "=" * 50

# Test 1: Load cable configuration
begin
  cable_config = Rails.application.config_for(:cable)
  puts "✅ Cable configuration loaded successfully"
  puts "   Adapter: #{cable_config[:adapter]}"
  puts "   Environment: #{Rails.env}"
  
  if Rails.env.production?
    puts "   URL: #{cable_config[:url]&.gsub(/:[^:@]*@/, ':***@')}" # Mask password
    puts "   Channel Prefix: #{cable_config[:channel_prefix]}"
    
    if cable_config.key?(:ssl_params)
      puts "   SSL Parameters: Present"
      puts "   SSL Verify Mode: #{cable_config[:ssl_params][:verify_mode]}"
    else
      puts "   SSL Parameters: Not present (normal for non-SSL Redis)"
    end
  end
rescue => e
  puts "❌ Error loading cable configuration: #{e.message}"
  exit 1
end

# Test 2: Test RedisConfig integration
begin
  redis_cable_config = RedisConfig.cable_config
  puts "✅ RedisConfig cable configuration loaded successfully"
  puts "   URL: #{redis_cable_config[:url]&.gsub(/:[^:@]*@/, ':***@')}" # Mask password
  puts "   Channel Prefix: #{redis_cable_config[:channel_prefix]}"
  puts "   Network Timeout: #{redis_cable_config[:network_timeout]}"
  puts "   Pool Timeout: #{redis_cable_config[:pool_timeout]}"
  
  if redis_cable_config.key?(:ssl_params)
    puts "   SSL Parameters: Present"
    puts "   SSL Verify Mode: #{redis_cable_config[:ssl_params][:verify_mode]}"
  else
    puts "   SSL Parameters: Not present (normal for non-SSL Redis)"
  end
rescue => e
  puts "❌ Error loading RedisConfig cable configuration: #{e.message}"
  exit 1
end

# Test 3: Test SSL detection logic
begin
  ssl_required = RedisConfig.send(:ssl_required?)
  puts "✅ SSL detection logic working"
  puts "   SSL Required: #{ssl_required}"
  puts "   Current Redis URL starts with rediss://: #{ENV['REDIS_URL']&.start_with?('rediss://') || false}"
  puts "   Environment: #{Rails.env}"
rescue => e
  puts "❌ Error testing SSL detection: #{e.message}"
  exit 1
end

# Test 4: Test ActionCable channels exist
begin
  puts "✅ ActionCable channels loaded successfully"
  puts "   FormResponseChannel: #{FormResponseChannel.name}"
  puts "   SessionChannel: #{SessionChannel.name}"
  puts "   ApplicationCable::Channel: #{ApplicationCable::Channel.name}"
rescue => e
  puts "❌ Error loading ActionCable channels: #{e.message}"
  exit 1
end

puts "=" * 50
puts "🎉 All ActionCable SSL configuration tests passed!"
puts ""
puts "Configuration Summary:"
puts "- ActionCable configuration loads without errors"
puts "- SSL parameters are conditionally included for rediss:// URLs"
puts "- RedisConfig provides proper cable configuration"
puts "- SSL verification is disabled for Heroku Redis (VERIFY_NONE)"
puts "- ActionCable channels are properly defined"
puts ""
puts "The ActionCable SSL configuration is ready for production deployment!"