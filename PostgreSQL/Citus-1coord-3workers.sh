anydbver --namespace=citus deploy \
node0 pg:latest \
node1 pg:latest \
node2 pg:latest \
node3 pg:latest 

# Check network address, if needed, to change pg_hba.conf rule
anydbver --namespace=citus exec node0 -- ip a

cat <<EOF >/tmp/run_alters.sql
 alter system set wal_level = 'logical';
 alter system set listen_addresses = '*';
 alter system set ssl = 'on';
 show shared_preload_libraries;
 alter system set shared_preload_libraries = 'citus';
 create database db01;
EOF

cat <<EOF >/tmp/run_citus.sh
 sudo -u postgres psql db01 -c "create extension citus";
EOF

cat <<EOF >/tmp/run_setup.sh
echo -n "Running setup in: "
hostname
yum -y install citus_16.x86_64
sudo -u postgres psql < run_alters.sql
sed -i -e 's/local   all             all/hostssl all all 192.168.0.0\/16 trust\nlocal all all/' /var/lib/pgsql/16/data/pg_hba.conf
cd /var/lib/pgsql/16/data/
openssl req -nodes -new -x509 -keyout server.key -out server.crt -subj '/C=US/L=NYC/O=Percona/CN=postgres'
chmod 400 server.{crt,key}
chown postgres:postgres server.{crt,key}
systemctl restart postgresql-16
cd
bash /run_citus.sh
EOF

# Run setup steps on all nodes
for node in node0 node1 node2 node3; do
  echo; echo "## Setup for" $node
  docker cp /tmp/run_alters.sql citus-$(whoami|tr '.' '-')-$node:run_alters.sql
  docker cp /tmp/run_citus.sh citus-$(whoami|tr '.' '-')-$node:run_citus.sh
  docker cp /tmp/run_setup.sh citus-$(whoami|tr '.' '-')-$node:run_setup.sh
  anydbver --namespace=citus exec $node -- bash run_setup.sh
done

# On coordinator node only
{
echo "SELECT citus_set_coordinator_host('node0', 5432);"
echo "SELECT citus_add_node('node1', 5432);"
echo "SELECT citus_add_node('node2', 5432);"
echo "SELECT citus_add_node('node3', 5432);"
echo "SELECT citus_get_active_worker_nodes();"
} | anydbver --namespace=citus exec node0 -- sudo -u postgres psql -Upostgres db01

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

# Explain query
SET citus.explain_all_tasks = 1;
EXPLAIN (ANALYZE, VERBOSE, BUFFERS) SELECT * FROM myevents WHERE device_id=36 OR device_id=100;
