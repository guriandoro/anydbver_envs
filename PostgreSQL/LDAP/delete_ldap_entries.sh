#!/bin/bash

# Script to delete LDAP entries in the correct order
# Usage: ./delete_ldap_entries.sh

# LDAP server details
LDAP_HOST="localhost"
LDAP_PORT=389
ADMIN_DN="cn=ldapadm,dc=percona,dc=local"
ADMIN_PASSWORD="secret"

# Function to delete an LDAP entry
delete_entry() {
    local dn="$1"
    echo "Deleting entry: $dn"
    ldapdelete -x -H ldap://${LDAP_HOST}:${LDAP_PORT} \
        -D "${ADMIN_DN}" \
        -w "${ADMIN_PASSWORD}" \
        "$dn"
}

echo "Starting LDAP entries deletion..."

# 1. Delete users (leaf nodes)
echo "Deleting users..."
delete_entry "uid=dba,ou=People,dc=percona,dc=local"
delete_entry "uid=perconaro,ou=People,dc=percona,dc=local"
delete_entry "uid=postgres,ou=People,dc=percona,dc=local"

# 2. Delete groups
echo "Deleting groups..."
delete_entry "cn=dbas,ou=Group,dc=percona,dc=local"
delete_entry "cn=developers,ou=Group,dc=percona,dc=local"

# 3. Delete organizational units
echo "Deleting organizational units..."
delete_entry "ou=People,dc=percona,dc=local"
delete_entry "ou=Group,dc=percona,dc=local"

# 4. Delete the admin user
echo "Deleting admin user..."
delete_entry "cn=ldapadm,dc=percona,dc=local"

# 5. Finally, delete the base DN
echo "Deleting base DN..."
delete_entry "dc=percona,dc=local"

echo "LDAP entries deletion completed." 
