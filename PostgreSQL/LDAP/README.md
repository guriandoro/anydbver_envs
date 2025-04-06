# PostgreSQL with LDAP Authentication

This project sets up a PostgreSQL environment with LDAP authentication using anydbver. It includes scripts for deploying and configuring both PostgreSQL and OpenLDAP servers.

## Environment Overview

The environment consists of:
- PostgreSQL server configured for LDAP authentication
- OpenLDAP server for user management
- Scripts for deployment, configuration, and testing

## Authentication Methods

The system supports two authentication methods:

1. **Local Authentication (Peer)**
   - Used for local connections (Unix domain socket)
   - Authenticates based on the operating system user name
   - No password required
   - Example: `sudo -u postgres psql`

2. **LDAP Authentication**
   - Used for all remote connections
   - Authenticates against the OpenLDAP server
   - Requires valid LDAP credentials
   - Example: `psql -h localhost -U pguser -d testdb`

## LDAP Structure

The LDAP directory is organized as follows:
```
dc=percona,dc=local (base DN)
└── ou=dbusers (organizational unit)
    └── uid=pguser (test database user)
```

### LDAP Credentials

- **LDAP Admin User:**
  - DN: `cn=ldapadm,dc=percona,dc=local`
  - Password: `secret`

- **Test Database User:**
  - Username: `pguser`
  - Password: `secret123`
  - Full DN: `uid=pguser,ou=dbusers,dc=percona,dc=local`

## Scripts

1. `deploy_pg_ldap.sh`: Deploys PostgreSQL and OpenLDAP servers
   - Usage: `./deploy_pg_ldap.sh [NAMESPACE]`
   - Default namespace: pg-ldap

2. `configure_pg_ldap.sh`: Configures PostgreSQL for LDAP authentication
   - Sets up pg_hba.conf with both peer and LDAP authentication
   - Configures LDAP authentication parameters

3. `add_ldap_user.sh`: Adds a new user to OpenLDAP
   - Creates the LDAP directory structure
   - Adds the test user (pguser)

4. `delete_ldap_entries.sh`: Cleans up LDAP entries
   - Removes all entries in the correct order
   - Useful for resetting the LDAP structure

## Usage

1. Deploy the environment:
   ```bash
   ./deploy_pg_ldap.sh
   ```

2. Configure LDAP authentication:
   ```bash
   ./configure_pg_ldap.sh
   ```

3. Add LDAP users:
   ```bash
   ./add_ldap_user.sh
   ```

## Testing Authentication

To test PostgreSQL authentication:

1. Local connection (peer authentication):
   ```bash
   sudo -u postgres psql
   ```

2. Remote connection (LDAP authentication):
   ```bash
   psql -h localhost -U pguser -d testdb
   ```
   Password: secret123

3. Verify LDAP structure:
   ```bash
   ldapsearch -x -H ldap://localhost:389 \
     -D "cn=ldapadm,dc=percona,dc=local" \
     -w secret \
     -b "dc=percona,dc=local" \
     "(objectClass=*)"
   ```

## Cleanup

To reset the LDAP structure:
```bash
./delete_ldap_entries.sh
./add_ldap_user.sh
```

## Customization

You can customize the following:
- Namespace: Pass as argument to deploy_pg_ldap.sh
- LDAP structure: Modify create_ldap_user.ldif
- PostgreSQL configuration: Modify configure_pg_ldap.sh 