# Third-Party Integrations Setup Guide

This guide covers the setup of Google Sheets and Stripe integrations for production deployment.

## 📊 Google Sheets Integration

### Prerequisites

1. **Google Cloud Console Account**
2. **Google Sheets API enabled**
3. **Service Account with JSON credentials**

### Quick Setup

```bash
# Run the automated setup script
./script/setup_google_sheets.sh your-app-name
```

### Manual Setup

#### Step 1: Google Cloud Console Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable Google Sheets API:
   - Navigate to **APIs & Services > Library**
   - Search for "Google Sheets API"
   - Click **Enable**

#### Step 2: Create Service Account

1. Go to **APIs & Services > Credentials**
2. Click **Create Credentials > Service Account**
3. Fill in service account details:
   - **Name**: `mydialogform-sheets-service`
   - **Description**: `Service account for Google Sheets integration`
4. Click **Create and Continue**
5. Skip role assignment (click **Continue**)
6. Click **Done**

#### Step 3: Generate JSON Key

1. Click on the created service account
2. Go to **Keys** tab
3. Click **Add Key > Create new key**
4. Select **JSON** format
5. Click **Create** and download the JSON file

#### Step 4: Configure Rails Credentials

```bash
# Edit Rails credentials
EDITOR=nano heroku run rails credentials:edit --app your-app-name
```

Add the following structure (replace with your JSON values):

```yaml
google_sheets:
  type: service_account
  project_id: your-project-id
  private_key_id: your-private-key-id
  private_key: |
    -----BEGIN PRIVATE KEY-----
    your-private-key-content
    -----END PRIVATE KEY-----
  client_email: your-service-account@your-project.iam.gserviceaccount.com
  client_id: your-client-id
  auth_uri: https://accounts.google.com/o/oauth2/auth
  token_uri: https://oauth2.googleapis.com/token
  auth_provider_x509_cert_url: https://www.googleapis.com/oauth2/v1/certs
  client_x509_cert_url: https://www.googleapis.com/robot/v1/metadata/x509/your-service-account%40your-project.iam.gserviceaccount.com
```

#### Step 5: Share Google Sheets

Share your Google Sheets with the service account email (found in `client_email` field).

#### Step 6: Test Integration

```bash
heroku run rails console --app your-app-name
```

```ruby
# Test credentials loading
creds = Rails.application.credentials.google_sheets
puts creds.present? ? '✅ Credentials loaded' : '❌ Credentials missing'

# Test connection (replace with your sheet ID)
# service = GoogleSheetsService.new
# service.test_connection('your-google-sheet-id')
```

## 💳 Stripe Integration

### Prerequisites

1. **Stripe Account**
2. **API Keys (Publishable and Secret)**
3. **Webhook endpoint configured (optional)**

### Quick Setup

```bash
# Run the automated setup script
./script/setup_stripe.sh your-app-name
```

### Manual Setup

#### Step 1: Get Stripe API Keys

