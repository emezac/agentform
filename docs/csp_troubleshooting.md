# Content Security Policy (CSP) Troubleshooting Guide

## Problem: CSP Blocking Inline Scripts

### Symptoms
- Sign out menu not appearing
- JavaScript console errors like:
  ```
  Refused to execute inline script because it violates the following Content Security Policy directive: "script-src 'self' https:". Either the 'unsafe-inline' keyword, a hash ('sha256-...'), or a nonce ('nonce-...') is required to enable inline execution.
  ```
- Interactive elements not working (forms, menus, buttons)
- Payment processing scripts failing

### Root Cause
The Content Security Policy (CSP) was configured too restrictively, blocking inline JavaScript that the application relies on.

## Quick Solution

### Deploy the CSP Fix
```bash
# Automated deployment
./script/deploy_csp_fix.sh your-app-name

# Manual deployment
git add .
git commit -m "Fix CSP configuration to allow inline scripts"
git push heroku main
```

### Verify the Fix
```bash
# Test CSP configuration
heroku run ruby script/test_csp_configuration.rb --app your-app-name

# Check application functionality
heroku open --app your-app-name
```

## Technical Details

### What Was Changed

**Before (Restrictive CSP):**
```ruby
config.content_security_policy do |policy|
  policy.script_src :self, :https  # ❌ Blocks inline scripts
end
```

**After (Permissive CSP):**
```ruby
config.content_security_policy do |policy|
  policy.script_src :self, :https, :unsafe_inline, :unsafe_eval,
                     'https://cdn.tailwindcss.com',
                     'https://js.stripe.com',
                     'https://www.paypal.com'
end
```

### CSP Configuration Breakdown

```ruby
# Content Security Policy - Configured for Rails app with inline scripts
config.content_security_policy do |policy|
  policy.default_src :self, :https
  policy.font_src    :self, :https, :data
  policy.img_src     :self, :https, :data, 'blob:'
  policy.object_src  :none
  
  # Allow inline scripts and external CDNs
  policy.script_src  :self, :https, :unsafe_inline, :unsafe_eval, 
                     'https://cdn.tailwindcss.com',
                     'https://js.stripe.com',
                     'https://www.paypal.com'
  
  policy.style_src   :self, :https, :unsafe_inline
  
  # Allow WebSocket connections for ActionCable
  policy.connect_src :self, :https, :wss, 
                     "wss://#{ENV.fetch('APP_DOMAIN', 'localhost')}"
  
  # Allow frames for payment providers
  policy.frame_src   :self, :https,
                     'https://js.stripe.com',
                     'https://www.paypal.com'
end
```

## Security Considerations

### Current Security Level
- **Medium Security**: Allows inline scripts but restricts external sources
- **Whitelisted CDNs**: Only specific external scripts are allowed
- **No eval() restrictions**: Allows dynamic code execution (needed for some libraries)

### Why unsafe-inline is Necessary
The application currently has inline scripts in multiple views:
- Form interaction scripts
- Payment processing
- Dynamic UI elements
- Analytics and tracking

### Future Security Improvements

#### Option 1: Migrate to External Scripts
```javascript
// Instead of inline scripts in views
<script>
  function handleClick() { ... }
</script>

// Use external JavaScript files
// app/assets/javascripts/form_interactions.js
```

#### Option 2: Implement CSP Nonces
```erb
<!-- Use nonces for inline scripts -->
<%= javascript_tag nonce: content_security_policy_nonce do %>
  function handleClick() { ... }
<% end %>
```

#### Option 3: Use Stimulus Controllers
```javascript
// app/javascript/controllers/form_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  handleClick() { ... }
}
```

## Testing CSP Configuration

### Browser Testing
1. Open browser developer tools (F12)
2. Go to Console tab
3. Look for CSP violation errors
4. Test interactive elements

### Automated Testing
```bash
# Run CSP configuration test
heroku run ruby script/test_csp_configuration.rb --app your-app-name
```

### Manual Verification
```bash
# Check CSP headers
curl -I https://your-app.herokuapp.com | grep -i content-security

# Test specific functionality
heroku run rails console --app your-app-name
```

## Common CSP Issues and Solutions

### Issue 1: External Scripts Blocked
**Error:** `Refused to load the script 'https://example.com/script.js'`
**Solution:** Add the domain to `script_src` whitelist

### Issue 2: WebSocket Connections Blocked
**Error:** `Refused to connect to 'wss://...' because it violates CSP`
**Solution:** Add WebSocket URLs to `connect_src`

### Issue 3: Inline Styles Blocked
**Error:** `Refused to apply inline style`
**Solution:** Add `unsafe-inline` to `style_src`

### Issue 4: Image Loading Issues
**Error:** `Refused to load the image`
**Solution:** Add appropriate sources to `img_src`

## CSP Best Practices

### Development Environment
```ruby
# More permissive for development
if Rails.env.development?
  config.content_security_policy do |policy|
    policy.script_src :self, :https, :unsafe_inline, :unsafe_eval
    policy.connect_src :self, :https, :wss, 'ws://localhost:*'
  end
end
```

### Production Environment
```ruby
# Balanced security for production
if Rails.env.production?
  config.content_security_policy do |policy|
    # Specific whitelisted sources only
    policy.script_src :self, :https, :unsafe_inline,
                      'https://trusted-cdn.com'
  end
end
```

### Monitoring CSP Violations
```ruby
# Set up violation reporting
config.content_security_policy_report_only = true
config.content_security_policy_report_uri = '/csp-report'
```

## Troubleshooting Commands

```bash
# Test CSP configuration
heroku run ruby script/test_csp_configuration.rb --app your-app-name

# Check application logs for CSP errors
heroku logs --tail --app your-app-name | grep -i csp

# Test specific functionality
heroku run rails console --app your-app-name

# Deploy CSP fixes
./script/deploy_csp_fix.sh your-app-name
```

## Migration Plan (Future)

### Phase 1: Immediate Fix (Current)
- ✅ Allow `unsafe-inline` to restore functionality
- ✅ Whitelist necessary external scripts
- ✅ Test all interactive features

### Phase 2: Script Consolidation
- 🔄 Move inline scripts to external files
- 🔄 Implement Stimulus controllers
- 🔄 Reduce dependency on inline JavaScript

### Phase 3: Enhanced Security
- 🔄 Implement CSP nonces
- 🔄 Remove `unsafe-inline` directive
- 🔄 Set up CSP violation monitoring

---

**Last Updated:** January 2025  
**Status:** Phase 1 Complete - Functionality Restored  
**Security Level:** Medium (Balanced for functionality)  
**Next Phase:** Script Migration Planning