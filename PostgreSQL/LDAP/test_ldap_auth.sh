#!/bin/bash

# =============================================================================
# PostgreSQL LDAP Authentication Test Script
# =============================================================================
#
# This script tests the PostgreSQL LDAP authentication configuration
# by connecting to PostgreSQL with the LDAP user credentials.
#
# Prerequisites:
# - The anydbver environment must be running
# - OpenLDAP must be configured with the test user (pguser)
# - PostgreSQL must be configured for LDAP authentication
#
# Connection details:
# - Username: pguser
# - Password: secret123 (from LDAP)
# - Database: testdb
# =============================================================================

# Configuration - Change this to match the namespace in deploy_pg_ldap.sh
NAMESPACE="pg-ldap"

echo "Testing PostgreSQL LDAP authentication..."
echo "Connecting to PostgreSQL with LDAP user 'pguser'..."
echo "Password (when prompted): secret123"
echo ""

# Create a simple test query
anydbver -n $NAMESPACE exec node1 -- bash -c "cat > /tmp/test.sql << 'EOT'
\echo 'Connected successfully to PostgreSQL using LDAP authentication!'
\echo 'Current user:' \`SELECT current_user;\`
\echo 'Current database:' \`SELECT current_database();\`
CREATE TABLE IF NOT EXISTS ldap_test (
  id SERIAL PRIMARY KEY,
  message TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO ldap_test (message) VALUES ('LDAP authentication is working!');
SELECT * FROM ldap_test;
EOT"

# Run the test query with LDAP authentication
anydbver -n $NAMESPACE exec node1 -- bash -c "PGPASSWORD=secret123 psql -h localhost -U pguser -d testdb -f /tmp/test.sql" 
