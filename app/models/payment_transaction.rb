class PaymentTransaction < ApplicationRecord
  belongs_to :user
  belongs_to :form
  belongs_to :form_response

  # Validations
  validates :stripe_payment_intent_id, presence: true, uniqueness: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :currency, presence: true, length: { is: 3 }
  validates :status, presence: true, inclusion: { 
    in: %w[pending processing succeeded failed canceled requires_action] 
  }
  validates :payment_method, presence: true, inclusion: { 
    in: %w[credit_card paypal apple_pay google_pay] 
  }

  # Scopes
  scope :successful, -> { where(status: 'succeeded') }
  scope :failed, -> { where(status: 'failed') }
  scope :pending, -> { where(status: 'pending') }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_form, ->(form) { where(form: form) }

  # Callbacks
  before_validation :set_defaults, on: :create
  after_update :update_processed_at, if: :saved_change_to_status?

  def successful?
    status == 'succeeded'
  end

  def failed?
    status == 'failed'
  end

  def pending?
    status == 'pending'
  end

  def processing?
    status == 'processing'
  end

  def amount_in_cents
    (amount * 100).to_i
  end

  def formatted_amount
    "$#{'%.2f' % amount}"
  end

  def stripe_client
    user.stripe_client
  end

  def retrieve_payment_intent
    return nil unless stripe_client && stripe_payment_intent_id.present?
    
    begin
      stripe_client.payment_intents.retrieve(stripe_payment_intent_id)
    rescue Stripe::StripeError => e
      Rails.logger.error "Failed to retrieve payment intent #{stripe_payment_intent_id}: #{e.message}"
      nil
    end
  end

  def sync_with_stripe!
    payment_intent = retrieve_payment_intent
    return false unless payment_intent

    update!(
      status: payment_intent.status,
      metadata: metadata.merge(
        stripe_status: payment_intent.status,
        last_synced_at: Time.current.iso8601
      )
    )
    
    true
  rescue StandardError => e
    Rails.logger.error "Failed to sync payment transaction #{id} with Stripe: #{e.message}"
    false
  end

  private

  def set_defaults
    self.currency ||= 'USD'
    self.status ||= 'pending'
    self.metadata ||= {}
  end

  def update_processed_at
    if status_changed? && %w[succeeded failed canceled].include?(status)
      update_column(:processed_at, Time.current)
    end
  end
end
