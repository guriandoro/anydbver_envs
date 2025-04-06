#!/bin/bash

# Configuration - Change this to match the namespace in deploy_pg_ldap.sh
NAMESPACE="pg-ldap"

echo "Testing LDAP credentials..."

# Try with password 'secret'
echo "Trying with password 'secret'..."
anydbver -n $NAMESPACE exec node0 -- ldapsearch -x -D "cn=ldapadm,dc=percona,dc=local" -w secret -b "dc=percona,dc=local" "(objectClass=*)"

# Try with password 'admin'
echo "Trying with password 'admin'..."
anydbver -n $NAMESPACE exec node0 -- ldapsearch -x -D "cn=ldapadm,dc=percona,dc=local" -w admin -b "dc=percona,dc=local" "(objectClass=*)"

# Try with password 'percona'
echo "Trying with password 'percona'..."
anydbver -n $NAMESPACE exec node0 -- ldapsearch -x -D "cn=ldapadm,dc=percona,dc=local" -w percona -b "dc=percona,dc=local" "(objectClass=*)" 