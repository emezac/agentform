class FormTemplatePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.all
    end
  end

  def index?
    user.present?
  end

  def show?
    user.present?
  end

  def instantiate?
    user.present? && record.visibility == 'template_public' || record.visibility == 'featured'
  end

  def create?
    user&.admin? || user&.creator?
  end

  def update?
    user&.admin? || user&.creator? || record.creator == user
  end

  def destroy?
    user&.admin? || user&.creator? || record.creator == user
  end
end