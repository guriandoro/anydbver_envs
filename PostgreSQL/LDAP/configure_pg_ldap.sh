#!/bin/bash

# =============================================================================
# PostgreSQL LDAP Authentication Configuration Script
# =============================================================================
#
# This script configures PostgreSQL on node1 to authenticate users via LDAP
# from node0 in the specified anydbver namespace.
#
# Prerequisites:
# - The anydbver environment must be running with the specified namespace
# - Node0 should have OpenLDAP server installed and configured
# - Node1 should have PostgreSQL 17 installed
# - The LDAP user should already be created (using add_ldap_user.sh)
#
# Configuration details:
# - Creates a PostgreSQL role matching the LDAP user
# - Configures pg_hba.conf with two authentication methods:
#   1. Peer authentication for local connections
#   2. LDAP authentication for remote connections
# - Sets up appropriate PostgreSQL authentication parameters
#
# LDAP connection details:
# - LDAP server: node0
# - LDAP port: 389
# - Base DN: dc=percona,dc=local
# - Search filter: uid=$username
# - Admin DN: cn=ldapadm,dc=percona,dc=local
# - Admin password: secret
# =============================================================================

# Configuration - Change this to match the namespace in deploy_pg_ldap.sh
NAMESPACE="pg-ldap"

# Add node0's IP address to node1's /etc/hosts
node0_ip=`anydbver -n $NAMESPACE exec node0 -- ip a | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1`
echo "Adding node0's IP address to node1's /etc/hosts..."
anydbver -n $NAMESPACE exec node1 -- tee -a /etc/hosts > /dev/null << EOT
$node0_ip node0
EOT

# Add LDAP configuration to pg_hba.conf
echo "Configuring PostgreSQL to use LDAP authentication..."
# Create a temporary file with the LDAP configuration
anydbver -n $NAMESPACE exec node1 -- sudo -u postgres bash -c "cat > /tmp/pg_hba.conf << 'EOT'
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             all                                     peer
# IPv4 and IPv6 local connections:
host    all             all             127.0.0.1/32           scram-sha-256
host    all             all             ::1/128                scram-sha-256
# LDAP authentication
host    all             all             0.0.0.0/0              ldap ldapserver=node0 ldapport=389 ldapbasedn=\"dc=percona,dc=local\" ldapsearchfilter=\"(uid=\$username)\" ldapbinddn=\"cn=ldapadm,dc=percona,dc=local\" ldapbindpasswd=\"secret\"
# The rest of connections using md5
host    all             all             0.0.0.0/0              md5
EOT"

# Show the pg_hba.conf file
#anydbver -n $NAMESPACE exec node1 -- sudo -u postgres bash -c "cat /tmp/pg_hba.conf"

# Backup the original pg_hba.conf
anydbver -n $NAMESPACE exec node1 -- sudo -u postgres bash -c "mv /var/lib/pgsql/17/data/pg_hba.conf /var/lib/pgsql/17/data/pg_hba.conf.bak"

# Replace the pg_hba.conf with the new configuration
anydbver -n $NAMESPACE exec node1 -- sudo -u postgres bash -c "mv /tmp/pg_hba.conf /var/lib/pgsql/17/data/pg_hba.conf"

# Create a PostgreSQL role for the LDAP user
echo "Creating PostgreSQL role for LDAP user..."
anydbver -n $NAMESPACE exec node1 -- sudo -u postgres psql -c "CREATE ROLE pguser WITH LOGIN;"
anydbver -n $NAMESPACE exec node1 -- sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON SCHEMA public TO pguser;"

# Create a test database
echo "Creating test database..."
anydbver -n $NAMESPACE exec node1 -- sudo -u postgres psql -c "CREATE DATABASE testdb;"
anydbver -n $NAMESPACE exec node1 -- sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE testdb TO pguser;"

# Reload PostgreSQL to apply new configuration
echo "Reloading PostgreSQL configuration..."
anydbver -n $NAMESPACE exec node1 -- sudo systemctl reload postgresql-17

echo "Configuration completed!"
echo "You can now connect to PostgreSQL using:"
echo "1. Local connection (peer auth): anydbver -n $NAMESPACE exec node1 -- sudo -u postgres psql"
node1_ip=`anydbver -n $NAMESPACE exec node1 -- ip a | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1`
echo "2. Remote connection (LDAP auth): anydbver -n $NAMESPACE exec node1 -- bash -c \"PGPASSWORD=secret123 psql -h $node1_ip -U pguser -d testdb\""
