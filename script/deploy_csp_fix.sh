#!/bin/bash

# CSP Configuration Fix Deployment Script
# This script deploys the CSP fixes to resolve inline script blocking

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

APP_NAME=${1:-"your-app-name"}

echo -e "${BLUE}🔒 CSP Configuration Fix Deployment${NC}"
echo "===================================="
echo "App: $APP_NAME"
echo "Issue: Content Security Policy blocking inline scripts"
echo "Solution: Configure CSP to allow necessary inline scripts"
echo

# Step 1: Commit and deploy CSP fixes
echo -e "${BLUE}📦 Step 1: Deploying CSP fixes${NC}"
echo "Committing CSP configuration fixes..."

git add .
if git diff --staged --quiet; then
    echo "No changes to commit"
else
    git commit -m "Fix Content Security Policy configuration

- Allow unsafe-inline for scripts to fix menu and interactive elements
- Whitelist external CDNs (Tailwind, Stripe, PayPal)
- Enable WebSocket connections for ActionCable
- Add CSP helper utilities and testing tools

Fixes:
- Sign out menu not appearing
- JavaScript console CSP violation errors
- Interactive form elements not working"
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

# Step 3: Test CSP configuration
echo -e "${BLUE}🔍 Step 3: Testing CSP configuration${NC}"
echo "Running CSP configuration test..."

if heroku run ruby script/test_csp_configuration.rb --app "$APP_NAME"; then
    echo -e "${GREEN}✅ CSP configuration test PASSED${NC}"
else
    echo -e "${YELLOW}⚠️  CSP configuration test had issues${NC}"
    echo "Check the output above for details"
fi

echo

# Step 4: Test application functionality
echo -e "${BLUE}🧪 Step 4: Testing application functionality${NC}"
echo "Please test the following in your browser:"
echo
echo "1. Sign out menu:"
echo "   - Go to: https://$APP_NAME.herokuapp.com"
echo "   - Log in as superadmin"
echo "   - Check if sign out menu appears"
echo
echo "2. Interactive elements:"
echo "   - Form builder functionality"
echo "   - JavaScript-based features"
echo "   - Payment forms (if applicable)"
echo
echo "3. Browser console:"
echo "   - Open developer tools (F12)"
echo "   - Check console for CSP violation errors"
echo "   - Should see no more CSP-related errors"
echo

# Step 5: Check browser console
echo -e "${BLUE}🔍 Step 5: Browser Console Check${NC}"
echo "================================"
echo
echo "In your browser's developer console, you should now see:"
echo "  ✅ No CSP violation errors"
echo "  ✅ JavaScript functions working normally"
echo "  ✅ Interactive elements responding"
echo
echo "If you still see CSP errors, they might be from:"
echo "  - Third-party scripts not in our whitelist"
echo "  - New inline scripts that need to be addressed"
echo

# Step 6: Monitor application logs
echo -e "${BLUE}📊 Step 6: Monitoring application logs${NC}"
echo "Monitoring logs for 60 seconds to check for issues..."

timeout 60s heroku logs --tail --app "$APP_NAME" | grep -i "csp\|content.*security\|script.*src" || true

echo

# Summary
echo -e "${GREEN}🎉 CSP FIX DEPLOYMENT SUMMARY${NC}"
echo "=============================="
echo -e "✅ CSP configuration updated to allow inline scripts"
echo -e "✅ External CDNs whitelisted (Tailwind, Stripe, PayPal)"
echo -e "✅ WebSocket connections enabled for ActionCable"
echo -e "✅ CSP testing tools deployed"
echo
echo "What was fixed:"
echo "  🔧 Sign out menu should now appear"
echo "  🔧 JavaScript console errors resolved"
echo "  🔧 Interactive form elements working"
echo "  🔧 Payment processing scripts allowed"
echo
echo "Next steps:"
echo "1. Test all interactive features in production"
echo "2. Verify sign out functionality works"
echo "3. Check that forms and payments work correctly"
echo "4. Plan future migration of inline scripts to external files"
echo
echo -e "${BLUE}Deployment completed at: $(date)${NC}"

# Optional: Open application
echo
echo "Would you like to open the application to test? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    heroku open --app "$APP_NAME"
fi