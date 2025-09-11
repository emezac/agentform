#!/bin/bash

# Complete Third-Party Integrations Setup Script
# This script sets up both Google Sheets and Stripe integrations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

APP_NAME=${1:-"your-app-name"}

echo -e "${BLUE}🚀 Complete Third-Party Integrations Setup${NC}"
echo "============================================="
echo "App: $APP_NAME"
echo "This script will help you set up:"
echo "  📊 Google Sheets Integration"
echo "  💳 Stripe Payment Processing"
echo

# Check if scripts exist
if [[ ! -f "script/setup_google_sheets.sh" ]]; then
    echo -e "${RED}❌ Google Sheets setup script not found${NC}"
    exit 1
fi

if [[ ! -f "script/setup_stripe.sh" ]]; then
    echo -e "${RED}❌ Stripe setup script not found${NC}"
    exit 1
fi

# Make scripts executable
chmod +x script/setup_google_sheets.sh
chmod +x script/setup_stripe.sh

echo -e "${GREEN}✅ Setup scripts found and ready${NC}"
echo

# Ask user what they want to set up
echo "What would you like to set up?"
echo "1) Google Sheets only"
echo "2) Stripe only"
echo "3) Both Google Sheets and Stripe"
echo "4) Skip setup (just show instructions)"
echo
read -p "Enter your choice (1-4): " choice

case $choice in
    1)
        echo -e "${BLUE}📊 Setting up Google Sheets Integration${NC}"
        ./script/setup_google_sheets.sh "$APP_NAME"
        ;;
    2)
        echo -e "${BLUE}💳 Setting up Stripe Integration${NC}"
        ./script/setup_stripe.sh "$APP_NAME"
        ;;
    3)
        echo -e "${BLUE}📊 Setting up Google Sheets Integration${NC}"
        ./script/setup_google_sheets.sh "$APP_NAME"
        echo
        echo -e "${BLUE}💳 Setting up Stripe Integration${NC}"
        ./script/setup_stripe.sh "$APP_NAME"
        ;;
    4)
        echo -e "${YELLOW}📋 Setup Instructions${NC}"
        echo "====================="
        echo
        echo "To set up integrations later:"
        echo
        echo "Google Sheets:"
        echo "  ./script/setup_google_sheets.sh $APP_NAME"
        echo
        echo "Stripe:"
        echo "  ./script/setup_stripe.sh $APP_NAME"
        echo
        echo "Documentation:"
        echo "  docs/third_party_integrations_setup.md"
        ;;
    *)
        echo -e "${RED}❌ Invalid choice${NC}"
        exit 1
        ;;
esac

echo

# Final verification
echo -e "${BLUE}🔍 Final Verification${NC}"
echo "===================="
echo

echo "Checking current configuration..."

# Check Google Sheets
echo "Google Sheets:"
if heroku run rails console --app "$APP_NAME" -c "puts Rails.application.credentials.google_sheets.present? ? '✅ Configured' : '❌ Not configured'" 2>/dev/null; then
    echo "  Status checked"
else
    echo "  ⚠️  Could not verify Google Sheets configuration"
fi

# Check Stripe
echo "Stripe:"
stripe_keys=$(heroku config --app "$APP_NAME" | grep STRIPE | wc -l)
if [[ $stripe_keys -gt 0 ]]; then
    echo "  ✅ $stripe_keys Stripe environment variables configured"
else
    echo "  ❌ No Stripe environment variables found"
fi

echo

# Summary and next steps
echo -e "${GREEN}🎉 Integration Setup Complete!${NC}"
echo "=============================="
echo
echo "What's been configured:"
echo "  📊 Google Sheets: Check Rails credentials"
echo "  💳 Stripe: Check environment variables"
echo
echo "Next steps:"
echo "1. Test both integrations in your application"
echo "2. Set up monitoring for integration failures"
echo "3. Configure error tracking (Sentry, etc.)"
echo "4. Review security best practices"
echo "5. Train your team on managing these integrations"
echo
echo "Documentation:"
echo "  📖 docs/third_party_integrations_setup.md"
echo
echo "Testing commands:"
echo "  🧪 heroku run rails console --app $APP_NAME"
echo "  🔍 heroku config --app $APP_NAME | grep STRIPE"
echo

echo -e "${BLUE}Setup completed at: $(date)${NC}"