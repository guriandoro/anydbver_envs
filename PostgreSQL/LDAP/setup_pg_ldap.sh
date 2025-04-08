#!/bin/bash

# =============================================================================
# PostgreSQL LDAP Setup Main Script
# =============================================================================
#
# This script orchestrates the complete setup process for PostgreSQL LDAP authentication.
# It guides users through each step and executes the necessary helper scripts in order.
#
# Prerequisites:
# - anydbver must be installed
# =============================================================================

# Configuration
NAMESPACE="pg-ldap"

# Function to print section headers
print_header() {
    echo -e "\n\033[1;34m========================================\033[0m"
    echo -e "\033[1;34m$1\033[0m"
    echo -e "\033[1;34m========================================\033[0m\n"
}

# Function to check if a command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo "Error: $1 is required but not installed."
        exit 1
    fi
}

# Check prerequisites
print_header "Checking Prerequisites"
check_command anydbver

# Step 1: Deploy PostgreSQL and OpenLDAP
print_header "Step 1: Deploying PostgreSQL and OpenLDAP"
echo "This will deploy PostgreSQL and OpenLDAP using anydbver..."
read -p "Press Enter to continue or Ctrl+C to abort..."
./deploy_pg_ldap.sh

# Step 2: Configure PostgreSQL for LDAP
print_header "Step 2: Configuring PostgreSQL for LDAP Authentication"
echo "This will configure PostgreSQL to use LDAP authentication..."
read -p "Press Enter to continue or Ctrl+C to abort..."
./configure_pg_ldap.sh

# Step 3: Add LDAP User
print_header "Step 3: Adding LDAP User"
echo "This will add the test user to OpenLDAP..."
read -p "Press Enter to continue or Ctrl+C to abort..."
./add_ldap_user.sh

# Step 4: Test LDAP Credentials
print_header "Step 4: Testing LDAP Credentials"
echo "This will verify that the LDAP user can authenticate..."
read -p "Press Enter to continue or Ctrl+C to abort..."
./test_ldap_credentials.sh

# Step 5: Test PostgreSQL LDAP Authentication
print_header "Step 5: Testing PostgreSQL LDAP Authentication"
echo "This will test the complete setup by connecting to PostgreSQL using LDAP..."
read -p "Press Enter to continue or Ctrl+C to abort..."
./test_ldap_auth.sh

print_header "Setup Complete!"
echo "All steps have been completed successfully."
echo "You can now connect to PostgreSQL using LDAP authentication."
echo "To clean up, you can use the delete_ldap_entries.sh script." 
