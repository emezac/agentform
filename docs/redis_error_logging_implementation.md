# Redis Error Logging Implementation

## Overview

This document describes the comprehensive Redis error logging system implemented for the mydialogform application. The system provides enhanced error logging, monitoring, and diagnostics for all Redis operations across the application.

## Components Implemented

### 1. RedisErrorLogger Service (`app/services/redis_error_logger.rb`)

A centralized service that provides comprehensive Redis error logging with the following features:

- **Error Categorization**: Automatically categorizes Redis errors by type (connection, command, protocol, client)
- **Context-Aware Logging**: Includes detailed context information for each error
- **Masked URL Logging**: Safely logs Redis URLs with sensitive information masked
- **SSL Configuration Detection**: Automatically detects and logs SSL configuration details
- **Sentry Integration**: Sends errors to Sentry when available
- **Metrics Tracking**: Tracks error counts by category and date
- **Connection Diagnostics**: Provides comprehensive Redis connection diagnostics

#### Key Methods:

- `log_redis_error(exception, context, severity)` - Main error logging method
- `log_connection_error(exception, context)` - Specialized connection error logging
- `log_command_error(exception, context)` - Command error logging with appropriate severity
- `log_redis_warning(message, context)` - Warning message logging
- `log_redis_info(message, context)` - Informational message logging
- `test_and_log_connection(component)` - Test Redis connectivity with logging
- `get_connection_diagnostics()` - Retrieve comprehensive connection diagnostics

### 2. Enhanced Redis Configuration (`config/initializers/00_redis_config.rb`)

Updated the existing RedisConfig class to use the centralized error logging:

- Integrated with RedisErrorLogger for consistent error handling
- Maintains existing SSL configuration functionality
- Provides centralized error handling for all Redis components

### 3. Updated Service Integrations

#### AdminNotificationService (`app/services/admin_notification_service.rb`)
- Enhanced Redis error handling for notification creation and broadcasting
- Graceful degradation when Redis is unavailable
- Comprehensive error logging with context

#### GoogleSheets::RateLimiter (`app/services/google_sheets/rate_limiter.rb`)
- Added Redis connection error handling
- Allows operations to continue when Redis is unavailable
- Logs rate limiting failures with context

#### AI::CachingService (`app/services/ai/caching_service.rb`)
- Enhanced error handling for cache read/write operations
- Graceful fallback when Redis is unavailable
- Comprehensive error logging for cache operations

#### HealthController (`app/controllers/health_controller.rb`)
- Integrated with RedisErrorLogger for health checks
- Provides detailed Redis diagnostics in health responses
- Enhanced error reporting for monitoring systems

### 4. Configuration and Monitoring

#### Redis Error Logger Configuration (`config/initializers/redis_error_logger.rb`)
- Configures logging behavior for different environments
- Sets up periodic Redis connection monitoring in production
- Integrates with Rails cache error handling

#### Rake Tasks (`lib/tasks/redis_diagnostics.rake`)
- `redis:diagnostics` - Comprehensive Redis connection and operation testing
- `redis:clear_error_stats` - Clear Redis error statistics
- `redis:test_ssl` - Test SSL configuration specifically

### 5. Testing

#### Unit Tests (`spec/services/redis_error_logger_spec.rb`)
- Comprehensive test coverage for RedisErrorLogger functionality
- Tests error categorization, logging, and metrics tracking
- Validates Sentry integration and configuration handling

#### Integration Tests (`spec/integration/redis_comprehensive_error_logging_spec.rb`)
- Tests Redis error handling across all integrated components
- Validates graceful degradation behavior
- Tests SSL configuration logging and metrics tracking

## Features

### Error Categorization

The system automatically categorizes Redis errors into the following types:

- **Connection Errors**: `Redis::CannotConnectError`, `Redis::ConnectionError`, `Redis::TimeoutError`, `Redis::ReadOnlyError`
- **Command Errors**: `Redis::CommandError`, `Redis::WrongTypeError`, `Redis::OutOfMemoryError`
- **Protocol Errors**: `Redis::ProtocolError`, `Redis::ParserError`
- **Client Errors**: `Redis::ClientError`, `Redis::InheritedError`
- **Unknown**: Any other Redis-related errors

