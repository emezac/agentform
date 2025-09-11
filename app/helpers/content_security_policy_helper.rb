# frozen_string_literal: true

# Content Security Policy Helper
# Provides utilities for working with CSP nonces and secure inline scripts
module ContentSecurityPolicyHelper
  # Get the current CSP nonce for scripts
  def csp_script_nonce
    content_security_policy_nonce
  end

  # Get the current CSP nonce for styles
  def csp_style_nonce
    content_security_policy_nonce
  end

  # Create a script tag with proper CSP nonce
  def safe_javascript_tag(content = nil, **options, &block)
    options[:nonce] = csp_script_nonce if Rails.env.production?
    
    if block_given?
      javascript_tag(**options, &block)
    else
      javascript_tag(content, **options)
    end
  end

  # Create a style tag with proper CSP nonce
  def safe_style_tag(content = nil, **options, &block)
    options[:nonce] = csp_style_nonce if Rails.env.production?
    
    if block_given?
      content_tag(:style, **options, &block)
    else
      content_tag(:style, content, **options)
    end
  end

  # Check if CSP is enabled
  def csp_enabled?
    Rails.env.production? && Rails.application.config.content_security_policy.present?
  end

  # Get CSP report URI if configured
  def csp_report_uri
    Rails.application.config.content_security_policy_report_only ? '/csp-report' : nil
  end
end