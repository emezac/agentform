class DiscountCodeUsage < ApplicationRecord
  include AdminCacheable
  
  belongs_to :discount_code
  belongs_to :user

  validates :user_id, uniqueness: true, presence: true
  validates :discount_code_id, presence: true
  validates :original_amount, presence: true, numericality: { greater_than: 0 }
  validates :discount_amount, presence: true, numericality: { greater_than: 0 }
  validates :final_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :used_at, presence: true

  validate :final_amount_calculation_is_correct
  validate :discount_amount_not_greater_than_original

  scope :recent, -> { order(used_at: :desc) }
  scope :by_discount_code, ->(code) { where(discount_code: code) }
  scope :by_user, ->(user) { where(user: user) }

  def savings_percentage
    return 0 if original_amount.zero?
    (discount_amount.to_f / original_amount * 100).round(1)
  end

  def formatted_original_amount
    ActionController::Base.helpers.number_to_currency(original_amount / 100.0)
  end

  def formatted_discount_amount
    ActionController::Base.helpers.number_to_currency(discount_amount / 100.0)
  end

  def formatted_final_amount
    ActionController::Base.helpers.number_to_currency(final_amount / 100.0)
  end

  private

  def final_amount_calculation_is_correct
    return unless original_amount.present? && discount_amount.present? && final_amount.present?
    
    expected_final_amount = original_amount - discount_amount
    unless final_amount == expected_final_amount
      errors.add(:final_amount, "must equal original amount minus discount amount (#{expected_final_amount})")
    end
  end

  def discount_amount_not_greater_than_original
    return unless original_amount.present? && discount_amount.present?
    
    if discount_amount > original_amount
      errors.add(:discount_amount, "cannot be greater than original amount")
    end
  end
end