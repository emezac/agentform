# frozen_string_literal: true

class FormPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      # Superadmin can see all forms, regular users see only their own
      return scope.all if user&.superadmin?
      return scope.where(user: user) if user
      scope.none
    end
  end

  def index?
    user.present?
  end

  def show?
    owner? || admin?
  end

  def create?
    true
  end

  def new?
    create?
  end

  def update?
    owner? || admin?
  end

  def edit?
    update?
  end

  def destroy?
    owner? || admin?
  end

  def publish?
    owner? || admin?
  end

  def unpublish?
    owner? || admin?
  end

  def duplicate?
    show?
  end

  def analytics?
    owner? || admin?
  end

  def export?
    owner? || admin?
  end

  def preview?
    show?
  end

  def test_ai_feature?
    owner? || admin?
  end

  def embed_code?
    show?
  end

  def responses?
    owner? || admin?
  end

  def download_responses?
    owner? || admin?
  end

  def ai_features?
    user.premium? || user.admin? || user.superadmin?
  end

  def enable_ai?
    owner? && ai_features?
  end

  def test_connection?
    owner? || admin?
  end

  private

  def owner?
    record.user == user
  end

  def admin?
    user&.admin? || user&.superadmin?
  end
end