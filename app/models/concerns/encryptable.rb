# frozen_string_literal: true

module Encryptable
  extend ActiveSupport::Concern

  included do
    # Manual encryption using Base64 encoding
    # No automatic field encryption to avoid Active Record Encryption dependency
  end

  # Instance methods for manual encryption/decryption
  def encrypt_data(data)
    return nil if data.blank?
    
    # Use simple Base64 encoding with a salt for basic obfuscation
    # Note: This is not cryptographically secure, just basic obfuscation
    salt = Rails.application.secret_key_base[0..15]
    encrypted = Base64.strict_encode64("#{salt}#{data}#{salt}")
    "encrypted:#{encrypted}"
  end

  def decrypt_data(encrypted_data)
    return nil if encrypted_data.blank?
    
    # Remove the 'encrypted:' prefix and decrypt
    if encrypted_data.start_with?('encrypted:')
      encrypted_value = encrypted_data.sub('encrypted:', '')
      decoded = Base64.strict_decode64(encrypted_value)
      salt = Rails.application.secret_key_base[0..15]
      # Remove salt from both ends
      decoded.sub(/^#{Regexp.escape(salt)}/, '').sub(/#{Regexp.escape(salt)}$/, '')
    else
      encrypted_data
    end
  rescue => e
    # If decryption fails, return the original data
    encrypted_data
  end

  class_methods do
    def encrypt_field(field_name, **options)
      # Custom field encryption using manual methods
      # This is a placeholder for future implementation if needed
      Rails.logger.info "Field encryption requested for #{field_name} but using manual encryption instead"
    end
  end
end