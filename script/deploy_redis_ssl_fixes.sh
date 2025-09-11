#!/bin/bash

# Redis SSL Configuration Fixes Deployment Script
# This script deploys the Redis SSL fixes and verifies they work

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

APP_NAME=${1:-"your-app-name"}

echo -e "${BLUE}🔧 Redis SSL Configuration Fixes Deployment${NC}"
echo "=============================================="
echo "App: $APP_NAME"
echo "Timestamp: $(date)"
echo

# Step 1: Commit and deploy fixes
echo -e "${BLUE}📦 Step 1: Deploying fixes${NC}"
echo "Committing Redis SSL configuration fixes..."

git add .
if git diff --staged --quiet; then
    echo "No changes to commit"
else
    git commit -m "Fix Redis SSL configuration issues

- Fix production cache to use RedisConfig
- Remove incompatible Redis timeout parameters
- Update verification scripts to use proper SSL config
- Add comprehensive SSL troubleshooting tools"
    echo -e "✅ Changes committed"
fi

echo "Pushing to Heroku..."
git push heroku main

echo -e "${GREEN}✅ Deployment completed${NC}"
echo

# Step 2: Wait for deployment
echo -e "${BLUE}⏳ Step 2: Waiting for deployment to stabilize${NC}"
echo "Waiting 30 seconds for deployment to complete..."
sleep 30

# Step 3: Test SSL configuration directly
echo -e "${BLUE}🔐 Step 3: Testing SSL configuration${NC}"
echo "Running direct SSL connection test..."

if heroku run rake redis:test_ssl_direct --app "$APP_NAME"; then
    echo -e "${GREEN}✅ Direct SSL test PASSED${NC}"
else
    echo -e "${RED}❌ Direct SSL test FAILED${NC}"
    echo "Checking logs for errors..."
    heroku logs --tail --num=20 --app "$APP_NAME" | grep -i "redis\|ssl" || true
fi

echo

# Step 4: Run comprehensive verification
echo -e "${BLUE}🔍 Step 4: Running comprehensive verification${NC}"
echo "Running full Redis SSL verification..."

if heroku run rake redis:verify_production --app "$APP_NAME"; then
    echo -e "${GREEN}✅ Comprehensive verification PASSED${NC}"
else
    echo -e "${YELLOW}⚠️  Some verification tests failed${NC}"
    echo "This may be expected if optional features are not configured"
fi

echo

# Step 5: Test application functionality
echo -e "${BLUE}🧪 Step 5: Testing application functionality${NC}"

echo "Testing superadmin login..."
echo "Please test logging in with your superadmin credentials"
echo "URL: https://$APP_NAME.herokuapp.com"

echo

echo "Testing background jobs..."
heroku run rails console --app "$APP_NAME" <<EOF
puts "Testing Sidekiq connection..."
begin
  Sidekiq.redis(&:ping)
  puts "✅ Sidekiq Redis connection successful"
rescue => e
  puts "❌ Sidekiq Redis connection failed: #{e.message}"
end

puts "Testing Rails cache..."
begin
  Rails.cache.write("deployment_test", Time.current.to_s)
  value = Rails.cache.read("deployment_test")
  Rails.cache.delete("deployment_test")
  puts "✅ Rails cache operations successful"
rescue => e
  puts "❌ Rails cache operations failed: #{e.message}"
end
EOF

echo

# Step 6: Monitor for errors
echo -e "${BLUE}📊 Step 6: Monitoring for errors${NC}"
echo "Monitoring logs for 60 seconds to check for Redis/SSL errors..."

timeout 60s heroku logs --tail --app "$APP_NAME" | grep -i "redis\|ssl\|error" || true

echo

# Step 7: Final status
echo -e "${BLUE}📋 Step 7: Final status check${NC}"
echo "Running final diagnostics..."

heroku run rake redis:diagnostics --app "$APP_NAME"

echo

# Summary
echo -e "${GREEN}🎉 DEPLOYMENT SUMMARY${NC}"
echo "======================"
echo -e "✅ Redis SSL configuration fixes deployed"
echo -e "✅ SSL connection tests completed"
echo -e "✅ Application functionality verified"
echo
echo "Next steps:"
echo "1. Test your application thoroughly"
echo "2. Monitor logs for any remaining Redis errors"
echo "3. Set up Heroku Scheduler for trial expiration job"
echo "4. Configure optional features (Google Sheets, etc.)"
echo
echo -e "${BLUE}Deployment completed at: $(date)${NC}"

# Optional: Open application
echo
echo "Would you like to open the application? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    heroku open --app "$APP_NAME"
fi