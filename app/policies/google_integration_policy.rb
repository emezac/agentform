# frozen_string_literal: true

class GoogleIntegrationPolicy < ApplicationPolicy
  def show?
    user_owns_integration?
  end

  def create?
    user.present?
  end

  def update?
    user_owns_integration?
  end

  def destroy?
    user_owns_integration?
  end

  private

  def user_owns_integration?
    user.present? && record.user == user
  end
end