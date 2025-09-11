# Redis SSL Connection Troubleshooting

## Problem: SSL Certificate Verification Failed

If you're seeing errors like:
```
SSL_connect returned=1 errno=0 peeraddr=X.X.X.X:30420 state=error: certificate verify failed (self-signed certificate in certificate chain)
```

This means Redis SSL is not configured correctly for Heroku's self-signed certificates.

## Quick Solutions

### Solution 1: Verify Current Configuration

First, check if the SSL configuration is working:

```bash
# Test SSL configuration directly
heroku run rake redis:test_ssl_direct --app your-app-name

# Run comprehensive diagnostics
heroku run rake redis:diagnostics --app your-app-name
```

### Solution 2: Deploy the Fixed Configuration

The issue is likely that the production cache configuration is not using `RedisConfig`. Deploy these fixes:

```bash
# Commit and deploy the fixes
git add .
git commit -m "Fix Redis SSL configuration for production cache"
git push heroku main
```

### Solution 3: Manual Verification

Test the connection manually in Rails console:

```bash
heroku run rails console --app your-app-name
```

In the console:
```ruby
# Test RedisConfig
config = RedisConfig.connection_config
puts "Config: #{config.inspect}"

# Test connection
redis = Redis.new(config)
redis.ping
# Should return "PONG"

# Test cache
Rails.cache.write("test", "value")
Rails.cache.read("test")
# Should return "value"
```

## Root Cause Analysis

### The Problem
Heroku Redis uses self-signed SSL certificates. By default, Redis clients verify SSL certificates, which fails with self-signed certificates.

### The Solution
We need to configure Redis to use `OpenSSL::SSL::VERIFY_NONE` for SSL connections, which our `RedisConfig` class handles automatically.

### What Was Wrong
1. **Production cache config**: `config/environments/production.rb` was using a direct Redis URL instead of `RedisConfig`
2. **Verification script**: Was not using `RedisConfig` for basic connection tests

## Configuration Details

### Correct SSL Configuration
```ruby
# config/initializers/00_redis_config.rb
def ssl_params
  {
    verify_mode: OpenSSL::SSL::VERIFY_NONE
  }
end
```

### Correct Cache Configuration
```ruby
# config/initializers/redis.rb
Rails.application.configure do
  unless Rails.env.test?
    config.cache_store = :redis_cache_store, RedisConfig.cache_config
  end
end
```

### Correct Production Environment
```ruby
# config/environments/production.rb
# Use Redis for caching in production - configuration handled by RedisConfig
# This will be overridden by config/initializers/redis.rb
```

## Verification Steps

### 1. Check SSL Parameters
```bash
heroku run rails console --app your-app-name
```

```ruby
config = RedisConfig.connection_config
puts "SSL Required: #{RedisConfig.send(:ssl_required?)}"
puts "SSL Params: #{config[:ssl_params]}"
# Should show: SSL Params: {:verify_mode=>0}
```

### 2. Test Each Component

```bash
# Test basic Redis connection
heroku run rake redis:test_ssl_direct --app your-app-name

# Test all components
heroku run rake redis:verify_production --app your-app-name
```

### 3. Monitor Application Logs

```bash
# Check for Redis errors
heroku logs --tail --app your-app-name | grep -i redis

# Check for SSL errors
heroku logs --tail --app your-app-name | grep -i ssl
```

## Common Issues and Solutions

### Issue 1: Cache Still Using Wrong Configuration
**Symptoms:** Cache operations fail with SSL errors
**Solution:** Restart the application after deploying the fix
```bash
heroku restart --app your-app-name
```

### Issue 2: Sidekiq SSL Errors
**Symptoms:** Background jobs fail with Redis SSL errors
**Solution:** Verify Sidekiq is using RedisConfig
```bash
heroku run rails console --app your-app-name
```
```ruby
Sidekiq.redis { |conn| conn.ping }
# Should return "PONG"
```

### Issue 3: ActionCable SSL Errors
**Symptoms:** Real-time features don't work
**Solution:** Check ActionCable configuration
```bash
heroku run rails console --app your-app-name
```
```ruby
ActionCable.server.broadcast("test", { message: "test" })
# Should not raise SSL errors
```

## Prevention

### 1. Always Use RedisConfig
Never configure Redis connections directly. Always use:
```ruby
Redis.new(RedisConfig.connection_config)
```

### 2. Test After Changes
Always run verification after Redis configuration changes:
```bash
heroku run rake redis:verify_production --app your-app-name
```

### 3. Monitor SSL Errors
Set up alerts for SSL-related errors in your logs.

## Advanced Debugging

### Enable Debug Logging
```bash
heroku config:set DEBUG=true --app your-app-name
heroku run rake redis:test_ssl_direct --app your-app-name
```

### Check Redis Add-on Status
```bash
heroku addons --app your-app-name | grep redis
heroku addons:info your-redis-addon-name --app your-app-name
```

### Verify SSL URL Format
```bash
heroku config:get REDIS_URL --app your-app-name
# Should start with "rediss://" (note the double 's')
```

## Support Commands

```bash
# Quick SSL test
heroku run rake redis:test_ssl_direct --app your-app-name

# Full verification
heroku run rake redis:verify_production --app your-app-name

# Basic diagnostics
heroku run rake redis:diagnostics --app your-app-name

# Monitor connections
heroku run rake redis:monitor --app your-app-name
```

---

**Last Updated:** January 2025  
**Tested With:** Heroku Redis, Rails 7.1+  
**SSL Configuration:** OpenSSL::SSL::VERIFY_NONE