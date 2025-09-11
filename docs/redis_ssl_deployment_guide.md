# Redis SSL Configuration Deployment Guide

This guide provides step-by-step instructions for deploying and verifying the Redis SSL configuration in production on Heroku.

## Pre-Deployment Checklist

Before deploying the Redis SSL configuration, ensure the following components are in place:

### 1. Configuration Files
- [ ] `config/initializers/00_redis_config.rb` - Centralized Redis configuration
- [ ] `config/initializers/redis.rb` - Rails cache configuration
- [ ] `config/initializers/sidekiq.rb` - Sidekiq configuration with SSL support
- [ ] `config/cable.yml` - ActionCable configuration with SSL parameters
- [ ] `app/services/redis_error_logger.rb` - Enhanced error logging
- [ ] `app/services/admin_notification_service.rb` - Graceful Redis failure handling

### 2. Environment Variables
Ensure these environment variables are set in production:

```bash
# Required
REDIS_URL=rediss://...  # Heroku Redis URL with SSL (rediss://)

# Optional (with defaults)
REDIS_NETWORK_TIMEOUT=5
REDIS_POOL_TIMEOUT=5
REDIS_CACHE_TTL=3600
SIDEKIQ_CONCURRENCY=10
```

### 3. Dependencies
- [ ] Redis gem with SSL support
- [ ] Sidekiq configured for Redis SSL
- [ ] ActionCable configured for Redis SSL

## Deployment Steps

### Step 1: Deploy to Heroku

```bash
# Commit all changes
git add .
git commit -m "Implement Redis SSL configuration for production"

# Deploy to production
git push heroku main

# Verify deployment
heroku logs --tail --app your-app-name
```

### Step 2: Verify Heroku Redis Add-on

```bash
# Check Redis add-on status
heroku addons --app your-app-name

# Get Redis connection info
heroku config:get REDIS_URL --app your-app-name

# Verify Redis SSL URL format (should start with rediss://)
# Example: rediss://h:password@hostname:port
```

### Step 3: Run Verification Script

```bash
# Run the comprehensive verification script
heroku run ruby script/verify_redis_ssl_production.rb --app your-app-name
```

### Step 4: Test Individual Components

#### Test ActionCable
```bash
# Check ActionCable connection
heroku run rails console --app your-app-name
# In console:
ActionCable.server.pubsub.redis_connection_for_subscriptions.ping
```

#### Test Sidekiq
```bash
# Check Sidekiq connection
heroku run rails console --app your-app-name
# In console:
Sidekiq.redis(&:ping)
```

#### Test Rails Cache
```bash
# Check cache connection
heroku run rails console --app your-app-name
# In console:
Rails.cache.write('test', 'value')
Rails.cache.read('test')
```

### Step 5: Test Superadmin Creation

```bash
# Run superadmin creation task
heroku run rake create_superadmin --app your-app-name

# Check logs for any Redis-related errors
heroku logs --tail --app your-app-name | grep -i redis
```

## Verification Checklist

After deployment, verify the following:

### ✅ Redis Connection Tests
- [ ] Basic Redis connection works
- [ ] SSL parameters are correctly applied
- [ ] Connection timeouts are configured
- [ ] Redis info command returns version information

### ✅ ActionCable Tests
- [ ] ActionCable can connect to Redis
- [ ] Broadcasting works without errors
- [ ] SSL connection is established
- [ ] Channel prefix is correctly set

### ✅ Sidekiq Tests
- [ ] Sidekiq can connect to Redis
- [ ] Jobs can be enqueued successfully
- [ ] Job processing works
- [ ] Error handling for Redis failures works
- [ ] Sidekiq stats are accessible

### ✅ Rails Cache Tests
- [ ] Cache write operations work
- [ ] Cache read operations work
- [ ] Cache delete operations work
- [ ] Error handler for cache failures works
- [ ] Cache namespace is correctly set

### ✅ Error Handling Tests
- [ ] RedisErrorLogger captures Redis errors
- [ ] AdminNotificationService handles Redis failures gracefully
- [ ] Superadmin creation works even if Redis notifications fail
- [ ] Application remains stable during Redis connectivity issues

### ✅ Monitoring Tests
- [ ] Redis connection monitoring is active
- [ ] Error tracking (Sentry) receives Redis errors
- [ ] Logs contain appropriate Redis connection information
- [ ] Health checks include Redis status

## Troubleshooting

### Common Issues and Solutions

#### 1. SSL Certificate Verification Errors
```
Error: certificate verify failed (self-signed certificate in certificate chain)
```

**Solution:** Ensure `verify_mode: OpenSSL::SSL::VERIFY_NONE` is set in SSL parameters.

#### 2. Connection Timeout Errors
```
Error: Redis::TimeoutError
```

**Solution:** Adjust `REDIS_NETWORK_TIMEOUT` and `REDIS_POOL_TIMEOUT` environment variables.

#### 3. ActionCable Connection Issues
```
Error: ActionCable cannot connect to Redis
```

**Solution:** Verify `config/cable.yml` has correct SSL configuration for production.

#### 4. Sidekiq Job Failures
```
Error: Sidekiq jobs failing with Redis connection errors
```

**Solution:** Check Sidekiq configuration and ensure retry logic is in place.

### Diagnostic Commands

```bash
# Check Redis connection from Rails console
heroku run rails console --app your-app-name
Redis.new(RedisConfig.connection_config).ping

# Check environment variables
heroku config --app your-app-name | grep REDIS

# Check application logs for Redis errors
heroku logs --app your-app-name | grep -i "redis\|ssl"

# Run Redis diagnostics
heroku run rake redis:diagnostics --app your-app-name
```

### Rollback Plan

If issues occur after deployment:

1. **Immediate Rollback:**
   ```bash
   heroku rollback --app your-app-name
   ```

2. **Partial Rollback (if needed):**
   - Revert specific configuration files
   - Deploy with previous Redis configuration
   - Monitor application stability

3. **Emergency Measures:**
   - Disable Redis-dependent features temporarily
   - Use fallback mechanisms (memory cache, skip notifications)
   - Scale down Sidekiq workers if needed

## Post-Deployment Monitoring

### Key Metrics to Monitor

1. **Redis Connection Health**
   - Connection success rate
   - Connection latency
   - SSL handshake time

2. **Application Performance**
   - ActionCable message delivery
   - Sidekiq job processing rate
   - Cache hit/miss ratios

3. **Error Rates**
   - Redis connection errors
   - SSL certificate errors
   - Job failure rates

### Monitoring Setup

```bash
# Set up log monitoring for Redis errors
heroku logs --tail --app your-app-name | grep "Redis\|SSL" > redis_monitoring.log

# Monitor Sidekiq performance
# Access Sidekiq Web UI at: https://your-app.herokuapp.com/sidekiq
```

## Success Criteria

The deployment is considered successful when:

- [ ] All verification script tests pass
- [ ] No Redis connection errors in logs
- [ ] ActionCable real-time features work
- [ ] Background jobs process successfully
- [ ] Cache operations complete without errors
- [ ] Superadmin creation works without Redis errors
- [ ] Error handling gracefully manages Redis failures
- [ ] Application performance remains stable

## Support and Escalation

If issues persist after following this guide:

1. Check Heroku Redis add-on status
2. Contact Heroku support for Redis-specific issues
3. Review application logs for detailed error information
4. Consider temporary fallback to non-Redis solutions if critical

---

**Last Updated:** January 2025
**Version:** 1.0
**Environment:** Production (Heroku)