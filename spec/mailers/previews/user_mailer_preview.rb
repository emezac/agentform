# frozen_string_literal: true

# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/admin_invitation
  def admin_invitation
    user = User.first || FactoryBot.build(:user, 
      first_name: 'John', 
      last_name: 'Doe', 
      email: 'john.doe@example.com'
    )
    temporary_password = 'TempPass123!'
    
    UserMailer.admin_invitation(user, temporary_password)
  end

  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/account_suspended
  def account_suspended
    user = User.first || FactoryBot.build(:user, 
      first_name: 'Jane', 
      last_name: 'Smith', 
      email: 'jane.smith@example.com'
    )
    suspension_reason = 'Multiple violations of our terms of service, including spam and inappropriate content.'
    
    UserMailer.account_suspended(user, suspension_reason)
  end

  # Preview this email at http://localhost:3000/rails/mailers/user_mailer/account_reactivated
  def account_reactivated
    user = User.first || FactoryBot.build(:user, 
      first_name: 'Bob', 
      last_name: 'Johnson', 
      email: 'bob.johnson@example.com'
    )
    
    UserMailer.account_reactivated(user)
  end
end