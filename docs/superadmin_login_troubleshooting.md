# Superadmin Login Troubleshooting Guide

## Problem: "Invalid Email or Password" Error

If you're getting an "Invalid Email or Password" error when trying to log in as superadmin, this guide will help you diagnose and fix the issue.

## Quick Solutions

### Solution 1: Complete Superadmin Setup (Recommended)

Run this command to automatically fix all common issues:

```bash
# For production (Heroku)
heroku run EMAIL=your-email@example.com PASSWORD=YourPassword123! rake users:setup_superadmin --app your-app-name

# For local development
EMAIL=your-email@example.com PASSWORD=YourPassword123! rake users:setup_superadmin
```

This will:
- ✅ Create or update the superadmin user
- ✅ Confirm the email address
- ✅ Activate the user account
- ✅ Remove any suspension
- ✅ Verify login credentials
- ✅ Test authentication

### Solution 2: Step-by-Step Manual Fix

If you prefer to fix issues individually:

#### Step 1: Diagnose the Problem
```bash
# For production
heroku run rake users:diagnose_superadmin --app your-app-name

# For local development
rake users:diagnose_superadmin
```

#### Step 2: Confirm Email Address
```bash
# For production
heroku run rake users:confirm_superadmin --app your-app-name

# For local development
rake users:confirm_superadmin
```

#### Step 3: Activate User Account
```bash
# For production
heroku run rake users:activate_superadmin --app your-app-name

# For local development
rake users:activate_superadmin
```

#### Step 4: Reset Password
```bash
# For production
heroku run EMAIL=your-email@example.com PASSWORD=YourPassword123! rake users:reset_superadmin_password --app your-app-name

# For local development
EMAIL=your-email@example.com PASSWORD=YourPassword123! rake users:reset_superadmin_password
```

### Solution 3: Create New Superadmin

If the user doesn't exist or is corrupted:

```bash
# For production
heroku run EMAIL=your-email@example.com PASSWORD=YourPassword123! rake users:create_superadmin --app your-app-name

# For local development
EMAIL=your-email@example.com PASSWORD=YourPassword123! rake users:create_superadmin
```

## Common Issues and Causes

### 1. Email Not Confirmed
**Cause:** The application uses Devise with email confirmation enabled. Superadmin users should be auto-confirmed, but this might fail.

**Symptoms:**
- User exists in database
- `confirmed_at` field is `null`
- `confirmation_token` is present

**Fix:** Run `rake users:confirm_superadmin`

### 2. User Account Inactive
**Cause:** The `active` field is set to `false` or the user is suspended.

**Symptoms:**
- User exists and is confirmed
- `active` field is `false`
- `suspended_at` field has a date

**Fix:** Run `rake users:activate_superadmin`

### 3. Password Issues
**Cause:** Password was not set correctly or encryption failed.

**Symptoms:**
- User exists and is confirmed
- `encrypted_password` field is empty or invalid
- `valid_password?` returns false

**Fix:** Run `rake users:reset_superadmin_password`

### 4. User Doesn't Exist
**Cause:** Superadmin user was never created or was deleted.

**Symptoms:**
- No user found with superadmin role
- Database query returns empty result

**Fix:** Run `rake users:create_superadmin`

## Manual Database Fixes

If the Rake tasks don't work, you can fix issues directly in the Rails console:

### Access Rails Console
```bash
# For production
heroku run rails console --app your-app-name

# For local development
rails console
```

### Fix Email Confirmation
```ruby
# Find the user
user = User.find_by(email: 'your-email@example.com')

# Confirm the email
user.confirmed_at = Time.current
user.confirmation_token = nil
user.save(validate: false)

puts "User confirmed: #{user.confirmed?}"
```

### Activate User Account
```ruby
# Find the user
user = User.find_by(email: 'your-email@example.com')

# Activate the user
user.active = true
user.save!

# Remove suspension if any
if user.suspended?
  user.reactivate!
end

puts "User active: #{user.active?}"
puts "User suspended: #{user.suspended?}"
```

### Reset Password
```ruby
# Find the user
user = User.find_by(email: 'your-email@example.com')

# Set new password
user.password = 'YourNewPassword123!'
user.password_confirmation = 'YourNewPassword123!'
user.save!

# Test the password
puts "Password valid: #{user.valid_password?('YourNewPassword123!')}"
```

### Create New Superadmin
```ruby
# Create new superadmin user
user = User.create!(
  email: 'your-email@example.com',
  password: 'YourPassword123!',
  password_confirmation: 'YourPassword123!',
  first_name: 'Super',
  last_name: 'Admin',
  role: 'superadmin',
  subscription_tier: 'premium',
  active: true,
  confirmed_at: Time.current
)

puts "Superadmin created: #{user.email}"
puts "Role: #{user.role}"
puts "Active: #{user.active?}"
puts "Confirmed: #{user.confirmed?}"
```

## Verification Steps

After applying any fix, verify the login works:

### 1. Check User Status
```ruby
user = User.find_by(email: 'your-email@example.com')

puts "Email: #{user.email}"
puts "Role: #{user.role}"
puts "Active: #{user.active?}"
puts "Confirmed: #{user.confirmed?}"
puts "Suspended: #{user.suspended?}"
puts "Subscription: #{user.subscription_tier}"
```

### 2. Test Password
```ruby
user = User.find_by(email: 'your-email@example.com')
password = 'YourPassword123!'

puts "Password valid: #{user.valid_password?(password)}"
```

### 3. Test Devise Authentication
```ruby
email = 'your-email@example.com'
password = 'YourPassword123!'

authenticated_user = User.find_for_database_authentication(email: email)
if authenticated_user && authenticated_user.valid_password?(password)
  puts "✅ Devise authentication successful"
else
  puts "❌ Devise authentication failed"
end
```

## Prevention

To prevent future login issues:

1. **Always use the setup task** when creating superadmin users:
   ```bash
   EMAIL=admin@example.com PASSWORD=SecurePassword123! rake users:setup_superadmin
   ```

2. **Monitor user creation** in production logs to catch issues early.

3. **Test login immediately** after creating superadmin users.

4. **Document credentials securely** and test them regularly.

## Support

If these solutions don't work:

1. **Check application logs** for detailed error messages:
   ```bash
   heroku logs --tail --app your-app-name
   ```

2. **Run the diagnostic script** for detailed analysis:
   ```bash
   heroku run rake users:diagnose_superadmin --app your-app-name
   ```

3. **Contact support** with the diagnostic output and error logs.

---

**Last Updated:** January 2025  
**Tested On:** Rails 7.1+, Devise 4.9+  
**Environment:** Production (Heroku) and Development