class GoogleIntegration < ApplicationRecord
  belongs_to :user
  has_many :google_sheets_integrations, dependent: :destroy

  validates :access_token, presence: true
  validates :refresh_token, presence: true
  validates :scope, presence: true

  scope :active, -> { where(active: true) }
  scope :expired, -> { where('token_expires_at < ?', Time.current) }

  def expired?
    token_expires_at < Time.current
  end

  def needs_refresh?
    token_expires_at < 5.minutes.from_now
  end

  def refresh_access_token!
    return unless refresh_token.present?

    begin
      credentials = Rails.application.credentials.google_sheets_integration[Rails.env.to_sym]
      
      client = Signet::OAuth2::Client.new(
        client_id: credentials[:client_id],
        client_secret: credentials[:client_secret],
        token_credential_uri: 'https://oauth2.googleapis.com/token',
        refresh_token: refresh_token
      )

      client.refresh!

      update!(
        access_token: client.access_token,
        token_expires_at: Time.current + client.expires_in.seconds,
        last_used_at: Time.current,
        error_log: []
      )

      true
    rescue => e
      update!(
        active: false,
        error_log: (error_log || []) << {
          timestamp: Time.current.iso8601,
          error: e.message,
          type: 'token_refresh_failed'
        }
      )
      false
    end
  end

  def valid_token?
    return false unless active?
    return false if expired?
    
    refresh_access_token! if needs_refresh?
    
    active? && !expired?
  end

  def revoke!
    # Revoke the token with Google
    begin
      uri = URI('https://oauth2.googleapis.com/revoke')
      response = Net::HTTP.post_form(uri, token: access_token)
    rescue => e
      Rails.logger.warn "Failed to revoke Google token: #{e.message}"
    end

    # Mark as inactive
    update!(active: false)
  end
end