# Post-Deployment Configuration Guide

This guide covers the configuration steps needed after deploying the application to production.

## 🔧 Required Configurations

### 1. Heroku Scheduler Setup

The application requires scheduled jobs to run properly. Set up the Heroku Scheduler:

```bash
# Install Heroku Scheduler add-on
heroku addons:create scheduler:standard --app your-app-name

# Open scheduler dashboard
heroku addons:open scheduler --app your-app-name
```

**Required Scheduled Job:**
- **Job Name:** Trial Expiration Check
- **Command:** `bundle exec rails runner 'TrialExpirationJob.perform_now'`
- **Frequency:** Daily
- **Time:** 09:00 UTC

### 2. Environment Variables

Set these optional environment variables for better configuration:

```bash
# Application domain (for emails and links)
heroku config:set APP_DOMAIN=your-domain.com --app your-app-name

# Trial configuration (optional - defaults to 14 days)
heroku config:set TRIAL_DAYS=14 --app your-app-name

# Redis timeouts (optional - defaults shown)
heroku config:set REDIS_NETWORK_TIMEOUT=5 --app your-app-name
heroku config:set REDIS_POOL_TIMEOUT=5 --app your-app-name

# Sidekiq concurrency (optional - defaults to 10)
heroku config:set SIDEKIQ_CONCURRENCY=10 --app your-app-name
```

### 3. Third-Party Integrations

Configure Google Sheets and Stripe integrations:

#### Quick Setup (Recommended)
```bash
# Set up both Google Sheets and Stripe
./script/setup_all_integrations.sh your-app-name

# Or set up individually
./script/setup_google_sheets.sh your-app-name
./script/setup_stripe.sh your-app-name
```

#### Manual Setup
See detailed instructions in: `docs/third_party_integrations_setup.md`

**Google Sheets Integration:**
- Requires Google Cloud Console setup
- Service Account with JSON credentials
- Rails encrypted credentials configuration

**Stripe Integration:**
- Requires Stripe account and API keys
- Environment variables for keys
- Optional webhook configuration

## 🧪 Verification Steps

### 1. Test Redis SSL Configuration

```bash
heroku run rake redis:verify_production --app your-app-name
```

### 2. Test Superadmin Access

1. Go to your application URL
2. Log in with the superadmin credentials you created
3. Verify you can access admin features

### 3. Test Background Jobs

```bash
# Test Sidekiq is working
heroku run rails console --app your-app-name
# In console: TestJob.perform_async("test message")
```

### 4. Test Trial Expiration Job

```bash
heroku run rails runner 'TrialExpirationJob.perform_now' --app your-app-name
```

## 📊 Monitoring Setup

### 1. Application Logs

Monitor your application logs regularly:

```bash
# Real-time logs
heroku logs --tail --app your-app-name

# Filter for errors
heroku logs --tail --app your-app-name | grep ERROR

# Filter for Redis issues
heroku logs --tail --app your-app-name | grep -i redis
```

### 2. Redis Health Monitoring

Set up periodic Redis health checks:

```bash
# Manual health check
heroku run rake redis:diagnostics --app your-app-name

# Add to scheduler (optional)
# Command: bundle exec rake redis:diagnostics
# Frequency: Daily
```

### 3. Performance Monitoring

Consider adding these monitoring tools:

- **New Relic** or **Datadog** for APM
- **Sentry** for error tracking
- **Heroku Metrics** for basic monitoring

## 🚨 Troubleshooting

### Common Issues After Deployment

#### 1. Redis Connection Errors
```bash
# Check Redis add-on status
heroku addons --app your-app-name | grep redis

# Test Redis connectivity
heroku run rake redis:ssl_test --app your-app-name
```

#### 2. Background Jobs Not Processing
```bash
# Check Sidekiq status
heroku ps --app your-app-name

# Scale Sidekiq workers if needed
heroku ps:scale worker=1 --app your-app-name
```

#### 3. Email Delivery Issues
```bash
# Check email configuration
heroku config --app your-app-name | grep -i mail

# Test email sending
heroku run rails console --app your-app-name
# In console: UserMailer.welcome_email(User.first).deliver_now
```

#### 4. SSL Certificate Issues
```bash
# Check SSL configuration
heroku certs --app your-app-name

# Verify domain configuration
heroku domains --app your-app-name
```

## 📋 Post-Deployment Checklist

- [ ] Heroku Scheduler configured with trial expiration job
- [ ] Superadmin user created and tested
- [ ] Redis SSL configuration verified
- [ ] Background jobs processing correctly
- [ ] Email delivery working (if configured)
- [ ] Google Sheets integration configured (if needed)
- [ ] Environment variables set appropriately
- [ ] Monitoring and logging configured
- [ ] SSL certificates valid and working
- [ ] Domain configuration correct

## 🔄 Regular Maintenance

### Daily
- [ ] Check application logs for errors
- [ ] Verify scheduled jobs ran successfully
- [ ] Monitor Redis connection health

### Weekly
- [ ] Review application performance metrics
- [ ] Check for any failed background jobs
- [ ] Verify email delivery statistics

### Monthly
- [ ] Review and rotate credentials if needed
- [ ] Update dependencies and security patches
- [ ] Analyze usage patterns and optimize resources

---

**Last Updated:** January 2025  
**Environment:** Production (Heroku)  
**Version:** 1.0