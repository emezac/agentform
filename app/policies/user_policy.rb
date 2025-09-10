# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def show?
    user == record || user.admin?
  end

  def update?
    user == record || user.admin?
  end

  def destroy?
    user.admin? && user != record
  end

  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(id: user.id)
      end
    end
  end
end