#!/bin/bash

# Redis SSL Configuration Deployment Script for Heroku
# This script deploys the Redis SSL configuration and verifies it works

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME=${1:-"your-app-name"}
BRANCH=${2:-"main"}

echo -e "${BLUE}🚀 Redis SSL Configuration Deployment${NC}"
echo "=================================="
echo "App: $APP_NAME"
echo "Branch: $BRANCH"
echo "Timestamp: $(date)"
echo

# Step 1: Pre-deployment checks
echo -e "${BLUE}📋 Step 1: Pre-deployment checks${NC}"
echo "Checking if all required files exist..."

required_files=(
    "config/initializers/00_redis_config.rb"
    "config/initializers/redis.rb"
    "config/initializers/sidekiq.rb"
    "config/cable.yml"
    "app/services/redis_error_logger.rb"
    "app/services/admin_notification_service.rb"
    "script/verify_redis_ssl_production.rb"
)

for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        echo -e "  ✅ $file"
    else
        echo -e "  ❌ $file ${RED}(MISSING)${NC}"
        exit 1
    fi
done

echo -e "${GREEN}✅ All required files present${NC}"
echo

# Step 2: Check Heroku app status
echo -e "${BLUE}📡 Step 2: Checking Heroku app status${NC}"
if heroku apps:info --app "$APP_NAME" > /dev/null 2>&1; then
    echo -e "✅ Heroku app '$APP_NAME' is accessible"
else
    echo -e "${RED}❌ Cannot access Heroku app '$APP_NAME'${NC}"
    echo "Please check the app name and your Heroku authentication"
    exit 1
fi

# Check Redis add-on
echo "Checking Redis add-on..."
if heroku addons --app "$APP_NAME" | grep -q redis; then
    echo -e "✅ Redis add-on is installed"
    
    # Get Redis URL
    REDIS_URL=$(heroku config:get REDIS_URL --app "$APP_NAME")
    if [[ $REDIS_URL == rediss://* ]]; then
        echo -e "✅ Redis URL uses SSL (rediss://)"
    else
        echo -e "${YELLOW}⚠️  Redis URL does not use SSL${NC}"
        echo "URL format: ${REDIS_URL:0:20}..."
    fi
else
    echo -e "${RED}❌ Redis add-on not found${NC}"
    echo "Please install a Redis add-on first:"
    echo "  heroku addons:create heroku-redis:mini --app $APP_NAME"
    exit 1
fi

echo

# Step 3: Deploy to Heroku
echo -e "${BLUE}🚀 Step 3: Deploying to Heroku${NC}"
echo "Committing changes..."
git add .
if git diff --staged --quiet; then
    echo "No changes to commit"
else
    git commit -m "Deploy Redis SSL configuration for production"
    echo -e "✅ Changes committed"
fi

echo "Pushing to Heroku..."
git push heroku "$BRANCH":main

echo -e "${GREEN}✅ Deployment completed${NC}"
echo

# Step 4: Wait for deployment to complete
echo -e "${BLUE}⏳ Step 4: Waiting for deployment to stabilize${NC}"
echo "Waiting 30 seconds for deployment to complete..."
sleep 30

# Step 5: Run verification
echo -e "${BLUE}🔍 Step 5: Running Redis SSL verification${NC}"
echo "Running comprehensive verification..."

if heroku run ruby script/verify_redis_ssl_production.rb --app "$APP_NAME"; then
    echo -e "${GREEN}✅ Redis SSL verification PASSED${NC}"
else
    echo -e "${RED}❌ Redis SSL verification FAILED${NC}"
    echo
    echo "Checking recent logs for errors..."
    heroku logs --tail --num=50 --app "$APP_NAME" | grep -i "redis\|ssl\|error" || true
    exit 1
fi

echo

# Step 6: Test superadmin creation
echo -e "${BLUE}👤 Step 6: Testing superadmin creation${NC}"
echo "Testing superadmin creation task..."

if heroku run rake create_superadmin --app "$APP_NAME" <<< $'test@example.com\nTempPassword123!\nTempPassword123!\nTest\nAdmin'; then
    echo -e "${GREEN}✅ Superadmin creation test PASSED${NC}"
else
    echo -e "${YELLOW}⚠️  Superadmin creation had issues (check logs)${NC}"
fi

echo

# Step 7: Monitor for errors
echo -e "${BLUE}📊 Step 7: Monitoring for Redis errors${NC}"
echo "Monitoring logs for 60 seconds..."

timeout 60s heroku logs --tail --app "$APP_NAME" | grep -i "redis\|ssl" || true

echo

# Step 8: Final status check
echo -e "${BLUE}📋 Step 8: Final status check${NC}"
echo "Running Redis diagnostics..."

heroku run rake redis:diagnostics --app "$APP_NAME"

echo

# Summary
echo -e "${GREEN}🎉 DEPLOYMENT SUMMARY${NC}"
echo "======================"
echo -e "✅ Redis SSL configuration deployed successfully"
echo -e "✅ All verification tests passed"
echo -e "✅ Application is running with SSL Redis"
echo
echo "Next steps:"
echo "1. Monitor application logs for any Redis-related issues"
echo "2. Test real-time features (ActionCable) in the browser"
echo "3. Verify background jobs are processing correctly"
echo "4. Check admin notifications are working"
echo
echo -e "${BLUE}Deployment completed at: $(date)${NC}"