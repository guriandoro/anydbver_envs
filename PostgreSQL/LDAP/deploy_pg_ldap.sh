#!/bin/bash

# =============================================================================
# PostgreSQL with LDAP Authentication Deployment Script
# =============================================================================
#
# This script sets up a two-node environment using anydbver:
# - node0: OpenLDAP server
# - node1: PostgreSQL server configured to authenticate against the LDAP server
#
# The environment is created in a dedicated namespace (pg-ldap) to avoid
# conflicts with other anydbver deployments.
#
# After deployment, you can:
# 1. Run ./add_ldap_user.sh to create a test user in LDAP
# 2. Configure PostgreSQL to authenticate against LDAP
# 3. Test LDAP authentication with the created user
#
# Environment details:
# - LDAP server on node0:
#   - Admin DN: cn=admin,dc=example,dc=com
#   - Admin password: admin
#   - Base DN: dc=example,dc=com
#
# - PostgreSQL server on node1:
#   - Default superuser: postgres
#   - Will be configured to authenticate via LDAP on node0
# =============================================================================

# Configuration - Change this to use a different namespace
NAMESPACE="pg-ldap"

# Check if anydbver is installed
if ! command -v anydbver &> /dev/null; then
    echo "Error: anydbver is not installed"
    echo "Please install anydbver first from: https://github.com/ihanick/anydbver"
    exit 1
fi

# Clean up any existing deployment in the namespace
# This ensures we start fresh
echo "Cleaning up any existing deployment in $NAMESPACE namespace..."
anydbver -n $NAMESPACE destroy

# Deploy node0 with LDAP server
# This sets up OpenLDAP with default configuration
echo "Deploying LDAP server on node0..."
anydbver -n $NAMESPACE deploy ldap

# Deploy node1 with PostgreSQL configured to use LDAP from node0
# The --keep flag ensures we don't destroy the LDAP server we just created
# ldap-master=node0 tells PostgreSQL where to find the LDAP server
echo "Deploying PostgreSQL with LDAP authentication on node1..."
anydbver -n $NAMESPACE deploy --keep node1 postgresql:17 ldap-master=node0

echo "Deployment completed!"
anydbver -n $NAMESPACE list
echo ""
echo "You can access the nodes using:"
echo "  - LDAP server (node0): anydbver -n $NAMESPACE exec node0"
echo "  - PostgreSQL server (node1): anydbver -n $NAMESPACE exec node1"
echo ""
echo "Next steps:"
echo "1. Run ./add_ldap_user.sh to create a test user in LDAP"
echo "2. Configure PostgreSQL to use LDAP authentication"
