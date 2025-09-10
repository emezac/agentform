class GoogleSheetsIntegrationPolicy < ApplicationPolicy
  def show?
    user_owns_form? && user_has_premium_access?
  end

  def create?
    user_owns_form? && user_has_premium_access?
  end

  def update?
    user_owns_form? && user_has_premium_access?
  end

  def destroy?
    user_owns_form? && user_has_premium_access?
  end

  def export?
    user_owns_form? && user_has_premium_access?
  end

  def toggle_auto_sync?
    user_owns_form? && user_has_premium_access?
  end

  def test_connection?
    user_owns_form? && user_has_premium_access?
  end

  private

  def user_owns_form?
    return false unless user && record

    # If record is a GoogleSheetsIntegration
    if record.is_a?(GoogleSheetsIntegration)
      record.form.user == user
    # If record is a Form (for create action)
    elsif record.is_a?(Form)
      record.user == user
    else
      false
    end
  end

  def user_has_premium_access?
    user&.can_use_google_sheets?
  end
end