#!/bin/bash

# =============================================================================
# LDAP User Creation Script for PostgreSQL Authentication
# =============================================================================
#
# This script adds a test user to the OpenLDAP server running on node0
# in the specified anydbver namespace. The user will be used for testing
# PostgreSQL authentication against LDAP.
#
# Prerequisites:
# - The anydbver environment must be running with the specified namespace
# - Node0 should have OpenLDAP server installed
# - The create_ldap_user.ldif file should be in the current directory
#
# User details created:
# - Username: pguser
# - Password: secret123
# - Full DN: uid=pguser,ou=dbusers,dc=percona,dc=local
#
# LDAP server details:
# - Admin DN: cn=ldapadm,dc=percona,dc=local
# - Admin password: secret
# - Base DN: dc=percona,dc=local
# =============================================================================

# Configuration - Change this to match the namespace in deploy_pg_ldap.sh
NAMESPACE="pg-ldap"

# Copy the LDIF file to the container
# The file contains definitions for a new organizational unit and user
echo "Copying LDIF file to LDAP server container..."
# Helper function to copy files to containers using docker cp
anydbver_cp() {
    local namespace=$1
    local src=$2 
    local dest=$3
    local node="${dest%%:*}"
    local container_path="${dest#*:}"
    local user=$(whoami | tr '.' '-')
    local container_name="${namespace}-${user}-${node}"
    docker cp "$src" "$container_name:$container_path"
}

anydbver_cp "$NAMESPACE" create_ldap_user.ldif "node0:/"

# Add the user to LDAP using the admin credentials
# This creates both the ou=dbusers organizational unit and the pguser user
echo "Adding new user to LDAP..."
anydbver -n $NAMESPACE exec node0 -- ldapadd -c -x -D "cn=ldapadm,dc=percona,dc=local" -w secret -f /create_ldap_user.ldif

# Verify the user was added by performing an LDAP search
# This confirms the user exists and shows all attributes
echo "Verifying user creation..."
anydbver -n $NAMESPACE exec node0 -- ldapsearch -x -D "cn=ldapadm,dc=percona,dc=local" -w secret -b "dc=percona,dc=local" "(uid=pguser)" 
