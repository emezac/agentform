#!/bin/bash

# Heroku Scheduler Setup Script
# This script helps configure the Heroku Scheduler for trial expiration jobs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

APP_NAME=${1:-"your-app-name"}

echo -e "${BLUE}⏰ Heroku Scheduler Setup${NC}"
echo "================================"
echo "App: $APP_NAME"
echo

# Check if Heroku Scheduler add-on is installed
echo -e "${BLUE}📋 Checking Heroku Scheduler add-on...${NC}"
if heroku addons --app "$APP_NAME" | grep -q scheduler; then
    echo -e "${GREEN}✅ Heroku Scheduler is already installed${NC}"
else
    echo -e "${YELLOW}⚠️  Heroku Scheduler not found. Installing...${NC}"
    heroku addons:create scheduler:standard --app "$APP_NAME"
    echo -e "${GREEN}✅ Heroku Scheduler installed${NC}"
fi

echo

# Instructions for configuring the scheduler
echo -e "${BLUE}📅 Scheduler Configuration Instructions${NC}"
echo "========================================"
echo
echo "1. Open the Heroku Scheduler dashboard:"
echo -e "   ${BLUE}heroku addons:open scheduler --app $APP_NAME${NC}"
echo
echo "2. Add the following scheduled job:"
echo -e "   ${GREEN}Job Name:${NC} Trial Expiration Check"
echo -e "   ${GREEN}Command:${NC} bundle exec rails runner 'TrialExpirationJob.perform_now'"
echo -e "   ${GREEN}Frequency:${NC} Daily"
echo -e "   ${GREEN}Time:${NC} 09:00 UTC (or your preferred time)"
echo
echo "3. Save the scheduled job"
echo

# Alternative: Use Heroku CLI to add the job (if supported)
echo -e "${BLUE}🤖 Automated Setup (Alternative)${NC}"
echo "=================================="
echo "You can also try to add the job via CLI:"
echo
echo -e "${YELLOW}Note: This may not work on all Heroku plans${NC}"
echo -e "${BLUE}heroku run rails runner 'TrialExpirationJob.perform_now' --app $APP_NAME${NC}"
echo

# Test the job manually
echo -e "${BLUE}🧪 Testing the Job${NC}"
echo "=================="
echo "To test the trial expiration job manually:"
echo -e "${BLUE}heroku run rails runner 'TrialExpirationJob.perform_now' --app $APP_NAME${NC}"
echo

# Additional scheduler jobs that might be needed
echo -e "${BLUE}📋 Additional Recommended Jobs${NC}"
echo "================================"
echo
echo "Consider adding these additional scheduled jobs:"
echo
echo -e "${GREEN}1. Redis Health Check (Optional)${NC}"
echo "   Command: bundle exec rake redis:diagnostics"
echo "   Frequency: Daily"
echo "   Time: 08:00 UTC"
echo
echo -e "${GREEN}2. Database Cleanup (Optional)${NC}"
echo "   Command: bundle exec rails runner 'DatabaseCleanupJob.perform_now'"
echo "   Frequency: Weekly"
echo "   Time: Sunday 02:00 UTC"
echo
echo -e "${GREEN}3. Analytics Processing (Optional)${NC}"
echo "   Command: bundle exec rails runner 'AnalyticsProcessingJob.perform_now'"
echo "   Frequency: Daily"
echo "   Time: 01:00 UTC"
echo

echo -e "${GREEN}✅ Scheduler setup instructions complete!${NC}"
echo
echo "Next steps:"
echo "1. Open the scheduler dashboard and configure the jobs"
echo "2. Test the jobs manually to ensure they work"
echo "3. Monitor the logs to verify jobs are running correctly"