1. Go to [Stripe Dashboard](https://dashboard.stripe.com/)
2. Navigate to **Developers > API keys**
3. Copy your keys:
   - **Publishable key** (starts with `pk_`)
   - **Secret key** (starts with `sk_`)

#### Step 2: Set Environment Variables

```bash
# Set Stripe keys
heroku config:set STRIPE_PUBLISHABLE_KEY="pk_test_..." --app your-app-name
heroku config:set STRIPE_SECRET_KEY="sk_test_..." --app your-app-name

# Set environment (test or live)
heroku config:set STRIPE_ENV="test" --app your-app-name
```

#### Step 3: Configure Webhooks (Optional)

1. In Stripe Dashboard, go to **Developers > Webhooks**
2. Click **Add endpoint**
3. Set endpoint URL: `https://your-app-name.herokuapp.com/webhooks/stripe`
4. Select events to listen for
5. Copy the webhook signing secret
6. Set the webhook secret:

```bash
heroku config:set STRIPE_WEBHOOK_SECRET="whsec_..." --app your-app-name
```

#### Step 4: Test Integration

```bash
heroku run rails console --app your-app-name
```

```ruby
# Test Stripe configuration
require 'stripe'
Stripe.api_key = ENV['STRIPE_SECRET_KEY']

# Test connection
account = Stripe::Account.retrieve
puts "✅ Connected to Stripe account: #{account.email}"

# Test creating a customer (test mode)
customer = Stripe::Customer.create(
  email: 'test@example.com',
  name: 'Test Customer'
)
puts "✅ Test customer created: #{customer.id}"
```

## 🔧 Configuration Verification

### Check All Environment Variables

```bash
# Check Google Sheets credentials
heroku run rails console --app your-app-name -c "puts Rails.application.credentials.google_sheets.present?"

# Check Stripe configuration
heroku config --app your-app-name | grep STRIPE
```

### Test Both Integrations

```bash
# Create a comprehensive test script
heroku run rails console --app your-app-name
```

```ruby
# Test Google Sheets
puts "Testing Google Sheets..."
if Rails.application.credentials.google_sheets.present?
  puts "✅ Google Sheets credentials loaded"
else
  puts "❌ Google Sheets credentials missing"
end

# Test Stripe
puts "\nTesting Stripe..."
if ENV['STRIPE_PUBLISHABLE_KEY'].present? && ENV['STRIPE_SECRET_KEY'].present?
  puts "✅ Stripe keys configured"
  
  require 'stripe'
  Stripe.api_key = ENV['STRIPE_SECRET_KEY']
  
  begin
    account = Stripe::Account.retrieve
    puts "✅ Stripe connection successful"
  rescue => e
    puts "❌ Stripe connection failed: #{e.message}"
  end
else
  puts "❌ Stripe keys missing"
end
```

## 🚨 Security Best Practices

### Google Sheets Security

- ✅ Never commit service account JSON files to repository
- ✅ Use Rails encrypted credentials for storing keys
- ✅ Limit service account permissions to minimum required
- ✅ Regularly rotate service account keys
- ✅ Monitor Google Cloud Console for unusual activity

### Stripe Security

- ✅ Never commit API keys to repository
- ✅ Use test keys during development
- ✅ Implement webhook signature verification
- ✅ Use HTTPS for all Stripe endpoints
- ✅ Monitor Stripe dashboard for suspicious activity
- ✅ Set up fraud detection rules
- ✅ Regularly rotate API keys

## 🔍 Troubleshooting

### Google Sheets Issues

**Problem**: "No credentials found" error
**Solution**: Verify Rails credentials are properly set and deployed

**Problem**: "Permission denied" error
**Solution**: Ensure Google Sheet is shared with service account email

**Problem**: "API not enabled" error
**Solution**: Enable Google Sheets API in Google Cloud Console

### Stripe Issues

**Problem**: "Invalid API key" error
**Solution**: Verify API keys are correctly set and match your Stripe account

**Problem**: "Webhook signature verification failed"
**Solution**: Ensure webhook secret is correctly configured

**Problem**: "SSL certificate verification failed"
**Solution**: Ensure your app is accessible via HTTPS

## 📋 Environment Variables Summary

### Required for Google Sheets
- Rails credentials with `google_sheets` configuration

### Required for Stripe
- `STRIPE_PUBLISHABLE_KEY` - Your Stripe publishable key
- `STRIPE_SECRET_KEY` - Your Stripe secret key
- `STRIPE_ENV` - "test" or "live"

### Optional for Stripe
- `STRIPE_WEBHOOK_SECRET` - Webhook signing secret
- `STRIPE_CONNECT_CLIENT_ID` - For Stripe Connect (marketplace)
- `STRIPE_CURRENCY` - Default currency (default: "usd")

## 🎯 Next Steps

After completing both integrations:

1. **Test thoroughly** in your application
2. **Set up monitoring** for both services
3. **Configure error tracking** for integration failures
4. **Document** your specific use cases and workflows
5. **Train your team** on managing these integrations

---

**Last Updated:** January 2025  
**Environment:** Production (Heroku)  
**Integrations:** Google Sheets API, Stripe API