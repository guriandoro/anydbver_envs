#!/bin/bash

anydbver --namespace=citus deploy \
node0 pg:16 \
node1 pg:16 \
node2 pg:16 \
node3 pg:16 

# Get node0's IP address to automatically edit pg_hba.conf rule below
ANYNET=`anydbver --namespace=citus exec node0 -- ip a | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d '/' -f1`
echo "IP address for node0 is" $ANYNET

# Run setup steps on all nodes
for NODE in node0 node1 node2 node3; do
  anydbver --namespace=citus exec $NODE <<EOF
echo; echo -n "# Running setup in: "
hostname
yum -q -y install citus_16.x86_64
{
echo "alter system set wal_level = 'logical';"
echo "alter system set listen_addresses = '*';"
echo "alter system set ssl = 'on';"
echo "show shared_preload_libraries;"
echo "alter system set shared_preload_libraries = citus,pg_stat_statements;"
echo "create database db01;"
} | sudo -u postgres psql
echo "# Running sed"
sed -i -e '0,/^host / s/^host /hostssl all all ${ANYNET}\/24 trust\nhost /' /var/lib/pgsql/16/data/pg_hba.conf
cd /var/lib/pgsql/16/data/
echo "# Running openssl"
openssl req -nodes -new -x509 -keyout server.key -out server.crt -subj '/C=US/L=NYC/O=Percona/CN=postgres' 2>/dev/null
chmod 400 server.{crt,key}
chown postgres:postgres server.{crt,key}
echo "# Restarting postgres service"
systemctl restart postgresql-16
sudo -u postgres psql db01 -c "create extension citus; create extension pg_stat_statements;";
EOF
done

# On coordinator node only
{
echo "SELECT citus_set_coordinator_host('node0', 5432);"
echo "SELECT citus_add_node('node1', 5432);"
echo "SELECT citus_add_node('node2', 5432);"
echo "SELECT citus_add_node('node3', 5432);"
echo "SELECT citus_get_active_worker_nodes();"
} | anydbver --namespace=citus exec node0 -- sudo -u postgres psql -Upostgres db01

### END OF SCRIPT ###

# Some misc tests
# Connect to coordinator
anydbver --namespace=citus exec node0 -- sudo -u postgres psql -Upostgres db01

# Optionally enable logging of commands
#ALTER SYSTEM SET citus.log_remote_commands=on;
#SELECT pg_reload_conf();

# Get active workers
SELECT * from master_get_active_worker_nodes() ORDER BY 1;

# Create distributed table
CREATE TABLE myevents (
    device_id bigint,
    event_id bigserial,
    event_time timestamptz default now(),
    data jsonb not null,
    primary key (device_id, event_id)
);
SELECT create_distributed_table('myevents', 'device_id');

# Get distributed tables
SELECT * FROM citus_tables;

# Get shards
SELECT shard_name, citus_table_type, nodename, shard_size 
FROM citus_shards;

# Insert data into table
INSERT INTO myevents (device_id, data) 
  SELECT s % 100, ('{"measurement":'||random()||'}')::jsonb
  FROM generate_series(1,1000000) s;

# We can use the "get" queries above to see how stats changed for table and shard sizes
SELECT * FROM citus_tables;
SELECT * FROM citus_shards;

# Get Citus queries
SELECT * FROM citus_stat_statements;

# Explain query
SET citus.explain_all_tasks = 1;
EXPLAIN (ANALYZE, VERBOSE, BUFFERS) SELECT * FROM myevents WHERE device_id=36 OR device_id=100;
