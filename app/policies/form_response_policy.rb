class FormResponsePolicy < ApplicationPolicy
  def show?
    user_owns_form?
  end

  def create?
    true # Anyone can create form responses (public forms)
  end

  def update?
    user_owns_form?
  end

  def destroy?
    user_owns_form?
  end

  def generate_report?
    user_owns_form?
  end

  private

  def user_owns_form?
    record.form.user == user
  end

  class Scope < Scope
    def resolve
      scope.joins(:form).where(forms: { user: user })
    end
  end
end