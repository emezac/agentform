#!/bin/bash

# Google Sheets Integration Setup Script
# This script helps configure Google Sheets API credentials for Heroku

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

APP_NAME=${1:-"your-app-name"}

echo -e "${BLUE}📊 Google Sheets Integration Setup${NC}"
echo "===================================="
echo "App: $APP_NAME"
echo

# Step 1: Instructions for Google Cloud Console
echo -e "${BLUE}📋 Step 1: Google Cloud Console Setup${NC}"
echo "======================================"
echo
echo "Before running this script, you need to:"
echo
echo "1. Go to Google Cloud Console: https://console.cloud.google.com/"
echo "2. Create a new project or select an existing one"
echo "3. Enable the Google Sheets API:"
echo "   - Go to APIs & Services > Library"
echo "   - Search for 'Google Sheets API'"
echo "   - Click 'Enable'"
echo
echo "4. Create a Service Account:"
echo "   - Go to APIs & Services > Credentials"
echo "   - Click 'Create Credentials' > 'Service Account'"
echo "   - Fill in the details and create"
echo
echo "5. Generate a JSON key:"
echo "   - Click on the created service account"
echo "   - Go to 'Keys' tab"
echo "   - Click 'Add Key' > 'Create new key' > 'JSON'"
echo "   - Download the JSON file"
echo
echo "6. Share your Google Sheets with the service account email"
echo "   (found in the JSON file as 'client_email')"
echo

# Step 2: Check if user has the JSON file
echo -e "${BLUE}📁 Step 2: JSON Credentials File${NC}"
echo "================================="
echo
echo "Do you have the Google Service Account JSON file ready? (y/n)"
read -r has_json

if [[ ! "$has_json" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⚠️  Please complete Step 1 first and then run this script again.${NC}"
    exit 1
fi

echo
echo "Please provide the path to your JSON credentials file:"
read -r json_path

if [[ ! -f "$json_path" ]]; then
    echo -e "${RED}❌ File not found: $json_path${NC}"
    exit 1
fi

echo -e "${GREEN}✅ JSON file found${NC}"

# Step 3: Parse JSON and set up credentials
echo -e "${BLUE}🔑 Step 3: Setting up Rails credentials${NC}"
echo "======================================="

# Create a temporary Ruby script to parse JSON and generate credentials
cat > /tmp/parse_google_json.rb << 'EOF'
require 'json'

json_path = ARGV[0]
app_name = ARGV[1]

begin
  json_data = JSON.parse(File.read(json_path))
  
  puts "# Add this to your Rails credentials:"
  puts "# Run: EDITOR=nano heroku run rails credentials:edit --app #{app_name}"
  puts
  puts "google_sheets:"
  puts "  type: #{json_data['type']}"
  puts "  project_id: #{json_data['project_id']}"
  puts "  private_key_id: #{json_data['private_key_id']}"
  puts "  private_key: |"
  json_data['private_key'].split('\n').each do |line|
    puts "    #{line}"
  end
  puts "  client_email: #{json_data['client_email']}"
  puts "  client_id: #{json_data['client_id']}"
  puts "  auth_uri: #{json_data['auth_uri']}"
  puts "  token_uri: #{json_data['token_uri']}"
  puts "  auth_provider_x509_cert_url: #{json_data['auth_provider_x509_cert_url']}"
  puts "  client_x509_cert_url: #{json_data['client_x509_cert_url']}"
  
rescue => e
  puts "Error parsing JSON: #{e.message}"
  exit 1
end
EOF

echo "Parsing JSON credentials..."
ruby /tmp/parse_google_json.rb "$json_path" "$APP_NAME" > /tmp/google_credentials.yml

echo -e "${GREEN}✅ Credentials parsed successfully${NC}"
echo

# Step 4: Display credentials to add
echo -e "${BLUE}📝 Step 4: Rails Credentials Configuration${NC}"
echo "=========================================="
echo
echo "Copy the following configuration to your Rails credentials:"
echo
echo -e "${YELLOW}$(cat /tmp/google_credentials.yml)${NC}"
echo

# Step 5: Instructions for adding to Rails credentials
echo -e "${BLUE}⚙️ Step 5: Adding to Rails Credentials${NC}"
echo "======================================"
echo
echo "To add these credentials to your Heroku app:"
echo
echo "1. Edit Rails credentials:"
echo -e "   ${BLUE}EDITOR=nano heroku run rails credentials:edit --app $APP_NAME${NC}"
echo
echo "2. Add the google_sheets configuration shown above"
echo
echo "3. Save and exit (Ctrl+X, then Y, then Enter in nano)"
echo
echo "4. Verify the configuration:"
echo -e "   ${BLUE}heroku run rails console --app $APP_NAME${NC}"
echo "   Then run: Rails.application.credentials.google_sheets"
echo

# Step 6: Test the integration
echo -e "${BLUE}🧪 Step 6: Testing the Integration${NC}"
echo "================================="
echo
echo "After adding the credentials, test the integration:"
echo
echo -e "${BLUE}heroku run rails console --app $APP_NAME${NC}"
echo
echo "Then run these commands in the console:"
echo
echo "# Test credentials loading"
echo "creds = Rails.application.credentials.google_sheets"
echo "puts creds.present? ? '✅ Credentials loaded' : '❌ Credentials missing'"
echo
echo "# Test Google Sheets connection (if you have a test sheet)"
echo "# Replace 'your-sheet-id' with an actual Google Sheet ID"
echo "# service = GoogleSheetsService.new"
echo "# service.test_connection('your-sheet-id')"
echo

# Cleanup
rm -f /tmp/parse_google_json.rb /tmp/google_credentials.yml

echo -e "${GREEN}🎉 Google Sheets setup instructions complete!${NC}"
echo
echo "Next steps:"
echo "1. Add the credentials to Rails using the command above"
echo "2. Test the integration in Rails console"
echo "3. Share your Google Sheets with the service account email"
echo "4. Start using Google Sheets integration in your app"