### Context Information

Each logged error includes comprehensive context:

- Error class and message
- Error category
- Component that generated the error
- Operation being performed
- Masked Redis URL
- SSL configuration status
- Environment information
- Timestamp
- Stack trace (in development)

### SSL Configuration Support

The system automatically detects and logs SSL configuration:

- Detects `rediss://` protocol usage
- Logs SSL status in error messages
- Includes SSL configuration in diagnostics
- Supports Heroku Redis SSL requirements

### Metrics Tracking

Error metrics are tracked and stored in Redis cache:

- Daily error counts by category
- Total error counts
- Warning counts
- Accessible via cache keys: `redis_errors:YYYY-MM-DD:category`

### Graceful Degradation

All integrated components handle Redis failures gracefully:

- **AdminNotificationService**: Continues user operations even if notifications fail
- **GoogleSheets::RateLimiter**: Disables rate limiting when Redis is unavailable
- **AI::CachingService**: Returns data even if caching fails
- **HealthController**: Provides detailed diagnostics even during failures

## Configuration

### Environment Variables

- `REDIS_URL` - Redis connection URL (supports both `redis://` and `rediss://`)
- `LOG_REDIS_ERRORS_IN_TEST` - Enable Redis error logging in test environment
- `VERBOSE_REDIS_LOGGING` - Enable verbose Redis logging

### Application Configuration

```ruby
# Enable Redis error logging in test environment
Rails.application.config.log_redis_errors_in_test = true

# Enable verbose Redis logging
Rails.application.config.verbose_redis_logging = true
```

## Usage Examples

### Basic Error Logging

```ruby
begin
  # Redis operation that might fail
  Redis.current.get('some_key')
rescue Redis::CannotConnectError => e
  RedisErrorLogger.log_connection_error(e, {
    component: 'my_service',
    operation: 'get_cached_data',
    key: 'some_key'
  })
end
```

### Connection Testing

```ruby
# Test Redis connection for a specific component
if RedisErrorLogger.test_and_log_connection(component: 'sidekiq')
  # Redis is available, proceed with operations
else
  # Redis is unavailable, use fallback behavior
end
```

### Getting Diagnostics

```ruby
# Get comprehensive Redis diagnostics
diagnostics = RedisErrorLogger.get_connection_diagnostics
puts "Redis Status: #{diagnostics[:connection_status]}"
puts "Redis Version: #{diagnostics[:redis_version]}"
```

## Monitoring and Maintenance

### Rake Tasks

```bash
# Run comprehensive Redis diagnostics
bundle exec rake redis:diagnostics

# Test SSL configuration
bundle exec rake redis:test_ssl

# Clear error statistics
bundle exec rake redis:clear_error_stats
```

### Health Checks

The `/health/detailed` endpoint now includes comprehensive Redis diagnostics:

```json
{
  "status": "ok",
  "checks": {
    "redis": {
      "status": "ok",
      "message": "Redis connection successful",
      "diagnostics": {
        "redis_version": "7.2.4",
        "connected_clients": "2",
        "used_memory_human": "1.21M"
      }
    }
  }
}
```

### Production Monitoring

In production, the system automatically:

- Monitors Redis connections every 5 minutes
- Logs connection failures and recoveries
- Sends critical errors to Sentry
- Tracks error metrics for analysis

## Benefits

1. **Comprehensive Visibility**: Full visibility into Redis operations and failures
2. **Graceful Degradation**: Application continues to function even when Redis is unavailable
3. **Enhanced Debugging**: Detailed context and diagnostics for troubleshooting
4. **Production Monitoring**: Automated monitoring and alerting for Redis issues
5. **SSL Support**: Full support for Heroku Redis SSL configuration
6. **Centralized Logging**: Consistent error logging across all Redis integrations

## Requirements Satisfied

This implementation satisfies the following requirements from the Redis SSL Configuration spec:

- **4.1**: Enhanced error logging across all Redis integrations
- **4.4**: Context information and masked connection details in logs
- **Sentry Integration**: Automatic error tracking when Sentry is available
- **SSL Configuration**: Comprehensive SSL configuration logging and diagnostics

The system provides a robust foundation for Redis error handling and monitoring in production environments.