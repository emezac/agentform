# frozen_string_literal: true

class FormQuestionPolicy < ApplicationPolicy
  def index?
    user.present? && (record.form.user == user || user.admin?)
  end

  def show?
    user.present? && (record.form.user == user || user.admin?)
  end

  def create?
    user.present? && (record.form.user == user || user.admin?)
  end

  def update?
    user.present? && (record.form.user == user || user.admin?)
  end

  def destroy?
    user.present? && (record.form.user == user || user.admin?)
  end

  def edit?
    update?
  end

  def new?
    create?
  end

  def move_up?
    update?
  end

  def move_down?
    update?
  end

  def duplicate?
    create?
  end

  def ai_enhance?
    update? && record.form.ai_enhanced?
  end

  def preview?
    show?
  end

  def analytics?
    show?
  end

  def reorder?
    update?
  end

  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.joins(:form).where(forms: { user: user })
      end
    end
  end
end