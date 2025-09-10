# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin Discount Code Management', type: :system do
  let(:superadmin) { create(:user, role: 'superadmin') }
  let(:admin) { create(:user, role: 'admin') }
  let(:regular_user) { create(:user, role: 'user') }

  before do
    driven_by(:rack_test)
  end

  describe 'Complete admin workflow' do
    before do
      login_as(superadmin, scope: :user)
    end

    it 'allows superadmin to manage discount codes end-to-end' do
      # Navigate to admin dashboard
      visit '/admin/dashboard'
      expect(page).to have_content('Admin Dashboard')
      expect(page).to have_link('Discount Codes')

      # Navigate to discount codes section
      click_link 'Discount Codes'
      expect(page).to have_current_path('/admin/discount_codes')
      expect(page).to have_content('Discount Code Management')

      # Create a new discount code
      click_link 'Create New Discount Code'
      expect(page).to have_current_path('/admin/discount_codes/new')

      fill_in 'Code', with: 'SYSTEM_TEST_20'
      fill_in 'Discount Percentage', with: '20'
      fill_in 'Max Usage Count', with: '100'
      fill_in 'Expires At', with: 1.month.from_now.strftime('%Y-%m-%d')
      check 'Active'

      click_button 'Create Discount Code'

      # Verify creation success
      expect(page).to have_content('Discount code created successfully')
      expect(page).to have_content('SYSTEM_TEST_20')
      expect(page).to have_content('20%')
      expect(page).to have_content('0 / 100') # Usage count

      # Edit the discount code
      click_link 'Edit'
      fill_in 'Discount Percentage', with: '25'
      fill_in 'Max Usage Count', with: '50'
      click_button 'Update Discount Code'

      # Verify update success
      expect(page).to have_content('Discount code updated successfully')
      expect(page).to have_content('25%')
      expect(page).to have_content('0 / 50')

      # Test status toggle
      within('.discount-code-actions') do
        click_button 'Deactivate'
      end

      expect(page).to have_content('Discount code deactivated')
      expect(page).to have_content('Inactive')

      # Reactivate
      within('.discount-code-actions') do
        click_button 'Activate'
      end

      expect(page).to have_content('Discount code activated')
      expect(page).to have_content('Active')

      # View usage statistics (should be empty)
      expect(page).to have_content('Usage Statistics')
      expect(page).to have_content('Total Uses: 0')
      expect(page).to have_content('Revenue Impact: $0.00')

      # Return to index and verify the code is listed
      click_link 'Back to Discount Codes'
      expect(page).to have_content('SYSTEM_TEST_20')
      expect(page).to have_content('25%')
      expect(page).to have_content('Active')

      # Test search functionality
      fill_in 'Search', with: 'SYSTEM_TEST'
      click_button 'Search'
      expect(page).to have_content('SYSTEM_TEST_20')

      # Test filtering
      select 'Active', from: 'Status'
      click_button 'Filter'
      expect(page).to have_content('SYSTEM_TEST_20')

      select 'Inactive', from: 'Status'
      click_button 'Filter'
      expect(page).not_to have_content('SYSTEM_TEST_20')

      # Reset filters
      click_link 'Clear Filters'
      expect(page).to have_content('SYSTEM_TEST_20')
    end

    it 'prevents deletion of used discount codes' do
      # Create a discount code with usage
      discount_code = create(:discount_code, code: 'USED_CODE', created_by: superadmin)
      create(:discount_code_usage, discount_code: discount_code)

      visit "/admin/discount_codes/#{discount_code.id}"

      # Try to delete the used code
      accept_confirm do
        click_link 'Delete'
      end

      expect(page).to have_content('cannot be deleted because it has been used')
      expect(page).to have_current_path("/admin/discount_codes/#{discount_code.id}")
    end

    it 'allows deletion of unused discount codes' do
      # Create an unused discount code
      discount_code = create(:discount_code, code: 'UNUSED_CODE', created_by: superadmin)

      visit "/admin/discount_codes/#{discount_code.id}"

      # Delete the unused code
      accept_confirm do
        click_link 'Delete'
      end

      expect(page).to have_content('Discount code deleted successfully')
      expect(page).to have_current_path('/admin/discount_codes')
      expect(page).not_to have_content('UNUSED_CODE')
    end

    it 'displays comprehensive usage statistics' do
      # Create a discount code with multiple usages
      discount_code = create(:discount_code, code: 'STATS_TEST', created_by: superadmin)
      users = create_list(:user, 3)
      
      users.each_with_index do |user, index|
        create(:discount_code_usage, 
               discount_code: discount_code,
               user: user,
               original_amount: 5000,
               discount_amount: 1000,
               final_amount: 4000,
               used_at: (index + 1).days.ago)
      end

      visit "/admin/discount_codes/#{discount_code.id}"

      # Verify statistics display
      expect(page).to have_content('Total Uses: 3')
      expect(page).to have_content('Revenue Impact: $30.00')
      expect(page).to have_content('Usage Percentage: 3.0%')

      # Verify recent usages table
      expect(page).to have_content('Recent Usages')
      users.each do |user|
        expect(page).to have_content(user.email)
      end

      expect(page).to have_content('$10.00', count: 3) # Discount amount for each usage
    end

    it 'handles bulk operations efficiently' do
      # Create multiple discount codes
      codes = create_list(:discount_code, 5, created_by: superadmin)

      visit '/admin/discount_codes'

      # Select multiple codes
      codes.first(3).each do |code|
        check "discount_code_#{code.id}"
      end

      # Bulk deactivate
      select 'Deactivate', from: 'bulk_action'
      click_button 'Apply to Selected'

      expect(page).to have_content('3 discount codes deactivated')

      # Verify codes are deactivated
      codes.first(3).each do |code|
        expect(page).to have_content("#{code.code}") # Still visible
        within("#discount_code_#{code.id}") do
          expect(page).to have_content('Inactive')
        end
      end
    end
  end

  describe 'User management workflow' do
    before do
      login_as(superadmin, scope: :user)
    end

    it 'allows complete user management operations' do
      # Navigate to user management
      visit '/admin/dashboard'
      click_link 'Users'
      expect(page).to have_current_path('/admin/users')

      # Create a new user
      click_link 'Create New User'
      fill_in 'Email', with: 'newuser@example.com'
      fill_in 'First Name', with: 'New'
      fill_in 'Last Name', with: 'User'
      select 'user', from: 'Role'
      select 'freemium', from: 'Subscription Tier'
      click_button 'Create User'

      expect(page).to have_content('User created successfully')
      expect(page).to have_content('newuser@example.com')

      # View user details
      click_link 'View'
      expect(page).to have_content('User Details')
      expect(page).to have_content('New User')
      expect(page).to have_content('freemium')
      expect(page).to have_content('Eligible for discount codes: Yes')

      # Edit user
      click_link 'Edit'
      fill_in 'First Name', with: 'Updated'
      select 'premium', from: 'Subscription Tier'
      click_button 'Update User'

      expect(page).to have_content('User updated successfully')
      expect(page).to have_content('Updated User')
      expect(page).to have_content('premium')
      expect(page).to have_content('Eligible for discount codes: No')

      # Suspend user
      click_button 'Suspend User'
      fill_in 'Suspension Reason', with: 'Policy violation'
      click_button 'Confirm Suspension'

      expect(page).to have_content('User suspended successfully')
      expect(page).to have_content('Suspended')
      expect(page).to have_content('Policy violation')

      # Reactivate user
      click_button 'Reactivate User'
      expect(page).to have_content('User reactivated successfully')
      expect(page).not_to have_content('Suspended')
    end

    it 'displays comprehensive user statistics and activity' do
      # Create users with various states
      active_users = create_list(:user, 3, :with_forms)
      suspended_user = create(:user, suspended_at: 1.day.ago, suspended_reason: 'Test')
      premium_user = create(:user, subscription_tier: 'premium')

      visit '/admin/users'

      # Verify user listing
      expect(page).to have_content("#{User.count} users total")
      
      active_users.each do |user|
        expect(page).to have_content(user.email)
      end

      # Test search functionality
      fill_in 'Search', with: active_users.first.email
      click_button 'Search'
      expect(page).to have_content(active_users.first.email)
      expect(page).not_to have_content(active_users.last.email)

      # Test filtering
      select 'suspended', from: 'Status'
      click_button 'Filter'
      expect(page).to have_content(suspended_user.email)
      expect(page).not_to have_content(active_users.first.email)

      # View detailed user statistics
      click_link 'Clear Filters'
      within("#user_#{active_users.first.id}") do
        click_link 'View'
      end

      expect(page).to have_content('Usage Statistics')
      expect(page).to have_content('Total Forms: 3')
      expect(page).to have_content('Recent Activity')
    end

    it 'prevents unauthorized operations' do
      # Create another superadmin
      other_superadmin = create(:user, role: 'superadmin')

      visit "/admin/users/#{other_superadmin.id}"

      # Try to suspend another superadmin
      expect(page).not_to have_button('Suspend User')

      # Try to delete another superadmin
      expect(page).not_to have_link('Delete User')

      # Try to suspend self
      visit "/admin/users/#{superadmin.id}"
      expect(page).not_to have_button('Suspend User')
      expect(page).not_to have_link('Delete User')
    end
  end

  describe 'Dashboard overview and navigation' do
    before do
      # Create test data for dashboard
      create_list(:user, 10)
      create_list(:discount_code, 5, created_by: superadmin)
      create_list(:discount_code_usage, 8)

      login_as(superadmin, scope: :user)
    end

    it 'displays comprehensive dashboard statistics' do
      visit '/admin/dashboard'

      # Verify main statistics cards
      expect(page).to have_content('Total Users')
      expect(page).to have_content('Active Discount Codes')
      expect(page).to have_content('Total Usage')
      expect(page).to have_content('Revenue Impact')

      # Verify recent activity feed
      expect(page).to have_content('Recent Activity')
      expect(page).to have_content('User registered')
      expect(page).to have_content('Discount code used')

      # Verify quick actions
      expect(page).to have_link('Create Discount Code')
      expect(page).to have_link('Create User')
      expect(page).to have_link('View All Users')
      expect(page).to have_link('View All Discount Codes')

      # Test navigation to different sections
      click_link 'View All Discount Codes'
      expect(page).to have_current_path('/admin/discount_codes')

      visit '/admin/dashboard'
      click_link 'View All Users'
      expect(page).to have_current_path('/admin/users')
    end

    it 'provides real-time statistics updates' do
      visit '/admin/dashboard'
      
      initial_user_count = page.find('.user-count').text.to_i

      # Create a new user in another session (simulating real-time update)
      create(:user)

      # Refresh the page to see updated statistics
      visit '/admin/dashboard'
      
      updated_user_count = page.find('.user-count').text.to_i
      expect(updated_user_count).to eq(initial_user_count + 1)
    end
  end

  describe 'Authorization and access control' do
    it 'prevents regular users from accessing admin areas' do
      login_as(regular_user, scope: :user)

      # Try to access admin dashboard
      visit '/admin/dashboard'
      expect(page).to have_current_path('/')
      expect(page).to have_content('Access denied')

      # Try to access discount codes management
      visit '/admin/discount_codes'
      expect(page).to have_current_path('/')
      expect(page).to have_content('Access denied')

      # Try to access user management
      visit '/admin/users'
      expect(page).to have_current_path('/')
      expect(page).to have_content('Access denied')
    end

    it 'allows admin users read-only access' do
      login_as(admin, scope: :user)

      # Can access dashboard
      visit '/admin/dashboard'
      expect(page).to have_content('Admin Dashboard')

      # Can view discount codes
      visit '/admin/discount_codes'
      expect(page).to have_content('Discount Code Management')
      expect(page).not_to have_link('Create New Discount Code')

      # Can view users
      visit '/admin/users'
      expect(page).to have_content('User Management')
      expect(page).not_to have_link('Create New User')

      # Cannot access creation forms directly
      visit '/admin/discount_codes/new'
      expect(page).to have_current_path('/')
      expect(page).to have_content('Superadmin privileges required')
    end

    it 'requires authentication for all admin areas' do
      # Try to access admin areas without login
      visit '/admin/dashboard'
      expect(page).to have_current_path('/users/sign_in')

      visit '/admin/discount_codes'
      expect(page).to have_current_path('/users/sign_in')

      visit '/admin/users'
      expect(page).to have_current_path('/users/sign_in')
    end
  end

  describe 'Error handling and user experience' do
    before do
      login_as(superadmin, scope: :user)
    end

    it 'handles validation errors gracefully' do
      visit '/admin/discount_codes/new'

      # Submit form with invalid data
      fill_in 'Code', with: ''
      fill_in 'Discount Percentage', with: '150'
      click_button 'Create Discount Code'

      # Verify error messages are displayed
      expect(page).to have_content("Code can't be blank")
      expect(page).to have_content('Discount percentage must be between 1 and 99')

      # Form should retain valid values
      expect(page).to have_field('Discount Percentage', with: '150')
    end

    it 'provides helpful feedback for user actions' do
      discount_code = create(:discount_code, created_by: superadmin)

      visit "/admin/discount_codes/#{discount_code.id}"

      # Test status toggle feedback
      click_button 'Deactivate'
      expect(page).to have_content('Discount code deactivated successfully')
      expect(page).to have_css('.alert-success')

      click_button 'Activate'
      expect(page).to have_content('Discount code activated successfully')
      expect(page).to have_css('.alert-success')
    end

    it 'handles concurrent modifications gracefully' do
      discount_code = create(:discount_code, created_by: superadmin)

      # Open edit form
      visit "/admin/discount_codes/#{discount_code.id}/edit"

      # Simulate another user modifying the record
      discount_code.update!(discount_percentage: 30)

      # Try to submit changes
      fill_in 'Discount Percentage', with: '25'
      click_button 'Update Discount Code'

      expect(page).to have_content('This discount code was modified by another user')
      expect(page).to have_field('Discount Percentage', with: '30') # Shows current value
    end

    it 'provides clear navigation and breadcrumbs' do
      discount_code = create(:discount_code, created_by: superadmin)

      visit "/admin/discount_codes/#{discount_code.id}"

      # Verify breadcrumb navigation
      expect(page).to have_content('Admin Dashboard > Discount Codes > ' + discount_code.code)

      # Test breadcrumb links
      click_link 'Discount Codes'
      expect(page).to have_current_path('/admin/discount_codes')

      click_link 'Admin Dashboard'
      expect(page).to have_current_path('/admin/dashboard')
    end
  end

  describe 'Performance and responsiveness' do
    before do
      login_as(superadmin, scope: :user)
    end

    it 'handles large datasets efficiently' do
      # Create a large number of discount codes
      create_list(:discount_code, 100, created_by: superadmin)

      visit '/admin/discount_codes'

      # Page should load within reasonable time
      expect(page).to have_content('Discount Code Management')

      # Pagination should be present
      expect(page).to have_content('Page 1 of')
      expect(page).to have_link('Next')

      # Search should work efficiently
      fill_in 'Search', with: 'DISCOUNT1'
      click_button 'Search'
      expect(page).to have_content('DISCOUNT1')
    end

    it 'provides responsive design for different screen sizes' do
      # Test mobile viewport
      page.driver.browser.manage.window.resize_to(375, 667)

      visit '/admin/dashboard'

      # Mobile navigation should be present
      expect(page).to have_css('.mobile-nav-toggle')

      # Statistics should stack vertically
      expect(page).to have_css('.stats-grid.mobile')

      # Reset to desktop
      page.driver.browser.manage.window.resize_to(1200, 800)
    end
  end
end