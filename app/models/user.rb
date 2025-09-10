class User < ApplicationRecord
  include Encryptable
  include AdminCacheable

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :trackable, :confirmable

  # Skip automatic confirmation email sending
  def send_on_create_confirmation_instructions
    # Override to prevent automatic sending
    # We'll send our custom confirmation email manually
  end

  # Auto-confirm admin and superadmin users
  before_create :auto_confirm_admin_users

  # Associations
  has_many :forms, dependent: :destroy
  has_many :form_responses, through: :forms
  has_many :api_tokens, dependent: :destroy
  has_many :payment_transactions, dependent: :destroy
  has_many :created_discount_codes, class_name: 'DiscountCode', foreign_key: 'created_by_id', dependent: :destroy
  has_one :discount_code_usage, dependent: :destroy
  has_one :used_discount_code, through: :discount_code_usage, source: :discount_code
  
  # Google Sheets Integration
  has_one :google_integration, dependent: :destroy
  has_many :export_jobs, dependent: :destroy

  # Role and subscription tier as string fields
  validates :role, inclusion: { in: %w[user admin superadmin] }, allow_nil: false
  validates :subscription_tier, inclusion: { in: %w[basic premium] }, allow_nil: false
  
  # Set defaults
  after_initialize :set_defaults, if: :new_record?

  # Validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, :last_name, presence: true
  validates :ai_credits_used, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :monthly_ai_limit, presence: true, numericality: { greater_than: 0 }
  
  # Stripe validations
  validates :stripe_publishable_key, presence: true, if: :stripe_enabled?
  validates :stripe_secret_key, presence: true, if: :stripe_enabled?
  validate :validate_stripe_keys, if: :stripe_enabled?

  # Callbacks
  before_create :set_default_preferences
  before_create :set_trial_end_date
  before_save :update_last_activity
  after_create :notify_admin_of_registration
  after_update :notify_admin_of_subscription_changes

  # Public instance methods
  def full_name
    "#{first_name} #{last_name}".strip
  end

  def ai_credits_used_this_month
    # For now, return total usage since we don't have monthly reset functionality yet
    # In a future enhancement, this could be filtered by date range
    (ai_credits_used || 0.0).to_f
  end

  def ai_credits_limit
    (monthly_ai_limit || 0.0).to_f
  end

  def ai_credits_remaining
    limit = ai_credits_limit
    used = ai_credits_used_this_month
    [limit - used, 0.0].max
  end

  def admin?
    role == 'admin' || role == 'superadmin'
  end

  def superadmin?
    role == 'superadmin'
  end

  def premium?
    subscription_tier == 'premium' || role == 'admin' || role == 'superadmin'
  end

  def freemium?
    false # Freemium plan has been deprecated, all users are now basic or premium
  end

  def active?
    # Check the active attribute from the database
    self.active
  end

  def can_use_ai_features?
    premium? || admin?
  end

  def consume_ai_credit(cost = 1.0)
    return false unless can_use_ai_features?
    
    cost = cost.to_f
    return false if cost <= 0
    
    # Check if user has enough credits before consuming
    return false if ai_credits_remaining < cost
    
    increment!(:ai_credits_used, cost)
    true
  end

  def can_consume_ai_credit?(cost = 1.0)
    return false unless can_use_ai_features?
    
    cost = cost.to_f
    return false if cost <= 0
    
    ai_credits_remaining >= cost
  end

  def form_usage_stats
    {
      total_forms: forms.count,
      published_forms: forms.published.count,
      total_responses: form_responses.count,
      avg_completion_rate: forms.average(:completion_rate) || 0.0
    }
  end

  # Stripe methods
  def stripe_configured?
    stripe_enabled? && stripe_publishable_key.present? && stripe_secret_key.present?
  end

  def stripe_client
    return nil unless stripe_configured?
    
    @stripe_client ||= Stripe::StripeClient.new(stripe_secret_key)
  end

  def can_accept_payments?
    stripe_configured? && premium?
  end

  # Google Sheets integration methods
  def google_sheets_connected?
    google_integration&.active?
  end

  def can_use_google_sheets?
    premium? || admin?
  end

  def can_export_to_google_sheets?
    can_use_google_sheets? && google_sheets_connected?
  end

  def time_zone
    preferences&.dig('time_zone') || 'UTC'
  end

  def encrypt_stripe_keys!
    if stripe_secret_key.present? && !stripe_secret_key.start_with?('encrypted:')
      self.stripe_secret_key = encrypt_data(stripe_secret_key)
    end
    
    if stripe_webhook_secret.present? && !stripe_webhook_secret.start_with?('encrypted:')
      self.stripe_webhook_secret = encrypt_data(stripe_webhook_secret)
    end
  end

  def decrypt_stripe_secret_key
    return nil unless stripe_secret_key.present?
    
    if stripe_secret_key.start_with?('encrypted:')
      decrypt_data(stripe_secret_key)
    else
      stripe_secret_key
    end
  end

  def decrypt_stripe_webhook_secret
    return nil unless stripe_webhook_secret.present?
    
    if stripe_webhook_secret.start_with?('encrypted:')
      decrypt_data(stripe_webhook_secret)
    else
      stripe_webhook_secret
    end
  end

  def set_defaults
    self.role ||= 'user'
    self.subscription_tier ||= 'basic'
    
    # Set subscription status based on trial configuration
    if self.subscription_status.nil?
      self.subscription_status = TrialConfig.trial_enabled? ? 'trialing' : 'active'
    end
  end

  # --- Lógica del Free Trial ---

  # Devuelve true si el usuario está en el periodo de prueba.
  def on_trial?
    # Un usuario está en trial si tiene una fecha de vencimiento y aún no es premium.
    subscription_tier == 'basic' && trial_expires_at.present?
  end

  # Devuelve true si el trial ha terminado.
  def trial_expired?
    on_trial? && trial_expires_at < Time.current
  end

  # Devuelve true si el trial está activo.
  def trial_active?
    on_trial? && trial_expires_at >= Time.current
  end

  # Subscription management methods
  def subscription_active?
    subscription_status.in?(['active', 'trialing'])
  end

  def subscription_canceling?
    subscription_status == 'canceling'
  end

  def subscription_past_due?
    subscription_status == 'past_due'
  end

  def subscription_canceled?
    subscription_status == 'canceled'
  end

  def subscription_expires_soon?
    subscription_expires_at.present? && 
    subscription_expires_at <= 7.days.from_now
  end

  def days_until_subscription_expires
    return nil unless subscription_expires_at.present?
    
    days = (subscription_expires_at.to_date - Date.current).to_i
    [days, 0].max
  end

  def subscription_renewal_date
    subscription_expires_at
  end

  def has_valid_subscription?
    premium? && subscription_active? && 
    (subscription_expires_at.nil? || subscription_expires_at > Time.current)
  end

  # Trial management methods
  def trial_days_remaining
    return 0 unless trial_ends_at && subscription_status == 'trialing'
    
    days = ((trial_ends_at - Time.current) / 1.day).ceil
    [days, 0].max
  end

  def trial_expired?
    return false unless trial_ends_at
    Time.current >= trial_ends_at
  end

  def trial_expires_soon?
    trial_days_remaining <= 7 && trial_days_remaining > 0
  end

  def trial_expires_today?
    trial_days_remaining == 1
  end

  def trial_status_message
    return nil unless subscription_status == 'trialing'
    
    days = trial_days_remaining
    case days
    when 0
      "Your trial has expired"
    when 1
      "Your trial expires today"
    when 2..3
      "Your trial expires in #{days} days"
    when 4..7
      "#{days} days left in your trial"
    else
      "Trial active (#{days} days remaining)"
    end
  end

  # Discount code eligibility methods
  def eligible_for_discount?
    !discount_code_used? && !suspended? && subscription_tier != 'premium'
  end

  def can_use_discount_code?
    eligible_for_discount?
  end

  def discount_code_used?
    discount_code_used || discount_code_usage.present?
  end

  def mark_discount_code_as_used!
    update!(discount_code_used: true)
  end

  # User suspension methods
  def suspended?
    suspended_at.present?
  end

  def active_user?
    !suspended?
  end

  def suspend!(reason)
    update!(
      suspended_at: Time.current,
      suspended_reason: reason
    )
  end

  def reactivate!
    update!(
      suspended_at: nil,
      suspended_reason: nil
    )
  end

  def suspension_duration
    return nil unless suspended?
    Time.current - suspended_at
  end

  def suspension_duration_in_days
    return nil unless suspended?
    (suspension_duration / 1.day).round
  end

  # Payment setup status methods
  def payment_setup_status
    {
      stripe_configured: stripe_configured?,
      premium_subscription: premium?,
      can_accept_payments: can_accept_payments?,
      setup_completion_percentage: calculate_setup_completion
    }
  end

  def calculate_setup_completion
    total_steps = 2 # Stripe + Premium
    completed_steps = 0
    completed_steps += 1 if stripe_configured?
    completed_steps += 1 if premium?
    (completed_steps.to_f / total_steps * 100).round
  end

  def payment_setup_complete_for?(required_features)
    return true if required_features.blank?
    
    required_features.all? do |feature|
      case feature
      when 'stripe_payments'
        stripe_configured?
      when 'premium_subscription'
        premium?
      else
        true # Unknown features are considered complete
      end
    end
  end

  private

  def auto_confirm_admin_users
    if admin? || superadmin?
      self.confirmed_at = Time.current
      self.confirmation_token = nil
    end
  end

  def set_default_preferences
    self.preferences ||= default_preferences
    self.ai_settings ||= default_ai_settings
    self.monthly_ai_limit ||= default_ai_credits
  end

  def set_trial_end_date
    if subscription_status == 'trialing' && trial_ends_at.nil? && TrialConfig.trial_enabled?
      self.trial_ends_at = TrialConfig.trial_end_date(created_at || Time.current)
    end
  end

  def default_preferences
    {
      theme: 'light',
      notifications: {
        email: true,
        browser: true,
        form_responses: true,
        ai_insights: true
      },
      dashboard: {
        default_view: 'grid',
        items_per_page: 20
      }
    }
  end

  def default_ai_settings
    {
      auto_analysis: true,
      confidence_threshold: 0.7,
      preferred_model: 'gpt-3.5-turbo',
      max_tokens: 1000
    }
  end

  def default_ai_credits
    case role
    when 'superadmin'
      10000.0
    when 'admin'
      1000.0
    when 'premium'
      100.0
    else
      10.0
    end
  end

  def update_last_activity
    self.last_activity_at = Time.current if changed?
  end

  def validate_stripe_keys
    return unless stripe_enabled?
    
    if stripe_publishable_key.present?
      unless stripe_publishable_key.start_with?('pk_')
        errors.add(:stripe_publishable_key, 'must start with pk_')
      end
    end
    
    if stripe_secret_key.present?
      decrypted_key = decrypt_stripe_secret_key
      unless decrypted_key&.start_with?('sk_')
        errors.add(:stripe_secret_key, 'must start with sk_')
      end
    end
  end

  # Admin notification methods
  def notify_admin_of_registration
    AdminNotificationService.notify(:user_registered, user: self)
  end

  def notify_admin_of_subscription_changes
    if subscription_tier_changed? && subscription_tier_was.present?
      if subscription_tier == 'premium' && subscription_tier_was == 'basic'
        AdminNotificationService.notify(:user_upgraded, 
          user: self, 
          from_plan: subscription_tier_was, 
          to_plan: subscription_tier
        )
      elsif subscription_tier == 'basic' && subscription_tier_was == 'premium'
        AdminNotificationService.notify(:user_downgraded, 
          user: self, 
          from_plan: subscription_tier_was, 
          to_plan: subscription_tier
        )
      end
    end

    # Notify when trial starts
    if trial_ends_at_changed? && trial_ends_at.present? && trial_ends_at_was.nil?
      AdminNotificationService.notify(:trial_started, user: self)
    end
  end
end
