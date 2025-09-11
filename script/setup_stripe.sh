#!/bin/bash

# Stripe Integration Setup Script
# This script helps configure Stripe API keys for Heroku

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

APP_NAME=${1:-"your-app-name"}

echo -e "${BLUE}💳 Stripe Integration Setup${NC}"
echo "============================"
echo "App: $APP_NAME"
echo

# Step 1: Instructions for Stripe Dashboard
echo -e "${BLUE}📋 Step 1: Stripe Dashboard Setup${NC}"
echo "================================="
echo
echo "Before configuring Stripe, you need to:"
echo
echo "1. Go to Stripe Dashboard: https://dashboard.stripe.com/"
echo "2. Create a Stripe account or log in to existing one"
echo "3. Get your API keys:"
echo "   - Go to Developers > API keys"
echo "   - Copy your Publishable key (starts with pk_)"
echo "   - Copy your Secret key (starts with sk_)"
echo
echo "4. Set up webhooks (optional but recommended):"
echo "   - Go to Developers > Webhooks"
echo "   - Click 'Add endpoint'"
echo "   - URL: https://$APP_NAME.herokuapp.com/webhooks/stripe"
echo "   - Select events you want to listen to"
echo "   - Copy the webhook signing secret"
echo

# Step 2: Get Stripe keys from user
echo -e "${BLUE}🔑 Step 2: Stripe API Keys${NC}"
echo "=========================="
echo
echo "Please provide your Stripe API keys:"
echo

# Get publishable key
echo "Enter your Stripe Publishable Key (pk_...):"
read -r stripe_publishable_key

if [[ ! "$stripe_publishable_key" =~ ^pk_ ]]; then
    echo -e "${RED}❌ Invalid publishable key. It should start with 'pk_'${NC}"
    exit 1
fi

# Get secret key
echo "Enter your Stripe Secret Key (sk_...):"
read -s stripe_secret_key
echo

if [[ ! "$stripe_secret_key" =~ ^sk_ ]]; then
    echo -e "${RED}❌ Invalid secret key. It should start with 'sk_'${NC}"
    exit 1
fi

# Get webhook secret (optional)
echo "Enter your Stripe Webhook Secret (whsec_...) [optional, press Enter to skip]:"
read -s stripe_webhook_secret
echo

echo -e "${GREEN}✅ Stripe keys collected${NC}"

# Step 3: Set environment variables
echo -e "${BLUE}⚙️ Step 3: Setting Environment Variables${NC}"
echo "======================================="
echo

echo "Setting Stripe environment variables..."

# Set publishable key
heroku config:set STRIPE_PUBLISHABLE_KEY="$stripe_publishable_key" --app "$APP_NAME"
echo -e "${GREEN}✅ STRIPE_PUBLISHABLE_KEY set${NC}"

# Set secret key
heroku config:set STRIPE_SECRET_KEY="$stripe_secret_key" --app "$APP_NAME"
echo -e "${GREEN}✅ STRIPE_SECRET_KEY set${NC}"

# Set webhook secret if provided
if [[ -n "$stripe_webhook_secret" ]]; then
    heroku config:set STRIPE_WEBHOOK_SECRET="$stripe_webhook_secret" --app "$APP_NAME"
    echo -e "${GREEN}✅ STRIPE_WEBHOOK_SECRET set${NC}"
else
    echo -e "${YELLOW}⚠️  STRIPE_WEBHOOK_SECRET not set (optional)${NC}"
fi

# Set Stripe environment (test or live)
echo
echo "Are you using test keys or live keys? (test/live)"
read -r stripe_env

if [[ "$stripe_env" == "live" ]]; then
    heroku config:set STRIPE_ENV="live" --app "$APP_NAME"
    echo -e "${GREEN}✅ STRIPE_ENV set to live${NC}"
    echo -e "${RED}⚠️  WARNING: You are using LIVE Stripe keys. Real payments will be processed!${NC}"
else
    heroku config:set STRIPE_ENV="test" --app "$APP_NAME"
    echo -e "${GREEN}✅ STRIPE_ENV set to test${NC}"
    echo -e "${YELLOW}ℹ️  Using test mode. No real payments will be processed.${NC}"
fi

echo

# Step 4: Verify configuration
echo -e "${BLUE}🔍 Step 4: Verifying Configuration${NC}"
echo "=================================="
echo

echo "Current Stripe configuration:"
heroku config --app "$APP_NAME" | grep STRIPE || echo "No Stripe config found"

echo

# Step 5: Test the integration
echo -e "${BLUE}🧪 Step 5: Testing Stripe Integration${NC}"
echo "===================================="
echo

echo "To test your Stripe integration:"
echo
echo "1. Test in Rails console:"
echo -e "   ${BLUE}heroku run rails console --app $APP_NAME${NC}"
echo
echo "   Then run:"
echo "   # Test Stripe configuration"
echo "   puts ENV['STRIPE_PUBLISHABLE_KEY']"
echo "   puts ENV['STRIPE_SECRET_KEY']"
echo
echo "   # Test Stripe connection"
echo "   require 'stripe'"
echo "   Stripe.api_key = ENV['STRIPE_SECRET_KEY']"
echo "   Stripe::Account.retrieve"
echo

echo "2. Test webhook endpoint (if configured):"
echo "   curl -X POST https://$APP_NAME.herokuapp.com/webhooks/stripe"
echo

echo "3. Test payment processing in your application"
echo

# Step 6: Security recommendations
echo -e "${BLUE}🔒 Step 6: Security Recommendations${NC}"
echo "==================================="
echo
echo "Security best practices:"
echo
echo "✅ Never commit Stripe keys to your repository"
echo "✅ Use test keys during development"
echo "✅ Rotate your keys regularly"
echo "✅ Monitor your Stripe dashboard for suspicious activity"
echo "✅ Set up webhook signature verification"
echo "✅ Use HTTPS for all Stripe-related endpoints"
echo

# Step 7: Additional configuration
echo -e "${BLUE}⚙️ Step 7: Additional Configuration${NC}"
echo "=================================="
echo
echo "Optional environment variables you might want to set:"
echo
echo "# Stripe Connect (if using marketplace features)"
echo "# heroku config:set STRIPE_CONNECT_CLIENT_ID=ca_... --app $APP_NAME"
echo
echo "# Custom webhook endpoint path"
echo "# heroku config:set STRIPE_WEBHOOK_PATH=/custom/stripe/webhook --app $APP_NAME"
echo
echo "# Currency (default: USD)"
echo "# heroku config:set STRIPE_CURRENCY=usd --app $APP_NAME"
echo

echo -e "${GREEN}🎉 Stripe setup complete!${NC}"
echo
echo "Next steps:"
echo "1. Test the integration in Rails console"
echo "2. Configure webhook endpoints in Stripe dashboard"
echo "3. Test payment processing in your application"
echo "4. Set up monitoring and alerts for payments"
echo "5. Review Stripe's security guidelines"