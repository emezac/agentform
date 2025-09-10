# frozen_string_literal: true

class ApiToken < ApplicationRecord
  # Associations
  belongs_to :user

  # Validations
  validates :name, presence: true
  validates :token, presence: true, uniqueness: true

  # Callbacks
  before_create :generate_token

  # Scopes
  scope :active, -> { where(active: true) }
  scope :expired, -> { where('expires_at < ?', Time.current) }
  scope :valid, -> { active.where('expires_at IS NULL OR expires_at > ?', Time.current) }
  scope :recent, -> { order(created_at: :desc) }

  # Core Methods
  def active?
    active && !expired?
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def can_access?(resource, action)
    return false unless active?
    
    # Check if token has permission for this resource and action
    return true if permissions.blank? # No restrictions means full access
    
    resource_permissions = permissions[resource.to_s]
    return false if resource_permissions.nil?
    
    # Check if action is allowed
    case resource_permissions
    when Array
      resource_permissions.include?(action.to_s)
    when Hash
      resource_permissions[action.to_s] == true
    when true
      true # Full access to resource
    else
      false
    end
  end

  def record_usage!
    increment!(:usage_count)
    update!(last_used_at: Time.current)
  end

  def revoke!
    update!(active: false)
  end

  def extend_expiration(duration)
    new_expiration = expires_at ? expires_at + duration : Time.current + duration
    update!(expires_at: new_expiration)
  end

  def usage_summary
    {
      name: name,
      token_preview: "#{token[0..7]}...",
      created_at: created_at,
      last_used_at: last_used_at,
      usage_count: usage_count,
      expires_at: expires_at,
      active: active?,
      permissions: permissions_summary
    }
  end

  def permissions_summary
    return 'Full access' if permissions.blank?
    
    summary = []
    permissions.each do |resource, actions|
      case actions
      when true
        summary << "#{resource}: full access"
      when Array
        summary << "#{resource}: #{actions.join(', ')}"
      when Hash
        allowed_actions = actions.select { |_, allowed| allowed }.keys
        summary << "#{resource}: #{allowed_actions.join(', ')}"
      end
    end
    
    summary.join('; ')
  end

  def self.authenticate(token_string)
    return nil if token_string.blank?
    
    # Remove 'Bearer ' prefix if present
    clean_token = token_string.gsub(/^Bearer\s+/, '')
    
    token = find_by(token: clean_token)
    return nil unless token&.active?
    
    token.record_usage!
    token
  end

  def self.create_for_user(user, name:, expires_in: nil, permissions: {})
    create!(
      user: user,
      name: name,
      expires_at: expires_in ? Time.current + expires_in : nil,
      permissions: permissions
    )
  end

  def self.cleanup_expired
    expired.update_all(active: false)
  end

  # Default permission templates
  def self.readonly_permissions
    {
      'forms' => ['index', 'show'],
      'responses' => ['index', 'show'],
      'analytics' => ['show']
    }
  end

  def self.full_permissions
    {
      'forms' => true,
      'responses' => true,
      'analytics' => true,
      'users' => ['show', 'update']
    }
  end

  def self.forms_only_permissions
    {
      'forms' => true,
      'responses' => ['create', 'show']
    }
  end

  private

  def generate_token
    return if token.present?
    
    loop do
      # Generate a secure random token
      self.token = SecureRandom.urlsafe_base64(32)
      break unless self.class.exists?(token: token)
    end
  end
end